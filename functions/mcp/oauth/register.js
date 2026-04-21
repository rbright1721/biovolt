const { createClient } = require("./storage");

async function handleRegister(req, res) {
  if (req.method !== "POST") {
    return res.status(405).json({ error: "method_not_allowed" });
  }
  const body = req.body || {};
  const clientName =
    typeof body.client_name === "string" ? body.client_name : "unnamed";
  const redirectUris = Array.isArray(body.redirect_uris)
    ? body.redirect_uris
    : [];
  if (redirectUris.length === 0) {
    return res.status(400).json({
      error: "invalid_redirect_uri",
      error_description: "at least one redirect_uri required",
    });
  }
  for (const uri of redirectUris) {
    if (typeof uri !== "string") {
      return res.status(400).json({
        error: "invalid_redirect_uri",
        error_description: "redirect_uris must be strings",
      });
    }
  }
  const clientId = await createClient({ clientName, redirectUris });
  return res.status(201).json({
    client_id: clientId,
    client_name: clientName,
    redirect_uris: redirectUris,
    token_endpoint_auth_method: "none",
    grant_types: ["authorization_code", "refresh_token"],
    response_types: ["code"],
  });
}

module.exports = { handleRegister };
