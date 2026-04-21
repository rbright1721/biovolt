const NAME = "get_fasting_state";

async function handler({ input, ctx }) {
  const { userRef, now } = ctx;

  const doc = await userRef.collection("meta").doc("profile").get();
  const p = doc.data() || {};
  let fastingHours = null;
  let inEatingWindow = false;

  if (p.lastMealTime) {
    fastingHours = (now -
      new Date(p.lastMealTime).getTime()) / 3600000;
  }

  if (p.eatWindowStartHour != null && p.eatWindowEndHour != null) {
    const nowDate = new Date(now);
    const hour = nowDate.getHours() + nowDate.getMinutes() / 60;
    inEatingWindow = hour >= p.eatWindowStartHour &&
      hour < p.eatWindowEndHour;
  }

  return {
    fastingHours: fastingHours
      ? Math.round(fastingHours * 10) / 10 : null,
    fastingType: p.fastingType,
    eatWindowStart: p.eatWindowStartHour,
    eatWindowEnd: p.eatWindowEndHour,
    lastMealTime: p.lastMealTime,
    currentlyInEatingWindow: inEatingWindow,
  };
}

module.exports = { name: NAME, handler };
