const crypto = require("crypto");

process.env.MCP_JWT_SIGNING_KEY_TEST =
  crypto.randomBytes(32).toString("base64");
process.env.MCP_ISSUER = "https://test.example.com";

jest.mock("../storage", () => {
  const nodeCrypto = require("crypto");
  const clients = new Map();
  const authCodes = new Map();
  const refreshTokens = new Map();

  function sha256Hex(input) {
    return nodeCrypto.createHash("sha256").update(input).digest("hex");
  }

  return {
    createClient: jest.fn(async ({ clientName, redirectUris }) => {
      const id = "client-" + nodeCrypto.randomBytes(4).toString("hex");
      clients.set(id, {
        client_id: id,
        client_name: clientName,
        redirect_uris: redirectUris,
      });
      return id;
    }),
    getClient: jest.fn(async (id) => clients.get(id) || null),
    touchClient: jest.fn(async () => {}),
    storeAuthCode: jest.fn(async (args) => {
      const hash = sha256Hex(args.code);
      authCodes.set(hash, {
        code_hash: hash,
        client_id: args.clientId,
        uid: args.uid,
        redirect_uri: args.redirectUri,
        code_challenge: args.codeChallenge,
        scope: args.scope,
        expires_at: new Date(Date.now() + 60000),
      });
    }),
    consumeAuthCode: jest.fn(async (code) => {
      const hash = sha256Hex(code);
      const rec = authCodes.get(hash);
      if (!rec) return null;
      authCodes.delete(hash);
      if (rec.expires_at.getTime() < Date.now()) return null;
      return rec;
    }),
    storeRefreshToken: jest.fn(async (args) => {
      const hash = sha256Hex(args.token);
      refreshTokens.set(hash, {
        token_hash: hash,
        client_id: args.clientId,
        uid: args.uid,
        scope: args.scope,
        issued_at: Date.now(),
        expires_at: new Date(Date.now() + 30 * 24 * 3600 * 1000),
        revoked_at: null,
        replaced_by: null,
      });
    }),
    lookupRefreshToken: jest.fn(async (token) => {
      const hash = sha256Hex(token);
      const rec = refreshTokens.get(hash);
      if (!rec) return null;
      if (rec.revoked_at) return null;
      if (rec.expires_at.getTime() < Date.now()) return null;
      return { ...rec, hash };
    }),
    rotateRefreshToken: jest.fn(async ({ oldHash, newToken }) => {
      const rec = refreshTokens.get(oldHash);
      if (rec) {
        rec.revoked_at = Date.now();
        rec.replaced_by = sha256Hex(newToken);
      }
    }),
    revokeRefreshToken: jest.fn(async () => true),
    _clients: clients,
    _authCodes: authCodes,
    _refreshTokens: refreshTokens,
    _sha256Hex: sha256Hex,
  };
});

const { handleToken } = require("../token");
const storage = require("../storage");
const { verifyAccessToken } = require("../../auth/jwt");

function makeVerifier() {
  return crypto.randomBytes(32).toString("base64url");
}

function s256(v) {
  return crypto.createHash("sha256").update(v).digest("base64url");
}

function fakeRes() {
  return {
    statusCode: 200,
    body: null,
    status(code) { this.statusCode = code; return this; },
    json(b) { this.body = b; return this; },
  };
}

async function seed({ clientId, redirectUri, code, uid, codeChallenge }) {
  storage._clients.set(clientId, {
    client_id: clientId,
    client_name: "seeded",
    redirect_uris: [redirectUri],
  });
  await storage.storeAuthCode({
    code,
    clientId,
    uid,
    redirectUri,
    codeChallenge,
    scope: "mcp",
  });
}

describe("POST /oauth/token — authorization_code grant", () => {
  const clientId = "seed-client";
  const redirectUri = "https://test.example.com/cb";
  const uid = "user-xyz";

  test("exchanges a valid code for access + refresh tokens", async () => {
    const verifier = makeVerifier();
    const challenge = s256(verifier);
    const code = crypto.randomBytes(32).toString("base64url");
    await seed({
      clientId,
      redirectUri,
      code,
      uid,
      codeChallenge: challenge,
    });

    const req = {
      method: "POST",
      body: {
        grant_type: "authorization_code",
        code,
        code_verifier: verifier,
        client_id: clientId,
        redirect_uri: redirectUri,
      },
    };
    const res = fakeRes();
    await handleToken(req, res);

    expect(res.statusCode).toBe(200);
    expect(res.body.token_type).toBe("Bearer");
    expect(res.body.expires_in).toBe(3600);
    expect(typeof res.body.access_token).toBe("string");
    expect(typeof res.body.refresh_token).toBe("string");
    expect(res.body.scope).toBe("mcp");

    const payload = await verifyAccessToken(res.body.access_token);
    expect(payload.sub).toBe(uid);
    expect(payload.client_id).toBe(clientId);
  });

  test("rejects a PKCE mismatch", async () => {
    const verifier = makeVerifier();
    const wrongVerifier = makeVerifier();
    const challenge = s256(verifier);
    const code = crypto.randomBytes(32).toString("base64url");
    await seed({
      clientId, redirectUri, code, uid, codeChallenge: challenge,
    });

    const res = fakeRes();
    await handleToken({
      method: "POST",
      body: {
        grant_type: "authorization_code",
        code,
        code_verifier: wrongVerifier,
        client_id: clientId,
        redirect_uri: redirectUri,
      },
    }, res);

    expect(res.statusCode).toBe(400);
    expect(res.body.error).toBe("invalid_grant");
    expect(res.body.error_description).toMatch(/PKCE/);
  });

  test("rejects a code that was already consumed", async () => {
    const verifier = makeVerifier();
    const challenge = s256(verifier);
    const code = crypto.randomBytes(32).toString("base64url");
    await seed({
      clientId, redirectUri, code, uid, codeChallenge: challenge,
    });

    // First exchange succeeds
    await handleToken({
      method: "POST",
      body: {
        grant_type: "authorization_code",
        code,
        code_verifier: verifier,
        client_id: clientId,
        redirect_uri: redirectUri,
      },
    }, fakeRes());

    // Second should fail
    const res = fakeRes();
    await handleToken({
      method: "POST",
      body: {
        grant_type: "authorization_code",
        code,
        code_verifier: verifier,
        client_id: clientId,
        redirect_uri: redirectUri,
      },
    }, res);

    expect(res.statusCode).toBe(400);
    expect(res.body.error).toBe("invalid_grant");
  });

  test("rejects client mismatch", async () => {
    const verifier = makeVerifier();
    const challenge = s256(verifier);
    const code = crypto.randomBytes(32).toString("base64url");
    await seed({
      clientId, redirectUri, code, uid, codeChallenge: challenge,
    });
    // Also register an alternate client so the first lookup passes
    storage._clients.set("other-client", {
      client_id: "other-client",
      client_name: "other",
      redirect_uris: [redirectUri],
    });

    const res = fakeRes();
    await handleToken({
      method: "POST",
      body: {
        grant_type: "authorization_code",
        code,
        code_verifier: verifier,
        client_id: "other-client",
        redirect_uri: redirectUri,
      },
    }, res);

    expect(res.statusCode).toBe(400);
    expect(res.body.error).toBe("invalid_grant");
  });

  test("rejects unknown client_id", async () => {
    const res = fakeRes();
    await handleToken({
      method: "POST",
      body: {
        grant_type: "authorization_code",
        code: "irrelevant",
        code_verifier: makeVerifier(),
        client_id: "never-registered",
        redirect_uri: "https://test.example.com/cb",
      },
    }, res);
    expect(res.statusCode).toBe(400);
    expect(res.body.error).toBe("invalid_client");
  });

  test("rejects missing fields", async () => {
    const res = fakeRes();
    await handleToken({
      method: "POST",
      body: { grant_type: "authorization_code" },
    }, res);
    expect(res.statusCode).toBe(400);
    expect(res.body.error).toBe("invalid_request");
  });
});

describe("POST /oauth/token — refresh_token grant", () => {
  const clientId = "refresh-client";
  const redirectUri = "https://test.example.com/cb";
  const uid = "user-abc";

  async function mint() {
    const verifier = makeVerifier();
    const challenge = s256(verifier);
    const code = crypto.randomBytes(32).toString("base64url");
    await seed({
      clientId, redirectUri, code, uid, codeChallenge: challenge,
    });
    const res = fakeRes();
    await handleToken({
      method: "POST",
      body: {
        grant_type: "authorization_code",
        code,
        code_verifier: verifier,
        client_id: clientId,
        redirect_uri: redirectUri,
      },
    }, res);
    return res.body;
  }

  test("rotates refresh token and issues a new access token", async () => {
    const first = await mint();
    const res = fakeRes();
    await handleToken({
      method: "POST",
      body: {
        grant_type: "refresh_token",
        refresh_token: first.refresh_token,
        client_id: clientId,
      },
    }, res);

    expect(res.statusCode).toBe(200);
    expect(res.body.access_token).toBeTruthy();
    expect(res.body.refresh_token).toBeTruthy();
    expect(res.body.refresh_token).not.toBe(first.refresh_token);

    // Old refresh token should now be unusable
    const res2 = fakeRes();
    await handleToken({
      method: "POST",
      body: {
        grant_type: "refresh_token",
        refresh_token: first.refresh_token,
        client_id: clientId,
      },
    }, res2);
    expect(res2.statusCode).toBe(400);
    expect(res2.body.error).toBe("invalid_grant");
  });

  test("rejects unknown refresh token", async () => {
    const res = fakeRes();
    await handleToken({
      method: "POST",
      body: {
        grant_type: "refresh_token",
        refresh_token: "not-a-real-token",
        client_id: clientId,
      },
    }, res);
    expect(res.statusCode).toBe(400);
    expect(res.body.error).toBe("invalid_grant");
  });

  test("rejects missing fields", async () => {
    const res = fakeRes();
    await handleToken({
      method: "POST",
      body: { grant_type: "refresh_token" },
    }, res);
    expect(res.statusCode).toBe(400);
    expect(res.body.error).toBe("invalid_request");
  });
});

describe("POST /oauth/token — unknown grant", () => {
  test("returns unsupported_grant_type", async () => {
    const res = fakeRes();
    await handleToken({
      method: "POST",
      body: { grant_type: "password" },
    }, res);
    expect(res.statusCode).toBe(400);
    expect(res.body.error).toBe("unsupported_grant_type");
  });

  test("non-POST rejected", async () => {
    const res = fakeRes();
    await handleToken({ method: "GET", body: {} }, res);
    expect(res.statusCode).toBe(405);
  });
});
