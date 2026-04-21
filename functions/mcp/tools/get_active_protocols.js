const NAME = "get_active_protocols";

async function handler({ input, ctx }) {
  const { userRef } = ctx;

  const snap = await userRef.collection("protocols").get();
  return {
    protocols: snap.docs.map((d) => d.data()),
  };
}

module.exports = { name: NAME, handler };
