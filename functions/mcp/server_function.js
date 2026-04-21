const { onRequest } = require("firebase-functions/v2/https");
const { route } = require("./router");
const { signingKeySecret } = require("./auth/jwt");

// maxInstances: 1 pins the function to a single Cloud Run instance.
// MCP session state (in `server.js`) is an in-process Map — any second
// instance would 404 sessions initialized on the first. This pin
// documents and enforces the single-instance constraint. When session
// state moves to Firestore/Redis, remove this pin.
exports.mcpServer = onRequest(
  {
    region: "us-central1",
    cors: true,
    timeoutSeconds: 30,
    maxInstances: 1,
    secrets: [signingKeySecret],
  },
  route,
);
