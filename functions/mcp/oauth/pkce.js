const crypto = require("crypto");

function verifyChallenge(codeVerifier, storedChallenge) {
  if (
    typeof codeVerifier !== "string" ||
    codeVerifier.length < 43 ||
    codeVerifier.length > 128
  ) {
    return false;
  }
  const computed = crypto
    .createHash("sha256")
    .update(codeVerifier)
    .digest("base64url");
  return computed === storedChallenge;
}

module.exports = { verifyChallenge };
