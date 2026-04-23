const {shapeProtocolForMcp} = require("./_protocol_shape");

const NAME = "get_biological_context";

async function handler({ input, ctx }) {
  const { userRef, now } = ctx;
  const referenceNow = typeof now === "number" ? new Date(now) : new Date();

  const [profileDoc, protocolsSnap, sessionsSnap] = await Promise.all([
    userRef.collection("meta").doc("profile").get(),
    userRef.collection("protocols")
      .orderBy("startDate", "desc").limit(10).get(),
    userRef.collection("sessions")
      .orderBy("createdAt", "desc").limit(5).get(),
  ]);

  const profile = profileDoc.data() || {};
  // Shape protocols server-side so currentCycleDay/isOngoing reflect
  // today's reality rather than a stale write-time snapshot.
  const protocols = protocolsSnap.docs.map(
    (d) => shapeProtocolForMcp(d, referenceNow),
  );
  const sessions = sessionsSnap.docs.map((d) => d.data());

  let fastingHours = null;
  if (profile.lastMealTime) {
    const lastMeal = new Date(profile.lastMealTime);
    fastingHours = (now - lastMeal.getTime()) / 3600000;
  }

  const hrvValues = sessions
    .map((s) => s.biometrics?.hrvRmssdMs)
    .filter((v) => v && v > 0);
  const hrvBaseline = hrvValues.length > 0
    ? hrvValues.reduce((a, b) => a + b, 0) / hrvValues.length
    : null;

  return {
    profile: {
      weightKg: profile.weightKg,
      mthfr: profile.mthfr,
      apoe: profile.apoe,
      comt: profile.comt,
    },
    fastingState: {
      fastingHours: fastingHours
        ? Math.round(fastingHours * 10) / 10
        : null,
      fastingType: profile.fastingType,
      eatWindowStart: profile.eatWindowStartHour,
      eatWindowEnd: profile.eatWindowEndHour,
      lastMealTime: profile.lastMealTime,
    },
    activeProtocols: protocols.map((p) => ({
      name: p.name,
      type: p.type,
      doseMcg: p.doseMcg,
      route: p.route,
      currentCycleDay: p.currentCycleDay,
      cycleLengthDays: p.cycleLengthDays,
      isOngoing: p.isOngoing,
      notes: p.notes,
    })),
    biometricBaseline: {
      hrvBaselineMs: hrvBaseline ? Math.round(hrvBaseline) : null,
      sessionCount: sessions.length,
      lastSessionAt: sessions[0]?.createdAt || null,
    },
  };
}

module.exports = { name: NAME, handler };
