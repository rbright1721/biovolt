const {
  shapeLogEntryForMcp,
  toIsoString,
} = require("../_log_entry_shape");

describe("toIsoString", () => {
  test("ISO string passes through unchanged", () => {
    expect(toIsoString("2026-04-22T12:00:00.000Z"))
      .toBe("2026-04-22T12:00:00.000Z");
  });

  test("Date object converts to ISO", () => {
    const d = new Date("2026-04-22T12:00:00Z");
    expect(toIsoString(d)).toBe("2026-04-22T12:00:00.000Z");
  });

  test("milliseconds number converts to ISO", () => {
    const ms = Date.UTC(2026, 3, 22, 12, 0, 0);
    expect(toIsoString(ms)).toBe("2026-04-22T12:00:00.000Z");
  });

  test("Firestore Timestamp duck-type converts via .toDate()", () => {
    const ts = {
      toDate: () => new Date("2026-04-22T12:00:00Z"),
    };
    expect(toIsoString(ts)).toBe("2026-04-22T12:00:00.000Z");
  });

  test("null/undefined return null", () => {
    expect(toIsoString(null)).toBeNull();
    expect(toIsoString(undefined)).toBeNull();
  });

  test("unsupported types return null", () => {
    expect(toIsoString(true)).toBeNull();
    expect(toIsoString({})).toBeNull();
  });
});

describe("shapeLogEntryForMcp", () => {
  function fakeDoc(id, data) {
    return {id, data: () => data};
  }

  test("classified entry includes confidence, modelVersion, structured", () => {
    const out = shapeLogEntryForMcp(fakeDoc("e1", {
      occurredAt: "2026-04-22T12:00:00Z",
      type: "dose",
      classificationStatus: "classified",
      classificationConfidence: 0.92,
      classificationModelVersion: "claude-sonnet-4-5-prompt-v1",
      structured: {compound: "BPC-157", dose: "250mcg"},
      protocolIdAtTime: "p-bpc",
      rawText: "took my BPC dose",
    }));

    expect(out).toMatchObject({
      id: "e1",
      occurredAt: "2026-04-22T12:00:00Z",
      type: "dose",
      classificationStatus: "classified",
      rawText: "took my BPC dose",
      confidence: 0.92,
      modelVersion: "claude-sonnet-4-5-prompt-v1",
      structured: {compound: "BPC-157", dose: "250mcg"},
      protocolIdAtTime: "p-bpc",
    });
  });

  test("unclassified (pending) entry omits classifier fields", () => {
    const out = shapeLogEntryForMcp(fakeDoc("e2", {
      occurredAt: "2026-04-22T12:00:00Z",
      type: "other",
      classificationStatus: "pending",
      rawText: "felt okay",
    }));

    expect(out.confidence).toBeUndefined();
    expect(out.modelVersion).toBeUndefined();
    expect(out.structured).toBeUndefined();
    expect(out.protocolIdAtTime).toBeUndefined();
    expect(out.rawText).toBe("felt okay");
    expect(out.classificationStatus).toBe("pending");
  });

  test("rawText defaults to empty string when missing", () => {
    const out = shapeLogEntryForMcp(fakeDoc("e3", {
      occurredAt: "2026-04-22T12:00:00Z",
      type: "other",
      classificationStatus: "pending",
    }));
    expect(out.rawText).toBe("");
  });

  test("entry with no vitals omits the vitals field entirely", () => {
    const out = shapeLogEntryForMcp(fakeDoc("e4", {
      occurredAt: "2026-04-22T12:00:00Z",
      type: "note",
      classificationStatus: "classified",
      structured: null,
    }));
    expect(out.vitals).toBeUndefined();
  });

  test("zero vitals are treated as missing", () => {
    const out = shapeLogEntryForMcp(fakeDoc("e5", {
      occurredAt: "2026-04-22T12:00:00Z",
      type: "note",
      classificationStatus: "classified",
      hrBpm: 0,
      hrvMs: 0,
      gsrUs: 0,
    }));
    expect(out.vitals).toBeUndefined();
  });

  test("mixed vitals: only non-zero readings appear", () => {
    const out = shapeLogEntryForMcp(fakeDoc("e6", {
      occurredAt: "2026-04-22T12:00:00Z",
      type: "note",
      classificationStatus: "classified",
      hrBpm: 64,
      hrvMs: 0,
      gsrUs: 2.7,
      skinTempF: 0,
      spo2Percent: 97,
    }));
    expect(out.vitals).toEqual({
      hrBpm: 64,
      gsrUs: 2.7,
      spo2Percent: 97,
    });
  });

  test("plain object input (no .data() wrapper) works", () => {
    const out = shapeLogEntryForMcp({
      id: "e7",
      occurredAt: "2026-04-22T12:00:00Z",
      type: "note",
      classificationStatus: "pending",
      rawText: "raw style",
    });
    expect(out.id).toBe("e7");
    expect(out.rawText).toBe("raw style");
  });

  test("classified entry with no protocolIdAtTime omits the field", () => {
    const out = shapeLogEntryForMcp(fakeDoc("e8", {
      occurredAt: "2026-04-22T12:00:00Z",
      type: "meal",
      classificationStatus: "classified",
      structured: {description: "eggs"},
    }));
    expect(out.protocolIdAtTime).toBeUndefined();
    expect(out.structured).toEqual({description: "eggs"});
  });
});
