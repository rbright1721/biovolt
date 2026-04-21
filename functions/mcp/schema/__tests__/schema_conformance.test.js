// Note: `zod-to-json-schema` v3.25 does not support zod v4 (emits an
// empty document). Zod 4 ships its own `toJSONSchema()` which produces
// clean, draft-2020-12 output — we use that instead. The installed
// zod-to-json-schema package is kept as a transitional dependency but
// is not exercised here. See the Prompt 6 deviation note.

const { toJSONSchema } = require("zod");
const { SCHEMAS } = require("../zod_schemas");
const { TOOLS } = require("../tools");

describe("Zod ↔ JSON Schema conformance", () => {
  for (const tool of TOOLS) {
    test(`${tool.name}: Zod schema produces compatible JSON Schema`, () => {
      const zodSchema = SCHEMAS[tool.name];
      expect(zodSchema).toBeDefined();

      const derived = toJSONSchema(zodSchema);

      expect(derived.type).toBe("object");

      const declaredProps = Object.keys(tool.inputSchema.properties || {});
      const derivedProps = Object.keys(derived.properties || {});
      for (const prop of declaredProps) {
        expect(derivedProps).toContain(prop);
      }

      const declaredRequired = tool.inputSchema.required || [];
      const derivedRequired = derived.required || [];
      expect(derivedRequired.sort()).toEqual(declaredRequired.sort());
    });
  }

  test("every schema tool has a Zod schema", () => {
    for (const tool of TOOLS) {
      expect(SCHEMAS[tool.name]).toBeDefined();
    }
  });
});
