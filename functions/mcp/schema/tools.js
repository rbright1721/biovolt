// Single source of truth for BioVolt MCP tool definitions.
// Consumed by:
//   - functions/mcp/legacy.js       (current JSON-RPC GET handler)
//   - functions/mcp/server.js       (future Streamable HTTP server — Prompt 6)
//   - functions/mcp/tools/*         (future per-tool handler files — Prompt 3)
//
// When adding, removing, or modifying a tool, update this file. The
// conformance test in __tests__/tools.test.js enforces that legacy.js
// serves exactly this schema.

const SERVER_INFO = Object.freeze({
  name: "biovolt",
  version: "1.0.0",
  description: "BioVolt personal health data hub — " +
    "biometric sessions, protocols, fasting state, " +
    "bloodwork, and health journal",
});

const TOOLS = Object.freeze([
  Object.freeze({
    name: "get_biological_context",
    description: "Get a complete snapshot of the " +
      "user's current biological state including " +
      "active protocols, fasting hours, HRV baseline, " +
      "and recent session summary. Use this first in " +
      "any health conversation.",
    inputSchema: { type: "object", properties: {} },
  }),
  Object.freeze({
    name: "get_session_history",
    description: "Get recent biometric session data " +
      "including HRV, GSR, heart rate, coherence, " +
      "and AI analysis insights.",
    inputSchema: {
      type: "object",
      properties: {
        days: {
          type: "number",
          description: "Number of days to look back " +
            "(default 7, max 30)",
        },
      },
    },
  }),
  Object.freeze({
    name: "get_active_protocols",
    description: "Get all active supplement and " +
      "peptide protocols with cycle day, dose, " +
      "route, and protocol notes/rationale.",
    inputSchema: { type: "object", properties: {} },
  }),
  Object.freeze({
    name: "get_fasting_state",
    description: "Get current fasting status — " +
      "hours fasted, eating window, last meal time, " +
      "and fasting schedule type.",
    inputSchema: { type: "object", properties: {} },
  }),
  Object.freeze({
    name: "get_bloodwork",
    description: "Get the most recent bloodwork " +
      "panel with all biomarker values.",
    inputSchema: { type: "object", properties: {} },
  }),
  Object.freeze({
    name: "get_journal_context",
    description: "Get recent health journal " +
      "conversations for context on symptoms, " +
      "observations, and ongoing discussions.",
    inputSchema: {
      type: "object",
      properties: {
        limit: {
          type: "number",
          description: "Number of recent entries " +
            "to return (default 10)",
        },
      },
    },
  }),
  Object.freeze({
    name: "log_journal_entry",
    description: "Write a new entry to the health " +
      "journal timeline. Use when the user mentions " +
      "a symptom, observation, or health event that " +
      "should be recorded.",
    inputSchema: {
      type: "object",
      properties: {
        message: {
          type: "string",
          description: "The observation or note to log",
        },
      },
      required: ["message"],
    },
  }),
]);

module.exports = { SERVER_INFO, TOOLS };
