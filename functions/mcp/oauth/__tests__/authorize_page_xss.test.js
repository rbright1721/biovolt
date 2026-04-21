// Regression tests for script-context XSS on the /oauth/authorize consent
// page. The existing authorize.test.js only covers HTML-body escape of
// clientName; these tests cover the JSON values embedded inside the
// <script type="module"> block, which JSON.stringify alone does NOT
// make safe.

const {
  renderAuthorizePage,
  escapeScriptJson,
} = require("../authorize_page");

const LS = String.fromCharCode(0x2028);
const PS = String.fromCharCode(0x2029);

function baseParams(overrides = {}) {
  return {
    clientName: "Test Client",
    clientId: "cid_xyz",
    redirectUri: "https://claude.ai/cb",
    codeChallenge: "abc123",
    codeChallengeMethod: "S256",
    state: "opaque-state-from-claude",
    scope: "mcp",
    ...overrides,
  };
}

// Find the body of the script-context assignment (the JSON-like text
// between `const NAME = ` and the terminating `;`). Throws if missing.
function extractAssignment(html, name) {
  const re = new RegExp("const " + name + " = (\\{[^;]+\\});");
  const match = html.match(re);
  if (!match) throw new Error(`no ${name} embed found`);
  return match[1];
}

describe("renderAuthorizePage script-context XSS", () => {
  test("state containing </script> does not break out of OAUTH_PARAMS", () => {
    const html = renderAuthorizePage(baseParams({
      state: "</script><script>alert(1)</script>",
    }));
    const body = extractAssignment(html, "OAUTH_PARAMS");
    // The raw closing-script payload must never appear inside the embed.
    expect(body.includes("</script>")).toBe(false);
    // The escaped form must be present.
    expect(body).toContain("\\u003c\\u002fscript\\u003e");
  });

  test("scope containing </script>alert(1) is escaped", () => {
    const html = renderAuthorizePage(baseParams({
      scope: "</script>alert(1)",
    }));
    const body = extractAssignment(html, "OAUTH_PARAMS");
    expect(body.includes("</script>")).toBe(false);
    expect(body.includes("alert(1)")).toBe(true); // inert, inside a JS string literal
    expect(body).toContain("\\u003c\\u002fscript\\u003e");
  });

  test("code_challenge containing <img src=x onerror=alert(1)> is escaped", () => {
    const payload = "<img src=x onerror=alert(1)>";
    const html = renderAuthorizePage(baseParams({
      codeChallenge: payload,
    }));
    const body = extractAssignment(html, "OAUTH_PARAMS");
    // No raw angle brackets inside the embedded value.
    expect(body.includes("<img")).toBe(false);
    expect(body.includes("<")).toBe(false);
    expect(body.includes(">")).toBe(false);
    // Escaped form present.
    expect(body).toContain("\\u003cimg src=x onerror=alert(1)\\u003e");
  });

  test("U+2028 line separator in state is escaped, not emitted raw", () => {
    const html = renderAuthorizePage(baseParams({
      state: `opaque${LS}state`,
    }));
    const body = extractAssignment(html, "OAUTH_PARAMS");
    expect(body.includes(LS)).toBe(false);
    expect(body.includes(PS)).toBe(false);
    expect(body).toContain("opaque\\u2028state");
  });

  test("happy path: normal OAuth params produce parseable JSON embed", () => {
    const html = renderAuthorizePage(baseParams());
    const body = extractAssignment(html, "OAUTH_PARAMS");
    // Reverse the script-escape so the JSON becomes standard JSON text.
    const roundTripped = body
      .replace(/\\u003c/g, "<")
      .replace(/\\u003e/g, ">")
      .replace(/\\u0026/g, "&")
      .replace(/\\u002f/g, "/");
    const parsed = JSON.parse(roundTripped);
    expect(parsed.client_id).toBe("cid_xyz");
    expect(parsed.redirect_uri).toBe("https://claude.ai/cb");
    expect(parsed.state).toBe("opaque-state-from-claude");
    expect(parsed.scope).toBe("mcp");
    expect(parsed.code_challenge).toBe("abc123");
    expect(parsed.code_challenge_method).toBe("S256");
  });

  test("firebaseConfig embed is also script-escaped", () => {
    const html = renderAuthorizePage(baseParams());
    const body = extractAssignment(html, "firebaseConfig");
    // The hardcoded Firebase config has no malicious chars, but the embed
    // must use the same escape path — so forward slashes in any URL-ish
    // value would be /-encoded. Assert no raw </ in the embed and
    // no stray `<` characters either.
    expect(body.includes("</")).toBe(false);
    expect(body.includes("<")).toBe(false);
  });
});

describe("escapeScriptJson helper", () => {
  test("escapes <, >, &, / in JSON output", () => {
    const out = escapeScriptJson({ x: "<a>&b</a>" });
    expect(out.includes("<")).toBe(false);
    expect(out.includes(">")).toBe(false);
    expect(out.includes("&")).toBe(false);
    expect(out.includes("/")).toBe(false);
    expect(out).toContain("\\u003c");
    expect(out).toContain("\\u003e");
    expect(out).toContain("\\u0026");
    expect(out).toContain("\\u002f");
  });

  test("escapes U+2028 and U+2029 line/paragraph separators", () => {
    const out = escapeScriptJson({ x: `a${LS}b${PS}c` });
    expect(out.includes(LS)).toBe(false);
    expect(out.includes(PS)).toBe(false);
    expect(out).toContain("\\u2028");
    expect(out).toContain("\\u2029");
  });

  test("round-trips normal values via reverse of the script-escape", () => {
    const value = {
      client_id: "abc",
      redirect_uri: "https://example.com/cb?x=1",
      state: "plain-state",
    };
    const out = escapeScriptJson(value);
    const reversed = out
      .replace(/\\u003c/g, "<")
      .replace(/\\u003e/g, ">")
      .replace(/\\u0026/g, "&")
      .replace(/\\u002f/g, "/");
    expect(JSON.parse(reversed)).toEqual(value);
  });
});
