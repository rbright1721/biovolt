// Zod schemas for tool inputs — authoritative for runtime validation by
// the MCP SDK (@modelcontextprotocol/sdk v1.x). The JSON Schema form in
// ./tools.js is still what clients see in the legacy discovery document;
// schema_conformance.test.js enforces they stay shape-equivalent.
//
// Zod 4 is installed. z.object() produces schemas that emit
// additionalProperties: false by default, so we do not call .strict().

const {z} = require("zod");

const SCHEMAS = {
  get_biological_context: z.object({}),
  get_session_history: z.object({
    days: z.number().optional().describe(
      "Number of days to look back (default 7, max 30)",
    ),
  }),
  get_active_protocols: z.object({
    includeRetired: z.boolean().optional().describe(
      "Include retired protocols (isActive=false). Default false.",
    ),
  }),
  get_fasting_state: z.object({}),
  get_bloodwork: z.object({}),
  get_journal_context: z.object({
    limit: z.number().optional().describe(
      "Number of recent entries to return (default 10)",
    ),
  }),
  log_journal_entry: z.object({
    message: z.string().describe("The observation or note to log"),
  }),
  get_log_entries: z.object({
    sinceDaysAgo: z.number().optional().describe(
      "How many days back to include (default 7, min 1, max 90)",
    ),
    types: z.array(z.string()).optional().describe(
      "Filter to these classifier types (e.g. ['dose','meal']). " +
        "Pass 'unclassified' to match any entry the classifier " +
        "hasn't finished. Omit to include all types.",
    ),
    limit: z.number().optional().describe(
      "Maximum entries to return (default 100, capped at 200)",
    ),
  }),
  get_protocol_timeline: z.object({
    protocolId: z.string().describe(
      "The protocol document id (from get_active_protocols).",
    ),
    includeSessions: z.boolean().optional().describe(
      "Include sessions overlapping the cycle window (default true).",
    ),
    includeBloodwork: z.boolean().optional().describe(
      "Include bloodwork panels with before/during/after context " +
        "(default true).",
    ),
  }),
};

module.exports = {SCHEMAS};
