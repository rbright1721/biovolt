const crypto = require("crypto");

const TEST_KEY_B64 = crypto.randomBytes(32).toString("base64");
process.env.MCP_JWT_SIGNING_KEY_TEST = TEST_KEY_B64;
process.env.MCP_ISSUER = "https://test.example.com";

const {
  signAccessToken,
  verifyAccessToken,
  _resetKeyCacheForTests,
} = require("../jwt");
const { SignJWT } = require("jose");

beforeEach(() => {
  _resetKeyCacheForTests();
});

describe("jwt sign/verify", () => {
  test("round-trips a token with expected claims", async () => {
    const token = await signAccessToken({
      uid: "user-123",
      clientId: "client-abc",
      scope: "mcp",
      jti: "jti-xyz",
    });

    const payload = await verifyAccessToken(token);

    expect(payload.sub).toBe("user-123");
    expect(payload.client_id).toBe("client-abc");
    expect(payload.scope).toBe("mcp");
    expect(payload.jti).toBe("jti-xyz");
    expect(payload.iss).toBe("https://test.example.com");
    expect(payload.aud).toBe("biovolt-mcp");
  });

  test("rejects a token signed with a different key", async () => {
    const wrongKey = Buffer.from(
      crypto.randomBytes(32).toString("base64"),
      "base64",
    );
    const foreign = await new SignJWT({ client_id: "x", scope: "mcp" })
      .setProtectedHeader({ alg: "HS256" })
      .setSubject("user")
      .setIssuer("https://test.example.com")
      .setAudience("biovolt-mcp")
      .setIssuedAt()
      .setExpirationTime("1h")
      .sign(wrongKey);

    await expect(verifyAccessToken(foreign)).rejects.toThrow();
  });

  test("rejects an expired token", async () => {
    const key = Buffer.from(TEST_KEY_B64, "base64");
    const pastExp = Math.floor(Date.now() / 1000) - 60;
    const expired = await new SignJWT({ client_id: "x", scope: "mcp" })
      .setProtectedHeader({ alg: "HS256" })
      .setSubject("user")
      .setIssuer("https://test.example.com")
      .setAudience("biovolt-mcp")
      .setIssuedAt(pastExp - 120)
      .setExpirationTime(pastExp)
      .sign(key);

    await expect(verifyAccessToken(expired)).rejects.toThrow();
  });

  test("rejects a token with wrong audience", async () => {
    const key = Buffer.from(TEST_KEY_B64, "base64");
    const wrongAud = await new SignJWT({ client_id: "x", scope: "mcp" })
      .setProtectedHeader({ alg: "HS256" })
      .setSubject("user")
      .setIssuer("https://test.example.com")
      .setAudience("not-biovolt")
      .setIssuedAt()
      .setExpirationTime("1h")
      .sign(key);

    await expect(verifyAccessToken(wrongAud)).rejects.toThrow();
  });
});
