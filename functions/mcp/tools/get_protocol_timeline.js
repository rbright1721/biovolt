const {shapeLogEntryForMcp, toIsoString} = require("./_log_entry_shape");
const {
  shapeProtocolForMcp,
  resolveIsOngoing,
} = require("./_protocol_shape");

const NAME = "get_protocol_timeline";

const DAY_MS = 24 * 60 * 60 * 1000;

// Return a full timeline view for one protocol — its cycle window,
// log entries tagged to it, an adherence summary (with expected vs
// logged dose count when computable), and optionally the sessions
// and bloodwork that overlapped the cycle.
//
// Cycle window:
//   start = startDate
//   end   = isOngoing  → now
//           else       → min(plannedEndDate, now)   if still on cycle
//                      → endDate                    if cycle has ended
//
// Adherence:
//   loggedDoses     = count of entries with type='dose' AND
//                     protocolIdAtTime == protocolId
//   loggedMeals/symptoms/moods/training = count of entries with that
//                     type within cycleWindow regardless of protocol
//                     tag (these signals matter for protocol context
//                     even when not directly tagged)
//   expectedDoses   = currentCycleDay × dosesPerDay; only computed
//                     when the protocol carries enough info to be
//                     authoritative (frequency or timesOfDayMinutes).
async function handler({input, ctx}) {
  const {userRef, now} = ctx;

  // --- Validation ---
  const protocolId = input.protocolId;
  if (!protocolId || typeof protocolId !== "string") {
    throw new Error("protocolId is required and must be a string");
  }

  const includeSessions = input.includeSessions !== false; // default true
  const includeBloodwork = input.includeBloodwork !== false; // default true
  const referenceNow = typeof now === "number" ? now : Date.now();

  // --- Protocol lookup ---
  const protocolDoc = await userRef.collection("protocols")
    .doc(protocolId)
    .get();
  if (!protocolDoc.exists) {
    // 404-style response: the calling user either doesn't own the
    // protocol or it doesn't exist. We do NOT distinguish between
    // these two cases to avoid leaking presence-of-id across users.
    throw new Error(`Protocol ${protocolId} not found`);
  }
  const protocol = protocolDoc.data();

  // --- Cycle window ---
  const startIso = toIsoString(protocol.startDate);
  const startMs = startIso ? Date.parse(startIso) : referenceNow;
  const endIso = computeCycleEnd({
    protocol,
    startMs,
    referenceNow,
  });
  const endMs = endIso ? Date.parse(endIso) : referenceNow;

  // Shape the protocol once and reuse the derived currentCycleDay
  // for adherence math below — keeps a single source of truth for
  // the per-call snapshot.
  const shapedProtocol = shapeProtocolForMcp(
    protocolDoc,
    new Date(referenceNow),
  );

  // --- Log entries ---
  // Pull a generous slice so we can filter in JS — see comment in
  // get_log_entries.js for the same pattern.
  const logSnap = await userRef.collection("log_entries")
    .orderBy("occurredAt", "desc")
    .limit(500)
    .get();
  const allEntries = logSnap.docs.map((d) => ({
    doc: d,
    data: d.data(),
  }));

  const inWindow = ({data}) => {
    if (typeof data.occurredAt !== "string") return false;
    const occ = Date.parse(data.occurredAt);
    return occ >= startMs && occ <= endMs;
  };

  const protocolEntries = allEntries.filter(({data}) =>
    data.protocolIdAtTime === protocolId,
  );
  const windowedEntries = allEntries.filter(inWindow);

  // --- Adherence summary ---
  const loggedDoses = protocolEntries.filter(
    ({data}) => data.type === "dose",
  ).length;

  const countTypeInWindow = (type) => windowedEntries.filter(
    ({data}) => data.type === type,
  ).length;

  const adherenceSummary = {
    loggedDoses,
    loggedMeals: countTypeInWindow("meal"),
    loggedSymptoms: countTypeInWindow("symptom"),
    loggedMoods: countTypeInWindow("mood"),
    loggedTraining: countTypeInWindow("training"),
  };

  const expectedDoses = computeExpectedDoses(
    protocol,
    shapedProtocol.currentCycleDay,
  );
  if (expectedDoses != null) {
    adherenceSummary.expectedDoses = expectedDoses;
  }

  // --- Result assembly ---
  const result = {
    protocol: shapedProtocol,
    cycleWindow: {start: startIso, end: endIso},
    logEntries: protocolEntries.map(({doc}) => shapeLogEntryForMcp(doc)),
    adherenceSummary,
  };

  if (includeSessions) {
    const sessSnap = await userRef.collection("sessions")
      .orderBy("createdAt", "desc")
      .limit(200)
      .get();
    result.sessions = sessSnap.docs
      .map((d) => d.data())
      .filter((s) => {
        const createdIso = toIsoString(s.createdAt);
        if (!createdIso) return false;
        const created = Date.parse(createdIso);
        return created >= startMs && created <= endMs;
      })
      .map((s) => ({
        sessionId: s.sessionId,
        createdAt: toIsoString(s.createdAt),
        type: s.context?.activities?.[0]?.type || null,
        durationSeconds: s.durationSeconds,
        biometrics: s.biometrics || null,
      }));
  }

  if (includeBloodwork) {
    const bwSnap = await userRef.collection("bloodwork")
      .orderBy("labDate", "desc")
      .limit(20)
      .get();
    result.bloodwork = bwSnap.docs.map((d) => {
      const data = d.data();
      const labIso = toIsoString(data.labDate);
      const labMs = labIso ? Date.parse(labIso) : null;
      let context = "unknown";
      if (labMs != null) {
        if (labMs < startMs) context = "before";
        else if (labMs > endMs) context = "after";
        else context = "during";
      }
      return {
        id: data.id || d.id,
        labDate: labIso,
        context,
        // The full panel is potentially large; surface the raw doc
        // so Claude can read whatever marker the user asks about.
        panel: data,
      };
    });
  }

  return result;
}

function computeCycleEnd({protocol, startMs, referenceNow}) {
  // Hard end: the cycle has been retired explicitly.
  if (protocol.endDate) {
    const ended = toIsoString(protocol.endDate);
    if (ended) return ended;
  }
  // Ongoing: end is "right now" — the cycle hasn't terminated. Reads
  // through resolveIsOngoing so legacy docs (with `isOngoing` field
  // instead of `isOngoingFlag`) still work until cold-start backfill
  // re-syncs them.
  if (resolveIsOngoing(protocol)) {
    return new Date(referenceNow).toISOString();
  }
  // Cycled: end is the planned end OR now, whichever is earlier
  // (we don't extend the cycle past today even if planned end is in
  // the future — adherence over not-yet-elapsed days is meaningless).
  if (typeof protocol.cycleLengthDays === "number" &&
      protocol.cycleLengthDays > 0) {
    const plannedEndMs = startMs + protocol.cycleLengthDays * DAY_MS;
    return new Date(Math.min(plannedEndMs, referenceNow)).toISOString();
  }
  // Fallback — no length info, treat as ongoing.
  return new Date(referenceNow).toISOString();
}

function computeExpectedDoses(protocol, currentCycleDay) {
  // currentCycleDay comes from the shared shaper — derived fresh
  // from startDate/now rather than read from the (no-longer-stored)
  // Firestore field.
  const day = currentCycleDay;
  if (typeof day !== "number" || day < 1) return null;

  // Most authoritative: explicit times-of-day list.
  if (Array.isArray(protocol.timesOfDayMinutes) &&
      protocol.timesOfDayMinutes.length > 0) {
    return day * protocol.timesOfDayMinutes.length;
  }

  // Fallback: parse the frequency enum.
  const dosesPerDay = dosesPerDayForFrequency(protocol.frequency);
  if (dosesPerDay == null) return null;
  return day * dosesPerDay;
}

function dosesPerDayForFrequency(freq) {
  switch (freq) {
  case "once_daily":
    return 1;
  case "twice_daily":
    return 2;
  case "three_times_daily":
    return 3;
  default:
    // 'weekly', 'as_needed', 'custom' don't translate to a per-day
    // count without more context. Return null so the caller omits
    // the field rather than reporting a misleading number.
    return null;
  }
}

module.exports = {
  name: NAME,
  handler,
  computeCycleEnd,
  computeExpectedDoses,
};
