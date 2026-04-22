const { classifyLogEntryHandler } = require("../classify_log_entry");

// Minimal request factory — fills the required fields with valid
// defaults so each test can override only what it's exercising.
function makeRequest(overrides = {}) {
  return {
    auth: overrides.auth === undefined
      ? { uid: "user-abc" }
      : overrides.auth,
    data: {
      logEntryId: "entry-123",
      rawText: "took 500mg NAC",
      occurredAt: "2026-04-20T14:30:00.000Z",
      ...(overrides.data || {}),
    },
  };
}

// HttpsError shape: firebase-functions exports it as a class with
// `code` and `message`. Rather than importing the class we match on
// the structural shape so tests stay loose against SDK changes.
function expectHttpsError(fn, expectedCode, messageContains) {
  return expect(fn()).rejects.toEqual(
    expect.objectContaining({
      code: expectedCode,
      message: messageContains
        ? expect.stringContaining(messageContains)
        : expect.any(String),
    }),
  );
}

describe("classifyLogEntry (stub)", () => {
  test("happy path — returns stub response echoing logEntryId", async () => {
    const result = await classifyLogEntryHandler(makeRequest());

    expect(result.logEntryId).toBe("entry-123");
    expect(result.type).toBe("other");
    expect(result.structured).toBeNull();
    expect(result.confidence).toBe(0.0);
    expect(result.modelVersion).toBe("stub-v0");
    // classifiedAt is an ISO timestamp parseable as a Date.
    expect(Number.isNaN(Date.parse(result.classifiedAt))).toBe(false);
  });

  test("unauthenticated — no request.auth throws unauthenticated", async () => {
    await expectHttpsError(
      () => classifyLogEntryHandler(makeRequest({ auth: null })),
      "unauthenticated",
      "signed in",
    );
  });

  test("unauthenticated — undefined auth also throws", async () => {
    const req = makeRequest();
    delete req.auth;
    await expectHttpsError(
      () => classifyLogEntryHandler(req),
      "unauthenticated",
    );
  });

  test("missing logEntryId throws invalid-argument naming the field",
      async () => {
        const req = makeRequest();
        delete req.data.logEntryId;
        await expectHttpsError(
          () => classifyLogEntryHandler(req),
          "invalid-argument",
          "logEntryId",
        );
      });

  test("empty-string logEntryId throws invalid-argument", async () => {
    await expectHttpsError(
      () => classifyLogEntryHandler(
        makeRequest({ data: { logEntryId: "" } }),
      ),
      "invalid-argument",
      "logEntryId",
    );
  });

  test("missing rawText throws invalid-argument naming the field",
      async () => {
        const req = makeRequest();
        delete req.data.rawText;
        await expectHttpsError(
          () => classifyLogEntryHandler(req),
          "invalid-argument",
          "rawText",
        );
      });

  test("empty-string rawText is ACCEPTED — pure vitals snapshot", async () => {
    const result = await classifyLogEntryHandler(
      makeRequest({ data: { rawText: "" } }),
    );
    expect(result.type).toBe("other");
    expect(result.logEntryId).toBe("entry-123");
  });

  test("malformed occurredAt throws invalid-argument", async () => {
    await expectHttpsError(
      () => classifyLogEntryHandler(
        makeRequest({ data: { occurredAt: "not a date" } }),
      ),
      "invalid-argument",
      "occurredAt",
    );
  });

  test("missing occurredAt throws invalid-argument", async () => {
    const req = makeRequest();
    delete req.data.occurredAt;
    await expectHttpsError(
      () => classifyLogEntryHandler(req),
      "invalid-argument",
      "occurredAt",
    );
  });

  test("vitals with string where number expected throws invalid-argument",
      async () => {
        await expectHttpsError(
          () => classifyLogEntryHandler(makeRequest({
            data: { vitals: { hrBpm: "sixty" } },
          })),
          "invalid-argument",
          "hrBpm",
        );
      });

  test("vitals with null fields are accepted", async () => {
    const result = await classifyLogEntryHandler(makeRequest({
      data: {
        vitals: {
          hrBpm: null, hrvMs: null, gsrUs: null,
          skinTempF: null, spo2Percent: null, ecgHrBpm: null,
        },
      },
    }));
    expect(result.type).toBe("other");
  });

  test("vitals with all numeric fields populated are accepted", async () => {
    const result = await classifyLogEntryHandler(makeRequest({
      data: {
        vitals: {
          hrBpm: 62, hrvMs: 48, gsrUs: 2.1,
          skinTempF: 97.8, spo2Percent: 98, ecgHrBpm: 63,
        },
      },
    }));
    expect(result.type).toBe("other");
  });

  test("large context bundle (10 protocols, 50 recent entries) processes " +
      "cleanly — no implicit size limit", async () => {
    const activeProtocols = Array.from({ length: 10 }, (_, i) => ({
      id: `proto-${i}`,
      name: `Protocol ${i}`,
      type: "peptide",
      cycleDay: i + 1,
      cycleLength: 30,
      doseDisplay: "250mcg",
      route: "sub-q",
      frequency: "daily",
      measurementTargets: ["hrv", "sleep"],
    }));
    const recentEntries = Array.from({ length: 50 }, (_, i) => ({
      type: i % 2 === 0 ? "dose" : "meal",
      rawText: `entry ${i}`,
      occurredAt: "2026-04-20T10:00:00.000Z",
    }));

    const result = await classifyLogEntryHandler(makeRequest({
      data: {
        context: {
          activeProtocols,
          fastingHours: 16.5,
          recentEntries,
        },
      },
    }));
    expect(result.type).toBe("other");
    expect(result.logEntryId).toBe("entry-123");
  });

  test("context.activeProtocols as a non-array throws invalid-argument",
      async () => {
        await expectHttpsError(
          () => classifyLogEntryHandler(makeRequest({
            data: { context: { activeProtocols: "not-an-array" } },
          })),
          "invalid-argument",
          "activeProtocols",
        );
      });

  test("omitted optional fields (no vitals, no context) processes cleanly",
      async () => {
        const result = await classifyLogEntryHandler(makeRequest());
        expect(result.type).toBe("other");
      });

  test("numeric logEntryId (wrong type) throws invalid-argument", async () => {
    await expectHttpsError(
      () => classifyLogEntryHandler(
        makeRequest({ data: { logEntryId: 12345 } }),
      ),
      "invalid-argument",
      "logEntryId",
    );
  });

  test("response classifiedAt advances between calls", async () => {
    const first = await classifyLogEntryHandler(makeRequest());
    // Small wait so the two timestamps differ at millisecond resolution.
    await new Promise((r) => setTimeout(r, 5));
    const second = await classifyLogEntryHandler(makeRequest());
    expect(Date.parse(second.classifiedAt)).toBeGreaterThanOrEqual(
      Date.parse(first.classifiedAt),
    );
  });
});
