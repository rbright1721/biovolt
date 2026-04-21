const crypto = require("crypto");
const { verifyChallenge } = require("../pkce");

function s256(verifier) {
  return crypto.createHash("sha256").update(verifier).digest("base64url");
}

describe("verifyChallenge (PKCE S256)", () => {
  test("accepts a matching verifier/challenge pair", () => {
    const verifier = crypto.randomBytes(32).toString("base64url");
    const challenge = s256(verifier);
    expect(verifyChallenge(verifier, challenge)).toBe(true);
  });

  test("rejects a mismatched verifier", () => {
    const verifier1 = crypto.randomBytes(32).toString("base64url");
    const verifier2 = crypto.randomBytes(32).toString("base64url");
    const challenge = s256(verifier1);
    expect(verifyChallenge(verifier2, challenge)).toBe(false);
  });

  test("rejects a verifier shorter than 43 chars", () => {
    const short = "abc";
    expect(verifyChallenge(short, s256(short))).toBe(false);
  });

  test("rejects a verifier longer than 128 chars", () => {
    const long = "a".repeat(129);
    expect(verifyChallenge(long, s256(long))).toBe(false);
  });

  test("rejects non-string verifier", () => {
    expect(verifyChallenge(undefined, "x")).toBe(false);
    expect(verifyChallenge(null, "x")).toBe(false);
    expect(verifyChallenge(123, "x")).toBe(false);
  });
});
