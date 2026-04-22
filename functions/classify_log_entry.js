// =============================================================================
// classifyLogEntry — Callable Function.
//
// Part 2.5: real Claude-powered classifier. Takes a raw user observation
// plus context (active protocols, fasting state, recent entries) and
// returns a typed classification with confidence and structured fields.
//
// CONTRACT — do NOT change without coordinating with the on-device worker
// in lib/services/log_entry_worker.dart:
//
// Request shape
// -------------
//   {
//     logEntryId: string,             // required, non-empty
//     rawText: string,                // required (empty string OK)
//     occurredAt: string,             // required, ISO-8601 timestamp
//     vitals?: {                      // optional; each field optional & nullable
//       hrBpm?, hrvMs?, gsrUs?, skinTempF?, spo2Percent?, ecgHrBpm?
//     },
//     context?: {                     // optional context bundle
//       activeProtocols?: [...],
//       fastingHours?: number|null,
//       recentEntries?: [{ type, rawText, occurredAt }]
//     }
//   }
//
// Response shape (success)
// ------------------------
//   {
//     logEntryId: string,
//     type: string,                   // one of 10 committed values — see CLASSIFIER_VOCAB
//     structured: object|null,        // per-type schema; null for note/bookmark/other
//     confidence: number,             // 0.0–1.0 after clamp/threshold rules
//     modelVersion: string,           // 'claude-sonnet-4-5-prompt-v<N>'
//     classifiedAt: string            // ISO timestamp of classification
//   }
//
// Errors (HttpsError codes)
// -------------------------
//   'unauthenticated'      — request.auth missing
//   'invalid-argument'     — a validated field is missing or malformed
//   'resource-exhausted'   — Claude rate-limit; worker retries
//   'deadline-exceeded'    — Claude timeout; worker retries
//   'internal'             — Claude error / parse error / anything else
//
// Config notes:
//   * API key: read from `process.env.ANTHROPIC_API_KEY`, which Firebase
//     Functions Gen2 loads from `functions/.env` at deploy. Matches the
//     existing `analyzeSession` / `journalChat` pattern. No
//     defineSecret binding — consistent with those functions.
//   * HTTP client: raw `node-fetch` to the Anthropic messages API.
//     Consistent with the rest of the codebase. If we migrate to the
//     official SDK later, do it for all four callables at once.
// =============================================================================

const { onCall, HttpsError } = require("firebase-functions/v2/https");
const fetch = require("node-fetch");

// -----------------------------------------------------------------------------
// Constants.
// -----------------------------------------------------------------------------

/** Bump when CLASSIFIER_SYSTEM_PROMPT changes materially. */
const CLASSIFIER_PROMPT_VERSION = "v1";

/** The 10 committed type values. The classifier cannot return anything else. */
const CLASSIFIER_VOCAB = Object.freeze([
  "dose",
  "meal",
  "symptom",
  "mood",
  "bowel_movement",
  "training",
  "sleep_subjective",
  "note",
  "bookmark",
  "other",
]);

/** Claude call timeout. Longer than the stub's 30s to allow for real
 *  model latency. Worker's client-side timeout (30s) will surface a
 *  timeout before this one fires, so this is defense-in-depth. */
const CLAUDE_TIMEOUT_MS = 45_000;

/** Confidence thresholds applied server-side before returning. See
 *  parseClaudeResponse for how these map to type/structured overrides. */
const CONFIDENCE_LOW_OVERRIDE = 0.3;   // below → force type='other'
const CONFIDENCE_GOOD_THRESHOLD = 0.7; // between 0.3 and 0.7 → add confidence_note

const CLASSIFIER_SYSTEM_PROMPT = `You are a classification assistant for BioVolt, a personal health tracking app. Users speak or type short observations about what they're doing and how they feel. Your job is to classify each observation into one of 10 types and extract structured fields.

Types:
  dose: taking a supplement, peptide, medication, or other protocol dose
  meal: eating food or drink (exclude just water)
  symptom: physical sensation that wasn't asked for — headache, nausea, fatigue, pain, GI discomfort
  mood: emotional or cognitive state — anxious, wired, focused, low, calm
  bowel_movement: describing a BM
  training: exercise, cold exposure, heat exposure, movement
  sleep_subjective: user describing their sleep quality, duration, wakeups (not automated sleep data — that comes from devices)
  note: reminder, observation, thought, measurement recorded for reference
  bookmark: empty input, vitals snapshot only, no narrative
  other: can't classify, ambiguous, or doesn't fit any type

Classification rules:
  - If the text is empty, return type='bookmark'.
  - If you can't determine the type with any reasonable confidence, return type='other'.
  - Prefer specific types over 'note'. Only use 'note' when the user is recording something for later reference that isn't a dose/meal/symptom/etc.
  - Multi-concept entries: pick the strongest signal. If a user mentions a dose AND a symptom, pick whichever seems primary from context. When in doubt, pick the symptom (it's more actionable).
  - The user may reference active protocols by shorthand (e.g., "BPC" for "BPC-157"). Match these against the provided active protocols when possible.

Confidence scoring:
  0.9-1.0: Unambiguous. "took 250mcg BPC-157" is clearly a dose.
  0.7-0.89: Likely right. "feeling wired" is probably mood but could be symptom.
  0.5-0.69: Plausible but several interpretations.
  0.3-0.49: Low confidence, best guess.
  0.0-0.29: Essentially can't tell — return 'other'.

Context provided on each request:
  - Active protocols: list with name, type, cycleDay, cycleLength, doseDisplay, route, frequency, measurementTargets. Use to match dose references and ground protocol_id.
  - Fasting hours: hint for meal classification ("just ate" after 16 hours of fasting = meaningful event).
  - Recent entries: last 5 classified entries for context. "took it again" references something recent.
  - Current time: helps with meal_kind inference (8am = breakfast).

Per-type structured schema (extract what the text supports; omit or null for missing fields):
  dose:            { protocol_name, protocol_id, dose_amount, route, site, scheduled }
  meal:            { items, quantity_note, meal_kind, estimated_kcal }
  symptom:         { symptom, severity, body_location, onset }
  mood:            { mood_type, intensity, context }
  bowel_movement:  { quality, count_today }
  training:        { activity, duration_minutes, intensity }
  sleep_subjective:{ quality, duration_hours, wakeups, notes }
  note:            null  (no extraction)
  bookmark:        null  (pure vitals snapshot)
  other:           null  (unclassifiable)

Output format: return ONLY a JSON object, no prose, no markdown fences. Schema:
  {
    "type":       "dose" | "meal" | "symptom" | "mood" | "bowel_movement" | "training" | "sleep_subjective" | "note" | "bookmark" | "other",
    "confidence": number (0.0 to 1.0),
    "structured": object | null,
    "reasoning":  string (one sentence explaining the classification, under 100 chars)
  }

The reasoning field is for debugging — it will be logged but not shown to users.`;

// -----------------------------------------------------------------------------
// Error types — internal, converted to HttpsError at the handler boundary.
// -----------------------------------------------------------------------------

class ClassifierParseError extends Error {
  constructor(message, raw) {
    super(message);
    this.name = "ClassifierParseError";
    this.raw = raw;
  }
}

class ClassifierAnthropicError extends Error {
  constructor(message, status) {
    super(message);
    this.name = "ClassifierAnthropicError";
    this.status = status;
  }
}

// -----------------------------------------------------------------------------
// Handler.
// -----------------------------------------------------------------------------

/**
 * Pure async handler. Exported separately so unit tests can call it with a
 * plain object for `request` without standing up firebase-functions-test.
 *
 * @param {{auth?: {uid: string}, data: object}} request
 * @return {Promise<object>} classification response
 */
async function classifyLogEntryHandler(request) {
  if (!request.auth) {
    throw new HttpsError(
      "unauthenticated",
      "Must be signed in to classify a log entry.",
    );
  }

  const data = request.data || {};
  validateRequest(data);

  // Observability: log shape, not content. Raw text only reappears on
  // error paths below. See Cloud Logging for the emitted structured
  // fields.
  console.log(
    "classifyLogEntry called by uid:",
    request.auth.uid,
    "logEntryId:",
    data.logEntryId,
    "rawTextLen:",
    typeof data.rawText === "string" ? data.rawText.length : "n/a",
    "hasVitals:",
    !!data.vitals,
    "hasContext:",
    !!data.context,
    "activeProtocolCount:",
    data.context?.activeProtocols?.length ?? 0,
    "recentEntryCount:",
    data.context?.recentEntries?.length ?? 0,
  );

  // Empty input is a pure vitals snapshot — no Claude call needed.
  // Save latency and API quota on every "quick save" from the sheet.
  if (data.rawText === "") {
    return {
      logEntryId: data.logEntryId,
      type: "bookmark",
      structured: null,
      confidence: 1.0,
      modelVersion: modelVersionString(),
      classifiedAt: new Date().toISOString(),
    };
  }

  // Guard before the network call so we can fail fast with a clear
  // error code. Matches the existing analyzeSession guard pattern.
  if (!process.env.ANTHROPIC_API_KEY) {
    console.error("ANTHROPIC_API_KEY is not set");
    throw new HttpsError("internal", "Classifier not configured.");
  }

  let parsed;
  try {
    const userMessage = buildUserMessage(data);
    const rawContent = await callClaude(userMessage);
    parsed = parseClaudeResponse(rawContent);
  } catch (e) {
    throw mapError(e);
  }

  const response = applyConfidenceThresholds(parsed);

  console.log(
    "classifyLogEntry returning:",
    "logEntryId:",
    data.logEntryId,
    "type:",
    response.type,
    "confidence:",
    response.confidence,
    "modelVersion:",
    modelVersionString(),
  );

  return {
    logEntryId: data.logEntryId,
    type: response.type,
    structured: response.structured,
    confidence: response.confidence,
    modelVersion: modelVersionString(),
    classifiedAt: new Date().toISOString(),
  };
}

// -----------------------------------------------------------------------------
// Request validation (unchanged from stub).
// -----------------------------------------------------------------------------

function validateRequest(data) {
  if (typeof data.logEntryId !== "string" || data.logEntryId.length === 0) {
    throw new HttpsError(
      "invalid-argument",
      "logEntryId is required and must be a non-empty string.",
    );
  }
  if (typeof data.rawText !== "string") {
    throw new HttpsError(
      "invalid-argument",
      "rawText is required and must be a string (empty string allowed).",
    );
  }
  if (typeof data.occurredAt !== "string" || data.occurredAt.length === 0) {
    throw new HttpsError(
      "invalid-argument",
      "occurredAt is required and must be an ISO-8601 timestamp string.",
    );
  }
  const parsed = Date.parse(data.occurredAt);
  if (Number.isNaN(parsed)) {
    throw new HttpsError(
      "invalid-argument",
      "occurredAt must parse as a valid date (got: " +
        JSON.stringify(data.occurredAt) + ").",
    );
  }

  if (data.vitals !== undefined && data.vitals !== null) {
    if (typeof data.vitals !== "object" || Array.isArray(data.vitals)) {
      throw new HttpsError(
        "invalid-argument",
        "vitals must be an object when provided.",
      );
    }
    const numericVitals = [
      "hrBpm", "hrvMs", "gsrUs", "skinTempF", "spo2Percent", "ecgHrBpm",
    ];
    for (const key of numericVitals) {
      const v = data.vitals[key];
      if (v === undefined || v === null) continue;
      if (typeof v !== "number" || !Number.isFinite(v)) {
        throw new HttpsError(
          "invalid-argument",
          `vitals.${key} must be a finite number or null (got ` +
            `${typeof v}: ${JSON.stringify(v)}).`,
        );
      }
    }
  }

  if (data.context !== undefined && data.context !== null) {
    if (typeof data.context !== "object" || Array.isArray(data.context)) {
      throw new HttpsError(
        "invalid-argument",
        "context must be an object when provided.",
      );
    }
    const ctx = data.context;
    if (ctx.activeProtocols !== undefined && ctx.activeProtocols !== null &&
        !Array.isArray(ctx.activeProtocols)) {
      throw new HttpsError(
        "invalid-argument",
        "context.activeProtocols must be an array when provided.",
      );
    }
    if (ctx.recentEntries !== undefined && ctx.recentEntries !== null &&
        !Array.isArray(ctx.recentEntries)) {
      throw new HttpsError(
        "invalid-argument",
        "context.recentEntries must be an array when provided.",
      );
    }
    if (ctx.fastingHours !== undefined && ctx.fastingHours !== null) {
      if (typeof ctx.fastingHours !== "number" ||
          !Number.isFinite(ctx.fastingHours)) {
        throw new HttpsError(
          "invalid-argument",
          "context.fastingHours must be a finite number or null.",
        );
      }
    }
  }
}

// -----------------------------------------------------------------------------
// User-message builder.
// -----------------------------------------------------------------------------

function buildUserMessage(data) {
  const parts = [];
  parts.push(`Current time: ${new Date().toISOString()}`);
  if (data.context?.fastingHours != null) {
    parts.push(`Fasting hours: ${data.context.fastingHours}`);
  }
  if (data.context?.activeProtocols?.length) {
    parts.push("Active protocols:");
    for (const p of data.context.activeProtocols) {
      const dose = p.doseDisplay || "";
      const freq = p.frequency || "";
      const targets = Array.isArray(p.measurementTargets)
        ? p.measurementTargets.join(",")
        : "";
      parts.push(
        `  - ${p.name} (id=${p.id}, ${p.type}, day ${p.cycleDay}/${p.cycleLength}` +
        `${dose ? `, ${dose}` : ""}` +
        `${freq ? `, ${freq}` : ""}` +
        `${targets ? `, targets=${targets}` : ""})`,
      );
    }
  }
  if (data.context?.recentEntries?.length) {
    parts.push("Recent entries:");
    for (const e of data.context.recentEntries.slice(-5)) {
      parts.push(`  - ${e.occurredAt}: [${e.type}] ${e.rawText}`);
    }
  }
  parts.push("");
  parts.push(`User observation: "${data.rawText}"`);
  parts.push("");
  parts.push("Classify and return the JSON object.");
  return parts.join("\n");
}

// -----------------------------------------------------------------------------
// Claude call.
// -----------------------------------------------------------------------------

async function callClaude(userMessage) {
  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), CLAUDE_TIMEOUT_MS);

  let response;
  try {
    response = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-api-key": process.env.ANTHROPIC_API_KEY,
        "anthropic-version": "2023-06-01",
      },
      body: JSON.stringify({
        model: "claude-sonnet-4-5",
        max_tokens: 500,
        system: CLASSIFIER_SYSTEM_PROMPT,
        messages: [{ role: "user", content: userMessage }],
      }),
      signal: controller.signal,
    });
  } catch (e) {
    if (e.name === "AbortError" || e.type === "aborted") {
      throw new ClassifierAnthropicError(
        `Classifier timed out after ${CLAUDE_TIMEOUT_MS}ms`,
        "deadline-exceeded",
      );
    }
    throw new ClassifierAnthropicError(
      `Network error calling classifier: ${e.message}`,
      "internal",
    );
  } finally {
    clearTimeout(timeoutId);
  }

  if (!response.ok) {
    const body = await response.text();
    console.error("Anthropic error:", response.status, body);
    if (response.status === 429) {
      throw new ClassifierAnthropicError(
        "Classifier rate limit.",
        "resource-exhausted",
      );
    }
    if (response.status === 408 || response.status === 504) {
      throw new ClassifierAnthropicError(
        "Classifier upstream timeout.",
        "deadline-exceeded",
      );
    }
    throw new ClassifierAnthropicError(
      `Classifier upstream ${response.status}`,
      "internal",
    );
  }

  const result = await response.json();
  const content = result?.content?.[0]?.text;
  if (typeof content !== "string" || content.length === 0) {
    throw new ClassifierParseError(
      "Anthropic response had no text content.",
      JSON.stringify(result).slice(0, 500),
    );
  }
  return content;
}

// -----------------------------------------------------------------------------
// Response parser.
// -----------------------------------------------------------------------------

function parseClaudeResponse(rawContent) {
  const json = extractJsonObject(rawContent);

  if (!json || typeof json !== "object" || Array.isArray(json)) {
    throw new ClassifierParseError(
      "Classifier response did not parse to a JSON object.",
      rawContent.slice(0, 500),
    );
  }

  if (typeof json.type !== "string" ||
      !CLASSIFIER_VOCAB.includes(json.type)) {
    throw new ClassifierParseError(
      `Classifier returned invalid type: ${JSON.stringify(json.type)}`,
      rawContent.slice(0, 500),
    );
  }

  let confidence = json.confidence;
  if (typeof confidence !== "number" || !Number.isFinite(confidence)) {
    throw new ClassifierParseError(
      `Classifier returned invalid confidence: ${JSON.stringify(confidence)}`,
      rawContent.slice(0, 500),
    );
  }
  if (confidence < 0 || confidence > 1) {
    // Clamp rather than reject — a model that returned 1.2 or -0.1
    // is trying to classify; a handful of points on the boundary
    // isn't worth a user-visible error.
    console.warn(
      `Classifier confidence out of [0,1]: ${confidence} — clamping`,
    );
    confidence = Math.max(0, Math.min(1, confidence));
  }

  let structured = json.structured;
  if (structured !== null && structured !== undefined) {
    if (typeof structured !== "object" || Array.isArray(structured)) {
      throw new ClassifierParseError(
        "Classifier returned non-object structured.",
        rawContent.slice(0, 500),
      );
    }
  } else {
    structured = null;
  }

  // Log reasoning for debugging; it never leaves the function.
  if (typeof json.reasoning === "string" && json.reasoning.length > 0) {
    console.log("classifier reasoning:", json.reasoning.slice(0, 120));
  }

  return {
    type: json.type,
    confidence,
    structured,
  };
}

/**
 * Pulls a JSON object out of Claude's response text. Tolerates:
 *   - pure JSON objects
 *   - JSON fenced in ``` / ```json
 *   - JSON with a preamble ("Sure, here's the answer: {...}")
 *
 * Throws ClassifierParseError on genuinely malformed responses.
 */
function extractJsonObject(raw) {
  let text = raw.trim();

  // Strip markdown fences.
  if (text.startsWith("```")) {
    text = text.replace(/^```(?:json)?\s*/i, "");
    text = text.replace(/\s*```$/i, "");
  }

  // Try direct parse first. Common path when the prompt is respected.
  try {
    return JSON.parse(text);
  } catch (_) {
    // Fall through.
  }

  // Brace-match fallback: find the first `{` and the matching last `}`.
  const first = text.indexOf("{");
  const last = text.lastIndexOf("}");
  if (first === -1 || last === -1 || last <= first) {
    throw new ClassifierParseError(
      "No JSON object found in classifier response.",
      raw.slice(0, 500),
    );
  }
  const candidate = text.slice(first, last + 1);
  try {
    return JSON.parse(candidate);
  } catch (e) {
    throw new ClassifierParseError(
      `JSON parse failed: ${e.message}`,
      raw.slice(0, 500),
    );
  }
}

// -----------------------------------------------------------------------------
// Confidence thresholds.
// -----------------------------------------------------------------------------

function applyConfidenceThresholds(parsed) {
  const { type, confidence } = parsed;
  let structured = parsed.structured;

  // Very low confidence on a non-'other' type → force to 'other' with
  // null structured. The model is telling us it can't tell; the
  // worker/UI shouldn't pretend to a verdict.
  if (confidence < CONFIDENCE_LOW_OVERRIDE && type !== "other") {
    return {
      type: "other",
      structured: null,
      confidence,
    };
  }

  // 'other' always returns null structured regardless of confidence —
  // there's nothing to extract and annotating with a confidence_note
  // would be misleading ("low confidence classification" reads like we
  // tried to classify and failed, not like we chose 'other' because
  // there was nothing classifiable).
  if (type === "other") {
    return {
      type,
      structured: null,
      confidence,
    };
  }

  // Medium confidence on an actual type → keep the type but flag the
  // uncertainty inside structured. For types where structured is null
  // by schema (note, bookmark), synthesize a minimal object so the
  // note survives.
  if (confidence < CONFIDENCE_GOOD_THRESHOLD) {
    const note = "Low confidence classification; may need user review.";
    if (structured === null) {
      structured = { confidence_note: note };
    } else {
      structured = { ...structured, confidence_note: note };
    }
  }

  return {
    type,
    structured,
    confidence,
  };
}

// -----------------------------------------------------------------------------
// Error → HttpsError mapping.
// -----------------------------------------------------------------------------

function mapError(e) {
  if (e instanceof HttpsError) return e;
  if (e instanceof ClassifierAnthropicError) {
    if (e.status === "resource-exhausted") {
      return new HttpsError(
        "resource-exhausted",
        "Classifier rate limit; try again shortly.",
      );
    }
    if (e.status === "deadline-exceeded") {
      return new HttpsError(
        "deadline-exceeded",
        "Classifier timed out.",
      );
    }
    return new HttpsError("internal", "Classifier unavailable.");
  }
  if (e instanceof ClassifierParseError) {
    console.error("Classifier parse error:", e.message, "raw:", e.raw);
    return new HttpsError(
      "internal",
      "Classifier returned malformed response.",
    );
  }
  console.error("Classifier unexpected error:", e);
  return new HttpsError("internal", "Classifier unavailable.");
}

// -----------------------------------------------------------------------------
// Misc helpers.
// -----------------------------------------------------------------------------

function modelVersionString() {
  return `claude-sonnet-4-5-prompt-${CLASSIFIER_PROMPT_VERSION}`;
}

// onCall config mirrors analyzeSession/quickCoach/journalChat — same
// region, same CORS. 60s timeout is a cushion over the 45s Claude
// timeout so we get a clean error response rather than a platform
// abort if the model takes its time.
const classifyLogEntry = onCall(
  {
    timeoutSeconds: 60,
    memory: "256MiB",
    region: "us-central1",
    cors: true,
  },
  classifyLogEntryHandler,
);

module.exports = {
  classifyLogEntry,
  classifyLogEntryHandler,
  // Pure helpers — exported so unit tests can exercise parse / threshold
  // logic without mocking the Anthropic network call.
  parseClaudeResponse,
  applyConfidenceThresholds,
  buildUserMessage,
  CLASSIFIER_PROMPT_VERSION,
  CLASSIFIER_VOCAB,
  CLASSIFIER_SYSTEM_PROMPT,
  // Error types surfaced for test assertions.
  ClassifierParseError,
  ClassifierAnthropicError,
};
