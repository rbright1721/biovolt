const tools = [
  require("./get_biological_context"),
  require("./get_session_history"),
  require("./get_active_protocols"),
  require("./get_fasting_state"),
  require("./get_bloodwork"),
  require("./get_journal_context"),
  require("./log_journal_entry"),
  require("./get_log_entries"),
  require("./get_protocol_timeline"),
];

const byName = new Map(tools.map((t) => [t.name, t]));

function getHandler(name) {
  const tool = byName.get(name);
  return tool ? tool.handler : null;
}

module.exports = { tools, byName, getHandler };
