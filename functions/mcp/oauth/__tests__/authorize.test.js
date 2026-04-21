jest.mock("../storage", () => {
  const clients = new Map();
  const authCodes = [];
  return {
    getClient: jest.fn(async (id) => clients.get(id) || null),
    storeAuthCode: jest.fn(async (args) => {
      authCodes.push(args);
    }),
    touchClient: jest.fn(async () => {}),
    _clients: clients,
    _authCodes: authCodes,
  };
});

jest.mock("firebase-admin/auth", () => {
  return {
    getAuth: jest.fn(),
  };
});

const { handleAuthorize, handleAuthorizeComplete } = require("../authorize");
const storage = require("../storage");
const { getAuth } = require("firebase-admin/auth");

function fakeRes() {
  return {
    statusCode: 200,
    body: null,
    headers: {},
    htmlBody: null,
    status(code) { this.statusCode = code; return this; },
    json(b) { this.body = b; return this; },
    send(b) { this.htmlBody = b; return this; },
    set(name, value) { this.headers[name] = value; return this; },
  };
}

beforeEach(() => {
  storage._clients.clear();
  storage._authCodes.length = 0;
  storage.getClient.mockClear();
  storage.storeAuthCode.mockClear();
  storage.touchClient.mockClear();
  getAuth.mockReset();
});

function seedClient(clientId, { clientName = "Test Client", uris } = {}) {
  storage._clients.set(clientId, {
    client_id: clientId,
    client_name: clientName,
    redirect_uris: uris || ["https://claude.ai/callback"],
  });
}

// ── GET /oauth/authorize ──────────────────────────────────────────────

describe("GET /oauth/authorize", () => {
  test("happy path renders HTML with client name and consent text", async () => {
    seedClient("c1", { clientName: "Claude Desktop" });
    const req = {
      method: "GET",
      query: {
        client_id: "c1",
        redirect_uri: "https://claude.ai/callback",
        response_type: "code",
        code_challenge: "abc123",
        code_challenge_method: "S256",
        state: "state-xyz",
        scope: "mcp",
      },
    };
    const res = fakeRes();
    await handleAuthorize(req, res);

    expect(res.statusCode).toBe(200);
    expect(res.headers["Content-Type"]).toMatch(/text\/html/);
    expect(res.htmlBody).toContain("Claude Desktop");
    expect(res.htmlBody).toContain("BioVolt");
    expect(res.htmlBody).toContain("Sign in with Google");
    expect(res.htmlBody).toContain("Add new entries to your health journal");
    expect(res.htmlBody).toContain("abc123");
  });

  test("defaults code_challenge_method to S256 when omitted", async () => {
    seedClient("c1");
    const req = {
      method: "GET",
      query: {
        client_id: "c1",
        redirect_uri: "https://claude.ai/callback",
        response_type: "code",
        code_challenge: "abc123",
      },
    };
    const res = fakeRes();
    await handleAuthorize(req, res);
    expect(res.statusCode).toBe(200);
  });

  test("missing client_id returns 400 HTML error", async () => {
    const res = fakeRes();
    await handleAuthorize({ method: "GET", query: {} }, res);
    expect(res.statusCode).toBe(400);
    expect(res.htmlBody).toContain("missing client_id");
  });

  test("missing redirect_uri returns 400", async () => {
    const res = fakeRes();
    await handleAuthorize({
      method: "GET",
      query: { client_id: "c1" },
    }, res);
    expect(res.statusCode).toBe(400);
    expect(res.htmlBody).toContain("missing redirect_uri");
  });

  test("response_type !== 'code' returns 400", async () => {
    const res = fakeRes();
    await handleAuthorize({
      method: "GET",
      query: {
        client_id: "c1",
        redirect_uri: "https://claude.ai/callback",
        response_type: "token",
      },
    }, res);
    expect(res.statusCode).toBe(400);
    expect(res.htmlBody).toContain("response_type");
  });

  test("missing code_challenge returns 400", async () => {
    const res = fakeRes();
    await handleAuthorize({
      method: "GET",
      query: {
        client_id: "c1",
        redirect_uri: "https://claude.ai/callback",
        response_type: "code",
      },
    }, res);
    expect(res.statusCode).toBe(400);
    expect(res.htmlBody).toContain("code_challenge");
  });

  test("code_challenge_method other than S256 returns 400", async () => {
    const res = fakeRes();
    await handleAuthorize({
      method: "GET",
      query: {
        client_id: "c1",
        redirect_uri: "https://claude.ai/callback",
        response_type: "code",
        code_challenge: "abc",
        code_challenge_method: "plain",
      },
    }, res);
    expect(res.statusCode).toBe(400);
    expect(res.htmlBody).toContain("S256");
  });

  test("unknown client_id returns 400", async () => {
    const res = fakeRes();
    await handleAuthorize({
      method: "GET",
      query: {
        client_id: "ghost",
        redirect_uri: "https://claude.ai/callback",
        response_type: "code",
        code_challenge: "abc",
      },
    }, res);
    expect(res.statusCode).toBe(400);
    expect(res.htmlBody).toContain("unknown client_id");
  });

  test("unregistered redirect_uri returns 400", async () => {
    seedClient("c1", { uris: ["https://ok.example.com/cb"] });
    const res = fakeRes();
    await handleAuthorize({
      method: "GET",
      query: {
        client_id: "c1",
        redirect_uri: "https://evil.example.com/cb",
        response_type: "code",
        code_challenge: "abc",
      },
    }, res);
    expect(res.statusCode).toBe(400);
    expect(res.htmlBody).toContain("not registered");
  });

  test("escapes HTML-special characters in the client name", async () => {
    seedClient("c1", { clientName: "<script>alert(1)</script>" });
    const res = fakeRes();
    await handleAuthorize({
      method: "GET",
      query: {
        client_id: "c1",
        redirect_uri: "https://claude.ai/callback",
        response_type: "code",
        code_challenge: "abc",
      },
    }, res);
    expect(res.statusCode).toBe(200);
    expect(res.htmlBody).not.toContain("<script>alert(1)</script>");
    expect(res.htmlBody).toContain("&lt;script&gt;alert(1)&lt;/script&gt;");
  });
});

// ── POST /oauth/authorize/complete ────────────────────────────────────

describe("POST /oauth/authorize/complete", () => {
  const validBody = {
    idToken: "fake-id-token",
    client_id: "c1",
    redirect_uri: "https://claude.ai/callback",
    code_challenge: "ch-abc",
    code_challenge_method: "S256",
    state: "state-xyz",
    scope: "mcp",
  };

  function mockVerifiedToken(uid) {
    getAuth.mockReturnValue({
      verifyIdToken: jest.fn(async () => ({ uid })),
    });
  }

  function mockInvalidToken() {
    getAuth.mockReturnValue({
      verifyIdToken: jest.fn(async () => {
        throw new Error("invalid signature");
      }),
    });
  }

  test("happy path: returns redirect URL with code and state", async () => {
    seedClient("c1");
    mockVerifiedToken("user-abc");
    const res = fakeRes();
    await handleAuthorizeComplete({ body: validBody }, res);

    expect(res.body.redirect).toBeTruthy();
    const url = new URL(res.body.redirect);
    expect(url.origin + url.pathname).toBe("https://claude.ai/callback");
    expect(url.searchParams.get("code")).toBeTruthy();
    expect(url.searchParams.get("state")).toBe("state-xyz");

    expect(storage.storeAuthCode).toHaveBeenCalledTimes(1);
    const stored = storage.storeAuthCode.mock.calls[0][0];
    expect(stored.uid).toBe("user-abc");
    expect(stored.clientId).toBe("c1");
    expect(stored.redirectUri).toBe("https://claude.ai/callback");
    expect(stored.codeChallenge).toBe("ch-abc");
    expect(stored.scope).toBe("mcp");
    expect(storage.touchClient).toHaveBeenCalledWith("c1");
  });

  test("omits state from redirect when state was not provided", async () => {
    seedClient("c1");
    mockVerifiedToken("user-abc");
    const res = fakeRes();
    const body = { ...validBody };
    delete body.state;
    await handleAuthorizeComplete({ body }, res);

    const url = new URL(res.body.redirect);
    expect(url.searchParams.has("state")).toBe(false);
    expect(url.searchParams.get("code")).toBeTruthy();
  });

  test("missing idToken returns 400 invalid_request", async () => {
    const res = fakeRes();
    const body = { ...validBody };
    delete body.idToken;
    await handleAuthorizeComplete({ body }, res);
    expect(res.statusCode).toBe(400);
    expect(res.body.error).toBe("invalid_request");
  });

  test("invalid idToken returns 401 invalid_grant", async () => {
    seedClient("c1");
    mockInvalidToken();
    const res = fakeRes();
    await handleAuthorizeComplete({ body: validBody }, res);
    expect(res.statusCode).toBe(401);
    expect(res.body.error).toBe("invalid_grant");
  });

  test("unknown client_id returns 400 invalid_client", async () => {
    mockVerifiedToken("user-abc");
    const res = fakeRes();
    await handleAuthorizeComplete({
      body: { ...validBody, client_id: "ghost" },
    }, res);
    expect(res.statusCode).toBe(400);
    expect(res.body.error).toBe("invalid_client");
  });

  test("redirect_uri not in client's registered list returns 400", async () => {
    seedClient("c1", { uris: ["https://ok.example.com/cb"] });
    const res = fakeRes();
    await handleAuthorizeComplete({
      body: { ...validBody, redirect_uri: "https://evil.example.com/cb" },
    }, res);
    expect(res.statusCode).toBe(400);
    expect(res.body.error).toBe("invalid_grant");
  });

  test("missing OAuth params returns 400", async () => {
    const res = fakeRes();
    await handleAuthorizeComplete({
      body: { idToken: "x" },
    }, res);
    expect(res.statusCode).toBe(400);
    expect(res.body.error).toBe("invalid_request");
  });

  test("non-S256 code_challenge_method returns 400", async () => {
    const res = fakeRes();
    await handleAuthorizeComplete({
      body: { ...validBody, code_challenge_method: "plain" },
    }, res);
    expect(res.statusCode).toBe(400);
    expect(res.body.error).toBe("invalid_request");
  });
});

// ── Method guards ─────────────────────────────────────────────────────

describe("handleAuthorize method guard", () => {
  test("rejects non-GET/POST with 405", async () => {
    const res = fakeRes();
    await handleAuthorize({ method: "DELETE" }, res);
    expect(res.statusCode).toBe(405);
  });
});
