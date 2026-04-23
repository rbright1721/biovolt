const getBiologicalContext = require("../get_biological_context");
const getSessionHistory = require("../get_session_history");
const getActiveProtocols = require("../get_active_protocols");
const getFastingState = require("../get_fasting_state");
const getBloodwork = require("../get_bloodwork");
const getJournalContext = require("../get_journal_context");
const logJournalEntry = require("../log_journal_entry");

// ── Firestore fakes ─────────────────────────────────────────────────────

function fakeDocRef(data, setCapture) {
  return {
    get: async () => ({
      exists: data != null,
      data: () => data,
    }),
    set: async (value) => {
      if (setCapture) setCapture.value = value;
    },
  };
}

function fakeCollection(docs, setCapture) {
  const self = {
    doc: (id) => fakeDocRef(
      docs.find((d) => d.id === id)?.data,
      setCapture,
    ),
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

function fakeUserRef(collections, setCaptures = {}) {
  return {
    collection: (name) => fakeCollection(
      collections[name] || [],
      setCaptures[name],
    ),
  };
}

// ── Tests ───────────────────────────────────────────────────────────────

describe("get_biological_context", () => {
  test("assembles profile, protocols, sessions, and derived fields", async () => {
    const now = Date.UTC(2026, 3, 21, 12, 0, 0);
    const lastMeal = new Date(now - 5 * 3600000).toISOString();
    const userRef = fakeUserRef({
      meta: [{
        id: "profile",
        data: {
          weightKg: 80,
          mthfr: "C677T",
          apoe: "3/3",
          comt: "Val/Val",
          lastMealTime: lastMeal,
          fastingType: "16:8",
          eatWindowStartHour: 12,
          eatWindowEndHour: 20,
        },
      }],
      protocols: [
        { id: "p1", data: { name: "GlyNAC", type: "supplement" } },
      ],
      sessions: [
        { id: "s1", data: {
          sessionId: "s1",
          createdAt: "2026-04-20T10:00:00Z",
          biometrics: { hrvRmssdMs: 40 },
        } },
        { id: "s2", data: {
          sessionId: "s2",
          createdAt: "2026-04-19T10:00:00Z",
          biometrics: { hrvRmssdMs: 60 },
        } },
      ],
    });

    const result = await getBiologicalContext.handler({
      input: {},
      ctx: { userRef, now },
    });

    expect(result.profile.weightKg).toBe(80);
    expect(result.profile.mthfr).toBe("C677T");
    expect(result.fastingState.fastingHours).toBe(5);
    expect(result.fastingState.fastingType).toBe("16:8");
    expect(result.activeProtocols).toHaveLength(1);
    expect(result.activeProtocols[0].name).toBe("GlyNAC");
    expect(result.biometricBaseline.hrvBaselineMs).toBe(50);
    expect(result.biometricBaseline.sessionCount).toBe(2);
    expect(result.biometricBaseline.lastSessionAt)
      .toBe("2026-04-20T10:00:00Z");
  });
});

describe("get_session_history", () => {
  test("filters sessions by days window and attaches ai_analysis", async () => {
    const now = Date.UTC(2026, 3, 21, 12, 0, 0);
    const recent = new Date(now - 2 * 86400000).toISOString();
    const stale = new Date(now - 10 * 86400000).toISOString();
    const userRef = fakeUserRef({
      sessions: [
        { id: "r1", data: {
          sessionId: "r1",
          createdAt: recent,
          biometrics: { hrvRmssdMs: 45 },
          context: { activities: [{
            type: "breathwork",
            durationSeconds: 600,
          }] },
        } },
        { id: "s1", data: { sessionId: "s1", createdAt: stale } },
      ],
      ai_analysis: [
        { id: "r1", data: {
          insights: "good session",
          flags: [],
          trendSummary: "stable",
          confidence: 0.9,
        } },
      ],
    });

    const result = await getSessionHistory.handler({
      input: { days: 7 },
      ctx: { userRef, now },
    });

    expect(result.sessions).toHaveLength(1);
    expect(result.sessions[0].sessionId).toBe("r1");
    expect(result.sessions[0].type).toBe("breathwork");
    expect(result.sessions[0].durationSeconds).toBe(600);
    expect(result.sessions[0].aiAnalysis.insights).toBe("good session");
  });
});

describe("get_active_protocols", () => {
  test("returns active protocol docs", async () => {
    // After the post-audit follow-up, get_active_protocols filters
    // by isActive=true by default. Fixtures must opt in explicitly.
    const userRef = fakeUserRef({
      protocols: [
        {
          id: "p1",
          data: {name: "NAC", doseMcg: 600, isActive: true},
        },
        {
          id: "p2",
          data: {name: "BPC-157", doseMcg: 250, isActive: true},
        },
      ],
    });

    const result = await getActiveProtocols.handler({
      input: {},
      ctx: { userRef, now: Date.now() },
    });

    expect(result.protocols).toHaveLength(2);
    expect(result.protocols[0].name).toBe("NAC");
  });
});

describe("get_fasting_state", () => {
  test("computes fastingHours and eating-window status", async () => {
    // Local 14:30 — inside the 12:00–20:00 eating window in any timezone.
    const now = new Date(2026, 3, 21, 14, 30, 0).getTime();
    const lastMeal = new Date(now - 3 * 3600000).toISOString();
    const userRef = fakeUserRef({
      meta: [{
        id: "profile",
        data: {
          lastMealTime: lastMeal,
          fastingType: "16:8",
          eatWindowStartHour: 12,
          eatWindowEndHour: 20,
        },
      }],
    });

    const result = await getFastingState.handler({
      input: {},
      ctx: { userRef, now },
    });

    expect(result.fastingHours).toBe(3);
    expect(result.fastingType).toBe("16:8");
    expect(result.eatWindowStart).toBe(12);
    expect(result.eatWindowEnd).toBe(20);
    expect(result.currentlyInEatingWindow).toBe(true);
  });

  test("returns null fastingHours when no last meal is known", async () => {
    const userRef = fakeUserRef({
      meta: [{ id: "profile", data: {} }],
    });
    const result = await getFastingState.handler({
      input: {},
      ctx: { userRef, now: Date.now() },
    });
    expect(result.fastingHours).toBeNull();
    expect(result.currentlyInEatingWindow).toBe(false);
  });
});

describe("get_bloodwork", () => {
  test("returns the most recent bloodwork panel", async () => {
    const userRef = fakeUserRef({
      bloodwork: [
        { id: "bw1", data: { labDate: "2026-04-01", ferritin: 120 } },
      ],
    });
    const result = await getBloodwork.handler({
      input: {},
      ctx: { userRef, now: Date.now() },
    });
    expect(result.bloodwork.ferritin).toBe(120);
  });

  test("returns null when no bloodwork exists", async () => {
    const userRef = fakeUserRef({ bloodwork: [] });
    const result = await getBloodwork.handler({
      input: {},
      ctx: { userRef, now: Date.now() },
    });
    expect(result.bloodwork).toBeNull();
  });
});

describe("get_journal_context", () => {
  test("returns flattened journal entries", async () => {
    const userRef = fakeUserRef({
      journal: [
        { id: "j1", data: {
          timestamp: "2026-04-20T10:00:00Z",
          conversationId: "c1",
          userMessage: "hello",
          aiResponse: "hi",
          autoTags: ["greeting"],
          bookmarked: false,
        } },
      ],
    });
    const result = await getJournalContext.handler({
      input: { limit: 5 },
      ctx: { userRef, now: Date.now() },
    });
    expect(result.entries).toHaveLength(1);
    expect(result.entries[0].userMessage).toBe("hello");
    expect(result.entries[0].autoTags).toEqual(["greeting"]);
  });
});

describe("log_journal_entry", () => {
  test("writes entry to the journal collection", async () => {
    const now = Date.UTC(2026, 3, 21, 12, 0, 0);
    const setCapture = {};
    const userRef = fakeUserRef(
      { journal: [] },
      { journal: setCapture },
    );

    const result = await logJournalEntry.handler({
      input: { message: "woke up at 4am with cortisol spike" },
      ctx: { userRef, now },
    });

    expect(result.success).toBe(true);
    expect(result.entryId).toBe(String(now));
    expect(setCapture.value.userMessage)
      .toBe("woke up at 4am with cortisol spike");
    expect(setCapture.value.conversationId).toBe("claude_mcp");
    expect(setCapture.value.timestamp)
      .toBe(new Date(now).toISOString());
  });

  test("throws when message is missing", async () => {
    const userRef = fakeUserRef({ journal: [] });
    await expect(
      logJournalEntry.handler({
        input: {},
        ctx: { userRef, now: Date.now() },
      }),
    ).rejects.toThrow("message is required");
  });
});
