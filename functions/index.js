const { onCall, HttpsError } = require("firebase-functions/v2/https");
const fetch = require("node-fetch");

// ---------------------------------------------------------------------------
// analyzeSession — Claude proxy for post-session AI analysis
// ---------------------------------------------------------------------------

exports.analyzeSession = onCall(
  { timeoutSeconds: 60, memory: "256MiB" },
  async (request) => {
    // Require authenticated user
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Must be logged in.");
    }

    const { model, max_tokens, system, messages } = request.data;

    const response = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-api-key": process.env.ANTHROPIC_API_KEY,
        "anthropic-version": "2023-06-01",
      },
      body: JSON.stringify({ model, max_tokens, system, messages }),
    });

    if (!response.ok) {
      const errBody = await response.text();
      throw new HttpsError("internal",
        `Anthropic API error ${response.status}: ${errBody}`);
    }

    const data = await response.json();
    return data;
  },
);

// ---------------------------------------------------------------------------
// quickCoach — Gemini proxy for real-time coaching
// ---------------------------------------------------------------------------

exports.quickCoach = onCall(
  { timeoutSeconds: 15, memory: "128MiB" },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Must be logged in.");
    }

    const { model, payload } = request.data;
    const geminiModel = model || "gemini-2.0-flash";
    const url =
      `https://generativelanguage.googleapis.com/v1beta/models/` +
      `${geminiModel}:generateContent?key=${process.env.GEMINI_API_KEY}`;

    const response = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload),
    });

    if (!response.ok) {
      const errBody = await response.text();
      throw new HttpsError("internal",
        `Gemini API error ${response.status}: ${errBody}`);
    }

    const data = await response.json();
    return data;
  },
);
