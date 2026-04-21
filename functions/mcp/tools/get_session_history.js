const NAME = "get_session_history";

async function handler({ input, ctx }) {
  const { userRef, now } = ctx;

  const days = Math.min(input.days || 7, 30);
  const since = new Date(now);
  since.setDate(since.getDate() - days);

  const snap = await userRef.collection("sessions")
    .orderBy("createdAt", "desc")
    .limit(20)
    .get();

  const sessions = snap.docs
    .map((d) => d.data())
    .filter((s) => new Date(s.createdAt) >= since);

  const analysisSnap = await Promise.all(
    sessions.slice(0, 5).map((s) =>
      userRef.collection("ai_analysis").doc(s.sessionId).get(),
    ),
  );

  return {
    sessions: sessions.map((s, i) => ({
      sessionId: s.sessionId,
      createdAt: s.createdAt,
      type: s.context?.activities?.[0]?.type,
      durationSeconds:
        s.context?.activities?.[0]?.durationSeconds,
      biometrics: s.biometrics,
      subjective: s.subjective,
      aiAnalysis: analysisSnap[i]?.exists
        ? {
          insights: analysisSnap[i].data().insights,
          flags: analysisSnap[i].data().flags,
          trendSummary: analysisSnap[i].data().trendSummary,
          confidence: analysisSnap[i].data().confidence,
        }
        : null,
    })),
  };
}

module.exports = { name: NAME, handler };
