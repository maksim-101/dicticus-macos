# Phase 25: AI Cleanup Quality v3 — Brand & Acronym Recognition — Context

**Gathered:** 2026-05-16
**Status:** Ready for planning
**Source:** Inline synthesis from V15 capture-window analysis (218 JSONL records, 2026-05-13 → 2026-05-16). Discuss-phase explicitly skipped per user — empirical data substitutes for design discussion.

<domain>
## Phase Boundary

**In scope.** Lift AI-cleanup quality on the dimensions that V15 ships with as known regressions or known gaps:

1. **Brand/proper-noun recognition** when the canonical term has no in-sentence anchor (isolated mishearings).
2. **Number-word integrity** (the digit-concatenation bug: `forty one → 4001`).
3. **Acronym-letter-spacing collapse** (`H D D → HDD`, `T V → TV`) without regressing list-of-letters enumeration (`A, B, C, D`).
4. **Domain-noun homophone disambiguation** (`phase ↔ face`, similar pairs).
5. **Plain-mode logging parity** so plain-vs-AI A/B comparison becomes possible from production data.

**Out of scope.** Multilingual (DE-language) cleanup quality — capture window contained zero German records; defer to a separate phase when German capture data exists. Decimal words & digit grouping (Phase 23 territory). Self-correction handling (Phase 24 territory). New ASR engine work.

**Methodology constraint (user-mandated, MUST be plan structure):**
> "Do some iteration with different hypotheses first BEFORE implementing any changes to the app itself."

This means Plan 25-01 is a **research/experimentation plan** that runs in the offline harness (`.planning/debug/harness/`) and produces a hypothesis-ranked matrix. App-touching plans depend on its output. No prompt or service-layer code changes ship before the matrix is reviewed.

</domain>

<decisions>
## Implementation Decisions

### Plan structure (locked — derived from user-agreed scoping)

Four plans, in dependency order:

- **25-01 — Offline hypothesis matrix in `.planning/debug/harness/`.** Build fixtures from real V15 capture failures, run prompt-variant + dictionary-feeder variants under existing `multi_seed.py`, produce `results/v16_matrix.md` ranking hypotheses by lev-distance delta vs. V15 baseline. **No app code touched.** Hypotheses to test (minimum set):
  - H1: Adaptive dictionary always-on with canonical project terms (Claude, Gemini, CLI, NPM, NGINX, Docker, Dokku, Dockge, TrueNAS, Vercel, Opus, Sonnet, Phase, GSD)
  - H2: Phonetic-variant mapping (`Chemini, Cheminai, Jemini → Gemini`) vs. canonical-only listing
  - H3: Domain "topic words" (phase, plan, workflow, framework) injection — phase/face fix
  - H4: Number-word integrity few-shot anchor (`forty one → 41`, `two to three → 2 to 3`)
  - H5: Acronym-collapse few-shot (`G S D → GSD`, `T V → TV`) without regressing enumeration handling
  - H6: Context-window proximity ablation — paired fixtures with/without anchor sentence
  - H7: Bundled H1+H3+H4+H5 against existing V5 keyset (regression check)

- **25-02 — Plain-mode logging in `DebugRecorder` (macOS + iOS parity).** Smallest viable change that ships independently of the prompt work. Extend the recorder so `mode == .plain` cycles also emit JSONL with `raw` and `final` (post-rules) text, same file rotation, same `lang` field. Enables plain-vs-AI A/B from production capture. Cross-platform per `feedback_cleanup_cross_platform_parity`. **Ships ahead of 25-03/25-04** — gates open as soon as it lands.

- **25-03 — V16 prompt + dictionary-feeder code change (macOS + iOS parity).** Conditional on 25-01 results. Likely composite: (a) new prompt variant in `Shared/Models/CleanupPrompt.swift` rolling the winning few-shots, and (b) actual fix to the adaptive-dictionary feeder so it injects more than just "GSD". Includes regression-net tests mirroring the V15 baseline fixtures plus new fixtures for the failure cases listed in evidence below. Cross-platform shipping.

- **25-04 — Capture window v2 + UAT.** 3-day capture under V16 with plain-mode logging live. User-driven UAT against `v16_matrix.md` win predictions vs. observed reality. Same JSONL diff methodology as the V15 capture window. Closes Phase 25.

### Goal definition (locked)

> Reduce isolated-brand mishearing failure rate (target: ≤ 30% of V15 baseline failure rate on the captured brand corpus), eliminate the `forty one → 4001` digit-concatenation class entirely, collapse acronym-letter-spacing without regressing list-of-letters enumeration, fix the `phase ↔ face` homophone class. Enable plain-mode JSONL for production A/B.

### Cross-platform constraint (locked)

All app-code changes (25-02, 25-03) ship on macOS AND iOS together. Per `feedback_cleanup_cross_platform_parity` memory. Plan 25-01 is harness-only and platform-agnostic.

### Testing philosophy (locked)

- Per `feedback_tests_as_regression_nets`: every test added in 25-03 must lock a real V15-era failure as a regression net. No fixtures that regurgitate the implementation.
- 25-01 harness runs are reproducibility-locked at seed=42 (matches V5 methodology evidence cited in `CleanupPrompt.swift`).
- 25-04 verification is the live capture window, not the harness. The harness is necessary but not sufficient — production audio characteristics differ.

### Model constraint (locked)

- LLM stays Gemma 4 E2B Q4_K_M GGUF (per project tech stack). No model swap.
- Sampler stays `temp=0.1, top_p=0.9, top_k=40, max_tokens=512` unless 25-01 finds a sampler change is the bigger lever (low expectation).

### Claude's Discretion

- Choice of harness fixture file format (likely extend existing `fixtures/combined.tsv`).
- Whether 25-03 emits a single V16 prompt or splits into V16a/V16b for staged rollout.
- Implementation detail of the dictionary feeder fix in `Shared/Services/TextProcessingService.swift` (the planner should locate the actual feeder code; the symptom is `dictionary_context_keys` being empty/GSD-only in 199/218 records).
- Whether `lang` field stays as-is or grows a Swiss-DE bucket for future German capture.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Capture-window evidence
- `~/Library/Application Support/Dicticus/DebugRecordings/cleanup-2026-05-{13,14,15,16}.jsonl` — 218 records, all `mode: aiCleanup`, all `lang: en`. The raw evidence for every hypothesis in 25-01.

### Current AI-cleanup pipeline
- `Shared/Models/CleanupPrompt.swift` — V15 Micro-Scalpel prompt source. Header comment documents V4/V5/V6/V7 history and harness evidence pattern.
- `Shared/Services/TextProcessingService.swift` — orchestrator; contains `DEBUG_RECORDER` instrumentation and the `mode == .aiCleanup` gate that explains why no plain-mode logs exist today.
- `Shared/Services/SelfCorrectionResolver.swift` — Phase 24 Idiom Guard / Abort 3c rules layer.
- `Shared/Services/FillerWordRemover.swift` — Phase 24 orphan-comma fix landed here.

### Offline harness (Plan 25-01 home)
- `.planning/debug/harness/run.py` — single-shot prompt runner against the prod GGUF.
- `.planning/debug/harness/multi_seed.py` — multi-seed reproducibility wrapper.
- `.planning/debug/harness/analyze.py` — TSV → metrics pipeline.
- `.planning/debug/harness/prompts/v5_baseline.txt`, `v6_smart_verbatim.txt`, `v7_structural.txt` — prior prompt variants. **New V16 candidates go alongside these.**
- `.planning/debug/harness/fixtures/baseline.tsv`, `combined.tsv`, `phase24.tsv` — existing fixture sets.
- `.planning/debug/harness/results/` — TSV + Markdown reports from prior runs. V16 matrix lands here.

### Prior-phase context that bounds Phase 25
- `.planning/phases/24-ai-cleanup-quality-v2/` — V15 ship plan and tests. Phase 25 must not regress any of its 27/27 SelfCorrectionResolverTests or 10/10 CleanupPromptTests.
- `.planning/STATE.md` — current milestone and phase inventory.
- `.planning/ROADMAP.md` — Phase 25 entry at line 232.

### Memories that bound design choices
- `project_v15_capture_findings` — full failure scoreboard (the empirical input that produced this CONTEXT.md).
- `feedback_cleanup_cross_platform_parity` — macOS + iOS ship together.
- `feedback_tests_as_regression_nets` — no testing-the-implementation-at-itself fixtures.
- `project_ai_cleanup_self_correction_gap` — Phase 24 antecedent.
- `project_ai_cleanup_priorities` — currency/Swiss rules priorities (separate plane from this phase).
</canonical_refs>

<specifics>
## Specific Ideas — Concrete Failure Evidence (from 218-record V15 capture scan)

### Number-word concatenation (digit-glue bug)
- `What is phase forty one about?` → V15: `What is Phase 4001 about?` (2026-05-14 14:40)
- `I'm in forty one.` → V15: `I'm in 4001.` (same minute)
- `those two three streams` → V15: `those 203 streams` (2026-05-16 04:17)

### Isolated brand mishearings — NOT fixed by V15
- `Chemini headless` → kept (2026-05-15 15:02, 15:06)
- `Cheminai C Oli` → kept (and triggered the 203 bug above) (2026-05-16 04:17)
- `MPM supply chain attack` → kept (should be NPM) (2026-05-15 05:03)
- `engine eggs` → kept (should be NGINX) (2026-05-15 05:04)
- `Doghand` / `Dog Hand` → kept x3 (probably Dokku/Dokploy) (2026-05-15 16:59, 17:00, 17:05)
- `DogChee` → kept (probably Dockge) (2026-05-15 16:59)

### Acronym-letter-spacing — NOT collapsed by V15
- `Considering these H D D` → kept (2026-05-13 17:56)
- `T V series Dune Prophecy` → kept (2026-05-14 19:30)
- `S A B N C D UI` → V15: `SABNC D UI` (worst case: partial collapse) (2026-05-14 16:32)

### phase ↔ face homophone — NOT fixed by V15
- `discuss this face first` → kept as `face` (2026-05-14 04:21)
- `between GSD faces I should change models` → kept as `faces` (2026-05-15 15:28)

### Brand recognition WINS (V15 already does these — DO NOT regress)
- `GST` → `GSD` (5/5)
- `cloud code` / `clot code` → `Claude Code` (9/10)
- `Versal` / `Versal CLI` → `Vercel` / `Vercel CLI` (2/2)
- `true NAS` / `true Nas` → `TrueNAS` (4/4)
- `Jemini CLI` → `Gemini CLI` (1/1 when anchored)
- `opus four point seven` → `Opus 4.7` (1/1)
- `feeding` → `fitting` (suit context, 1/1)

### Dictionary feeder evidence (the largest single lever)
- 199 / 218 records have empty `dictionary_context_keys`. 19 / 218 contain only `["GSD", "gsd"]`. No other term is ever injected. This is the symptom; the planner should locate the feeder in `Shared/Services/` and design the fix.
</specifics>

<deferred>
## Deferred Ideas

- **DE-language cleanup quality** — capture window had zero German data. Defer to a separate phase that opens with a German capture window. Will reuse the same harness + plain-logging plumbing built here.
- **Sampler tuning** — out of scope unless 25-01 surfaces strong evidence a sampler change is the bigger lever.
- **Larger LLM swap** (e.g., Phi-3 Mini) — explicitly out of scope; locked to Gemma 4 E2B for v2.2.
- **Phase 23 (Decimal Words & Digit Grouping)** — still pending in backlog; the digit-concat bug from H4 may share root cause with Phase 23 — flag if discovered but do not absorb Phase 23 here.
</deferred>

---

*Phase: 25-ai-cleanup-quality-v3-brand-acronym-recognition*
*Context gathered: 2026-05-16 via inline synthesis (no discuss-phase) — empirical data from V15 capture window 2026-05-13 → 2026-05-16.*
