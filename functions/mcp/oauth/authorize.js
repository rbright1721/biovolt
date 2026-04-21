const { getAuth } = require("firebase-admin/auth");
const { getClient, storeAuthCode, touchClient } = require("./storage");
const { randomToken } = require("./crypto");
const { renderAuthorizePage } = require("./authorize_page");

async function handleAuthorize(req, res) {
  if (req.method === "GET") {
    return handleAuthorizeGet(req, res);
  }
  if (req.method === "POST") {
    // Defensive: POST at /oauth/authorize falls through to completion
    // in case a client posts to the base path rather than /complete.
    return handleAuthorizeComplete(req, res);
  }
  return res.status(405).json({ error: "method_not_allowed" });
}

async function handleAuthorizeGet(req, res) {
  const params = req.query || {};
  const {
    client_id: clientId,
    redirect_uri: redirectUri,
    response_type: responseType,
    code_challenge: codeChallenge,
    code_challenge_method: codeChallengeMethod,
    state,
    scope,
  } = params;

  if (!clientId) return renderError(res, 400, "missing client_id");
  if (!redirectUri) return renderError(res, 400, "missing redirect_uri");
  if (responseType !== "code") {
    return renderError(res, 400, "response_type must be \"code\"");
  }
  if (!codeChallenge) {
    return renderError(res, 400, "missing code_challenge (PKCE required)");
  }
  if (codeChallengeMethod && codeChallengeMethod !== "S256") {
    return renderError(res, 400, "code_challenge_method must be S256");
  }

  const client = await getClient(clientId);
  if (!client) return renderError(res, 400, "unknown client_id");
  if (!client.redirect_uris.includes(redirectUri)) {
    return renderError(res, 400,
      "redirect_uri is not registered for this client");
  }

  const html = renderAuthorizePage({
    clientName: client.client_name,
    clientId,
    redirectUri,
    codeChallenge,
    codeChallengeMethod: codeChallengeMethod || "S256",
    state: state || "",
    scope: scope || "mcp",
  });

  res.set("Content-Type", "text/html; charset=utf-8");
  res.set("Cache-Control", "no-store");
  return res.status(200).send(html);
}

async function handleAuthorizeComplete(req, res) {
  const body = req.body || {};
  const {
    idToken,
    client_id: clientId,
    redirect_uri: redirectUri,
    code_challenge: codeChallenge,
    code_challenge_method: codeChallengeMethod,
    state,
    scope,
  } = body;

  if (!idToken) {
    return res.status(400).json({
      error: "invalid_request",
      error_description: "idToken required",
    });
  }
  if (!clientId || !redirectUri || !codeChallenge) {
    return res.status(400).json({
      error: "invalid_request",
      error_description: "missing OAuth params",
    });
  }
  if (codeChallengeMethod && codeChallengeMethod !== "S256") {
    return res.status(400).json({
      error: "invalid_request",
      error_description: "S256 required",
    });
  }

  // Re-validate the client and redirect_uri. The GET already checked these,
  // but the client could in theory tamper with the POST body.
  const client = await getClient(clientId);
  if (!client) {
    return res.status(400).json({
      error: "invalid_client",
      error_description: "unknown client_id",
    });
  }
  if (!client.redirect_uris.includes(redirectUri)) {
    return res.status(400).json({
      error: "invalid_grant",
      error_description: "redirect_uri mismatch",
    });
  }

  let decoded;
  try {
    decoded = await getAuth().verifyIdToken(idToken);
  } catch (e) {
    return res.status(401).json({
      error: "invalid_grant",
      error_description: "invalid Firebase ID token",
    });
  }
  const uid = decoded.uid;

  const code = randomToken();
  await storeAuthCode({
    code,
    clientId,
    uid,
    redirectUri,
    codeChallenge,
    scope: scope || "mcp",
  });
  await touchClient(clientId);

  const url = new URL(redirectUri);
  url.searchParams.set("code", code);
  if (state) url.searchParams.set("state", state);

  return res.json({ redirect: url.toString() });
}

function renderError(res, status, message) {
  const safe = String(message).replace(/[<>&"]/g, (c) => ({
    "<": "&lt;",
    ">": "&gt;",
    "&": "&amp;",
    "\"": "&quot;",
  })[c]);
  const html = `<!doctype html><html><head><meta charset="utf-8">` +
    `<title>Authorization error</title>
<style>body{font-family:'JetBrains Mono',monospace;background:#0a0e1a;` +
    `color:#e8ecf4;padding:48px;max-width:520px;margin:0 auto;}
h1{color:#ef4444;font-size:18px;margin:0 0 16px;}` +
    `p{color:#8a94a8;line-height:1.6;}</style></head>
<body><h1>Authorization error</h1><p>${safe}</p>` +
    `<p style="margin-top:32px;font-size:12px;">` +
    `If you didn't expect this error, close this window and try again.` +
    `</p></body></html>`;
  res.set("Content-Type", "text/html; charset=utf-8");
  res.status(status).send(html);
}

module.exports = { handleAuthorize, handleAuthorizeComplete };
