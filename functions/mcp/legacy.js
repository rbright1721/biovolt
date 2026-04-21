const { onRequest } = require("firebase-functions/v2/https");
const { getFirestore } = require("firebase-admin/firestore");
const { getAuth } = require("firebase-admin/auth");
const fetch = require("node-fetch");
const { SERVER_INFO, TOOLS } = require("./schema/tools");
const toolRegistry = require("./tools");

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
      ...SERVER_INFO,
      tools: TOOLS,
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

  const handler = toolRegistry.getHandler(toolName);
  if (!handler) {
    res.status(400).json({
      jsonrpc: "2.0",
      error: { code: -32601, message: `Unknown tool: ${toolName}` },
      id,
    });
    return;
  }

  try {
    const result = await handler({
      input: toolInput,
      ctx: {
        uid,
        userRef,
        firestore: db,
        now: Date.now(),
      },
    });
    res.json({ jsonrpc: "2.0", result, id });
  } catch (e) {
    console.error("tool handler error:", toolName, e);
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
