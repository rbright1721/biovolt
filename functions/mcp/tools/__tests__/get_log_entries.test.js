const getLogEntries = require("../get_log_entries");

// ── Firestore fakes (mirror the pattern in handlers.test.js) ────────────

function fakeCollection(docs) {
  const self = {
    doc: (id) => ({
      get: async () => {
        const found = docs.find((d) => d.id === id);
        return {
          exists: !!found,
          data: () => (found ? found.data : undefined),
        };
      },
    }),
    orderBy: () => self,
    limit: () => self,
    get: async () => ({
      empty: docs.length === 0,
      docs: docs.map((d) => ({
        id: d.id,
        data: () => d.data,
      })),
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

function logEntryDoc(id, overrides) {
  return {
    id,
    data: {
      id,
      occurredAt: new Date(NOW).toISOString(),
      type: "other",
      classificationStatus: "pending",
      rawText: id,
      ...overrides,
    },
  };
}

// ── Tests ───────────────────────────────────────────────────────────────

describe("get_log_entries", () => {
  test("default sinceDaysAgo=7 returns entries from the last 7 days", async () => {
    const userRef = fakeUserRef({
      log_entries: [
        logEntryDoc("recent", {
          occurredAt: new Date(NOW - 2 * 86400000).toISOString(),
        }),
        logEntryDoc("stale", {
          occurredAt: new Date(NOW - 30 * 86400000).toISOString(),
        }),
      ],
    });
    const result = await getLogEntries.handler({
      input: {},
      ctx: {userRef, now: NOW},
    });
    expect(result.entries.map((e) => e.id)).toEqual(["recent"]);
    expect(result.sinceDaysAgo).toBe(7);
    expect(result.count).toBe(1);
  });

  test("sinceDaysAgo=30 widens the window", async () => {
    const userRef = fakeUserRef({
      log_entries: [
        logEntryDoc("a", {
          occurredAt: new Date(NOW - 25 * 86400000).toISOString(),
        }),
        logEntryDoc("b", {
          occurredAt: new Date(NOW - 50 * 86400000).toISOString(),
        }),
      ],
    });
    const result = await getLogEntries.handler({
      input: {sinceDaysAgo: 30},
      ctx: {userRef, now: NOW},
    });
    expect(result.entries.map((e) => e.id)).toEqual(["a"]);
  });

  test("sinceDaysAgo=0 throws invalid params", async () => {
    const userRef = fakeUserRef({log_entries: []});
    await expect(getLogEntries.handler({
      input: {sinceDaysAgo: 0},
      ctx: {userRef, now: NOW},
    })).rejects.toThrow(/sinceDaysAgo/);
  });

  test("sinceDaysAgo>90 throws invalid params", async () => {
    const userRef = fakeUserRef({log_entries: []});
    await expect(getLogEntries.handler({
      input: {sinceDaysAgo: 91},
      ctx: {userRef, now: NOW},
    })).rejects.toThrow(/sinceDaysAgo/);
  });

  test("types filter includes only specified types", async () => {
    const userRef = fakeUserRef({
      log_entries: [
        logEntryDoc("d1", {
          type: "dose",
          classificationStatus: "classified",
          structured: {},
          occurredAt: new Date(NOW - 1 * 86400000).toISOString(),
        }),
        logEntryDoc("m1", {
          type: "meal",
          classificationStatus: "classified",
          structured: {},
          occurredAt: new Date(NOW - 2 * 86400000).toISOString(),
        }),
        logEntryDoc("s1", {
          type: "symptom",
          classificationStatus: "classified",
          structured: {},
          occurredAt: new Date(NOW - 3 * 86400000).toISOString(),
        }),
      ],
    });
    const result = await getLogEntries.handler({
      input: {types: ["dose", "meal"]},
      ctx: {userRef, now: NOW},
    });
    const ids = result.entries.map((e) => e.id).sort();
    expect(ids).toEqual(["d1", "m1"]);
  });

  test("'unclassified' virtual type matches non-classified entries", async () => {
    const userRef = fakeUserRef({
      log_entries: [
        logEntryDoc("p1", {
          classificationStatus: "pending",
          occurredAt: new Date(NOW - 1 * 86400000).toISOString(),
        }),
        logEntryDoc("f1", {
          classificationStatus: "failed",
          occurredAt: new Date(NOW - 2 * 86400000).toISOString(),
        }),
        logEntryDoc("ok", {
          type: "dose",
          classificationStatus: "classified",
          structured: {},
          occurredAt: new Date(NOW - 3 * 86400000).toISOString(),
        }),
      ],
    });
    const result = await getLogEntries.handler({
      input: {types: ["unclassified"]},
      ctx: {userRef, now: NOW},
    });
    expect(result.entries.map((e) => e.id).sort()).toEqual(["f1", "p1"]);
  });

  test("limit above MAX_LIMIT is clamped, not rejected", async () => {
    const userRef = fakeUserRef({
      log_entries: Array.from({length: 250}, (_, i) => logEntryDoc(
        `e${i}`,
        {occurredAt: new Date(NOW - i * 60000).toISOString()},
      )),
    });
    const result = await getLogEntries.handler({
      input: {limit: 300},
      ctx: {userRef, now: NOW},
    });
    expect(result.count).toBe(getLogEntries.MAX_LIMIT);
  });

  test("limit < 1 throws invalid_params", async () => {
    const userRef = fakeUserRef({log_entries: []});
    await expect(getLogEntries.handler({
      input: {limit: 0},
      ctx: {userRef, now: NOW},
    })).rejects.toThrow(/limit/);
  });

  test("entries sorted DESC by occurredAt", async () => {
    const userRef = fakeUserRef({
      log_entries: [
        logEntryDoc("oldest", {
          occurredAt: new Date(NOW - 4 * 86400000).toISOString(),
        }),
        logEntryDoc("middle", {
          occurredAt: new Date(NOW - 2 * 86400000).toISOString(),
        }),
        logEntryDoc("newest", {
          occurredAt: new Date(NOW - 1 * 3600000).toISOString(),
        }),
      ],
    });
    const result = await getLogEntries.handler({
      input: {},
      ctx: {userRef, now: NOW},
    });
    expect(result.entries.map((e) => e.id))
      .toEqual(["newest", "middle", "oldest"]);
  });

  test("classified entry surfaces confidence/modelVersion/structured", async () => {
    const userRef = fakeUserRef({
      log_entries: [
        logEntryDoc("c1", {
          type: "dose",
          classificationStatus: "classified",
          classificationConfidence: 0.88,
          classificationModelVersion: "claude-sonnet-4-5-prompt-v1",
          structured: {compound: "BPC-157"},
          occurredAt: new Date(NOW - 1 * 86400000).toISOString(),
        }),
      ],
    });
    const result = await getLogEntries.handler({
      input: {},
      ctx: {userRef, now: NOW},
    });
    const entry = result.entries[0];
    expect(entry.confidence).toBe(0.88);
    expect(entry.modelVersion).toBe("claude-sonnet-4-5-prompt-v1");
    expect(entry.structured).toEqual({compound: "BPC-157"});
  });

  test("entries without vitals omit the vitals field", async () => {
    const userRef = fakeUserRef({
      log_entries: [
        logEntryDoc("nv", {
          occurredAt: new Date(NOW - 1 * 86400000).toISOString(),
        }),
      ],
    });
    const result = await getLogEntries.handler({
      input: {},
      ctx: {userRef, now: NOW},
    });
    expect(result.entries[0].vitals).toBeUndefined();
  });

  test("totalAvailable reflects pre-limit count when more match", async () => {
    const userRef = fakeUserRef({
      log_entries: Array.from({length: 30}, (_, i) => logEntryDoc(
        `e${i}`,
        {occurredAt: new Date(NOW - i * 60000).toISOString()},
      )),
    });
    const result = await getLogEntries.handler({
      input: {limit: 5},
      ctx: {userRef, now: NOW},
    });
    expect(result.count).toBe(5);
    expect(result.totalAvailable).toBe(30);
  });

  test("empty result returns count=0 and empty entries", async () => {
    const userRef = fakeUserRef({log_entries: []});
    const result = await getLogEntries.handler({
      input: {},
      ctx: {userRef, now: NOW},
    });
    expect(result.entries).toEqual([]);
    expect(result.count).toBe(0);
    expect(result.totalAvailable).toBe(0);
  });
});
