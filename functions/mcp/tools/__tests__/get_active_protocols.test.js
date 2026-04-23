const getActiveProtocols = require("../get_active_protocols");

// ── Firestore fakes (mirrors the pattern in handlers.test.js) ───────────

function fakeCollection(docs) {
  const self = {
    orderBy: () => self,
    limit: () => self,
    get: async () => ({
      empty: docs.length === 0,
      docs: docs.map((d) => ({id: d.id, data: () => d.data})),
    }),
  };
  return self;
}

function fakeUserRef(collections) {
  return {
    collection: (name) => fakeCollection(collections[name] || []),
  };
}

const NOW = Date.UTC(2026, 3, 22, 12, 0, 0);

function protocolDoc(id, overrides) {
  return {
    id,
    data: {
      id,
      name: id,
      type: "peptide",
      startDate: new Date(NOW - 5 * 86400000).toISOString(),
      cycleLengthDays: 30,
      doseMcg: 250,
      route: "sc",
      isActive: true,
      isOngoingFlag: false,
      ...overrides,
    },
  };
}

// ── Tests ───────────────────────────────────────────────────────────────

describe("get_active_protocols — retired filter", () => {
  test("default call excludes isActive=false docs", async () => {
    const userRef = fakeUserRef({
      protocols: [
        protocolDoc("active-1"),
        protocolDoc("retired-1", {isActive: false, endReason: "completed"}),
      ],
    });
    const result = await getActiveProtocols.handler({
      input: {},
      ctx: {userRef, now: NOW},
    });
    expect(result.protocols.map((p) => p.id)).toEqual(["active-1"]);
  });

  test("default call mixed: only active docs in result", async () => {
    const userRef = fakeUserRef({
      protocols: [
        protocolDoc("a", {isActive: true}),
        protocolDoc("b", {isActive: false}),
        protocolDoc("c", {isActive: true}),
        protocolDoc("d", {isActive: false}),
      ],
    });
    const result = await getActiveProtocols.handler({
      input: {},
      ctx: {userRef, now: NOW},
    });
    expect(result.protocols.map((p) => p.id).sort()).toEqual(["a", "c"]);
  });

  test("includeRetired=true returns both active and retired", async () => {
    const userRef = fakeUserRef({
      protocols: [
        protocolDoc("active-1"),
        protocolDoc("retired-1", {isActive: false}),
      ],
    });
    const result = await getActiveProtocols.handler({
      input: {includeRetired: true},
      ctx: {userRef, now: NOW},
    });
    expect(result.protocols.map((p) => p.id).sort())
      .toEqual(["active-1", "retired-1"]);
  });

  test("includeRetired=true with no retired docs matches default output",
      async () => {
        const userRef = fakeUserRef({
          protocols: [protocolDoc("only-active")],
        });
        const withFlag = await getActiveProtocols.handler({
          input: {includeRetired: true},
          ctx: {userRef, now: NOW},
        });
        const withoutFlag = await getActiveProtocols.handler({
          input: {},
          ctx: {userRef, now: NOW},
        });
        expect(withFlag.protocols.map((p) => p.id))
          .toEqual(withoutFlag.protocols.map((p) => p.id));
      });

  test("doc missing isActive entirely is excluded by default", async () => {
    // Older Firestore docs predating the schema may lack isActive.
    // Defensive default: exclude them so we don't surface
    // possibly-stale data.
    const userRef = fakeUserRef({
      protocols: [
        // Override `isActive` away by spreading after the default.
        {
          id: "legacy-no-flag",
          data: {
            id: "legacy-no-flag",
            name: "Legacy",
            type: "peptide",
            startDate: new Date(NOW - 5 * 86400000).toISOString(),
            cycleLengthDays: 30,
            doseMcg: 250,
            route: "sc",
            // intentional: no isActive field
          },
        },
      ],
    });
    const defaultResult = await getActiveProtocols.handler({
      input: {},
      ctx: {userRef, now: NOW},
    });
    expect(defaultResult.protocols).toEqual([]);

    const includedResult = await getActiveProtocols.handler({
      input: {includeRetired: true},
      ctx: {userRef, now: NOW},
    });
    expect(includedResult.protocols).toHaveLength(1);
    expect(includedResult.protocols[0].id).toBe("legacy-no-flag");
  });
});
