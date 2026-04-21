const { revokeRefreshToken } = require("./storage");

async function handleRevoke(req, res) {
  if (req.method !== "POST") {
    return res.status(405).json({ error: "method_not_allowed" });
  }
  const token = req.body?.token;
  if (!token) {
    return res.status(400).json({
      error: "invalid_request",
      error_description: "token required",
    });
  }
  // Per RFC 7009, respond 200 whether or not the token was valid.
  await revokeRefreshToken(token).catch(() => {});
  return res.status(200).send();
}

module.exports = { handleRevoke };
