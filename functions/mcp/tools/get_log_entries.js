const {shapeLogEntryForMcp} = require("./_log_entry_shape");

const NAME = "get_log_entries";

const DEFAULT_DAYS = 7;
const MAX_DAYS = 90;
const DEFAULT_LIMIT = 100;
const MAX_LIMIT = 200;

// Return raw timeline observations (LogEntry rows) for the user,
// optionally filtered by classification type and time window.
//
// Range/limit semantics:
//   - sinceDaysAgo defaults to 7, must be in [1, MAX_DAYS]; out-of-range
//     values throw (the SDK turns the throw into an isError response,
//     matching the convention used by other tools).
//   - limit defaults to 100, capped at MAX_LIMIT (200). Requests above
//     the cap are CLAMPED rather than rejected — Claude often passes
//     "give me everything" round-number arguments and silently working
//     within the cap is friendlier than failing.
//   - totalAvailable reflects the pre-limit match count so the caller
//     can tell when results were truncated.
//
// types filter:
//   - Omit / empty → all types pass.
//   - 'unclassified' is a virtual type matching any entry whose
//     classificationStatus !== 'classified' (covers 'pending',
//     'failed', 'permanently_failed', 'skipped').
async function handler({input, ctx}) {
  const {userRef, now} = ctx;

  // --- Validation ---
  const sinceDaysAgo = input.sinceDaysAgo != null ?
    input.sinceDaysAgo :
    DEFAULT_DAYS;
  if (typeof sinceDaysAgo !== "number" ||
      !Number.isFinite(sinceDaysAgo) ||
      sinceDaysAgo < 1 ||
      sinceDaysAgo > MAX_DAYS) {
    throw new Error(
      `sinceDaysAgo must be a number in [1, ${MAX_DAYS}]; got ${sinceDaysAgo}`,
    );
  }

  const requestedLimit = input.limit != null ? input.limit : DEFAULT_LIMIT;
  if (typeof requestedLimit !== "number" ||
      !Number.isFinite(requestedLimit) ||
      requestedLimit < 1) {
    throw new Error(
      `limit must be a positive number; got ${requestedLimit}`,
    );
  }
  const limit = Math.min(requestedLimit, MAX_LIMIT);

  const types = Array.isArray(input.types) ? input.types : null;
  if (types && types.some((t) => typeof t !== "string")) {
    throw new Error("types must be an array of strings");
  }
  const includeUnclassified = types?.includes("unclassified") || false;
  const concreteTypes = types?.filter((t) => t !== "unclassified") || [];

  // --- Read ---
  const referenceNow = typeof now === "number" ? now : Date.now();
  const since = new Date(referenceNow);
  since.setDate(since.getDate() - sinceDaysAgo);

  // We use Firestore's orderBy/limit as a hint but reapply the time
  // window + type filter in JS — `occurredAt` is stored as an ISO
  // string, so range queries on it work with string compare. We pull
  // a generous slice (limit * 4, capped) to allow JS-side filtering
  // without missing matches that fell outside the Firestore limit.
  const fetchSize = Math.min(limit * 4, 1000);
  const snap = await userRef.collection("log_entries")
    .orderBy("occurredAt", "desc")
    .limit(fetchSize)
    .get();

  const sinceIso = since.toISOString();
  const matched = snap.docs
    .map((d) => ({doc: d, data: d.data()}))
    .filter(({data}) => {
      // Time window — defensive against missing/non-string timestamps.
      const occurredAt = data.occurredAt;
      if (typeof occurredAt !== "string") return false;
      if (occurredAt < sinceIso) return false;
      // Type filter
      if (!types || types.length === 0) return true;
      if (concreteTypes.includes(data.type)) return true;
      if (includeUnclassified &&
          data.classificationStatus !== "classified") {
        return true;
      }
      return false;
    });

  // Sort DESC by occurredAt — the orderBy above already does this for
  // the Firestore-supplied slice, but explicit sort guards against
  // fakes/mocks that don't honor orderBy.
  matched.sort((a, b) => {
    if (a.data.occurredAt > b.data.occurredAt) return -1;
    if (a.data.occurredAt < b.data.occurredAt) return 1;
    return 0;
  });

  const totalAvailable = matched.length;
  const sliced = matched.slice(0, limit);

  return {
    entries: sliced.map(({doc}) => shapeLogEntryForMcp(doc)),
    count: sliced.length,
    totalAvailable,
    sinceDaysAgo,
  };
}

module.exports = {
  name: NAME,
  handler,
  // Exported for the schema_conformance test and potential reuse.
  DEFAULT_DAYS,
  MAX_DAYS,
  DEFAULT_LIMIT,
  MAX_LIMIT,
};
