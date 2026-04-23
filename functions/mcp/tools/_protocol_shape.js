// Shared ActiveProtocol → MCP-output shaper. Used by every MCP tool
// that returns protocol data so the wire format stays consistent and
// time-derived fields (currentCycleDay, plannedEndDate, isOnCycle,
// daysRemaining) are computed fresh on every read.
//
// Why server-side derivation: the Dart model exposes these as getters
// that read DateTime.now() against startDate/cycleLengthDays. The
// Firestore document only stores the source fields; if we wrote the
// derived snapshot at sync time it would silently drift between
// writes ("currentCycleDay: 12" frozen forever even though it's
// actually day 19 today). Computing on read keeps every tool's output
// honest.
//
// Source-of-truth semantics mirror lib/models/active_protocol.dart:
//   currentCycleDay  - 1-based, clamped to [1, cycleLengthDays] (or 1
//                      when cycleLengthDays is 0).
//   isOngoing        - isOngoingFlag ?? false (Dart getter at :189).
//                      Falls back to legacy `isOngoing` field for docs
//                      written before the schema split.
//   plannedEndDate   - startDate + cycleLengthDays days; null when
//                      ongoing or missing length.
//   isOnCycle        - isActive && !startDate-in-future && (ongoing OR
//                      now <= plannedEnd).
//   daysRemaining    - days from now to plannedEnd; null when ongoing.

const DAY_MS = 86400000;

function parseDate(v) {
  if (v == null) return null;
  if (v instanceof Date) return v;
  if (typeof v === "string") return new Date(v);
  if (typeof v.toDate === "function") return v.toDate();
  if (typeof v === "number") return new Date(v);
  return null;
}

// Mirror of ActiveProtocol.currentCycleDay (Dart):
//   final days = DateTime.now().difference(startDate).inDays + 1;
//   return days.clamp(1, cycleLengthDays == 0 ? 1 : cycleLengthDays);
//
// `inDays` in Dart is `floor((aMs - bMs) / 86400000)`, matching JS
// `Math.floor`. For startDate = today  → days=0+1=1. For startDate
// 28 days ago → days=29. Clamped to 1..cycleLengthDays (or 1 when
// cycleLengthDays is 0).
function computeCurrentCycleDay(startDate, now, cycleLengthDays) {
  if (!startDate) return 1;
  const days = Math.floor((now.getTime() - startDate.getTime()) / DAY_MS) + 1;
  const max = (cycleLengthDays == null || cycleLengthDays === 0)
    ? 1
    : cycleLengthDays;
  return Math.min(Math.max(days, 1), max);
}

function computePlannedEndDate(startDate, cycleLengthDays, isOngoing) {
  if (isOngoing || !startDate || !cycleLengthDays) return null;
  return new Date(startDate.getTime() + cycleLengthDays * DAY_MS);
}

// Mirror of ActiveProtocol.isOnCycle (Dart):
//   if (!isActive) return false;
//   if (now.isBefore(startDate)) return false;
//   if (isOngoing) return true;
//   if (cycleLengthDays <= 0) return true;
//   final planned = startDate.add(Duration(days: cycleLengthDays));
//   return !now.isAfter(planned);
//
// We additionally honor an explicit endDate: a manually-retired
// protocol (endDate set, in the past) is no longer on cycle. Dart's
// getter implicitly handles this through isActive=false on retire.
function computeIsOnCycle({
  isActive,
  startDate,
  endDate,
  isOngoing,
  cycleLengthDays,
  now,
}) {
  if (!isActive) return false;
  if (!startDate) return false;
  if (now < startDate) return false;
  if (endDate && now > endDate) return false;
  if (isOngoing) return true;
  if (cycleLengthDays == null || cycleLengthDays <= 0) return true;
  const plannedEnd = new Date(
    startDate.getTime() + cycleLengthDays * DAY_MS,
  );
  return now <= plannedEnd;
}

// Mirror of ActiveProtocol.daysRemaining (Dart):
//   if (isOngoing || !isActive) return null;
//   final planned = plannedEndDate;
//   if (planned == null) return null;
//   return planned.difference(DateTime.now()).inDays;
//
// Dart's `inDays` truncates toward zero. We mirror with floor; the
// audit's recommendation note used `ceil` but that diverges from the
// Dart getter. Source of truth wins.
function computeDaysRemaining(plannedEnd, now, isOngoing, isActive) {
  if (isOngoing || isActive === false || !plannedEnd) return null;
  return Math.floor((plannedEnd.getTime() - now.getTime()) / DAY_MS);
}

// Resolve isOngoing from the stored doc with backwards-compatible
// fallbacks:
//   1. New schema: isOngoingFlag (bool|null) → isOngoingFlag ?? false.
//   2. Legacy schema: pre-fix #4 docs wrote a derived `isOngoing`
//      bool. Honor it for docs the cold-start backfill hasn't yet
//      re-synced.
function resolveIsOngoing(data) {
  if (typeof data.isOngoingFlag === "boolean") return data.isOngoingFlag;
  if (typeof data.isOngoing === "boolean") return data.isOngoing;
  return false;
}

// Shape a Firestore protocol document for MCP output.
//
// Accepts a Firestore QueryDocumentSnapshot (`.id` + `.data()`) or a
// plain `{id, ...fields}` object (used by tests).
function shapeProtocolForMcp(docOrData, now = new Date()) {
  const data = typeof docOrData.data === "function"
    ? docOrData.data()
    : docOrData;
  const id = docOrData.id != null ? docOrData.id : data.id;

  const startDate = parseDate(data.startDate);
  const endDate = parseDate(data.endDate);
  const cycleLengthDays = data.cycleLengthDays;
  const isActive = data.isActive === true;
  const isOngoing = resolveIsOngoing(data);

  const currentCycleDay = computeCurrentCycleDay(
    startDate,
    now,
    cycleLengthDays,
  );
  const plannedEndDate = computePlannedEndDate(
    startDate,
    cycleLengthDays,
    isOngoing,
  );
  const isOnCycle = computeIsOnCycle({
    isActive,
    startDate,
    endDate,
    isOngoing,
    cycleLengthDays,
    now,
  });
  const daysRemaining = computeDaysRemaining(
    plannedEndDate,
    now,
    isOngoing,
    isActive,
  );

  return {
    id,
    name: data.name,
    type: data.type,
    startDate: startDate ? startDate.toISOString() : null,
    endDate: endDate ? endDate.toISOString() : null,
    cycleLengthDays: cycleLengthDays != null ? cycleLengthDays : null,
    doseMcg: data.doseMcg != null ? data.doseMcg : null,
    route: data.route || null,
    notes: data.notes || null,
    isActive,
    isOngoing,
    doseDisplay: data.doseDisplay || null,
    frequency: data.frequency || null,
    frequencyCustom: data.frequencyCustom || null,
    timesOfDayMinutes: data.timesOfDayMinutes || null,
    endReason: data.endReason || null,
    measurementTargets: data.measurementTargets || null,
    measurementTargetsNotes: data.measurementTargetsNotes || null,
    // Derived (server-side, fresh per call):
    currentCycleDay,
    plannedEndDate: plannedEndDate ? plannedEndDate.toISOString() : null,
    isOnCycle,
    daysRemaining,
  };
}

module.exports = {
  shapeProtocolForMcp,
  parseDate,
  computeCurrentCycleDay,
  computePlannedEndDate,
  computeIsOnCycle,
  computeDaysRemaining,
  resolveIsOngoing,
};
