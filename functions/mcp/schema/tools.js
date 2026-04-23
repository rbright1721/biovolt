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
    inputSchema: {type: "object", properties: {}},
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
    description: "Get the user's protocols (supplements, " +
      "peptides) with cycle day, dose, route, and notes. " +
      "By default returns only currently active protocols. " +
      "Pass includeRetired: true to include " +
      "historical/completed protocols (isActive=false).",
    inputSchema: {
      type: "object",
      properties: {
        includeRetired: {
          type: "boolean",
          description: "Include retired protocols " +
            "(isActive=false). Default false.",
        },
      },
    },
  }),
  Object.freeze({
    name: "get_fasting_state",
    description: "Get current fasting status — " +
      "hours fasted, eating window, last meal time, " +
      "and fasting schedule type.",
    inputSchema: {type: "object", properties: {}},
  }),
  Object.freeze({
    name: "get_bloodwork",
    description: "Get the most recent bloodwork " +
      "panel with all biomarker values.",
    inputSchema: {type: "object", properties: {}},
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
  Object.freeze({
    name: "get_log_entries",
    description: "Get the user's raw timeline log entries " +
      "(doses, meals, symptoms, moods, training, notes, " +
      "etc.). These are the user's verbatim observations, " +
      "with classifier-extracted structured fields when " +
      "available. Use to answer 'what have I logged' or " +
      "to surface specific entry types in a window.",
    inputSchema: {
      type: "object",
      properties: {
        sinceDaysAgo: {
          type: "number",
          description: "How many days back to include " +
            "(default 7, min 1, max 90)",
        },
        types: {
          type: "array",
          items: {type: "string"},
          description: "Filter to these classifier types " +
            "(e.g. ['dose','meal']). Pass 'unclassified' " +
            "to match any entry the classifier hasn't " +
            "finished. Omit to include all types.",
        },
        limit: {
          type: "number",
          description: "Maximum entries to return " +
            "(default 100, capped at 200)",
        },
      },
    },
  }),
  Object.freeze({
    name: "get_protocol_timeline",
    description: "Get a full timeline view of one " +
      "protocol — the cycle window, every log entry " +
      "tagged to it, an adherence summary (logged vs " +
      "expected doses, plus contextual meal/symptom/" +
      "mood/training counts in window), and optionally " +
      "the sessions and bloodwork that overlapped the " +
      "cycle. Use after get_active_protocols to dive " +
      "into a specific protocol.",
    inputSchema: {
      type: "object",
      properties: {
        protocolId: {
          type: "string",
          description: "The protocol document id (from " +
            "get_active_protocols).",
        },
        includeSessions: {
          type: "boolean",
          description: "Include sessions overlapping the " +
            "cycle window (default true).",
        },
        includeBloodwork: {
          type: "boolean",
          description: "Include bloodwork panels with " +
            "before/during/after context (default true).",
        },
      },
      required: ["protocolId"],
    },
  }),
]);

module.exports = {SERVER_INFO, TOOLS};
