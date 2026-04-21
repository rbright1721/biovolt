// Zod 4 ships its own `toJSONSchema()` which produces clean,
// draft-2020-12 output. We use it directly — no external converter.

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
