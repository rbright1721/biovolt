const { onCall, onRequest, HttpsError } = require("firebase-functions/v2/https");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { getAuth } = require("firebase-admin/auth");
const fetch = require("node-fetch");

initializeApp();

// ---------------------------------------------------------------------------
// PubMed helpers — search for peer-reviewed studies and extract abstracts
// to ground AI journal responses in evidence.
// ---------------------------------------------------------------------------

async function searchPubMed(query, maxResults = 3) {
  try {
    const searchUrl = new URL(
      "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi",
    );
    searchUrl.searchParams.set("db", "pubmed");
    searchUrl.searchParams.set("term", query);
    searchUrl.searchParams.set("retmax", maxResults.toString());
    searchUrl.searchParams.set("retmode", "json");
    searchUrl.searchParams.set("sort", "relevance");
    const year = new Date().getFullYear();
    searchUrl.searchParams.set("mindate", (year - 10).toString());
    searchUrl.searchParams.set("maxdate", year.toString());
    searchUrl.searchParams.set("datetype", "pdat");
    const res = await fetch(searchUrl.toString());
    const data = await res.json();
    return data.esearchresult?.idlist ?? [];
  } catch (e) {
    console.error("PubMed search error:", e);
    return [];
  }
}

async function fetchPubMedAbstracts(ids) {
  if (!ids.length) return "";
  try {
    const fetchUrl = new URL(
      "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi",
    );
    fetchUrl.searchParams.set("db", "pubmed");
    fetchUrl.searchParams.set("id", ids.join(","));
    fetchUrl.searchParams.set("retmode", "xml");
    fetchUrl.searchParams.set("rettype", "abstract");
    const res = await fetch(fetchUrl.toString());
    const xml = await res.text();
    const articles = [];
    const titleMatches = [
      ...xml.matchAll(/<ArticleTitle>([\s\S]*?)<\/ArticleTitle>/g),
    ];
    const abstractMatches = [
      ...xml.matchAll(/<AbstractText[^>]*>([\s\S]*?)<\/AbstractText>/g),
    ];
    const yearMatches = [
      ...xml.matchAll(/<PubDate>[\s\S]*?<Year>(\d{4})<\/Year>/g),
    ];
    const titles = titleMatches.map((m) =>
      m[1].replace(/<[^>]+>/g, "").trim(),
    );
    const abstracts = abstractMatches.map((m) =>
      m[1].replace(/<[^>]+>/g, "").trim(),
    );
    const years = yearMatches.map((m) => m[1]);
    for (let i = 0; i < titles.length; i++) {
      if (titles[i] && abstracts[i]) {
        articles.push(
          `Study ${i + 1} (${years[i] ?? "n/a"}): ${titles[i]}\n` +
            `Abstract: ${abstracts[i].substring(0, 600)}...`,
        );
      }
    }
    return articles.join("\n\n");
  } catch (e) {
    console.error("PubMed fetch error:", e);
    return "";
  }
}

function extractHealthKeywords(text) {
  const lower = text.toLowerCase();
  const keywords = [
    "nac", "n-acetyl", "glycine", "glutathione", "bpc", "bpc-157",
    "tb-500", "ghk", "epithalon", "ss-31", "nad", "nmn", "melatonin",
    "magnesium", "zinc", "vitamin d", "omega", "creatine", "collagen",
    "resveratrol", "berberine", "metformin", "rapamycin", "ashwagandha",
    "rhodiola", "lions mane", "fasting", "intermittent fasting",
    "ketosis", "ketogenic", "cold exposure", "cold plunge", "breathwork",
    "wim hof", "hrv", "heart rate variability", "cortisol", "testosterone",
    "inflammation", "oxidative stress", "mitochondria", "autophagy",
    "sleep", "circadian", "gut", "microbiome", "longevity", "peptide",
  ];
  return keywords.filter((k) => lower.includes(k));
}

exports.analyzeSession = onCall({
  timeoutSeconds: 60,
  memory: "256MiB",
  region: "us-central1",
  cors: true,
}, async (request) => {
  if (!request.auth) {
    throw new HttpsError(
      "unauthenticated",
      "Must be signed in to use AI analysis.",
    );
  }

  console.log("analyzeSession called by uid:", request.auth.uid);
  console.log("Request data keys:", Object.keys(request.data || {}));
  console.log("Model:", request.data?.model);
  console.log("Has messages:", Array.isArray(request.data?.messages));
  console.log("ANTHROPIC_API_KEY set:", !!process.env.ANTHROPIC_API_KEY);

  const data = request.data;

  if (!process.env.ANTHROPIC_API_KEY) {
    console.error("ANTHROPIC_API_KEY is not set");
    throw new HttpsError("internal", "API key not configured.");
  }

  try {
    console.log("Calling Anthropic API...");
    const response = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-api-key": process.env.ANTHROPIC_API_KEY,
        "anthropic-version": "2023-06-01",
      },
      body: JSON.stringify(data),
    });

    console.log("Anthropic response status:", response.status);
    const result = await response.json();

    if (!response.ok) {
      console.error("Anthropic error:", JSON.stringify(result));
      throw new HttpsError(
        "internal",
        result.error?.message ?? `Anthropic API error ${response.status}`,
      );
    }

    return result;
  } catch (error) {
    if (error instanceof HttpsError) throw error;
    console.error("analyzeSession unexpected error:", error);
    throw new HttpsError("internal", error.message);
  }
});

exports.quickCoach = onCall({
  timeoutSeconds: 15,
  memory: "128MiB",
  region: "us-central1",
  cors: true,
}, async (request) => {
  if (!request.auth) {
    throw new HttpsError(
      "unauthenticated",
      "Must be signed in to use AI coach.",
    );
  }

  console.log("quickCoach called by uid:", request.auth.uid);

  const data = request.data;

  if (!process.env.GEMINI_API_KEY) {
    console.error("GEMINI_API_KEY is not set");
    throw new HttpsError("internal", "API key not configured.");
  }

  try {
    const model = data.model ?? "gemini-2.0-flash";
    const url =
      `https://generativelanguage.googleapis.com/v1beta/models/` +
      `${model}:generateContent?key=${process.env.GEMINI_API_KEY}`;

    const response = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(data.payload),
    });

    const result = await response.json();

    if (!response.ok) {
      console.error("Gemini error:", JSON.stringify(result));
      throw new HttpsError("internal", `Gemini API error ${response.status}`);
    }

    return result;
  } catch (error) {
    if (error instanceof HttpsError) throw error;
    console.error("quickCoach unexpected error:", error);
    throw new HttpsError("internal", error.message);
  }
});

// ---------------------------------------------------------------------------
// journalChat — health journal conversation grounded in PubMed research.
// ---------------------------------------------------------------------------

exports.journalChat = onCall({
  timeoutSeconds: 45,
  memory: "256MiB",
  region: "us-central1",
  cors: true,
}, async (request) => {
  if (!request.auth) {
    throw new HttpsError(
      "unauthenticated",
      "Must be signed in to use the health journal.",
    );
  }

  console.log("journalChat called by uid:", request.auth.uid);

  const {
    userMessage,
    conversationContext,
    biologicalContext,
    researchMode,
  } = request.data;

  if (!userMessage) {
    throw new HttpsError("invalid-argument", "userMessage is required");
  }

  if (!process.env.ANTHROPIC_API_KEY) {
    throw new HttpsError("internal", "API key not configured.");
  }

  // Step 1: Detect keywords and search PubMed. In research mode we
  // always search — even if no strong health keywords surface — and
  // pull more abstracts so the synthesis has more substrate.
  let researchContext = "";
  const keywords = extractHealthKeywords(userMessage);

  if (keywords.length > 0 || researchMode) {
    const query = researchMode && keywords.length === 0
      ? userMessage.substring(0, 100)
      : keywords.slice(0, 3).join(" AND ");
    const maxResults = researchMode ? 5 : 3;
    console.log("Research mode:", !!researchMode,
      "keywords:", keywords, "query:", query);
    const ids = await searchPubMed(query, maxResults);
    console.log("PubMed IDs found:", ids);
    if (ids.length > 0) {
      const abstracts = await fetchPubMedAbstracts(ids);
      if (abstracts) {
        researchContext = abstracts;
        console.log("PubMed abstracts retrieved successfully");
      }
    }
  }

  // Step 2: Build system prompt — research mode gets a literature-synthesis
  // framing; the default stays conversational.
  const systemPrompt = researchMode
    ? `You are a health research assistant helping the user explore the
scientific literature. The user has a specific biological context
and is asking a research question; your job is to synthesize PubMed
evidence clearly and honestly.

User biological context:
${biologicalContext || "No biological context provided."}

${researchContext ? `PUBMED RESEARCH:
${researchContext}

Synthesize these studies. Cite study numbers ("Study 1 found...").
Note study quality — RCT vs observational vs case report vs review —
whenever that shapes confidence in a claim. Connect findings back to
the user's biological context when relevant. Be intellectually honest
about what the evidence does and does not show; flag small-n studies,
conflicts of interest cues (industry-funded), and mechanism-only work.
` : "No PubMed results were retrieved for this query. Say so clearly \
and reason from first principles rather than inventing citations."}

Response rules:
- Lead with what the evidence shows, not with reassurance
- Cite by study number; never fabricate citations
- Distinguish strong evidence from suggestive signals
- 2-5 paragraphs
- End with a bracketed takeaway`
    : `You are a knowledgeable health optimization AI
assistant integrated into BioVolt, a biometric tracking app.

CRITICAL: Always prioritize the user's SPECIFIC biological context and
active protocols over general information. If the user is on a specific
research-backed protocol, acknowledge that protocol explicitly.

User's biological context:
${biologicalContext || "No biological context provided."}

${researchContext ? `RELEVANT PEER-REVIEWED RESEARCH (from PubMed):
${researchContext}

Use these studies to ground your response. Cite the study number
when referencing specific findings (e.g. "Study 1 found...").
If the studies support the user's current protocol, say so clearly.
If they suggest a different approach, note it constructively.` : ""}

When the user asks you to UPDATE their data — such as
resetting their fasting clock, updating a meal time,
adding protocol notes, or logging a bookmark — respond
with your normal conversational message AND append a
JSON action block at the very end in this exact format:

<biovolt_action>
{
  "action": "update_last_meal",
  "timestamp": "ISO-8601-timestamp-of-meal"
}
</biovolt_action>

Available actions:
- update_last_meal: { "action": "update_last_meal", "timestamp": "..." }
  Use when user says they just ate, finished eating,
  broke their fast, or wants to reset fasting clock.
  Use current time if no specific time mentioned.

- update_protocol_notes: { "action": "update_protocol_notes",
  "protocolName": "NAC", "notes": "..." }
  Use when user wants to update notes on a protocol.

- log_bookmark: { "action": "log_bookmark",
  "note": "user's observation" }
  Use when user wants to log a quick note to their timeline.

Only include the action block when the user explicitly
asks to update or change something. For questions and
discussions, respond normally without an action block.

Response rules:
- Ground response in user's specific protocol context first
- Reference research studies when available
- Distinguish protocol-intentional doses from general recommendations
- Conversational but precise — 2-4 paragraphs max
- End with a bracketed insight
- Never diagnose. Frame as patterns and observations.`;

  // Step 3: Build messages
  const messages = [];
  if (conversationContext) {
    messages.push({
      role: "user",
      content: `Previous conversation:\n${conversationContext}`,
    });
    messages.push({
      role: "assistant",
      content: "I have that context noted.",
    });
  }
  messages.push({ role: "user", content: userMessage });

  // Step 4: Call Claude
  try {
    const response = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-api-key": process.env.ANTHROPIC_API_KEY,
        "anthropic-version": "2023-06-01",
      },
      body: JSON.stringify({
        model: "claude-sonnet-4-5",
        max_tokens: researchMode ? 1200 : 600,
        system: systemPrompt,
        messages,
      }),
    });

    const result = await response.json();

    if (!response.ok) {
      console.error("Anthropic error:", JSON.stringify(result));
      throw new HttpsError(
        "internal",
        result.error?.message ?? `Anthropic error ${response.status}`,
      );
    }

    const text = result.content?.[0]?.text ?? "";

    // ── Action detection ─────────────────────────────────────────
    // The AI may append <biovolt_action>{...}</biovolt_action> when
    // the user asks to update data. Parse it out and strip from the
    // displayed response so the user sees only conversation.
    const actionMatch = text.match(
      /<biovolt_action>([\s\S]*?)<\/biovolt_action>/,
    );
    let action = null;
    let cleanResponse = text;
    if (actionMatch) {
      try {
        action = JSON.parse(actionMatch[1].trim());
        cleanResponse = text
          .replace(/<biovolt_action>[\s\S]*?<\/biovolt_action>/, "")
          .trim();
      } catch (e) {
        console.error("Action parse error:", e);
      }
    }

    return {
      response: cleanResponse,
      researchUsed: researchContext.length > 0,
      keywordsDetected: keywords,
      action: action,
    };
  } catch (error) {
    if (error instanceof HttpsError) throw error;
    console.error("journalChat error:", error);
    throw new HttpsError("internal", error.message);
  }
});

// ---------------------------------------------------------------------------
// mcpServer — HTTP endpoint implementing Model Context Protocol over
// JSON-RPC 2.0. Claude.ai connects here to read/write BioVolt health data.
// ---------------------------------------------------------------------------

exports.mcpServer = onRequest({
  region: "us-central1",
  cors: true,
  timeoutSeconds: 30,
}, async (req, res) => {
  // ── Handle MCP protocol discovery (GET) — public, no auth ────────────
  if (req.method === "GET") {
    res.json({
      name: "biovolt",
      version: "1.0.0",
      description: "BioVolt personal health data hub — " +
        "biometric sessions, protocols, fasting state, " +
        "bloodwork, and health journal",
      tools: [
        {
          name: "get_biological_context",
          description: "Get a complete snapshot of the " +
            "user's current biological state including " +
            "active protocols, fasting hours, HRV baseline, " +
            "and recent session summary. Use this first in " +
            "any health conversation.",
          inputSchema: { type: "object", properties: {} },
        },
        {
          name: "get_session_history",
          description: "Get recent biometric session data " +
            "including HRV, GSR, heart rate, coherence, " +
            "and AI analysis insights.",
          inputSchema: {
            type: "object",
            properties: {
              days: {
                type: "number",
                description: "Number of days to look back " +
                  "(default 7, max 30)",
              },
            },
          },
        },
        {
          name: "get_active_protocols",
          description: "Get all active supplement and " +
            "peptide protocols with cycle day, dose, " +
            "route, and protocol notes/rationale.",
          inputSchema: { type: "object", properties: {} },
        },
        {
          name: "get_fasting_state",
          description: "Get current fasting status — " +
            "hours fasted, eating window, last meal time, " +
            "and fasting schedule type.",
          inputSchema: { type: "object", properties: {} },
        },
        {
          name: "get_bloodwork",
          description: "Get the most recent bloodwork " +
            "panel with all biomarker values.",
          inputSchema: { type: "object", properties: {} },
        },
        {
          name: "get_journal_context",
          description: "Get recent health journal " +
            "conversations for context on symptoms, " +
            "observations, and ongoing discussions.",
          inputSchema: {
            type: "object",
            properties: {
              limit: {
                type: "number",
                description: "Number of recent entries " +
                  "to return (default 10)",
              },
            },
          },
        },
        {
          name: "log_journal_entry",
          description: "Write a new entry to the health " +
            "journal timeline. Use when the user mentions " +
            "a symptom, observation, or health event that " +
            "should be recorded.",
          inputSchema: {
            type: "object",
            properties: {
              message: {
                type: "string",
                description: "The observation or note to log",
              },
            },
            required: ["message"],
          },
        },
      ],
    });
    return;
  }

  // ── Handle JSON-RPC tool calls (POST) ────────────────────────────────
  if (req.method !== "POST") {
    res.status(405).json({ error: "Method not allowed" });
    return;
  }

  // ── Auth: verify Firebase ID token (tool calls only) ─────────────────
  const authHeader = req.headers.authorization || "";
  const idToken = authHeader.replace("Bearer ", "").trim();

  if (!idToken) {
    res.status(401).json({
      jsonrpc: "2.0",
      error: { code: -32001, message: "Missing auth token" },
      id: null,
    });
    return;
  }

  let uid;
  try {
    const decoded = await getAuth().verifyIdToken(idToken);
    uid = decoded.uid;
  } catch (e) {
    res.status(401).json({
      jsonrpc: "2.0",
      error: { code: -32001, message: "Invalid auth token" },
      id: null,
    });
    return;
  }

  const db = getFirestore();
  const userRef = db.collection("users").doc(uid);

  const { method, params, id } = req.body;
  const toolName = params?.name || method;
  const toolInput = params?.input || params || {};

  try {
    let result;

    switch (toolName) {
      case "get_biological_context": {
        const [profileDoc, protocolsSnap, sessionsSnap] = await Promise.all([
          userRef.collection("meta").doc("profile").get(),
          userRef.collection("protocols")
            .orderBy("startDate", "desc").limit(10).get(),
          userRef.collection("sessions")
            .orderBy("createdAt", "desc").limit(5).get(),
        ]);

        const profile = profileDoc.data() || {};
        const protocols = protocolsSnap.docs.map((d) => d.data());
        const sessions = sessionsSnap.docs.map((d) => d.data());

        let fastingHours = null;
        if (profile.lastMealTime) {
          const lastMeal = new Date(profile.lastMealTime);
          fastingHours = (Date.now() - lastMeal.getTime()) / 3600000;
        }

        const hrvValues = sessions
          .map((s) => s.biometrics?.hrvRmssdMs)
          .filter((v) => v && v > 0);
        const hrvBaseline = hrvValues.length > 0
          ? hrvValues.reduce((a, b) => a + b, 0) / hrvValues.length
          : null;

        result = {
          profile: {
            weightKg: profile.weightKg,
            mthfr: profile.mthfr,
            apoe: profile.apoe,
            comt: profile.comt,
          },
          fastingState: {
            fastingHours: fastingHours
              ? Math.round(fastingHours * 10) / 10
              : null,
            fastingType: profile.fastingType,
            eatWindowStart: profile.eatWindowStartHour,
            eatWindowEnd: profile.eatWindowEndHour,
            lastMealTime: profile.lastMealTime,
          },
          activeProtocols: protocols.map((p) => ({
            name: p.name,
            type: p.type,
            doseMcg: p.doseMcg,
            route: p.route,
            currentCycleDay: p.currentCycleDay,
            cycleLengthDays: p.cycleLengthDays,
            isOngoing: p.isOngoing,
            notes: p.notes,
          })),
          biometricBaseline: {
            hrvBaselineMs: hrvBaseline ? Math.round(hrvBaseline) : null,
            sessionCount: sessions.length,
            lastSessionAt: sessions[0]?.createdAt || null,
          },
        };
        break;
      }

      case "get_session_history": {
        const days = Math.min(toolInput.days || 7, 30);
        const since = new Date();
        since.setDate(since.getDate() - days);

        const snap = await userRef.collection("sessions")
          .orderBy("createdAt", "desc")
          .limit(20)
          .get();

        const sessions = snap.docs
          .map((d) => d.data())
          .filter((s) => new Date(s.createdAt) >= since);

        const analysisSnap = await Promise.all(
          sessions.slice(0, 5).map((s) =>
            userRef.collection("ai_analysis").doc(s.sessionId).get(),
          ),
        );

        result = {
          sessions: sessions.map((s, i) => ({
            sessionId: s.sessionId,
            createdAt: s.createdAt,
            type: s.context?.activities?.[0]?.type,
            durationSeconds:
              s.context?.activities?.[0]?.durationSeconds,
            biometrics: s.biometrics,
            subjective: s.subjective,
            aiAnalysis: analysisSnap[i]?.exists
              ? {
                insights: analysisSnap[i].data().insights,
                flags: analysisSnap[i].data().flags,
                trendSummary: analysisSnap[i].data().trendSummary,
                confidence: analysisSnap[i].data().confidence,
              }
              : null,
          })),
        };
        break;
      }

      case "get_active_protocols": {
        const snap = await userRef.collection("protocols").get();
        result = {
          protocols: snap.docs.map((d) => d.data()),
        };
        break;
      }

      case "get_fasting_state": {
        const doc = await userRef.collection("meta").doc("profile").get();
        const p = doc.data() || {};
        let fastingHours = null;
        let inEatingWindow = false;

        if (p.lastMealTime) {
          fastingHours = (Date.now() -
            new Date(p.lastMealTime).getTime()) / 3600000;
        }

        if (p.eatWindowStartHour != null && p.eatWindowEndHour != null) {
          const now = new Date();
          const hour = now.getHours() + now.getMinutes() / 60;
          inEatingWindow = hour >= p.eatWindowStartHour &&
            hour < p.eatWindowEndHour;
        }

        result = {
          fastingHours: fastingHours
            ? Math.round(fastingHours * 10) / 10 : null,
          fastingType: p.fastingType,
          eatWindowStart: p.eatWindowStartHour,
          eatWindowEnd: p.eatWindowEndHour,
          lastMealTime: p.lastMealTime,
          currentlyInEatingWindow: inEatingWindow,
        };
        break;
      }

      case "get_bloodwork": {
        const snap = await userRef.collection("bloodwork")
          .orderBy("labDate", "desc").limit(1).get();
        result = snap.empty
          ? { bloodwork: null }
          : { bloodwork: snap.docs[0].data() };
        break;
      }

      case "get_journal_context": {
        const limit = Math.min(toolInput.limit || 10, 20);
        const snap = await userRef.collection("journal")
          .orderBy("timestamp", "desc")
          .limit(limit)
          .get();
        result = {
          entries: snap.docs.map((d) => ({
            timestamp: d.data().timestamp,
            conversationId: d.data().conversationId,
            userMessage: d.data().userMessage,
            aiResponse: d.data().aiResponse,
            autoTags: d.data().autoTags,
            bookmarked: d.data().bookmarked,
          })),
        };
        break;
      }

      case "log_journal_entry": {
        const message = toolInput.message;
        if (!message) {
          throw new Error("message is required");
        }
        const entry = {
          id: Date.now().toString(),
          timestamp: new Date().toISOString(),
          conversationId: "claude_mcp",
          userMessage: message,
          aiResponse: "[Logged via Claude MCP]",
          bookmarked: false,
          autoTags: [],
          researchGrounded: false,
          syncedAt: new Date(),
        };
        await userRef.collection("journal").doc(entry.id).set(entry);
        result = {
          success: true,
          entryId: entry.id,
          message: "Logged to BioVolt journal",
        };
        break;
      }

      default:
        res.status(400).json({
          jsonrpc: "2.0",
          error: {
            code: -32601,
            message: `Unknown tool: ${toolName}`,
          },
          id,
        });
        return;
    }

    res.json({
      jsonrpc: "2.0",
      result,
      id,
    });
  } catch (e) {
    console.error("mcpServer error:", e);
    res.status(500).json({
      jsonrpc: "2.0",
      error: { code: -32000, message: e.message },
      id,
    });
  }
});

// ---------------------------------------------------------------------------
// refreshToken — exchange a Firebase refresh token for a fresh ID token.
// Lets Claude.ai stay connected beyond the 1-hour ID token lifetime.
// ---------------------------------------------------------------------------

exports.refreshToken = onRequest({
  region: "us-central1",
  cors: true,
  timeoutSeconds: 10,
}, async (req, res) => {
  if (req.method !== "POST") {
    res.status(405).json({ error: "Method not allowed" });
    return;
  }

  const { refreshToken } = req.body || {};
  if (!refreshToken) {
    res.status(400).json({ error: "refreshToken required" });
    return;
  }

  const apiKey = process.env.FB_WEB_API_KEY;
  if (!apiKey) {
    res.status(501).json({
      error: "Token refresh not configured server-side",
    });
    return;
  }

  try {
    const response = await fetch(
      `https://securetoken.googleapis.com/v1/token?key=${apiKey}`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          grant_type: "refresh_token",
          refresh_token: refreshToken,
        }),
      },
    );
    const data = await response.json();
    if (data.error) {
      res.status(401).json({
        error: data.error.message || "Refresh failed",
      });
      return;
    }
    res.json({
      idToken: data.id_token,
      expiresIn: data.expires_in,
    });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});
