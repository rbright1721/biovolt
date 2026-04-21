const NAME = "get_journal_context";

async function handler({ input, ctx }) {
  const { userRef } = ctx;

  const limit = Math.min(input.limit || 10, 20);
  const snap = await userRef.collection("journal")
    .orderBy("timestamp", "desc")
    .limit(limit)
    .get();
  return {
    entries: snap.docs.map((d) => ({
      timestamp: d.data().timestamp,
      conversationId: d.data().conversationId,
      userMessage: d.data().userMessage,
      aiResponse: d.data().aiResponse,
      autoTags: d.data().autoTags,
      bookmarked: d.data().bookmarked,
    })),
  };
}

module.exports = { name: NAME, handler };
