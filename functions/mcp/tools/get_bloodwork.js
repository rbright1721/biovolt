const NAME = "get_bloodwork";

async function handler({ input, ctx }) {
  const { userRef } = ctx;

  const snap = await userRef.collection("bloodwork")
    .orderBy("labDate", "desc").limit(1).get();
  return snap.empty
    ? { bloodwork: null }
    : { bloodwork: snap.docs[0].data() };
}

module.exports = { name: NAME, handler };
