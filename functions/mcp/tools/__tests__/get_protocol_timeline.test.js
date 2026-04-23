const getProtocolTimeline = require("../get_protocol_timeline");

// ── Firestore fakes ─────────────────────────────────────────────────────

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

// ── Helpers ─────────────────────────────────────────────────────────────

const NOW = Date.UTC(2026, 3, 22, 12, 0, 0);

function isoDaysBefore(days) {
  return new Date(NOW - days * 86400000).toISOString();
}
function isoDaysAfter(days) {
  return new Date(NOW + days * 86400000).toISOString();
}

function protocolDoc(id, overrides) {
  return {
    id,
    data: {
      id,
      name: id,
      type: "peptide",
      startDate: isoDaysBefore(5),
      cycleLengthDays: 30,
      doseMcg: 250,
      route: "sc",
      isActive: true,
      currentCycleDay: 6,
      isOngoing: false,
      ...overrides,
    },
  };
}

function logDoc(id, overrides) {
  return {
    id,
    data: {
      id,
      occurredAt: isoDaysBefore(1),
      type: "other",
      classificationStatus: "pending",
      rawText: id,
      ...overrides,
    },
  };
}

// ── Tests ───────────────────────────────────────────────────────────────

describe("get_protocol_timeline", () => {
  test("valid protocolId returns full timeline", async () => {
    const userRef = fakeUserRef({
      protocols: [protocolDoc("p1")],
      log_entries: [
        logDoc("d1", {
          type: "dose",
          classificationStatus: "classified",
          structured: {},
          protocolIdAtTime: "p1",
        }),
      ],
      sessions: [],
      bloodwork: [],
    });
    const result = await getProtocolTimeline.handler({
      input: {protocolId: "p1"},
      ctx: {userRef, now: NOW},
    });
    expect(result.protocol.id).toBe("p1");
    expect(result.cycleWindow.start).toBe(isoDaysBefore(5));
    expect(result.cycleWindow.end).toBe(new Date(NOW).toISOString());
    expect(result.logEntries.map((e) => e.id)).toEqual(["d1"]);
    expect(result.adherenceSummary.loggedDoses).toBe(1);
  });

  test("missing protocol throws not-found-style error", async () => {
    const userRef = fakeUserRef({protocols: []});
    await expect(getProtocolTimeline.handler({
      input: {protocolId: "missing"},
      ctx: {userRef, now: NOW},
    })).rejects.toThrow(/not found/);
  });

  test("missing protocolId param throws invalid_params", async () => {
    const userRef = fakeUserRef({protocols: []});
    await expect(getProtocolTimeline.handler({
      input: {},
      ctx: {userRef, now: NOW},
    })).rejects.toThrow(/protocolId is required/);
  });

  test("ongoing protocol cycleWindow.end equals now", async () => {
    const userRef = fakeUserRef({
      protocols: [protocolDoc("p2", {
        isOngoing: true,
        cycleLengthDays: 0,
      })],
      log_entries: [],
      sessions: [],
      bloodwork: [],
    });
    const result = await getProtocolTimeline.handler({
      input: {
        protocolId: "p2",
        includeSessions: false,
        includeBloodwork: false,
      },
      ctx: {userRef, now: NOW},
    });
    expect(result.cycleWindow.end).toBe(new Date(NOW).toISOString());
  });

  test("cycled protocol clamps end to plannedEnd when cycle has elapsed",
    async () => {
      // start 60 days ago, cycle is 30 days → planned end is 30 days ago.
      const userRef = fakeUserRef({
        protocols: [protocolDoc("p3", {
          startDate: isoDaysBefore(60),
          cycleLengthDays: 30,
          isOngoing: false,
          isActive: false,
        })],
        log_entries: [],
        sessions: [],
        bloodwork: [],
      });
      const result = await getProtocolTimeline.handler({
        input: {
          protocolId: "p3",
          includeSessions: false,
          includeBloodwork: false,
        },
        ctx: {userRef, now: NOW},
      });
      // Planned end = startDate + 30 days = 30 days before NOW.
      const expectedEnd = new Date(
        Date.parse(isoDaysBefore(60)) + 30 * 86400000,
      ).toISOString();
      expect(result.cycleWindow.end).toBe(expectedEnd);
    });

  test("logEntries only includes entries tagged to the protocol", async () => {
    const userRef = fakeUserRef({
      protocols: [protocolDoc("p1")],
      log_entries: [
        logDoc("mine", {
          type: "dose",
          classificationStatus: "classified",
          structured: {},
          protocolIdAtTime: "p1",
        }),
        logDoc("other-protocol", {
          type: "dose",
          classificationStatus: "classified",
          structured: {},
          protocolIdAtTime: "p2",
        }),
        logDoc("untagged", {
          type: "dose",
          classificationStatus: "classified",
          structured: {},
        }),
      ],
      sessions: [],
      bloodwork: [],
    });
    const result = await getProtocolTimeline.handler({
      input: {protocolId: "p1"},
      ctx: {userRef, now: NOW},
    });
    expect(result.logEntries.map((e) => e.id)).toEqual(["mine"]);
  });

  test("adherenceSummary counts protocol doses + windowed contextual types",
    async () => {
      const userRef = fakeUserRef({
        protocols: [protocolDoc("p1", {
          startDate: isoDaysBefore(5),
          currentCycleDay: 6,
          timesOfDayMinutes: [420, 1200], // 2/day → expected = 12
        })],
        log_entries: [
          // Two protocol-tagged doses.
          logDoc("d1", {
            type: "dose", protocolIdAtTime: "p1",
            occurredAt: isoDaysBefore(2),
          }),
          logDoc("d2", {
            type: "dose", protocolIdAtTime: "p1",
            occurredAt: isoDaysBefore(1),
          }),
          // Meals & symptoms within window — no protocol tag.
          logDoc("m1", {type: "meal", occurredAt: isoDaysBefore(1)}),
          logDoc("m2", {type: "meal", occurredAt: isoDaysBefore(2)}),
          logDoc("s1", {type: "symptom", occurredAt: isoDaysBefore(3)}),
          logDoc("mood1", {type: "mood", occurredAt: isoDaysBefore(4)}),
          logDoc("t1", {type: "training", occurredAt: isoDaysBefore(2)}),
          // Outside window (before startDate) — should NOT count.
          logDoc("old-meal", {
            type: "meal", occurredAt: isoDaysBefore(20),
          }),
        ],
        sessions: [],
        bloodwork: [],
      });
      const result = await getProtocolTimeline.handler({
        input: {
          protocolId: "p1",
          includeSessions: false,
          includeBloodwork: false,
        },
        ctx: {userRef, now: NOW},
      });
      expect(result.adherenceSummary).toEqual({
        loggedDoses: 2,
        loggedMeals: 2,
        loggedSymptoms: 1,
        loggedMoods: 1,
        loggedTraining: 1,
        expectedDoses: 12, // currentCycleDay 6 × 2 doses/day
      });
    });

  test("expectedDoses computed from timesOfDayMinutes when present",
    async () => {
      const userRef = fakeUserRef({
        protocols: [protocolDoc("p1", {
          // currentCycleDay is now derived from startDate by the
          // shared shaper — set startDate so derived day = 7.
          startDate: isoDaysBefore(6),
          timesOfDayMinutes: [420, 1200, 1380], // 3/day
        })],
        log_entries: [],
        sessions: [],
        bloodwork: [],
      });
      const result = await getProtocolTimeline.handler({
        input: {
          protocolId: "p1",
          includeSessions: false,
          includeBloodwork: false,
        },
        ctx: {userRef, now: NOW},
      });
      expect(result.adherenceSummary.expectedDoses).toBe(21);
    });

  test("expectedDoses falls back to frequency enum when timesOfDay missing",
    async () => {
      const userRef = fakeUserRef({
        protocols: [protocolDoc("p1", {
          // Derived currentCycleDay = 4 with startDate 3 days ago.
          startDate: isoDaysBefore(3),
          timesOfDayMinutes: null,
          frequency: "twice_daily",
        })],
        log_entries: [],
        sessions: [],
        bloodwork: [],
      });
      const result = await getProtocolTimeline.handler({
        input: {
          protocolId: "p1",
          includeSessions: false,
          includeBloodwork: false,
        },
        ctx: {userRef, now: NOW},
      });
      expect(result.adherenceSummary.expectedDoses).toBe(8);
    });

  test("expectedDoses omitted when neither timesOfDay nor known frequency",
    async () => {
      const userRef = fakeUserRef({
        protocols: [protocolDoc("p1", {
          currentCycleDay: 4,
          timesOfDayMinutes: null,
          frequency: "as_needed",
        })],
        log_entries: [],
        sessions: [],
        bloodwork: [],
      });
      const result = await getProtocolTimeline.handler({
        input: {
          protocolId: "p1",
          includeSessions: false,
          includeBloodwork: false,
        },
        ctx: {userRef, now: NOW},
      });
      expect(result.adherenceSummary.expectedDoses).toBeUndefined();
    });

  test("includeSessions=false omits sessions entirely", async () => {
    const userRef = fakeUserRef({
      protocols: [protocolDoc("p1")],
      log_entries: [],
      sessions: [
        {id: "s1", data: {
          sessionId: "s1",
          createdAt: isoDaysBefore(2),
          context: {activities: [{type: "breathwork"}]},
          durationSeconds: 600,
        }},
      ],
      bloodwork: [],
    });
    const result = await getProtocolTimeline.handler({
      input: {protocolId: "p1", includeSessions: false},
      ctx: {userRef, now: NOW},
    });
    expect(result.sessions).toBeUndefined();
  });

  test("includeBloodwork=false omits bloodwork entirely", async () => {
    const userRef = fakeUserRef({
      protocols: [protocolDoc("p1")],
      log_entries: [],
      sessions: [],
      bloodwork: [
        {id: "bw1", data: {id: "bw1", labDate: isoDaysBefore(3)}},
      ],
    });
    const result = await getProtocolTimeline.handler({
      input: {protocolId: "p1", includeBloodwork: false},
      ctx: {userRef, now: NOW},
    });
    expect(result.bloodwork).toBeUndefined();
  });

  test("bloodwork labeled before/during/after relative to cycle window",
    async () => {
      const userRef = fakeUserRef({
        protocols: [protocolDoc("p1", {
          startDate: isoDaysBefore(10),
          cycleLengthDays: 5, // ended 5 days ago
          isActive: false,
        })],
        log_entries: [],
        sessions: [],
        bloodwork: [
          {id: "before", data: {
            id: "before", labDate: isoDaysBefore(20),
          }},
          {id: "during", data: {
            id: "during", labDate: isoDaysBefore(7),
          }},
          {id: "after", data: {
            id: "after", labDate: isoDaysBefore(1),
          }},
        ],
      });
      const result = await getProtocolTimeline.handler({
        input: {protocolId: "p1"},
        ctx: {userRef, now: NOW},
      });
      const byId = Object.fromEntries(
        result.bloodwork.map((b) => [b.id, b.context]),
      );
      expect(byId).toEqual({
        before: "before",
        during: "during",
        after: "after",
      });
    });

  test("sessions inside cycleWindow included; outside excluded", async () => {
    const userRef = fakeUserRef({
      protocols: [protocolDoc("p1", {
        startDate: isoDaysBefore(5),
        currentCycleDay: 6,
      })],
      log_entries: [],
      sessions: [
        {id: "in", data: {
          sessionId: "in",
          createdAt: isoDaysBefore(2),
          context: {activities: [{type: "breathwork"}]},
          durationSeconds: 300,
        }},
        {id: "out-old", data: {
          sessionId: "out-old",
          createdAt: isoDaysBefore(20),
        }},
        {id: "out-future", data: {
          sessionId: "out-future",
          createdAt: isoDaysAfter(2),
        }},
      ],
      bloodwork: [],
    });
    const result = await getProtocolTimeline.handler({
      input: {protocolId: "p1"},
      ctx: {userRef, now: NOW},
    });
    expect(result.sessions.map((s) => s.sessionId)).toEqual(["in"]);
  });

  // ===========================================================================
  // Retired-protocol behavior (post-audit follow-up). The handler does NOT
  // filter by isActive on the protocol lookup, so retired protocols return a
  // full historical timeline. cycleWindow.end uses endDate when set rather
  // than now.
  // ===========================================================================

  test("retired protocol id returns full timeline without error",
      async () => {
        const userRef = fakeUserRef({
          protocols: [protocolDoc("retired-p", {
            isActive: false,
            startDate: isoDaysBefore(20),
            endDate: isoDaysBefore(5),
            cycleLengthDays: 30,
            endReason: "completed",
          })],
          log_entries: [
            logDoc("d1", {
              type: "dose",
              protocolIdAtTime: "retired-p",
              occurredAt: isoDaysBefore(15),
            }),
          ],
          sessions: [],
          bloodwork: [],
        });
        const result = await getProtocolTimeline.handler({
          input: {protocolId: "retired-p"},
          ctx: {userRef, now: NOW},
        });
        expect(result.protocol.id).toBe("retired-p");
        expect(result.protocol.isActive).toBe(false);
        expect(result.protocol.endReason).toBe("completed");
        expect(result.logEntries.map((e) => e.id)).toEqual(["d1"]);
        expect(result.adherenceSummary.loggedDoses).toBe(1);
      });

  test("cycleWindow.end for a retired protocol uses endDate", async () => {
    const userRef = fakeUserRef({
      protocols: [protocolDoc("retired-p", {
        isActive: false,
        startDate: isoDaysBefore(20),
        endDate: isoDaysBefore(5),
        cycleLengthDays: 30,
        endReason: "completed",
      })],
      log_entries: [],
      sessions: [],
      bloodwork: [],
    });
    const result = await getProtocolTimeline.handler({
      input: {
        protocolId: "retired-p",
        includeSessions: false,
        includeBloodwork: false,
      },
      ctx: {userRef, now: NOW},
    });
    expect(result.cycleWindow.end).toBe(isoDaysBefore(5));
  });

  test("cycleWindow.end for an active ongoing protocol = now", async () => {
    const userRef = fakeUserRef({
      protocols: [protocolDoc("ongoing-p", {
        isActive: true,
        isOngoingFlag: true,
        startDate: isoDaysBefore(50),
        cycleLengthDays: 0,
      })],
      log_entries: [],
      sessions: [],
      bloodwork: [],
    });
    const result = await getProtocolTimeline.handler({
      input: {
        protocolId: "ongoing-p",
        includeSessions: false,
        includeBloodwork: false,
      },
      ctx: {userRef, now: NOW},
    });
    expect(result.cycleWindow.end).toBe(new Date(NOW).toISOString());
  });

  test("cycleWindow.end for active cycled = min(plannedEnd, now)",
      async () => {
        // Active, cycled, planned end is in the future → end = now.
        const userRef = fakeUserRef({
          protocols: [protocolDoc("active-cycled", {
            isActive: true,
            isOngoingFlag: false,
            startDate: isoDaysBefore(5),
            cycleLengthDays: 30,
          })],
          log_entries: [],
          sessions: [],
          bloodwork: [],
        });
        const result = await getProtocolTimeline.handler({
          input: {
            protocolId: "active-cycled",
            includeSessions: false,
            includeBloodwork: false,
          },
          ctx: {userRef, now: NOW},
        });
        // planned end is 25 days in the future, so end clamps to now.
        expect(result.cycleWindow.end).toBe(new Date(NOW).toISOString());
      });
});
