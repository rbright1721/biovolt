const NAME = "log_journal_entry";

async function handler({ input, ctx }) {
  const { userRef, now } = ctx;

  const message = input.message;
  if (!message) {
    throw new Error("message is required");
  }
  const entry = {
    id: String(now),
    timestamp: new Date(now).toISOString(),
    conversationId: "claude_mcp",
    userMessage: message,
    aiResponse: "[Logged via Claude MCP]",
    bookmarked: false,
    autoTags: [],
    researchGrounded: false,
    syncedAt: new Date(now),
  };
  await userRef.collection("journal").doc(entry.id).set(entry);
  return {
    success: true,
    entryId: entry.id,
    message: "Logged to BioVolt journal",
  };
}

module.exports = { name: NAME, handler };
