const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { initializeApp } = require("firebase-admin/app");
const fetch = require("node-fetch");

initializeApp();

const mcp = require("./mcp");

exports.mcpServer = mcp.mcpServer;
exports.refreshToken = mcp.refreshToken;

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
    return {
      response: text,
      researchUsed: researchContext.length > 0,
      keywordsDetected: keywords,
    };
  } catch (error) {
    if (error instanceof HttpsError) throw error;
    console.error("journalChat error:", error);
    throw new HttpsError("internal", error.message);
  }
});

