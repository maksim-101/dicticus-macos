---
phase: 25-ai-cleanup-quality-v3-brand-acronym-recognition
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - .planning/debug/harness/prompts/v16a_dictionary_always_on.txt
  - .planning/debug/harness/prompts/v16b_phonetic_variants.txt
  - .planning/debug/harness/prompts/v16c_domain_topics.txt
  - .planning/debug/harness/prompts/v16d_number_integrity.txt
  - .planning/debug/harness/prompts/v16e_acronym_collapse.txt
  - .planning/debug/harness/prompts/v16f_bundled.txt
  - .planning/debug/harness/fixtures/phase25_brands.tsv
  - .planning/debug/harness/run.py
  - .planning/debug/harness/run_v16_matrix.py
  - .planning/debug/harness/results/v16_matrix.md
  - .planning/debug/harness/results/v16_matrix.tsv
autonomous: true
requirements: []
must_haves:
  truths:
    - "Each of the 7 hypotheses (H1–H7 in CONTEXT.md) has been executed against the production Gemma 4 E2B Q4_K_M GGUF at seed=42."
    - "Failure cases from <specifics> in CONTEXT.md (Chemini headless, forty one→4001, H D D, phase↔face, etc.) are represented as fixture rows."
    - "v16_matrix.md ranks variants by lev-distance delta vs. V15 baseline and per-failure-class breakdown."
    - "Matrix identifies a recommended winning variant (or composite) for plan 25-03 to roll forward."
    - "No file in macOS/ or iOS/ has been modified."
  artifacts:
    - path: ".planning/debug/harness/fixtures/phase25_brands.tsv"
      provides: "Brand / acronym / homophone / number-integrity fixture set, derived from the V15 capture window failures"
      contains: "id\tlang\tcategory\texpectation\tinput\texpected"
    - path: ".planning/debug/harness/prompts/v16a_dictionary_always_on.txt"
      provides: "V16a prompt variant — H1 (canonical project terms always injected)"
    - path: ".planning/debug/harness/prompts/v16b_phonetic_variants.txt"
      provides: "V16b prompt variant — H2 (phonetic-variant mapping for brand recovery)"
    - path: ".planning/debug/harness/prompts/v16c_domain_topics.txt"
      provides: "V16c prompt variant — H3 (domain topic-word injection for phase↔face)"
    - path: ".planning/debug/harness/prompts/v16d_number_integrity.txt"
      provides: "V16d prompt variant — H4 (number-word integrity few-shots)"
    - path: ".planning/debug/harness/prompts/v16e_acronym_collapse.txt"
      provides: "V16e prompt variant — H5 (acronym-collapse few-shots without enumeration regression)"
    - path: ".planning/debug/harness/prompts/v16f_bundled.txt"
      provides: "V16f bundled variant — H7 (H1+H3+H4+H5 stack vs. existing V5 keyset)"
    - path: ".planning/debug/harness/results/v16_matrix.md"
      provides: "Ranked hypothesis matrix with per-failure-class deltas + recommendation for plan 25-03"
      contains: "## Recommendation"
    - path: ".planning/debug/harness/results/v16_matrix.tsv"
      provides: "Machine-readable per-fixture-per-variant lev-distance table"
  key_links:
    - from: ".planning/debug/harness/run_v16_matrix.py"
      to: ".planning/debug/harness/multi_seed.py"
      via: "imports base_run.VARIANTS, calls runner per variant at seed=42"
      pattern: "import run as base_run"
    - from: ".planning/debug/harness/run.py"
      to: ".planning/debug/harness/prompts/v16*.txt"
      via: "VARIANTS dict registers V16a-V16f keyed to the prompt files"
      pattern: "VARIANTS\\[.V16"
    - from: ".planning/debug/harness/results/v16_matrix.md"
      to: "phase25_brands.tsv"
      via: "Per-failure-class table cites fixture IDs from the new TSV"
      pattern: "P25-"
---

<objective>
Build the offline hypothesis matrix that gates ALL Phase 25 app-code work. No prompt or service change ships before this matrix exists and identifies a winner.

Purpose: The user-mandated methodology is "iterate hypotheses BEFORE touching the app." This plan converts the seven hypotheses in `25-CONTEXT.md <decisions>` into runnable prompt variants, exercises them against fixtures derived from real V15 production failures (the timestamps in `<specifics>`), and produces a quantitative ranking that plan 25-03 will consume.

Output: A new fixture file (`phase25_brands.tsv`), six new prompt variant files (`v16a`–`v16f`), a runner script that ties it together, and the matrix report (`v16_matrix.md` + `.tsv`). No app code is touched in this plan.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/STATE.md
@.planning/ROADMAP.md
@.planning/phases/25-ai-cleanup-quality-v3-brand-acronym-recognition/25-CONTEXT.md

# Harness scaffolding (the executor lives here)
@.planning/debug/harness/run.py
@.planning/debug/harness/multi_seed.py
@.planning/debug/harness/prompts/v5_baseline.txt
@.planning/debug/harness/prompts/v6_smart_verbatim.txt
@.planning/debug/harness/prompts/v7_structural.txt
@.planning/debug/harness/fixtures/combined.tsv

# V15 prompt is the BASELINE — every V16 variant is measured against it
@Shared/Models/CleanupPrompt.swift

<interfaces>
<!-- Key harness extension points (extracted via grep). Use these directly — no further exploration of run.py needed. -->

From .planning/debug/harness/run.py:
- `VARIANTS: dict[str, tuple[str, Callable]]` at line 926 — register V16a–V16f here. Variant IDs ending in "T" use `build_targeted_context()`; non-T use `build_adaptive_context()`. For V16 (always-on dictionary), use a NEW context builder `build_always_on_context()` that injects canonical project terms regardless of input matches.
- `build_adaptive_context(text, dictionary) -> dict` at line 80 — current behavior, NOT what V16 wants.
- `build_targeted_context(text, dictionary) -> dict` at line 98 — substring-match filter, mirrors prod.
- `DEFAULT_DICT` at top — must be extended with the canonical project terms list AND phonetic variants (see Task 1).
- `LLAMA_SERVER`, `MODEL`, `TEMP/TOP_K/TOP_P/MAX_TOKENS`, `STOP_SEQUENCES` — keep as-is, the matrix run is sampler-locked.
- `--seed`, `--variant`, `--fixture` CLI flags already supported.

From .planning/debug/harness/multi_seed.py:
- Pattern for spinning up a `harness.LlamaServer` and looping seeds/variants. `run_v16_matrix.py` follows this pattern but loops VARIANTS × fixtures at fixed seed=42.

From .planning/debug/harness/fixtures/combined.tsv (header):
- Columns: `id\tlang\tcategory\texpectation\tinput`
- New phase25_brands.tsv extends with an `expected` column so lev-distance vs. ground truth is computable.
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Build phase25_brands.tsv fixture set + V16 prompt variant files</name>
  <read_first>
    - .planning/phases/25-ai-cleanup-quality-v3-brand-acronym-recognition/25-CONTEXT.md (the `<specifics>` section is the fixture source of truth)
    - .planning/debug/harness/fixtures/combined.tsv (column layout, formatting)
    - .planning/debug/harness/prompts/v5_baseline.txt (V5 baseline — what V15 evolved from)
    - .planning/debug/harness/prompts/v6_smart_verbatim.txt (V6 — closest to current V15 prompt shape)
    - Shared/Models/CleanupPrompt.swift lines 43-105 (the V15 rules block — V16 variants iterate ON this, not OFF it)
  </read_first>
  <files>
    .planning/debug/harness/fixtures/phase25_brands.tsv,
    .planning/debug/harness/prompts/v16a_dictionary_always_on.txt,
    .planning/debug/harness/prompts/v16b_phonetic_variants.txt,
    .planning/debug/harness/prompts/v16c_domain_topics.txt,
    .planning/debug/harness/prompts/v16d_number_integrity.txt,
    .planning/debug/harness/prompts/v16e_acronym_collapse.txt,
    .planning/debug/harness/prompts/v16f_bundled.txt
  </files>
  <action>
Create `phase25_brands.tsv` with columns `id\tlang\tcategory\texpectation\tinput\texpected`. Derive every fixture row directly from `25-CONTEXT.md <specifics>` — each row references the timestamp it came from in a trailing `# 2026-05-1X HH:MM` comment column or embedded in the id (e.g. `P25-brand-01-cheminiheadless-20260515T1502`). Minimum coverage:

- **Brand-mishearing rows (H1, H2):** Chemini headless (→ Gemini headless), Cheminai C Oli (→ Gemini CLI), MPM supply chain attack (→ NPM supply chain attack), engine eggs (→ NGINX), Doghand (→ Dokku) x3, DogChee (→ Dockge), plus 1-2 isolated occurrences per canonical term (Claude, Vercel, Opus, Sonnet) WITHOUT anchor context to verify H6 ablation.
- **Number-integrity rows (H4):** "What is phase forty one about?" (→ "What is phase 41 about?"), "I'm in forty one." (→ "I'm in 41."), "those two three streams" (→ "those 2 to 3 streams" — or preserve "two three", whichever is more defensible; pick one and lock it in `expected`).
- **Acronym-spacing rows (H5):** "Considering these H D D" (→ "...HDD"), "T V series Dune Prophecy" (→ "TV series..."), "S A B N C D UI" — and at least TWO enumeration-control rows that MUST stay spelled out, e.g. "options A, B, C, or D" and "letters A B C D as separators" to verify no regression.
- **Homophone rows (H3):** "discuss this face first" (→ "...phase first"), "between GSD faces I should change models" (→ "...GSD phases..."), plus a control row where `face` is genuinely meant (e.g. "look me in the face").
- **Anchor-vs-isolated paired rows (H6):** For at least 3 brands, two rows each — one isolated mishearing, one with surrounding context that names the canonical term. Used by H6 to quantify the anchor's contribution.
- **Regression-net rows (H7):** Re-import the V15 WIN cases from `<specifics>` (GST→GSD, cloud code→Claude Code, true NAS→TrueNAS, opus four point seven→Opus 4.7, feeding→fitting in suit context) so V16 candidates can be shown to NOT regress them.

Then create the six prompt variant files. Each file is a complete template that mirrors the V15 structure in `CleanupPrompt.swift:60-105` (rules block, optional `Known terms:` block, language banner, few-shots, final `In:\nOut:` anchor) — only the targeted layer changes:

- `v16a_dictionary_always_on.txt`: V15 rules + an EXPANDED Known terms block. The harness will populate this block via `build_always_on_context()` (Task 2) so the canonical list (Claude, Gemini, CLI, NPM, NGINX, Docker, Dokku, Dockge, TrueNAS, Vercel, Opus, Sonnet, Phase, GSD) is ALWAYS present, not substring-gated. Few-shots: V15's existing two safe few-shots, unchanged.
- `v16b_phonetic_variants.txt`: V16a + the Known terms block uses `mishearing -> canonical` form for known phonetic variants (`Chemini -> Gemini`, `Cheminai -> Gemini`, `Jemini -> Gemini`, `Versal -> Vercel`, `MPM -> NPM`, `engine eggs -> NGINX`, `Doghand -> Dokku`, `DogChee -> Dockge`, `true Nas -> TrueNAS`, `clot code -> Claude`). Done from PER 25-CONTEXT.md H2 hypothesis.
- `v16c_domain_topics.txt`: V15 rules + a new "Domain topic words: phase, plan, workflow, framework, plan, dictation, cleanup, prompt" hint line, plus one new few-shot `In: discuss this face first\nOut: Discuss this phase first.` (per H3). Per CONTEXT.md D-03 idea H3.
- `v16d_number_integrity.txt`: V15 rules + new few-shots `In: meeting at forty one Penn\nOut: Meeting at 41 Penn.` and `In: it lasted two to three minutes\nOut: It lasted 2 to 3 minutes.` and a rule line "8. Spelled-out two-digit numbers (twenty/thirty/forty/fifty/sixty/seventy/eighty/ninety + one..nine) MUST render as two-digit numerals, NEVER concatenated four-digit forms." Per H4.
- `v16e_acronym_collapse.txt`: V15 rules + few-shots `In: the H D D failed\nOut: The HDD failed.` and `In: T V series\nOut: TV series.` plus an enumeration anti-regression few-shot `In: options A, B, C, or D\nOut: Options A, B, C, or D.` and rule "9. Single capital letters separated by spaces inside a noun-phrase collapse to an acronym (H D D -> HDD); single capital letters separated by COMMAS or 'or'/'and' stay enumerated." Per H5.
- `v16f_bundled.txt`: composes the V16a Known terms always-on injection + V16c domain topics line + V16d number rule/few-shots + V16e acronym rule/few-shots. Per H7.

Reference D-03 hypothesis IDs (H1..H7) explicitly in a comment block at the top of each prompt file so future readers can trace.
  </action>
  <verify>
    <automated>
      cd .planning/debug/harness && \
      test -f fixtures/phase25_brands.tsv && \
      head -1 fixtures/phase25_brands.tsv | grep -q '^id	lang	category	expectation	input	expected' && \
      [ "$(grep -v '^#' fixtures/phase25_brands.tsv | grep -vc '^id\b')" -ge 25 ] && \
      grep -c '^P25-brand-' fixtures/phase25_brands.tsv && \
      grep -c '^P25-num-' fixtures/phase25_brands.tsv && \
      grep -c '^P25-acro-' fixtures/phase25_brands.tsv && \
      grep -c '^P25-phase-face-' fixtures/phase25_brands.tsv && \
      grep -c '^P25-anchor-' fixtures/phase25_brands.tsv && \
      grep -c '^P25-regress-' fixtures/phase25_brands.tsv && \
      for v in v16a_dictionary_always_on v16b_phonetic_variants v16c_domain_topics v16d_number_integrity v16e_acronym_collapse v16f_bundled; do \
        test -s prompts/${v}.txt || { echo "Missing prompts/${v}.txt"; exit 1; }; \
      done
    </automated>
  </verify>
  <done>phase25_brands.tsv has the documented column header and at least 25 non-comment rows covering all categories above; each row's id traces to a CONTEXT.md timestamp or is labeled `P25-regress-*` / `P25-anchor-*` / control. Six prompt variant files exist, each non-empty, each cross-referencing its H-id in a header comment.</done>
  <acceptance_criteria>
    - phase25_brands.tsv has ≥25 rows (excluding header, excluding `#` comment rows) and includes at least 6 brand rows, 3 number-integrity rows, 5 acronym rows (incl. 2 enumeration controls), 3 phase/face rows (incl. 1 control), 3 anchor/isolated pairs, and the V15 regression-net set.
    - Every brand-mishearing fixture id contains the source timestamp (`YYYYMMDDTHHMM`) it came from in `25-CONTEXT.md`.
    - Each of the six new prompt files contains a leading comment line referencing the hypothesis ID (e.g. `# Hypothesis H1 (CONTEXT.md decisions §)`).
    - No file under macOS/, iOS/, or Shared/ is modified by this task.
  </acceptance_criteria>
</task>

<task type="auto">
  <name>Task 2: Wire V16 variants into run.py + write run_v16_matrix.py orchestrator</name>
  <read_first>
    - .planning/debug/harness/run.py lines 80-122 (context builders) and lines 920-1130 (VARIANTS dict, CLI dispatch loop)
    - .planning/debug/harness/multi_seed.py (pattern for booting llama-server once, iterating variants/fixtures)
  </read_first>
  <files>
    .planning/debug/harness/run.py,
    .planning/debug/harness/run_v16_matrix.py
  </files>
  <action>
**Step A — extend `run.py`:**

1. Add `build_always_on_context(text: str, dictionary: dict) -> dict` next to `build_targeted_context`. It returns a dict containing (i) the union of canonical project terms (Claude, Gemini, CLI, NPM, NGINX, Docker, Dokku, Dockge, TrueNAS, Vercel, Opus, Sonnet, Phase, GSD) as `term -> term` self-anchors, AND (ii) any substring matches from `dictionary` (mirroring `build_targeted_context`). The always-on terms are returned regardless of whether they appear in input — this is the H1 lever.

2. Extend `DEFAULT_DICT` with phonetic variants: `Chemini -> Gemini, Cheminai -> Gemini, Jemini -> Gemini, MPM -> NPM, Doghand -> Dokku, DogChee -> Dockge, Versal -> Vercel, true Nas -> TrueNAS, clot code -> Claude` and any V15 entries discoverable in `Shared/Services/DictionaryService.swift`. Read `Shared/Services/DictionaryService.swift` once to align with the actual prod dictionary.

3. Register six new entries in `VARIANTS`: `V16A`, `V16B`, `V16C`, `V16D`, `V16E`, `V16F`. Each entry is a `(human_name, builder_fn)` tuple. The builder loads the corresponding `prompts/v16*.txt` file, then substitutes a `{{KNOWN_TERMS}}` placeholder using the same `Known terms:` formatting V15's Swift code uses (`CleanupPrompt.swift:75-85`) — sorted by key, `original -> replacement` if different, otherwise bare term. Convention: variant IDs `V16A` and `V16B` and `V16F` use `build_always_on_context`; `V16C`, `V16D`, `V16E` use `build_targeted_context` (current prod behavior). Add a comment block above `VARIANTS` documenting the new builders' context-fn pairing.

4. Add a `V15` entry to `VARIANTS` that loads V15 from the actual production source. Since V15 is Swift-side, ship a `prompts/v15_micro_scalpel.txt` derived BY READING `Shared/Models/CleanupPrompt.swift:60-105` and reproducing the exact rule-block + few-shots in text form. This V15 entry is the baseline every V16 variant is compared to.

**Step B — write `run_v16_matrix.py`:**

The orchestrator script that produces the matrix. Pattern:
- Boot `llama-server` once on port 8765 with the prod GGUF (same as `multi_seed.py`).
- For each variant in [`V15`, `V16A`, `V16B`, `V16C`, `V16D`, `V16E`, `V16F`]:
    - For each row in `fixtures/phase25_brands.tsv`:
        - Build prompt via the variant's builder + appropriate context fn.
        - POST to `/completion` with `seed=42, temp=0.1, top_k=40, top_p=0.9, n_predict=512, stop=STOP_SEQUENCES`.
        - Compute `lev_distance(output, expected)` and `lev_distance(output, input)` (use `python-Levenshtein` if available else a self-contained DP implementation).
        - Write a row to `results/v16_matrix.tsv`: `variant\tfixture_id\tcategory\tinput\texpected\toutput\tlev_to_expected\tlev_to_input\thypothesis_id`.
- Emit `results/v16_matrix.md` with:
    - **Section 1: Summary table** — rows = variants, cols = aggregate lev-to-expected (sum / mean), per-category aggregate (brand, num, acro, phase-face, anchor, regress).
    - **Section 2: Per-category breakdown** — one table per category showing which variant solved which fixture (Δ vs. V15 lev-to-expected, negative = improvement).
    - **Section 3: Regression check** — explicit row-by-row PASS/FAIL on the V15-win regression set. Any FAIL flagged with `⚠ REGRESSION`.
    - **Section 4: Anchor ablation (H6)** — paired-row comparison of isolated vs. anchored brand recovery, per variant.
    - **Section 5: Recommendation** — names the winning variant (or composite) plan 25-03 should ship. Justified by per-category numbers, NOT by aggregate alone.

CLI: `python3 run_v16_matrix.py [--port 8765] [--seed 42] [--variants V15,V16A,V16B,V16C,V16D,V16E,V16F]`. Default: run everything.
  </action>
  <verify>
    <automated>
      cd .planning/debug/harness && \
      python3 -c "import run; assert 'V15' in run.VARIANTS, 'V15 missing'; assert all(v in run.VARIANTS for v in ['V16A','V16B','V16C','V16D','V16E','V16F']), 'V16x missing'; print('VARIANTS OK')" && \
      python3 -c "import run; ctx = run.build_always_on_context('hello world', {}); assert 'Claude' in ctx and 'Gemini' in ctx and 'TrueNAS' in ctx, 'always-on context missing canonicals: ' + repr(ctx)" && \
      python3 -m py_compile run_v16_matrix.py && \
      python3 run_v16_matrix.py --help 2>&1 | grep -q -- '--seed'
    </automated>
  </verify>
  <done>Six V16 variant entries + V15 baseline entry exist in `run.py:VARIANTS`. `build_always_on_context` returns the full canonical project-term set. `run_v16_matrix.py` compiles, exposes `--seed`/`--port`/`--variants` flags, and is documented in its docstring.</done>
  <acceptance_criteria>
    - `python3 -c "import run; ..."` smoke test (above) passes.
    - `prompts/v15_micro_scalpel.txt` exists and a textual diff against the rules block in `Shared/Models/CleanupPrompt.swift:60-105` shows identical rules (same numbering, same imperative wording).
    - `run_v16_matrix.py` is self-contained — does not modify state outside `.planning/debug/harness/`.
    - All variant builders use the same `temp=0.1, top_k=40, top_p=0.9, max_tokens=512, seed=42` sampler — no variant is allowed to silently change sampler.
  </acceptance_criteria>
</task>

<task type="auto">
  <name>Task 3: Execute matrix, generate v16_matrix.md report, name a winner</name>
  <read_first>
    - .planning/debug/harness/results/q5_languagetool_REPORT.md (prior matrix-style report — match its readability and section layout)
    - .planning/debug/harness/run_v16_matrix.py (the runner from Task 2)
  </read_first>
  <files>
    .planning/debug/harness/results/v16_matrix.tsv,
    .planning/debug/harness/results/v16_matrix.md
  </files>
  <action>
Run `python3 .planning/debug/harness/run_v16_matrix.py --seed 42 --out .planning/debug/harness/results/v16_matrix.tsv` and capture full output. Llama-server boot will take 5–20s; full sweep is ~7 variants × ~25 fixtures × ~5–15s per inference = expect 15–40 minutes wall-clock. Use `run_in_background: true` for the run and poll the TSV row count to confirm progress.

After the TSV is complete, generate `results/v16_matrix.md` per Section 1–5 layout in Task 2 step B. The recommendation in Section 5 must be quantitatively backed:

- **Winner criterion 1:** strictly improves brand-mishearing aggregate lev-to-expected vs. V15.
- **Winner criterion 2:** zero V15-regression failures in Section 3 (any regression disqualifies, even if aggregate improves).
- **Winner criterion 3:** improves OR holds steady on number-integrity AND acronym categories.
- **Tiebreak:** prefer the variant with the simplest prompt diff vs. V15 (V16f is allowed to win but only if a single-lever variant doesn't).

If no variant satisfies all three criteria, the recommendation section says so explicitly and proposes a composite or further iteration (do NOT silently pick the best-aggregate variant — that hides regressions).

Append a "Provenance" subsection citing: matrix run timestamp, llama-server build (`llama-server --version`), GGUF SHA prefix (`shasum -a 256 ~/Library/Application\ Support/Dicticus/Models/gemma-4-E2B-it-Q4_K_M.gguf | head -c 16`), seed, and total wall time.
  </action>
  <verify>
    <automated>
      test -s .planning/debug/harness/results/v16_matrix.tsv && \
      test -s .planning/debug/harness/results/v16_matrix.md && \
      head -1 .planning/debug/harness/results/v16_matrix.tsv | grep -q '^variant	fixture_id' && \
      [ "$(grep -c '^V15	' .planning/debug/harness/results/v16_matrix.tsv)" -ge 25 ] && \
      [ "$(grep -c '^V16A	' .planning/debug/harness/results/v16_matrix.tsv)" -ge 25 ] && \
      grep -q '^## Recommendation' .planning/debug/harness/results/v16_matrix.md && \
      grep -q '^## Regression check' .planning/debug/harness/results/v16_matrix.md && \
      grep -q 'Provenance' .planning/debug/harness/results/v16_matrix.md
    </automated>
  </verify>
  <done>v16_matrix.tsv has ≥25 rows per variant (one per fixture). v16_matrix.md contains Summary, Per-category, Regression-check, Anchor-ablation, Recommendation, and Provenance sections. A specific winning variant (or named composite) is recommended with quantitative justification.</done>
  <acceptance_criteria>
    - Matrix run completed at seed=42 against the prod GGUF (sha256 prefix recorded).
    - Recommendation section names ONE winning prompt construct that plan 25-03 will roll forward. If no variant qualifies, the section explicitly says so and proposes next steps — never silently pick a regression-positive variant.
    - All seven hypotheses (H1–H7) have explicit per-hypothesis verdicts in the markdown.
    - No app code was modified during execution of this task.
  </acceptance_criteria>
</task>

</tasks>

<verification>
- Run `git status .` — only files under `.planning/debug/harness/` are modified (plus any new files in that tree). Zero diffs in `macOS/`, `iOS/`, or `Shared/`.
- Spot-check 3 random fixture ids in `phase25_brands.tsv` against `25-CONTEXT.md <specifics>` — each id traces to a real failure.
- Confirm `results/v16_matrix.md` recommendation is actionable: a human reader can answer "what should plan 25-03 ship?" from Section 5 alone.
</verification>

<success_criteria>
- All 7 hypotheses tested at seed=42 against the prod Gemma 4 E2B Q4_K_M GGUF.
- `v16_matrix.md` exists and ranks variants by lev-distance delta vs. V15, with explicit regression check.
- Winner (or "no viable winner — iterate") is named with quantitative backing.
- Zero app code modified.
- Plan 25-03 is unblocked: a downstream executor reading `v16_matrix.md` knows exactly which prompt construct and which dictionary-feeder behavior to roll into `CleanupPrompt.swift` / `TextProcessingService.swift`.
</success_criteria>

<output>
After completion, create `.planning/phases/25-ai-cleanup-quality-v3-brand-acronym-recognition/25-01-SUMMARY.md` capturing:
- Variants tested, fixtures touched, total wall-clock.
- Winning variant + the 3 most-improved fixture rows (input → V15 → V16 winner → expected).
- Any V15-win regressions discovered (even if winner avoids them, document them for memory).
- A direct pointer to `results/v16_matrix.md` and `results/v16_matrix.tsv`.
- An explicit note: "Plan 25-03 must roll variant `<NAME>` into `Shared/Models/CleanupPrompt.swift` and expand `TextProcessingService.swift:159-165` dictionary-feeder logic per Task 2's `build_always_on_context` reference implementation."
</output>
