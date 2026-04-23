const {SERVER_INFO, TOOLS} = require("../tools");
const registry = require("../../tools");

describe("MCP tool schema", () => {
  test("SERVER_INFO has required fields", () => {
    expect(SERVER_INFO.name).toBe("biovolt");
    expect(typeof SERVER_INFO.version).toBe("string");
    expect(typeof SERVER_INFO.description).toBe("string");
  });

  test("TOOLS is a frozen array", () => {
    expect(Array.isArray(TOOLS)).toBe(true);
    expect(Object.isFrozen(TOOLS)).toBe(true);
  });

  test("every tool has name, description, and inputSchema", () => {
    for (const tool of TOOLS) {
      expect(typeof tool.name).toBe("string");
      expect(tool.name.length).toBeGreaterThan(0);
      expect(typeof tool.description).toBe("string");
      expect(tool.description.length).toBeGreaterThan(0);
      expect(tool.inputSchema).toBeDefined();
      expect(tool.inputSchema.type).toBe("object");
    }
  });

  test("tool names are unique", () => {
    const names = TOOLS.map((t) => t.name);
    expect(new Set(names).size).toBe(names.length);
  });

  test("includes the nine expected tools", () => {
    const names = TOOLS.map((t) => t.name).sort();
    expect(names).toEqual([
      "get_active_protocols",
      "get_biological_context",
      "get_bloodwork",
      "get_fasting_state",
      "get_journal_context",
      "get_log_entries",
      "get_protocol_timeline",
      "get_session_history",
      "log_journal_entry",
    ]);
  });

  test("get_protocol_timeline declares protocolId as required", () => {
    const tool = TOOLS.find((t) => t.name === "get_protocol_timeline");
    expect(tool.inputSchema.required).toContain("protocolId");
  });

  test("log_journal_entry declares message as required", () => {
    const tool = TOOLS.find((t) => t.name === "log_journal_entry");
    expect(tool.inputSchema.required).toContain("message");
  });

  test("every schema tool has a registered handler", () => {
    for (const tool of TOOLS) {
      expect(registry.getHandler(tool.name)).toBeInstanceOf(Function);
    }
  });

  test("every registered handler has a schema entry", () => {
    const schemaNames = new Set(TOOLS.map((t) => t.name));
    for (const tool of registry.tools) {
      expect(schemaNames.has(tool.name)).toBe(true);
    }
  });
});
