jest.mock("../storage", () => {
  return {
    revokeRefreshToken: jest.fn(),
  };
});

const { handleRevoke } = require("../revoke");
const storage = require("../storage");

function fakeRes() {
  return {
    statusCode: 200,
    sent: false,
    body: null,
    status(code) { this.statusCode = code; return this; },
    json(b) { this.body = b; return this; },
    send() { this.sent = true; return this; },
  };
}

beforeEach(() => {
  storage.revokeRefreshToken.mockReset();
});

describe("POST /oauth/revoke", () => {
  test("revokes a known token and returns 200", async () => {
    storage.revokeRefreshToken.mockResolvedValueOnce(true);
    const res = fakeRes();
    await handleRevoke({
      method: "POST",
      body: { token: "any-token" },
    }, res);
    expect(res.statusCode).toBe(200);
    expect(storage.revokeRefreshToken).toHaveBeenCalledWith("any-token");
  });

  test("returns 200 even for an unknown token (RFC 7009)", async () => {
    storage.revokeRefreshToken.mockResolvedValueOnce(false);
    const res = fakeRes();
    await handleRevoke({
      method: "POST",
      body: { token: "never-issued" },
    }, res);
    expect(res.statusCode).toBe(200);
  });

  test("returns 200 even if storage throws (RFC 7009)", async () => {
    storage.revokeRefreshToken.mockRejectedValueOnce(new Error("firestore down"));
    const res = fakeRes();
    await handleRevoke({
      method: "POST",
      body: { token: "x" },
    }, res);
    expect(res.statusCode).toBe(200);
  });

  test("rejects missing token field", async () => {
    const res = fakeRes();
    await handleRevoke({ method: "POST", body: {} }, res);
    expect(res.statusCode).toBe(400);
    expect(res.body.error).toBe("invalid_request");
  });

  test("non-POST rejected", async () => {
    const res = fakeRes();
    await handleRevoke({ method: "GET", body: {} }, res);
    expect(res.statusCode).toBe(405);
  });
});
