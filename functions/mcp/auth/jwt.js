// ---------------------------------------------------------------------------
// Signing key — stored in Google Secret Manager under MCP_JWT_SIGNING_KEY.
//
// One-time setup (run manually; do not run from code):
//
//   # Create the signing key secret (run once per project):
//   openssl rand -base64 32 | \
//     gcloud secrets create MCP_JWT_SIGNING_KEY --data-file=- --project=biovolt
//
//   # Grant the Cloud Functions service account read access:
//   gcloud secrets add-iam-policy-binding MCP_JWT_SIGNING_KEY \
//     --member="serviceAccount:biovolt@appspot.gserviceaccount.com" \
//     --role="roles/secretmanager.secretAccessor" --project=biovolt
//
//   # Verify:
//   gcloud secrets versions access latest --secret=MCP_JWT_SIGNING_KEY \
//     --project=biovolt
// ---------------------------------------------------------------------------

const { SignJWT, jwtVerify } = require("jose");
const { defineSecret } = require("firebase-functions/params");

const signingKeySecret = defineSecret("MCP_JWT_SIGNING_KEY");

let cachedKey = null;

async function getKey() {
  if (cachedKey) return cachedKey;
  // Test shim: lets the unit tests supply a key without Secret Manager.
  const raw = process.env.MCP_JWT_SIGNING_KEY_TEST || signingKeySecret.value();
  if (!raw) throw new Error("MCP_JWT_SIGNING_KEY not available");
  cachedKey = Buffer.from(raw, "base64");
  return cachedKey;
}

// Reset for tests — the signing-key cache needs to be invalidated when a
// test changes the env-var shim between cases.
function _resetKeyCacheForTests() {
  cachedKey = null;
}

const ISSUER =
  process.env.MCP_ISSUER || "https://mcpserver-tgzwtssvja-uc.a.run.app";
const AUDIENCE = "biovolt-mcp";
const ACCESS_TOKEN_TTL_SECONDS = 3600;

async function signAccessToken({ uid, clientId, scope = "mcp", jti }) {
  const key = await getKey();
  return await new SignJWT({ client_id: clientId, scope })
    .setProtectedHeader({ alg: "HS256", kid: "v1" })
    .setSubject(uid)
    .setIssuer(ISSUER)
    .setAudience(AUDIENCE)
    .setIssuedAt()
    .setExpirationTime(`${ACCESS_TOKEN_TTL_SECONDS}s`)
    .setJti(jti)
    .sign(key);
}

async function verifyAccessToken(token) {
  const key = await getKey();
  const { payload } = await jwtVerify(token, key, {
    issuer: ISSUER,
    audience: AUDIENCE,
  });
  return payload;
}

module.exports = {
  signAccessToken,
  verifyAccessToken,
  signingKeySecret,
  ISSUER,
  AUDIENCE,
  ACCESS_TOKEN_TTL_SECONDS,
  _resetKeyCacheForTests,
};
