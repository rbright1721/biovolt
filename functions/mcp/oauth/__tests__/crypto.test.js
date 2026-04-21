const { randomToken, sha256Hex } = require("../crypto");

describe("randomToken", () => {
  test("default length is 32 bytes → 43-char base64url", () => {
    const t = randomToken();
    expect(typeof t).toBe("string");
    // base64url of 32 bytes = 43 chars (no padding)
    expect(t.length).toBe(43);
    expect(t).toMatch(/^[A-Za-z0-9_-]+$/);
  });

  test("different calls produce different values", () => {
    const a = randomToken();
    const b = randomToken();
    expect(a).not.toBe(b);
  });

  test("byte count is configurable", () => {
    const t = randomToken(16);
    // 16 bytes = 22 base64url chars
    expect(t.length).toBe(22);
  });
});

describe("sha256Hex", () => {
  test("deterministic for the same input", () => {
    expect(sha256Hex("hello")).toBe(sha256Hex("hello"));
  });

  test("known test vector", () => {
    // SHA-256("") = e3b0c44298fc1c149afbf4c8996fb924...
    expect(sha256Hex("")).toBe(
      "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
    );
  });

  test("produces 64-char hex output", () => {
    const h = sha256Hex("something");
    expect(h).toHaveLength(64);
    expect(h).toMatch(/^[0-9a-f]+$/);
  });
});
