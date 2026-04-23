// Shared LogEntry → MCP-output shaper. Used by both `get_log_entries`
// and `get_protocol_timeline` so the wire format for log entries is
// defined in exactly one place.
//
// Why this exists as its own module: the protocol-timeline tool returns
// log entries as a sub-section, and any drift between the two tools'
// output shape would silently break Claude's ability to reason across
// them. One source of truth instead.

// Convert a Firestore-stored timestamp value to an ISO 8601 string.
//
// `firestore_sync.dart` writes occurredAt/loggedAt as ISO strings via
// `DateTime.toIso8601String()`, so the string branch is the hot path.
// The Date / Timestamp / millis branches are defensive — if a
// downstream writer ever changes encoding, this helper still produces
// a stable wire format and the dependent tools don't have to know.
function toIsoString(value) {
  if (value == null) return null;
  if (typeof value === "string") return value;
  if (value instanceof Date) return value.toISOString();
  // Firestore Admin Timestamp duck-typed (has a .toDate()).
  if (typeof value.toDate === "function") {
    return value.toDate().toISOString();
  }
  if (typeof value === "number") {
    return new Date(value).toISOString();
  }
  return null;
}

// Shape a Firestore log entry document for MCP output.
//
// Accepts either a Firestore QueryDocumentSnapshot (has `.id` and
// `.data()`) or a raw object with the fields inline. The latter is
// used by tests that don't bother wrapping their fixtures.
//
// Output rules:
// - rawText is always present, defaults to '' so callers can render
//   without null checks.
// - Classifier fields (confidence, modelVersion, structured) are
//   only included when classificationStatus === 'classified'.
// - protocolIdAtTime is included only if non-null/non-empty.
// - vitals are bundled into a sub-object; zero/null values are
//   treated as "no reading" (matching the Dart-side `> 0` convention)
//   and the entire vitals object is omitted if every reading is
//   missing.
function shapeLogEntryForMcp(docOrData) {
  const data = typeof docOrData.data === "function" ?
    docOrData.data() :
    docOrData;
  const id = docOrData.id != null ? docOrData.id : data.id;

  const result = {
    id,
    occurredAt: toIsoString(data.occurredAt),
    type: data.type,
    classificationStatus: data.classificationStatus,
    rawText: data.rawText || "",
  };

  if (data.classificationStatus === "classified") {
    if (data.classificationConfidence != null) {
      result.confidence = data.classificationConfidence;
    }
    if (data.classificationModelVersion != null) {
      result.modelVersion = data.classificationModelVersion;
    }
    result.structured = data.structured || null;
    if (data.protocolIdAtTime) {
      result.protocolIdAtTime = data.protocolIdAtTime;
    }
  }

  const vitals = {};
  if (data.hrBpm != null && data.hrBpm > 0) vitals.hrBpm = data.hrBpm;
  if (data.hrvMs != null && data.hrvMs > 0) vitals.hrvMs = data.hrvMs;
  if (data.gsrUs != null && data.gsrUs > 0) vitals.gsrUs = data.gsrUs;
  if (data.skinTempF != null && data.skinTempF > 0) {
    vitals.skinTempF = data.skinTempF;
  }
  if (data.spo2Percent != null && data.spo2Percent > 0) {
    vitals.spo2Percent = data.spo2Percent;
  }
  if (Object.keys(vitals).length > 0) result.vitals = vitals;

  return result;
}

module.exports = {shapeLogEntryForMcp, toIsoString};
