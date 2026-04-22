# Classifier test corpus

This directory holds the eval corpus for `classifyLogEntry`. The eval
harness at `functions/test/corpus_eval.js` runs every entry through the
real classifier and reports accuracy.

## How to run

```bash
cd functions
npm run eval:classifier
```

Requires `ANTHROPIC_API_KEY` in the environment — either exported
directly or present in `functions/.env` (which is loaded by the
handler on import in the deploy environment but not automatically in
a standalone Node run; see the script header for details).

## Format

`log_entries.json` is an array of example objects. Each example is
either a **section marker** or a **test case**.

### Section markers

```json
{ "_section": "dose — simple, matches protocol" }
```

Ignored by the eval harness. Purely for organizing the file so humans
can scan it.

### Test cases

```json
{
  "input": "took 250mcg BPC-157 subq left delt",
  "expected_type": "dose",
  "expected_struct": {
    "protocol_name": "BPC-157",
    "dose_amount": "250mcg",
    "route": "subq",
    "site": "left_delt"
  },
  "ambiguous": false,
  "notes": "Optional human-readable commentary."
}
```

| Field | Required | Meaning |
|---|---|---|
| `input` | yes | The raw text the user would type or speak. Exactly the `rawText` field sent to `classifyLogEntry`. |
| `expected_type` | yes | What the classifier *should* return. One of the 10 committed type values. |
| `expected_struct` | no | Subset of the expected `structured` object. The eval harness doesn't assert on structured today (that's a v2 feature) — it's documentation for now. |
| `ambiguous` | no | `true` when the input is genuinely ambiguous and multiple types could be defensible. The eval harness counts an `ambiguous` case as **acceptable** regardless of what the classifier returns, so long as no error is thrown. Use sparingly — overuse inflates the accuracy number. |
| `notes` | no | Free-text commentary. Ignored by the harness, for humans. |

## Accuracy semantics

The harness reports two numbers:

- **Exact match %** — `result.type === example.expected_type`. The strict accuracy signal.
- **Acceptable %** — exact match OR `ambiguous: true`. This is the number we iterate against. The current target is ≥ 85%.

Ambiguous cases count as acceptable because a classifier that returns `other` on "feeling something" is behaving correctly — the input genuinely doesn't pin down a type. Forcing it into a specific category would be wrong.

## How to add new examples

1. Pick the best-fit section and add a new object under it.
2. Keep `input` short and realistic — how a user would actually phrase
   the observation. Voice-dictation idioms are welcome ("took my NAC"
   rather than "I ingested N-acetyl cysteine at the prescribed dose").
3. Only set `expected_struct` if there's a specific structured field
   the classifier should extract. Partial expected structures are
   allowed — the harness today only checks `type`.
4. Flag `ambiguous: true` sparingly — only when the input genuinely
   doesn't uniquely determine a type.
5. Re-run `npm run eval:classifier` to confirm the new example passes
   (or fails informatively).

## Maintenance

- Add real-world entries the user has miscategorized as they surface —
  those become corpus v2.
- When the prompt changes substantially, also review the corpus for
  entries that have become outdated (e.g., new type vocabulary would
  require new examples here).
- Keep the corpus small and curated. 45 entries is the v1 target. More
  than ~200 entries per type starts to overfit the prompt to the corpus.
