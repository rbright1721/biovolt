const { handleDiscovery } = require("./oauth/discovery");
const { handleRegister } = require("./oauth/register");
const {
  handleAuthorize,
  handleAuthorizeComplete,
} = require("./oauth/authorize");
const { handleToken } = require("./oauth/token");
const { handleRevoke } = require("./oauth/revoke");
const { handleMcpRequest } = require("./server");
const { mcpServerHandler } = require("./legacy");

async function route(req, res) {
  const url = req.url || "/";
  const path = url.split("?")[0];

  // OAuth + discovery
  if (path === "/.well-known/oauth-authorization-server") {
    return handleDiscovery(req, res);
  }
  if (path === "/oauth/register") return handleRegister(req, res);
  if (path === "/oauth/authorize") return handleAuthorize(req, res);
  if (path === "/oauth/authorize/complete") {
    return handleAuthorizeComplete(req, res);
  }
  if (path === "/oauth/token") return handleToken(req, res);
  if (path === "/oauth/revoke") return handleRevoke(req, res);

  // Legacy fallback — one-prompt rollback path, removed in Prompt 7.
  if (path === "/legacy" || path.startsWith("/legacy/")) {
    return mcpServerHandler(req, res);
  }

  // Default: MCP Streamable HTTP at the root.
  return handleMcpRequest(req, res);
}

module.exports = { route };
