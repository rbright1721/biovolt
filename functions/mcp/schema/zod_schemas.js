// Zod schemas for tool inputs — authoritative for runtime validation by
// the MCP SDK (@modelcontextprotocol/sdk v1.x). The JSON Schema form in
// ./tools.js is still what clients see in the legacy discovery document;
// schema_conformance.test.js enforces they stay shape-equivalent.
//
// Zod 4 is installed. z.object() produces schemas that emit
// additionalProperties: false by default, so we do not call .strict().

const { z } = require("zod");

const SCHEMAS = {
  get_biological_context: z.object({}),
  get_session_history: z.object({
    days: z.number().optional().describe(
      "Number of days to look back (default 7, max 30)",
    ),
  }),
  get_active_protocols: z.object({}),
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
};

module.exports = { SCHEMAS };
