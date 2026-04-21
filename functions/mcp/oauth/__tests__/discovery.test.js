const { discoveryDocument, handleDiscovery } = require("../discovery");

describe("discovery document", () => {
  test("contains required OAuth metadata fields", () => {
    const doc = discoveryDocument();
    expect(typeof doc.issuer).toBe("string");
    expect(doc.issuer.length).toBeGreaterThan(0);
    expect(doc.authorization_endpoint).toMatch(/\/oauth\/authorize$/);
    expect(doc.token_endpoint).toMatch(/\/oauth\/token$/);
    expect(doc.registration_endpoint).toMatch(/\/oauth\/register$/);
    expect(doc.revocation_endpoint).toMatch(/\/oauth\/revoke$/);
    expect(doc.response_types_supported).toEqual(["code"]);
    expect(doc.grant_types_supported).toEqual([
      "authorization_code",
      "refresh_token",
    ]);
    expect(doc.code_challenge_methods_supported).toEqual(["S256"]);
    expect(doc.token_endpoint_auth_methods_supported).toEqual(["none"]);
    expect(doc.scopes_supported).toEqual(["mcp"]);
  });

  test("handleDiscovery sets cache header and writes JSON body", () => {
    let cacheHeader = null;
    let body = null;
    const res = {
      set: (name, value) => { cacheHeader = { [name]: value }; return res; },
      json: (b) => { body = b; return res; },
    };
    handleDiscovery({}, res);
    expect(cacheHeader["Cache-Control"]).toMatch(/max-age=3600/);
    expect(body.issuer).toBe(discoveryDocument().issuer);
  });
});
