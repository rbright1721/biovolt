const {
  McpServer,
} = require("@modelcontextprotocol/sdk/server/mcp.js");
const {
  StreamableHTTPServerTransport,
} = require("@modelcontextprotocol/sdk/server/streamableHttp.js");
const { randomUUID } = require("crypto");
const { getFirestore } = require("firebase-admin/firestore");

const { SERVER_INFO, TOOLS } = require("./schema/tools");
const { SCHEMAS } = require("./schema/zod_schemas");
const toolRegistry = require("./tools");
const { verifyBearer } = require("./auth/verify");

// ──────────────────────────────────────────────────────────────────────
// Session store — in-memory, per Cloud Function instance. Cold starts
// drop sessions; clients re-initialize. Fine for our scale.
// ──────────────────────────────────────────────────────────────────────

const sessions = new Map(); // sessionId → { transport, server, uid, createdAt }

const SESSION_TTL_MS = 30 * 60 * 1000; // 30 minutes
const SESSION_CLEANUP_INTERVAL_MS = 5 * 60 * 1000;

const cleanupTimer = setInterval(() => {
  const now = Date.now();
  for (const [id, s] of sessions) {
    if (now - s.createdAt > SESSION_TTL_MS) {
      try {
        s.transport.close();
      } catch (_) { /* noop */ }
      sessions.delete(id);
    }
  }
}, SESSION_CLEANUP_INTERVAL_MS);
// In Node the setInterval keeps the process alive; in tests we don't
// want that. .unref() detaches it from the event loop.
if (typeof cleanupTimer.unref === "function") cleanupTimer.unref();

// ──────────────────────────────────────────────────────────────────────
// MCP server factory — one per session so per-session state (init flag,
// client info, capabilities) stays isolated between users.
//
// Exported so the integration test can connect it to InMemoryTransport
// without going through the HTTP layer.
// ──────────────────────────────────────────────────────────────────────

function createMcpServer(auth, { userRef: injectedUserRef } = {}) {
  const server = new McpServer({
    name: SERVER_INFO.name,
    version: SERVER_INFO.version,
  });

  // Tests can inject a fake userRef. Production resolves from Firestore.
  let db = null;
  let userRef = injectedUserRef;
  if (!userRef) {
    db = getFirestore();
    userRef = db.collection("users").doc(auth.uid);
  }

  for (const toolDef of TOOLS) {
    const zodSchema = SCHEMAS[toolDef.name];
    if (!zodSchema) {
      throw new Error(`No Zod schema registered for tool ${toolDef.name}`);
    }
    const handler = toolRegistry.getHandler(toolDef.name);
    if (!handler) {
      throw new Error(`No handler registered for tool ${toolDef.name}`);
    }

    // Pass the raw shape (not the full ZodObject) to the SDK — matches
    // the registerTool overload that accepts ZodRawShapeCompat.
    server.registerTool(
      toolDef.name,
      {
        description: toolDef.description,
        inputSchema: zodSchema.shape,
      },
      async (args) => {
        const ctx = {
          uid: auth.uid,
          userRef,
          firestore: db,
          now: Date.now(),
        };
        try {
          const result = await handler({ input: args || {}, ctx });
          return {
            content: [
              { type: "text", text: JSON.stringify(result) },
            ],
          };
        } catch (e) {
          return {
            isError: true,
            content: [
              { type: "text", text: `Error: ${e.message}` },
            ],
          };
        }
      },
    );
  }

  return server;
}

// ──────────────────────────────────────────────────────────────────────
// HTTP handler — validates bearer token, dispatches to session transport.
// ──────────────────────────────────────────────────────────────────────

async function handleMcpRequest(req, res) {
  // 1. Auth
  let auth;
  try {
    auth = await verifyBearer(req);
  } catch (e) {
    res.set(
      "WWW-Authenticate",
      'Bearer realm="biovolt", error="invalid_token"',
    );
    return res.status(e.status || 401).json({
      jsonrpc: "2.0",
      error: { code: -32001, message: e.message },
      id: null,
    });
  }

  // 2. Session resolution
  const sessionIdHeader = req.headers["mcp-session-id"];
  let session;

  if (sessionIdHeader) {
    session = sessions.get(sessionIdHeader);
    if (!session) {
      return res.status(404).json({
        jsonrpc: "2.0",
        error: { code: -32000, message: "Unknown session; re-initialize" },
        id: null,
      });
    }
    if (session.uid !== auth.uid) {
      return res.status(403).json({
        jsonrpc: "2.0",
        error: {
          code: -32000,
          message: "Session does not belong to authenticated user",
        },
        id: null,
      });
    }
  } else {
    // No session header — this must be an initialize request. The SDK's
    // transport validates that. Create a fresh session.
    const sessionId = randomUUID();
    const mcpServer = createMcpServer(auth);
    const transport = new StreamableHTTPServerTransport({
      sessionIdGenerator: () => sessionId,
      onsessioninitialized: (id) => {
        sessions.set(id, {
          transport,
          server: mcpServer,
          uid: auth.uid,
          createdAt: Date.now(),
        });
      },
      onsessionclosed: (id) => {
        sessions.delete(id);
      },
    });
    await mcpServer.connect(transport);
    session = {
      transport,
      server: mcpServer,
      uid: auth.uid,
      createdAt: Date.now(),
    };
    // Pre-register by our generated ID too, in case onsessioninitialized
    // fires after the transport responds (defensive).
    sessions.set(sessionId, session);
  }

  // 3. Delegate to the SDK transport. The SDK handles protocol framing,
  // SSE vs JSON negotiation, and writes the response.
  await session.transport.handleRequest(req, res, req.body);
}

module.exports = { handleMcpRequest, createMcpServer, sessions };
