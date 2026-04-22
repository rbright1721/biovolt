// =============================================================================
// classifyLogEntry — Callable Function stub.
//
// STATUS: stub. Returns a deterministic `{ type: 'other', confidence: 0 }`
// response. End-to-end plumbing is wired (auth, validation, logging, deploy,
// IAM) so Part 2.5 can swap the body out for a real Claude call without
// touching the contract, and Part 3 can build the on-device worker
// against a real live endpoint.
//
// CONTRACT — do NOT change without coordinating with the on-device worker
// in Part 3 (lib/services/log_entry_classifier_worker.dart or similar):
//
// Request shape
// -------------
//   {
//     logEntryId: string,             // required, non-empty
//     rawText: string,                // required (empty string OK)
//     occurredAt: string,             // required, ISO-8601 timestamp
//     vitals?: {                      // optional; each field optional & nullable
//       hrBpm?: number|null, hrvMs?: number|null, gsrUs?: number|null,
//       skinTempF?: number|null, spo2Percent?: number|null,
//       ecgHrBpm?: number|null
//     },
//     context?: {                     // optional context bundle
//       activeProtocols?: [{
//         id, name, type, cycleDay, cycleLength, doseDisplay,
//         route, frequency, measurementTargets
//       }],
//       fastingHours?: number|null,
//       recentEntries?: [{ type, rawText, occurredAt }]  // last N classified
//     }
//   }
//
// Response shape (success)
// ------------------------
//   {
//     logEntryId: string,             // echoed back from request
//     type: string,                   // 'other' (stub), real types in Part 2.5
//     structured: object|null,        // null (stub)
//     confidence: number,             // 0.0 (stub), 0.0–1.0 real
//     modelVersion: string,           // 'stub-v0' (stub)
//     classifiedAt: string            // ISO timestamp of classification
//   }
//
// Errors (HttpsError codes)
// -------------------------
//   'unauthenticated'  — request.auth missing
//   'invalid-argument' — a validated field is missing or malformed (message
//                        names the offending field, e.g. "logEntryId is required")
//   'internal'         — anything else (reserved; stub doesn't throw this)
//
// HARD constraints for Part 2 (this session):
//   * No Claude call, no LLM call, no fetch() to any external API.
//   * No ANTHROPIC_API_KEY or secret reads.
//   * No Firestore access.
//   * Auth check stays in place — DO NOT remove when implementing the real
//     classifier.
// =============================================================================

const { onCall, HttpsError } = require("firebase-functions/v2/https");

/**
 * Pure async handler. Exported separately so unit tests can call it with a
 * plain object for `request` rather than standing up a full
 * firebase-functions-test harness.
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

  // Log at info level so Cloud Logging captures request traffic once
  // deployed. Payload omitted to avoid logging arbitrary user-captured
  // raw text — log the shape instead of the contents.
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

  validateRequest(data);

  const response = {
    logEntryId: data.logEntryId,
    type: "other",
    structured: null,
    confidence: 0.0,
    modelVersion: "stub-v0",
    classifiedAt: new Date().toISOString(),
  };

  console.log(
    "classifyLogEntry returning:",
    "logEntryId:",
    response.logEntryId,
    "type:",
    response.type,
    "modelVersion:",
    response.modelVersion,
  );

  return response;
}

/**
 * Shallow request validation. Each thrown HttpsError names the bad field
 * in its message so the client can surface precise error text.
 *
 * @param {object} data
 */
function validateRequest(data) {
  if (typeof data.logEntryId !== "string" || data.logEntryId.length === 0) {
    throw new HttpsError(
      "invalid-argument",
      "logEntryId is required and must be a non-empty string.",
    );
  }
  if (typeof data.rawText !== "string") {
    // Empty string IS valid (pure vitals snapshot); only non-string fails.
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

  // `vitals` is optional. When present, each listed field must be a
  // number or null — shallow-typed, no range validation. Extra fields
  // are ignored so schema evolution in Part 2.5 doesn't break old
  // clients.
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

  // `context` is optional. When present, activeProtocols/recentEntries
  // must be arrays if set, and fastingHours must be numeric if set.
  // Deeper validation (per-protocol fields, etc.) is deferred —
  // deliberately loose so the stub returns cleanly for overshoot inputs
  // (see the "large context bundle" test).
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

// onCall config mirrors analyzeSession/quickCoach/journalChat — same region,
// same CORS, short timeout appropriate for a stub (the real classifier in
// Part 2.5 should fit well under 30s on average).
const classifyLogEntry = onCall(
  {
    timeoutSeconds: 30,
    memory: "256MiB",
    region: "us-central1",
    cors: true,
  },
  classifyLogEntryHandler,
);

module.exports = {
  classifyLogEntry,
  // Exported for unit tests only — call the handler directly with a mock
  // `request` object instead of instantiating firebase-functions-test.
  classifyLogEntryHandler,
};
