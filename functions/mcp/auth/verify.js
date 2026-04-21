const { verifyAccessToken } = require("./jwt");

async function verifyBearer(req) {
  const header = req.headers.authorization || "";
  const token = header.startsWith("Bearer ") ? header.slice(7).trim() : null;
  if (!token) {
    const err = new Error("missing bearer token");
    err.status = 401;
    throw err;
  }
  try {
    const payload = await verifyAccessToken(token);
    return {
      uid: payload.sub,
      clientId: payload.client_id,
      scope: payload.scope,
    };
  } catch (e) {
    const err = new Error("invalid bearer token");
    err.status = 401;
    throw err;
  }
}

module.exports = { verifyBearer };
