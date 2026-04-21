const { ISSUER } = require("../auth/jwt");

function discoveryDocument() {
  return {
    issuer: ISSUER,
    authorization_endpoint: `${ISSUER}/oauth/authorize`,
    token_endpoint: `${ISSUER}/oauth/token`,
    registration_endpoint: `${ISSUER}/oauth/register`,
    revocation_endpoint: `${ISSUER}/oauth/revoke`,
    response_types_supported: ["code"],
    grant_types_supported: ["authorization_code", "refresh_token"],
    code_challenge_methods_supported: ["S256"],
    token_endpoint_auth_methods_supported: ["none"],
    scopes_supported: ["mcp"],
  };
}

function handleDiscovery(req, res) {
  res.set("Cache-Control", "public, max-age=3600");
  res.json(discoveryDocument());
}

module.exports = { handleDiscovery, discoveryDocument };
