const {
  consumeAuthCode,
  storeRefreshToken,
  lookupRefreshToken,
  rotateRefreshToken,
  getClient,
  touchClient,
} = require("./storage");
const { verifyChallenge } = require("./pkce");
const { signAccessToken, ACCESS_TOKEN_TTL_SECONDS } = require("../auth/jwt");
const { randomToken } = require("./crypto");

function oauthError(res, status, error, description) {
  return res.status(status).json({ error, error_description: description });
}

async function handleToken(req, res) {
  if (req.method !== "POST") {
    return oauthError(res, 405, "method_not_allowed", "POST required");
  }

  const body = req.body || {};
  const grantType = body.grant_type;

  if (grantType === "authorization_code") {
    return handleAuthCodeGrant(body, res);
  }
  if (grantType === "refresh_token") {
    return handleRefreshGrant(body, res);
  }
  return oauthError(
    res,
    400,
    "unsupported_grant_type",
    `unknown grant_type: ${grantType}`,
  );
}

async function handleAuthCodeGrant(body, res) {
  const {
    code,
    code_verifier: codeVerifier,
    client_id: clientId,
    redirect_uri: redirectUri,
  } = body;
  if (!code || !codeVerifier || !clientId || !redirectUri) {
    return oauthError(
      res,
      400,
      "invalid_request",
      "code, code_verifier, client_id, redirect_uri required",
    );
  }

  const client = await getClient(clientId);
  if (!client) return oauthError(res, 400, "invalid_client", "unknown client_id");
  if (!client.redirect_uris.includes(redirectUri)) {
    return oauthError(res, 400, "invalid_grant", "redirect_uri mismatch");
  }

  const record = await consumeAuthCode(code);
  if (!record) {
    return oauthError(res, 400, "invalid_grant", "code invalid or expired");
  }
  if (record.client_id !== clientId) {
    return oauthError(res, 400, "invalid_grant", "client mismatch");
  }
  if (record.redirect_uri !== redirectUri) {
    return oauthError(res, 400, "invalid_grant", "redirect_uri mismatch");
  }
  if (!verifyChallenge(codeVerifier, record.code_challenge)) {
    return oauthError(res, 400, "invalid_grant", "PKCE verification failed");
  }

  const jti = randomToken(12);
  const accessToken = await signAccessToken({
    uid: record.uid,
    clientId,
    scope: record.scope,
    jti,
  });
  const refreshToken = randomToken();
  await storeRefreshToken({
    token: refreshToken,
    clientId,
    uid: record.uid,
    scope: record.scope,
  });
  await touchClient(clientId);

  return res.json({
    access_token: accessToken,
    token_type: "Bearer",
    expires_in: ACCESS_TOKEN_TTL_SECONDS,
    refresh_token: refreshToken,
    scope: record.scope,
  });
}

async function handleRefreshGrant(body, res) {
  const { refresh_token: refreshToken, client_id: clientId } = body;
  if (!refreshToken || !clientId) {
    return oauthError(
      res,
      400,
      "invalid_request",
      "refresh_token and client_id required",
    );
  }

  const record = await lookupRefreshToken(refreshToken);
  if (!record) {
    return oauthError(
      res,
      400,
      "invalid_grant",
      "refresh token invalid or expired",
    );
  }
  if (record.client_id !== clientId) {
    return oauthError(res, 400, "invalid_grant", "client mismatch");
  }

  // Rotate: issue new tokens, revoke old refresh token.
  const jti = randomToken(12);
  const newAccessToken = await signAccessToken({
    uid: record.uid,
    clientId,
    scope: record.scope,
    jti,
  });
  const newRefreshToken = randomToken();
  await storeRefreshToken({
    token: newRefreshToken,
    clientId,
    uid: record.uid,
    scope: record.scope,
  });
  await rotateRefreshToken({
    oldHash: record.hash,
    newToken: newRefreshToken,
  });
  await touchClient(clientId);

  return res.json({
    access_token: newAccessToken,
    token_type: "Bearer",
    expires_in: ACCESS_TOKEN_TTL_SECONDS,
    refresh_token: newRefreshToken,
    scope: record.scope,
  });
}

module.exports = { handleToken };
