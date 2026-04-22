// Mock node-fetch BEFORE requiring the handler so the module picks
// up the jest-mocked version. Each test supplies its own mock
// response via `mockFetch(...)` below.
jest.mock("node-fetch", () => jest.fn());
const fetch = require("node-fetch");

const {
  classifyLogEntryHandler,
  parseClaudeResponse,
  applyConfidenceThresholds,
  buildUserMessage,
  CLASSIFIER_PROMPT_VERSION,
  CLASSIFIER_VOCAB,
  ClassifierParseError,
  callTracker,
} = require("../classify_log_entry");

// -----------------------------------------------------------------------------
// Helpers.
// -----------------------------------------------------------------------------

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

/** Mock node-fetch to return a successful Claude response whose `content`
 *  text is the given JSON-stringified object. */
function mockClaude(bodyObj) {
  const payload = {
    content: [{ type: "text", text: JSON.stringify(bodyObj) }],
  };
  fetch.mockImplementationOnce(async () => ({
    ok: true,
    status: 200,
    text: async () => JSON.stringify(payload),
    json: async () => payload,
  }));
}

/** Mock node-fetch to return a raw Claude text content (not JSON
 *  stringified — useful for testing markdown-fenced / preambled
 *  responses). */
function mockClaudeRaw(rawText) {
  const payload = {
    content: [{ type: "text", text: rawText }],
  };
  fetch.mockImplementationOnce(async () => ({
    ok: true,
    status: 200,
    text: async () => JSON.stringify(payload),
    json: async () => payload,
  }));
}

/** Mock node-fetch to return an HTTP error (rate limit, 500, etc.). */
function mockClaudeHttpError(status) {
  fetch.mockImplementationOnce(async () => ({
    ok: false,
    status,
    text: async () => `error body ${status}`,
    json: async () => ({}),
  }));
}

/** Mock node-fetch to reject with a network-style error. */
function mockClaudeNetworkError(errorLike) {
  fetch.mockImplementationOnce(async () => {
    throw errorLike;
  });
}

beforeEach(() => {
  fetch.mockReset();
  // Give the handler a fake key so the pre-call guard passes. Restored
  // per-test via afterEach when a test deliberately clears it.
  process.env.ANTHROPIC_API_KEY = "sk-test-fake-key";
});

// =============================================================================
// Part 2 (stub) tests — preserved where behavior hasn't changed.
// Auth + validation fire before Claude is called, so these still hold.
// =============================================================================

describe("classifyLogEntry — auth + input validation (carried from stub)", () => {
  test("unauthenticated — no request.auth throws unauthenticated", async () => {
    await expectHttpsError(
      () => classifyLogEntryHandler(makeRequest({ auth: null })),
      "unauthenticated",
      "signed in",
    );
    expect(fetch).not.toHaveBeenCalled();
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

  test("numeric logEntryId (wrong type) throws invalid-argument", async () => {
    await expectHttpsError(
      () => classifyLogEntryHandler(
        makeRequest({ data: { logEntryId: 12345 } }),
      ),
      "invalid-argument",
      "logEntryId",
    );
  });

  test("API key not configured throws internal (pre-Claude guard)",
      async () => {
        delete process.env.ANTHROPIC_API_KEY;
        await expectHttpsError(
          () => classifyLogEntryHandler(makeRequest()),
          "internal",
          "not configured",
        );
        expect(fetch).not.toHaveBeenCalled();
      });
});

// =============================================================================
// New tests — real handler behavior via mocked node-fetch.
// =============================================================================

describe("classifyLogEntry — empty rawText fast path", () => {
  test("empty rawText bypasses Claude and returns bookmark", async () => {
    const result = await classifyLogEntryHandler(
      makeRequest({ data: { rawText: "" } }),
    );

    expect(fetch).not.toHaveBeenCalled();
    expect(result.type).toBe("bookmark");
    expect(result.structured).toBeNull();
    expect(result.confidence).toBe(1.0);
    expect(result.modelVersion).toBe(
      `claude-sonnet-4-5-prompt-${CLASSIFIER_PROMPT_VERSION}`,
    );
    expect(result.logEntryId).toBe("entry-123");
  });
});

describe("classifyLogEntry — Claude-backed classification", () => {
  test("valid Claude response parses correctly (high confidence)",
      async () => {
        mockClaude({
          type: "dose",
          confidence: 0.92,
          structured: {
            protocol_name: "NAC",
            dose_amount: "500mg",
            route: "oral",
          },
          reasoning: "Explicit compound + amount.",
        });

        const result = await classifyLogEntryHandler(makeRequest());

        expect(result.type).toBe("dose");
        expect(result.confidence).toBe(0.92);
        expect(result.structured).toEqual({
          protocol_name: "NAC",
          dose_amount: "500mg",
          route: "oral",
        });
        expect(result.modelVersion).toMatch(
          /^claude-sonnet-4-5-prompt-v\d+$/,
        );
      });

  test("Claude response with type='dose' and valid structured preserves "
      + "structured", async () => {
        mockClaude({
          type: "dose",
          confidence: 0.85,
          structured: {
            protocol_name: "BPC-157",
            protocol_id: "p-42",
            dose_amount: "250mcg",
            route: "subq",
            site: "left_delt",
          },
          reasoning: "Explicit dose + route + site.",
        });

        const result = await classifyLogEntryHandler(makeRequest());

        expect(result.structured).toEqual({
          protocol_name: "BPC-157",
          protocol_id: "p-42",
          dose_amount: "250mcg",
          route: "subq",
          site: "left_delt",
        });
      });

  test("markdown-fenced JSON response is still parsed", async () => {
    mockClaudeRaw('```json\n{"type":"meal","confidence":0.8,"structured":null}\n```');

    const result = await classifyLogEntryHandler(makeRequest());
    expect(result.type).toBe("meal");
  });

  test("JSON with preamble is extracted via brace-matching", async () => {
    mockClaudeRaw('Sure — here is the classification: {"type":"mood","confidence":0.75,"structured":{"mood_type":"wired"}}');

    const result = await classifyLogEntryHandler(makeRequest());
    expect(result.type).toBe("mood");
    expect(result.structured.mood_type).toBe("wired");
  });
});

describe("classifyLogEntry — malformed responses", () => {
  test("malformed (non-JSON) Claude response throws internal", async () => {
    mockClaudeRaw("this is not json and has no object in it");

    await expectHttpsError(
      () => classifyLogEntryHandler(makeRequest()),
      "internal",
      "malformed",
    );
  });

  test("Claude response with invalid type throws internal", async () => {
    mockClaude({
      type: "not-a-real-type",
      confidence: 0.9,
      structured: null,
    });

    await expectHttpsError(
      () => classifyLogEntryHandler(makeRequest()),
      "internal",
      "malformed",
    );
  });

  test("Claude response with non-numeric confidence throws internal",
      async () => {
        mockClaude({
          type: "dose",
          confidence: "high",
          structured: null,
        });

        await expectHttpsError(
          () => classifyLogEntryHandler(makeRequest()),
          "internal",
          "malformed",
        );
      });

  test("Claude response with out-of-range confidence is clamped", async () => {
    mockClaude({
      type: "dose",
      confidence: 1.2,
      structured: { dose_amount: "500mg" },
    });

    const result = await classifyLogEntryHandler(makeRequest());
    expect(result.confidence).toBe(1.0);
    expect(result.type).toBe("dose");
  });

  test("negative confidence is clamped to 0", async () => {
    mockClaude({
      type: "other",
      confidence: -0.3,
      structured: null,
    });

    const result = await classifyLogEntryHandler(makeRequest());
    expect(result.confidence).toBe(0);
  });
});

describe("classifyLogEntry — confidence threshold rules", () => {
  test("high confidence (>=0.7) returns a clean response", async () => {
    mockClaude({
      type: "dose",
      confidence: 0.85,
      structured: { dose_amount: "500mg" },
    });

    const result = await classifyLogEntryHandler(makeRequest());

    expect(result.type).toBe("dose");
    expect(result.structured).toEqual({ dose_amount: "500mg" });
    expect(result.structured).not.toHaveProperty("confidence_note");
  });

  test("medium confidence (0.3-0.69) keeps type, adds confidence_note",
      async () => {
        mockClaude({
          type: "mood",
          confidence: 0.55,
          structured: { mood_type: "wired" },
        });

        const result = await classifyLogEntryHandler(makeRequest());

        expect(result.type).toBe("mood");
        expect(result.structured.mood_type).toBe("wired");
        expect(result.structured.confidence_note).toContain(
          "Low confidence",
        );
      });

  test("medium confidence with null structured gets a synthesized wrapper",
      async () => {
        mockClaude({
          type: "note",
          confidence: 0.45,
          structured: null,
        });

        const result = await classifyLogEntryHandler(makeRequest());

        expect(result.type).toBe("note");
        expect(result.structured).not.toBeNull();
        expect(result.structured.confidence_note).toContain(
          "Low confidence",
        );
      });

  test("very low confidence (<0.3) forces type='other' with null structured",
      async () => {
        mockClaude({
          type: "meal",
          confidence: 0.15,
          structured: { items: ["something"] },
        });

        const result = await classifyLogEntryHandler(makeRequest());

        expect(result.type).toBe("other");
        expect(result.structured).toBeNull();
        expect(result.confidence).toBe(0.15);
      });

  test("very low confidence on type='other' stays 'other'", async () => {
    mockClaude({
      type: "other",
      confidence: 0.1,
      structured: null,
    });

    const result = await classifyLogEntryHandler(makeRequest());
    expect(result.type).toBe("other");
    expect(result.structured).toBeNull();
  });
});

describe("classifyLogEntry — error mapping", () => {
  test("Claude rate limit (429) maps to resource-exhausted", async () => {
    mockClaudeHttpError(429);

    await expectHttpsError(
      () => classifyLogEntryHandler(makeRequest()),
      "resource-exhausted",
      "rate limit",
    );
  });

  test("Claude 504 maps to deadline-exceeded", async () => {
    mockClaudeHttpError(504);

    await expectHttpsError(
      () => classifyLogEntryHandler(makeRequest()),
      "deadline-exceeded",
      "timed out",
    );
  });

  test("Claude 500 maps to internal", async () => {
    mockClaudeHttpError(500);

    await expectHttpsError(
      () => classifyLogEntryHandler(makeRequest()),
      "internal",
    );
  });

  test("AbortError (timeout during fetch) maps to deadline-exceeded",
      async () => {
        const err = new Error("aborted");
        err.name = "AbortError";
        mockClaudeNetworkError(err);

        await expectHttpsError(
          () => classifyLogEntryHandler(makeRequest()),
          "deadline-exceeded",
        );
      });

  test("generic network error maps to internal", async () => {
    mockClaudeNetworkError(new Error("ECONNRESET"));

    await expectHttpsError(
      () => classifyLogEntryHandler(makeRequest()),
      "internal",
    );
  });
});

describe("classifyLogEntry — response shape", () => {
  test("modelVersion string matches expected format", async () => {
    mockClaude({
      type: "meal",
      confidence: 0.8,
      structured: null,
    });

    const result = await classifyLogEntryHandler(makeRequest());
    expect(result.modelVersion).toBe(
      `claude-sonnet-4-5-prompt-${CLASSIFIER_PROMPT_VERSION}`,
    );
    expect(result.modelVersion).toMatch(
      /^claude-sonnet-4-5-prompt-v\d+$/,
    );
  });

  test("classifiedAt is a valid ISO timestamp", async () => {
    mockClaude({
      type: "meal",
      confidence: 0.8,
      structured: null,
    });

    const result = await classifyLogEntryHandler(makeRequest());
    expect(Number.isNaN(Date.parse(result.classifiedAt))).toBe(false);
  });

  test("logEntryId is echoed back", async () => {
    mockClaude({
      type: "dose",
      confidence: 0.9,
      structured: null,
    });

    const result = await classifyLogEntryHandler(
      makeRequest({ data: { logEntryId: "echo-me-please" } }),
    );
    expect(result.logEntryId).toBe("echo-me-please");
  });

  test("vitals with all numeric fields still classifies cleanly", async () => {
    mockClaude({
      type: "dose",
      confidence: 0.8,
      structured: null,
    });

    const result = await classifyLogEntryHandler(makeRequest({
      data: {
        vitals: {
          hrBpm: 62, hrvMs: 48, gsrUs: 2.1,
          skinTempF: 97.8, spo2Percent: 98, ecgHrBpm: 63,
        },
      },
    }));
    expect(result.type).toBe("dose");
  });

  test("vitals with all null fields classifies cleanly", async () => {
    mockClaude({
      type: "dose",
      confidence: 0.8,
      structured: null,
    });

    const result = await classifyLogEntryHandler(makeRequest({
      data: {
        vitals: {
          hrBpm: null, hrvMs: null, gsrUs: null,
          skinTempF: null, spo2Percent: null, ecgHrBpm: null,
        },
      },
    }));
    expect(result.type).toBe("dose");
  });

  test("large context bundle (10 protocols, 50 recent entries) works",
      async () => {
        mockClaude({
          type: "dose",
          confidence: 0.8,
          structured: null,
        });

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
          data: { context: { activeProtocols, recentEntries } },
        }));
        expect(result.type).toBe("dose");
      });
});

// =============================================================================
// Pure-helper tests — no network at all.
// =============================================================================

describe("parseClaudeResponse", () => {
  test("parses a well-formed JSON response", () => {
    const raw = '{"type":"dose","confidence":0.9,"structured":null}';
    const result = parseClaudeResponse(raw);
    expect(result.type).toBe("dose");
    expect(result.confidence).toBe(0.9);
    expect(result.structured).toBeNull();
  });

  test("strips markdown fences", () => {
    const raw = '```json\n{"type":"meal","confidence":0.8,"structured":null}\n```';
    const result = parseClaudeResponse(raw);
    expect(result.type).toBe("meal");
  });

  test("extracts JSON via brace-matching when there is preamble", () => {
    const raw = 'Answer: {"type":"mood","confidence":0.7,"structured":null} — hope this helps';
    const result = parseClaudeResponse(raw);
    expect(result.type).toBe("mood");
  });

  test("throws ClassifierParseError on no-object input", () => {
    expect(() => parseClaudeResponse("nothing here")).toThrow(
      ClassifierParseError,
    );
  });

  test("throws on invalid type", () => {
    const raw = '{"type":"not-a-type","confidence":0.9,"structured":null}';
    expect(() => parseClaudeResponse(raw)).toThrow(ClassifierParseError);
  });

  test("accepts every value in the vocab", () => {
    for (const t of CLASSIFIER_VOCAB) {
      const raw = JSON.stringify({ type: t, confidence: 0.8, structured: null });
      expect(() => parseClaudeResponse(raw)).not.toThrow();
    }
  });
});

describe("applyConfidenceThresholds", () => {
  test("high confidence passes through untouched", () => {
    const r = applyConfidenceThresholds({
      type: "dose",
      confidence: 0.9,
      structured: { dose_amount: "500mg" },
    });
    expect(r.type).toBe("dose");
    expect(r.structured).toEqual({ dose_amount: "500mg" });
  });

  test("medium confidence annotates structured", () => {
    const r = applyConfidenceThresholds({
      type: "mood",
      confidence: 0.5,
      structured: { mood_type: "wired" },
    });
    expect(r.structured.mood_type).toBe("wired");
    expect(r.structured.confidence_note).toBeDefined();
  });

  test("low confidence forces to 'other'", () => {
    const r = applyConfidenceThresholds({
      type: "meal",
      confidence: 0.1,
      structured: { items: ["x"] },
    });
    expect(r.type).toBe("other");
    expect(r.structured).toBeNull();
  });
});

describe("per-uid call tracker", () => {
  beforeEach(() => {
    callTracker.clear();
  });

  test("records each classify call under the uid", async () => {
    mockClaude({ type: "note", confidence: 0.8, structured: null });
    mockClaude({ type: "note", confidence: 0.8, structured: null });
    mockClaude({ type: "note", confidence: 0.8, structured: null });
    mockClaude({ type: "note", confidence: 0.8, structured: null });
    mockClaude({ type: "note", confidence: 0.8, structured: null });

    for (let i = 0; i < 5; i++) {
      await classifyLogEntryHandler(makeRequest({
        auth: { uid: "user-tracker" },
        data: { logEntryId: `entry-${i}` },
      }));
    }

    expect(callTracker.get("user-tracker")).toHaveLength(5);
  });

  test("tracks different uids independently", async () => {
    mockClaude({ type: "note", confidence: 0.8, structured: null });
    mockClaude({ type: "note", confidence: 0.8, structured: null });
    mockClaude({ type: "note", confidence: 0.8, structured: null });

    await classifyLogEntryHandler(makeRequest({
      auth: { uid: "alice" }, data: { logEntryId: "a-1" },
    }));
    await classifyLogEntryHandler(makeRequest({
      auth: { uid: "bob" }, data: { logEntryId: "b-1" },
    }));
    await classifyLogEntryHandler(makeRequest({
      auth: { uid: "alice" }, data: { logEntryId: "a-2" },
    }));

    expect(callTracker.get("alice")).toHaveLength(2);
    expect(callTracker.get("bob")).toHaveLength(1);
  });

  test("does not throw on any call volume (observability only, no cap)",
      async () => {
        for (let i = 0; i < 5; i++) {
          mockClaude({ type: "note", confidence: 0.8, structured: null });
        }
        for (let i = 0; i < 5; i++) {
          // Should not throw even once — the warn log fires above the
          // threshold but nothing blocks the call.
          await expect(classifyLogEntryHandler(makeRequest({
            auth: { uid: "unblocked" },
            data: { logEntryId: `u-${i}` },
          }))).resolves.toBeDefined();
        }
      });
});

describe("buildUserMessage", () => {
  test("includes raw text verbatim", () => {
    const msg = buildUserMessage({
      rawText: "took 250mcg BPC-157",
      context: {},
    });
    expect(msg).toContain('"took 250mcg BPC-157"');
  });

  test("includes active protocols when present", () => {
    const msg = buildUserMessage({
      rawText: "bpc done",
      context: {
        activeProtocols: [
          {
            id: "p-1",
            name: "BPC-157",
            type: "peptide",
            cycleDay: 5,
            cycleLength: 30,
            doseDisplay: "250mcg subq",
            frequency: "daily",
            measurementTargets: ["hrv"],
          },
        ],
      },
    });
    expect(msg).toContain("BPC-157");
    expect(msg).toContain("day 5/30");
  });

  test("includes fasting hours when present", () => {
    const msg = buildUserMessage({
      rawText: "just ate",
      context: { fastingHours: 16.5 },
    });
    expect(msg).toContain("Fasting hours: 16.5");
  });

  test("omits optional sections cleanly", () => {
    const msg = buildUserMessage({ rawText: "x", context: {} });
    expect(msg).not.toContain("Active protocols:");
    expect(msg).not.toContain("Recent entries:");
    expect(msg).not.toContain("Fasting hours:");
  });
});
