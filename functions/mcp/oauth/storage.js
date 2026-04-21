// Firestore collections used by the OAuth server:
//   mcp/oauth_clients/clients/{client_id}
//   mcp/auth_codes/codes/{sha256_hash}
//   mcp/refresh_tokens/tokens/{sha256_hash}
//
// TTL indexes (run once, Firebase Console → Firestore → Indexes → TTL,
// or via gcloud):
//
//   gcloud firestore fields ttls update expires_at \
//     --collection-group=codes --enable-ttl --project=biovolt
//
//   gcloud firestore fields ttls update expires_at \
//     --collection-group=tokens --enable-ttl --project=biovolt
//
// Without these indexes the tables grow unbounded. TTL propagation takes
// up to 24h to become active after initial setup.

const { getFirestore } = require("firebase-admin/firestore");
const { randomToken, sha256Hex } = require("./crypto");

function mcpRoot() {
  return getFirestore().collection("mcp");
}

function clientsRef() {
  return mcpRoot().doc("oauth_clients").collection("clients");
}

function authCodesRef() {
  return mcpRoot().doc("auth_codes").collection("codes");
}

function refreshTokensRef() {
  return mcpRoot().doc("refresh_tokens").collection("tokens");
}

// ── Clients ─────────────────────────────────────────────────────────────

async function createClient({ clientName, redirectUris }) {
  const clientId = randomToken(16);
  const now = Date.now();
  await clientsRef().doc(clientId).set({
    client_id: clientId,
    client_name: clientName,
    redirect_uris: redirectUris,
    created_at: now,
    last_used_at: null,
  });
  return clientId;
}

async function getClient(clientId) {
  const snap = await clientsRef().doc(clientId).get();
  return snap.exists ? snap.data() : null;
}

async function touchClient(clientId) {
  await clientsRef().doc(clientId).set(
    { last_used_at: Date.now() },
    { merge: true },
  );
}

// ── Auth codes ──────────────────────────────────────────────────────────

async function storeAuthCode({
  code, clientId, uid, redirectUri, codeChallenge, scope,
}) {
  const hash = sha256Hex(code);
  const expiresAt = new Date(Date.now() + 60_000); // 60 seconds
  await authCodesRef().doc(hash).set({
    code_hash: hash,
    client_id: clientId,
    uid,
    redirect_uri: redirectUri,
    code_challenge: codeChallenge,
    scope,
    expires_at: expiresAt,
  });
}

async function consumeAuthCode(code) {
  const hash = sha256Hex(code);
  const ref = authCodesRef().doc(hash);
  const snap = await ref.get();
  if (!snap.exists) return null;
  const data = snap.data();
  // Single-use: delete immediately
  await ref.delete();
  const expiresMs = data.expires_at.toDate
    ? data.expires_at.toDate().getTime()
    : new Date(data.expires_at).getTime();
  if (expiresMs < Date.now()) return null;
  return data;
}

// ── Refresh tokens ──────────────────────────────────────────────────────

async function storeRefreshToken({
  token, clientId, uid, scope, ttlSeconds = 30 * 24 * 3600,
}) {
  const hash = sha256Hex(token);
  const now = Date.now();
  const expiresAt = new Date(now + ttlSeconds * 1000);
  await refreshTokensRef().doc(hash).set({
    token_hash: hash,
    client_id: clientId,
    uid,
    scope,
    issued_at: now,
    expires_at: expiresAt,
    revoked_at: null,
    replaced_by: null,
  });
}

async function lookupRefreshToken(token) {
  const hash = sha256Hex(token);
  const snap = await refreshTokensRef().doc(hash).get();
  if (!snap.exists) return null;
  const data = snap.data();
  if (data.revoked_at) return null;
  const expiresMs = data.expires_at.toDate
    ? data.expires_at.toDate().getTime()
    : new Date(data.expires_at).getTime();
  if (expiresMs < Date.now()) return null;
  return { ...data, hash };
}

async function rotateRefreshToken({ oldHash, newToken }) {
  const newHash = sha256Hex(newToken);
  await refreshTokensRef().doc(oldHash).set(
    { revoked_at: Date.now(), replaced_by: newHash },
    { merge: true },
  );
}

async function revokeRefreshToken(token) {
  const hash = sha256Hex(token);
  const ref = refreshTokensRef().doc(hash);
  const snap = await ref.get();
  if (!snap.exists) return false;
  await ref.set({ revoked_at: Date.now() }, { merge: true });
  return true;
}

module.exports = {
  createClient,
  getClient,
  touchClient,
  storeAuthCode,
  consumeAuthCode,
  storeRefreshToken,
  lookupRefreshToken,
  rotateRefreshToken,
  revokeRefreshToken,
};
