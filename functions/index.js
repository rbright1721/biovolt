const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { initializeApp } = require("firebase-admin/app");
const fetch = require("node-fetch");

initializeApp();

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

  const data = request.data;

  if (!process.env.ANTHROPIC_API_KEY) {
    console.error("ANTHROPIC_API_KEY is not set");
    throw new HttpsError("internal", "API key not configured.");
  }

  try {
    const response = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-api-key": process.env.ANTHROPIC_API_KEY,
        "anthropic-version": "2023-06-01",
      },
      body: JSON.stringify(data),
    });

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
