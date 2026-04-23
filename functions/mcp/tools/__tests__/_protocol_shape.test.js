const {
  shapeProtocolForMcp,
  parseDate,
  computeCurrentCycleDay,
  computePlannedEndDate,
  computeIsOnCycle,
  computeDaysRemaining,
  resolveIsOngoing,
} = require("../_protocol_shape");

const DAY_MS = 86400000;
const NOW = new Date("2026-04-22T12:00:00Z");

function isoDaysBefore(days) {
  return new Date(NOW.getTime() - days * DAY_MS).toISOString();
}

// ── parseDate ───────────────────────────────────────────────────────────

describe("parseDate", () => {
  test("ISO string", () => {
    expect(parseDate("2026-04-22T12:00:00.000Z").getTime())
      .toBe(NOW.getTime());
  });
  test("Date passes through", () => {
    expect(parseDate(NOW)).toBe(NOW);
  });
  test("milliseconds number", () => {
    expect(parseDate(NOW.getTime()).getTime()).toBe(NOW.getTime());
  });
  test("Firestore Timestamp duck-type", () => {
    const ts = {toDate: () => NOW};
    expect(parseDate(ts)).toBe(NOW);
  });
  test("null/undefined", () => {
    expect(parseDate(null)).toBeNull();
    expect(parseDate(undefined)).toBeNull();
  });
});

// ── computeCurrentCycleDay ──────────────────────────────────────────────

describe("computeCurrentCycleDay", () => {
  const start = (days) => new Date(NOW.getTime() - days * DAY_MS);

  test("startDate today → day 1", () => {
    expect(computeCurrentCycleDay(start(0), NOW, 30)).toBe(1);
  });
  test("startDate one day ago → day 2", () => {
    expect(computeCurrentCycleDay(start(1), NOW, 30)).toBe(2);
  });
  test("startDate 28 days ago → day 29 (within 30-day cycle)", () => {
    expect(computeCurrentCycleDay(start(28), NOW, 30)).toBe(29);
  });
  test("clamped to cycleLengthDays", () => {
    expect(computeCurrentCycleDay(start(50), NOW, 30)).toBe(30);
  });
  test("cycleLengthDays of 0 clamps to 1 (matches Dart)", () => {
    expect(computeCurrentCycleDay(start(50), NOW, 0)).toBe(1);
  });
  test("cycleLengthDays missing/null clamps to 1", () => {
    expect(computeCurrentCycleDay(start(50), NOW, null)).toBe(1);
  });
  test("missing startDate returns 1", () => {
    expect(computeCurrentCycleDay(null, NOW, 30)).toBe(1);
  });
  test("startDate in future never goes below 1", () => {
    expect(computeCurrentCycleDay(start(-3), NOW, 30)).toBe(1);
  });
});

// ── computePlannedEndDate ───────────────────────────────────────────────

describe("computePlannedEndDate", () => {
  test("non-ongoing → start + cycleLength", () => {
    const start = new Date(NOW.getTime() - 5 * DAY_MS);
    expect(computePlannedEndDate(start, 30, false).getTime())
      .toBe(start.getTime() + 30 * DAY_MS);
  });
  test("ongoing → null", () => {
    expect(computePlannedEndDate(NOW, 30, true)).toBeNull();
  });
  test("missing cycleLengthDays → null", () => {
    expect(computePlannedEndDate(NOW, null, false)).toBeNull();
    expect(computePlannedEndDate(NOW, 0, false)).toBeNull();
  });
  test("missing startDate → null", () => {
    expect(computePlannedEndDate(null, 30, false)).toBeNull();
  });
});

// ── computeIsOnCycle ────────────────────────────────────────────────────

describe("computeIsOnCycle", () => {
  const start = (days) => new Date(NOW.getTime() - days * DAY_MS);

  test("isActive=false → false", () => {
    expect(computeIsOnCycle({
      isActive: false,
      startDate: start(2),
      isOngoing: false,
      cycleLengthDays: 30,
      now: NOW,
    })).toBe(false);
  });
  test("startDate in future → false", () => {
    expect(computeIsOnCycle({
      isActive: true,
      startDate: start(-3),
      isOngoing: false,
      cycleLengthDays: 30,
      now: NOW,
    })).toBe(false);
  });
  test("ongoing protocol with no plannedEnd → true", () => {
    expect(computeIsOnCycle({
      isActive: true,
      startDate: start(100),
      isOngoing: true,
      cycleLengthDays: 30,
      now: NOW,
    })).toBe(true);
  });
  test("inside cycle window → true", () => {
    expect(computeIsOnCycle({
      isActive: true,
      startDate: start(5),
      isOngoing: false,
      cycleLengthDays: 30,
      now: NOW,
    })).toBe(true);
  });
  test("past plannedEnd → false", () => {
    expect(computeIsOnCycle({
      isActive: true,
      startDate: start(50),
      isOngoing: false,
      cycleLengthDays: 30,
      now: NOW,
    })).toBe(false);
  });
  test("manually retired (endDate in past) → false", () => {
    expect(computeIsOnCycle({
      isActive: true,
      startDate: start(5),
      endDate: new Date(NOW.getTime() - DAY_MS),
      isOngoing: false,
      cycleLengthDays: 30,
      now: NOW,
    })).toBe(false);
  });
  test("cycleLengthDays<=0 with active+ongoing-equivalent → true", () => {
    expect(computeIsOnCycle({
      isActive: true,
      startDate: start(2),
      isOngoing: false,
      cycleLengthDays: 0,
      now: NOW,
    })).toBe(true);
  });
});

// ── computeDaysRemaining ────────────────────────────────────────────────

describe("computeDaysRemaining", () => {
  test("mid-cycle returns positive days", () => {
    const plannedEnd = new Date(NOW.getTime() + 25 * DAY_MS);
    expect(computeDaysRemaining(plannedEnd, NOW, false, true)).toBe(25);
  });
  test("past plannedEnd returns negative (matches Dart inDays)", () => {
    const plannedEnd = new Date(NOW.getTime() - 3 * DAY_MS);
    expect(computeDaysRemaining(plannedEnd, NOW, false, true)).toBe(-3);
  });
  test("ongoing → null", () => {
    const plannedEnd = new Date(NOW.getTime() + 5 * DAY_MS);
    expect(computeDaysRemaining(plannedEnd, NOW, true, true)).toBeNull();
  });
  test("inactive → null", () => {
    const plannedEnd = new Date(NOW.getTime() + 5 * DAY_MS);
    expect(computeDaysRemaining(plannedEnd, NOW, false, false)).toBeNull();
  });
  test("no plannedEnd → null", () => {
    expect(computeDaysRemaining(null, NOW, false, true)).toBeNull();
  });
});

// ── resolveIsOngoing ────────────────────────────────────────────────────

describe("resolveIsOngoing", () => {
  test("new schema isOngoingFlag=true wins", () => {
    expect(resolveIsOngoing({isOngoingFlag: true})).toBe(true);
    expect(resolveIsOngoing({isOngoingFlag: false})).toBe(false);
  });
  test("legacy isOngoing field used when isOngoingFlag absent", () => {
    expect(resolveIsOngoing({isOngoing: true})).toBe(true);
    expect(resolveIsOngoing({isOngoing: false})).toBe(false);
  });
  test("isOngoingFlag wins over legacy isOngoing if both set", () => {
    expect(resolveIsOngoing({
      isOngoingFlag: false,
      isOngoing: true,
    })).toBe(false);
  });
  test("neither set → false", () => {
    expect(resolveIsOngoing({})).toBe(false);
  });
});

// ── shapeProtocolForMcp full smoke ─────────────────────────────────────

describe("shapeProtocolForMcp", () => {
  function fakeDoc(id, data) {
    return {id, data: () => data};
  }

  test("full Firestore-shaped doc → all output fields populated", () => {
    const out = shapeProtocolForMcp(fakeDoc("p1", {
      id: "p1",
      name: "BPC-157",
      type: "peptide",
      startDate: isoDaysBefore(5),
      endDate: null,
      cycleLengthDays: 30,
      doseMcg: 250,
      route: "sc",
      notes: "morning + evening",
      isActive: true,
      isOngoingFlag: false,
      doseDisplay: "250mcg",
      frequency: "twice_daily",
      timesOfDayMinutes: [420, 1200],
      endReason: null,
      measurementTargets: ["hrv"],
      measurementTargetsNotes: "watch deep sleep",
    }), NOW);

    expect(out.id).toBe("p1");
    expect(out.name).toBe("BPC-157");
    expect(out.type).toBe("peptide");
    expect(out.startDate).toBe(isoDaysBefore(5));
    expect(out.endDate).toBeNull();
    expect(out.cycleLengthDays).toBe(30);
    expect(out.doseMcg).toBe(250);
    expect(out.route).toBe("sc");
    expect(out.notes).toBe("morning + evening");
    expect(out.isActive).toBe(true);
    expect(out.isOngoing).toBe(false);
    expect(out.doseDisplay).toBe("250mcg");
    expect(out.frequency).toBe("twice_daily");
    expect(out.timesOfDayMinutes).toEqual([420, 1200]);
    expect(out.measurementTargets).toEqual(["hrv"]);
    // Derived
    expect(out.currentCycleDay).toBe(6);
    expect(out.plannedEndDate).toBe(
      new Date(Date.parse(isoDaysBefore(5)) + 30 * DAY_MS).toISOString(),
    );
    expect(out.isOnCycle).toBe(true);
    expect(out.daysRemaining).toBe(25);
  });

  test("ongoing protocol omits plannedEndDate + daysRemaining", () => {
    const out = shapeProtocolForMcp(fakeDoc("p2", {
      name: "GlyNAC",
      type: "supplement",
      startDate: isoDaysBefore(100),
      cycleLengthDays: 0,
      isActive: true,
      isOngoingFlag: true,
    }), NOW);
    expect(out.isOngoing).toBe(true);
    expect(out.plannedEndDate).toBeNull();
    expect(out.daysRemaining).toBeNull();
    expect(out.isOnCycle).toBe(true);
  });

  test("legacy doc with `isOngoing` field instead of `isOngoingFlag`",
      () => {
        const out = shapeProtocolForMcp(fakeDoc("legacy", {
          name: "LegacyProto",
          type: "supplement",
          startDate: isoDaysBefore(5),
          cycleLengthDays: 30,
          isActive: true,
          isOngoing: true, // pre-Fix-#4 schema
        }), NOW);
        expect(out.isOngoing).toBe(true);
        expect(out.plannedEndDate).toBeNull();
      });

  test("plain object input (no .data()) works", () => {
    const out = shapeProtocolForMcp({
      id: "raw",
      name: "Raw",
      type: "peptide",
      startDate: isoDaysBefore(2),
      cycleLengthDays: 30,
      isActive: true,
      isOngoingFlag: false,
    }, NOW);
    expect(out.id).toBe("raw");
    expect(out.currentCycleDay).toBe(3);
  });

  test("retired protocol (isActive=false) → isOnCycle false", () => {
    const out = shapeProtocolForMcp(fakeDoc("done", {
      name: "EndedProto",
      type: "peptide",
      startDate: isoDaysBefore(10),
      endDate: isoDaysBefore(2),
      cycleLengthDays: 30,
      isActive: false,
      isOngoingFlag: false,
      endReason: "completed",
    }), NOW);
    expect(out.isOnCycle).toBe(false);
    expect(out.endReason).toBe("completed");
    expect(out.isActive).toBe(false);
  });
});
