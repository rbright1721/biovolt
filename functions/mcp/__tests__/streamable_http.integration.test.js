// End-to-end MCP round-trip through the official SDK. We use
// InMemoryTransport.createLinkedPair() to connect a Client to the Server
// without going through HTTP, so the test exercises the real SDK protocol
// handling (initialize, tools/list, tools/call) without any transport
// plumbing on our side.

jest.mock("firebase-admin/firestore", () => {
  const fakeCollection = (docs = {}) => {
    const self = {
      doc: (id) => ({
        get: async () => ({
          exists: docs[id] != null,
          data: () => docs[id],
        }),
        set: async () => {},
      }),
      orderBy: () => self,
      limit: () => self,
      get: async () => ({
        empty: Object.keys(docs).length === 0,
        docs: Object.entries(docs).map(([id, data]) => ({
          id,
          data: () => data,
        })),
      }),
    };
    return self;
  };
  const fakeUserRef = {
    collection: () => fakeCollection({}),
  };
  return {
    getFirestore: () => ({
      collection: () => ({ doc: () => fakeUserRef }),
    }),
    FieldValue: { serverTimestamp: () => "SERVER_TS" },
  };
});

const { Client } = require("@modelcontextprotocol/sdk/client/index.js");
const { InMemoryTransport } = require("@modelcontextprotocol/sdk/inMemory.js");
const { createMcpServer } = require("../server");
const { TOOLS, SERVER_INFO } = require("../schema/tools");

async function buildPair() {
  const [clientTransport, serverTransport] = InMemoryTransport.createLinkedPair();

  const server = createMcpServer({ uid: "test-uid", clientId: "test", scope: "mcp" });
  await server.connect(serverTransport);

  const client = new Client(
    { name: "test-client", version: "1.0.0" },
    { capabilities: {} },
  );
  await client.connect(clientTransport);

  return { client, server };
}

describe("MCP Streamable HTTP (SDK round-trip via InMemoryTransport)", () => {
  test("initialize returns our server info", async () => {
    const { client, server } = await buildPair();
    try {
      const info = client.getServerVersion();
      expect(info).toBeDefined();
      expect(info.name).toBe(SERVER_INFO.name);
      expect(info.version).toBe(SERVER_INFO.version);
    } finally {
      await server.close();
    }
  });

  test("tools/list returns all seven registered tools", async () => {
    const { client, server } = await buildPair();
    try {
      const result = await client.listTools();
      const names = result.tools.map((t) => t.name).sort();
      const expected = TOOLS.map((t) => t.name).sort();
      expect(names).toEqual(expected);
    } finally {
      await server.close();
    }
  });

  test("tools/call on get_biological_context returns a text content block", async () => {
    const { client, server } = await buildPair();
    try {
      const result = await client.callTool({
        name: "get_biological_context",
        arguments: {},
      });
      expect(result.isError).not.toBe(true);
      expect(Array.isArray(result.content)).toBe(true);
      expect(result.content.length).toBeGreaterThan(0);
      expect(result.content[0].type).toBe("text");
      const parsed = JSON.parse(result.content[0].text);
      // Shape check — the handler returns these keys even with empty data.
      expect(parsed).toHaveProperty("profile");
      expect(parsed).toHaveProperty("fastingState");
      expect(parsed).toHaveProperty("activeProtocols");
      expect(parsed).toHaveProperty("biometricBaseline");
    } finally {
      await server.close();
    }
  });

  test("tools/call on log_journal_entry with a message succeeds", async () => {
    const { client, server } = await buildPair();
    try {
      const result = await client.callTool({
        name: "log_journal_entry",
        arguments: { message: "slept 7h, HRV 52" },
      });
      expect(result.isError).not.toBe(true);
      const parsed = JSON.parse(result.content[0].text);
      expect(parsed.success).toBe(true);
      expect(parsed.entryId).toBeTruthy();
    } finally {
      await server.close();
    }
  });
});
