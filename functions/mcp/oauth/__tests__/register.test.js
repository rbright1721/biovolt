jest.mock("../storage", () => {
  const clients = new Map();
  let counter = 0;
  return {
    createClient: jest.fn(async ({ clientName, redirectUris }) => {
      const id = `test-client-${++counter}`;
      clients.set(id, { client_id: id, client_name: clientName, redirect_uris: redirectUris });
      return id;
    }),
    _clients: clients,
  };
});

const { handleRegister } = require("../register");
const storage = require("../storage");

function fakeRes() {
  const res = {
    statusCode: 200,
    body: null,
    status(code) { this.statusCode = code; return this; },
    json(b) { this.body = b; return this; },
  };
  return res;
}

describe("POST /oauth/register", () => {
  test("happy path: creates a client and returns 201 with metadata", async () => {
    const req = {
      method: "POST",
      body: {
        client_name: "Test Client",
        redirect_uris: ["https://test.example.com/cb"],
      },
    };
    const res = fakeRes();
    await handleRegister(req, res);

    expect(res.statusCode).toBe(201);
    expect(res.body.client_id).toMatch(/^test-client-/);
    expect(res.body.client_name).toBe("Test Client");
    expect(res.body.redirect_uris).toEqual([
      "https://test.example.com/cb",
    ]);
    expect(res.body.token_endpoint_auth_method).toBe("none");
    expect(res.body.grant_types).toEqual([
      "authorization_code",
      "refresh_token",
    ]);
    expect(storage.createClient).toHaveBeenCalled();
  });

  test("rejects missing redirect_uris", async () => {
    const req = { method: "POST", body: { client_name: "x" } };
    const res = fakeRes();
    await handleRegister(req, res);
    expect(res.statusCode).toBe(400);
    expect(res.body.error).toBe("invalid_redirect_uri");
  });

  test("rejects non-string redirect_uris", async () => {
    const req = {
      method: "POST",
      body: { redirect_uris: ["https://ok", 12345] },
    };
    const res = fakeRes();
    await handleRegister(req, res);
    expect(res.statusCode).toBe(400);
    expect(res.body.error).toBe("invalid_redirect_uri");
  });

  test("rejects non-POST method", async () => {
    const req = { method: "GET", body: {} };
    const res = fakeRes();
    await handleRegister(req, res);
    expect(res.statusCode).toBe(405);
  });
});
