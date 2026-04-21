const { SERVER_INFO, TOOLS } = require("../schema/tools");
const legacy = require("../legacy");

describe("legacy mcpServer GET response", () => {
  test("returns schema-equivalent body", async () => {
    let captured = null;
    const noop = () => {};
    const req = {
      method: "GET",
      headers: { origin: "http://localhost" },
      body: {},
      query: {},
      url: "/",
      on: noop,
      once: noop,
      off: noop,
      removeListener: noop,
      emit: noop,
    };
    const res = {
      json: (body) => {
        captured = body;
        return res;
      },
      status: () => res,
      setHeader: () => res,
      getHeader: () => undefined,
      removeHeader: () => res,
      end: () => res,
      writeHead: () => res,
      send: () => res,
      on: noop,
      once: noop,
      off: noop,
      removeListener: noop,
      emit: noop,
    };

    await legacy.mcpServer(req, res);

    expect(captured).not.toBeNull();
    expect(captured.name).toBe(SERVER_INFO.name);
    expect(captured.version).toBe(SERVER_INFO.version);
    expect(captured.description).toBe(SERVER_INFO.description);
    expect(captured.tools).toEqual(TOOLS);
  });
});
