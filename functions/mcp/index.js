const legacy = require("./legacy");
const serverFunction = require("./server_function");

// The new routed function replaces the raw legacy export. OAuth paths
// and discovery are served by the router; MCP root traffic still falls
// through to legacy.mcpServerHandler until Prompt 6 swaps it for
// Streamable HTTP.
exports.mcpServer = serverFunction.mcpServer;
exports.refreshToken = legacy.refreshToken;
