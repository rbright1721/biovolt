#!/usr/bin/env node
// =============================================================================
// corpus_eval.js — classifier accuracy harness.
//
// Runs every test case in ./corpus/log_entries.json through the real
// classifyLogEntryHandler (directly, not via the deployed endpoint)
// and prints an accuracy report. Used during prompt iteration to
// decide whether a prompt change improved or regressed the classifier.
//
// Usage:
//   cd functions
//   ANTHROPIC_API_KEY=sk-... npm run eval:classifier
//
// Or, if ANTHROPIC_API_KEY is already in your shell / functions/.env,
// the script loads the .env file below before importing the handler.
//
// Cost note: each run makes one Claude API call per non-empty entry
// in the corpus — currently ~44 calls. Not free. Don't run this in a
// tight loop.
// =============================================================================

const fs = require("fs");
const path = require("path");

// Load functions/.env so ANTHROPIC_API_KEY becomes available to the
// handler the same way the deployed environment loads it. Done
// manually (no dotenv dep) to avoid adding a runtime package just for
// this script.
const envPath = path.join(__dirname, "..", ".env");
if (fs.existsSync(envPath)) {
  for (const line of fs.readFileSync(envPath, "utf8").split(/\r?\n/)) {
    const m = line.match(/^\s*([A-Z_][A-Z0-9_]*)\s*=\s*(.*)\s*$/);
    if (!m) continue;
    let [, k, v] = m;
    // Strip surrounding quotes if present.
    if ((v.startsWith('"') && v.endsWith('"')) ||
        (v.startsWith("'") && v.endsWith("'"))) {
      v = v.slice(1, -1);
    }
    if (process.env[k] === undefined) process.env[k] = v;
  }
}

if (!process.env.ANTHROPIC_API_KEY) {
  console.error("ANTHROPIC_API_KEY not set. Export it or put it in functions/.env.");
  process.exit(1);
}

const corpus = require("./corpus/log_entries.json");
const {
  classifyLogEntryHandler,
  CLASSIFIER_PROMPT_VERSION,
} = require("../classify_log_entry");

// Filter out section markers — anything with `_section` and no `input`.
const tests = corpus.filter((c) => typeof c.input === "string");

async function run() {
  console.log(`Running ${tests.length} cases against prompt ${CLASSIFIER_PROMPT_VERSION}...`);
  const started = Date.now();
  const results = [];

  for (const example of tests) {
    const fakeRequest = {
      auth: { uid: "eval-user" },
      data: {
        logEntryId: `eval-${Math.random().toString(36).slice(2, 10)}`,
        rawText: example.input,
        occurredAt: new Date().toISOString(),
        vitals: {},
        context: {
          activeProtocols: example.context?.activeProtocols || [],
          recentEntries: example.context?.recentEntries || [],
          fastingHours: example.context?.fastingHours ?? null,
        },
      },
    };

    try {
      const result = await classifyLogEntryHandler(fakeRequest);
      const matched = result.type === example.expected_type;
      const acceptable = matched || example.ambiguous === true;

      results.push({
        input: example.input,
        expected: example.expected_type,
        actual: result.type,
        confidence: result.confidence,
        matched,
        acceptable,
        ambiguous: !!example.ambiguous,
        structured: result.structured,
      });
    } catch (e) {
      results.push({
        input: example.input,
        expected: example.expected_type,
        error: e.message || String(e),
        matched: false,
        acceptable: false,
        ambiguous: !!example.ambiguous,
      });
    }
  }

  const elapsedSec = ((Date.now() - started) / 1000).toFixed(1);
  const total = results.length;
  const matched = results.filter((r) => r.matched).length;
  const acceptable = results.filter((r) => r.acceptable).length;
  const errors = results.filter((r) => r.error).length;

  console.log(`\n=== Corpus Eval Report (prompt ${CLASSIFIER_PROMPT_VERSION}) ===`);
  console.log(`Total:       ${total}`);
  console.log(`Exact match: ${matched} (${((matched / total) * 100).toFixed(1)}%)`);
  console.log(`Acceptable:  ${acceptable} (${((acceptable / total) * 100).toFixed(1)}%)`);
  console.log(`Errors:      ${errors}`);
  console.log(`Elapsed:     ${elapsedSec}s`);

  const misses = results.filter((r) => !r.acceptable);
  if (misses.length > 0) {
    console.log(`\n=== Misses (${misses.length}) ===`);
    for (const r of misses) {
      console.log(`- "${r.input}"`);
      console.log(`  expected: ${r.expected}, got: ${r.actual || "ERROR"}`);
      if (r.error) {
        console.log(`  error:    ${r.error}`);
      } else {
        console.log(`  confidence: ${r.confidence?.toFixed(2)}`);
        if (r.structured) {
          console.log(`  structured: ${JSON.stringify(r.structured)}`);
        }
      }
    }
  }

  // Group misses by failure mode for prompt-iteration triage.
  if (misses.length > 0) {
    console.log(`\n=== Miss grouping ===`);
    const byMode = new Map();
    for (const r of misses) {
      let mode;
      if (r.error) mode = "error";
      else if (r.actual === "other") mode = `fell_back_to_other (expected ${r.expected})`;
      else mode = `confusion: ${r.expected} -> ${r.actual}`;
      byMode.set(mode, (byMode.get(mode) || 0) + 1);
    }
    for (const [mode, n] of [...byMode.entries()].sort((a, b) => b[1] - a[1])) {
      console.log(`  ${n}x  ${mode}`);
    }
  }

  // Non-zero exit when below the 85% acceptable target — lets CI or
  // iterative scripts detect regressions automatically.
  const targetPct = 85;
  const pct = (acceptable / total) * 100;
  process.exit(pct >= targetPct ? 0 : 1);
}

run().catch((e) => {
  console.error("Eval harness crashed:", e);
  process.exit(2);
});
