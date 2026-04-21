const { onRequest } = require("firebase-functions/v2/https");
const { route } = require("./router");
const { signingKeySecret } = require("./auth/jwt");

exports.mcpServer = onRequest(
  {
    region: "us-central1",
    cors: true,
    timeoutSeconds: 30,
    secrets: [signingKeySecret],
  },
  route,
);
