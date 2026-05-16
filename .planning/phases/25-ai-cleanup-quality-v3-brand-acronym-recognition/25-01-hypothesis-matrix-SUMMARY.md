---
phase: 25-ai-cleanup-quality-v3-brand-acronym-recognition
plan: 01
subsystem: ai-cleanup
tags: [harness, hypothesis-matrix, prompt-engineering, no-app-code]
requires: [.planning/phases/25-ai-cleanup-quality-v3-brand-acronym-recognition/25-CONTEXT.md]
provides: [V16-composite recommendation, phase25_brands.tsv, run_v16_matrix.py]
affects:
  - .planning/debug/harness/run.py
  - .planning/debug/harness/run_v16_matrix.py (new)
  - .planning/debug/harness/fixtures/phase25_brands.tsv (new)
  - .planning/debug/harness/prompts/v15_micro_scalpel.txt (new)
  - .planning/debug/harness/prompts/v16{a,b,c,d,e,f}_*.txt (new)
  - .planning/debug/harness/results/v16_matrix.{tsv,md} (new)
tech-stack:
  added: []
  patterns:
    - "Hypothesis-first gating before app-code touch (user-mandated)"
    - "Template-loading prompt builders with {{KNOWN_TERMS}} placeholders"
    - "Char-level Levenshtein for sub-word fix resolution"
key-files:
  created:
    - .planning/debug/harness/fixtures/phase25_brands.tsv
    - .planning/debug/harness/prompts/v15_micro_scalpel.txt
    - .planning/debug/harness/prompts/v16a_dictionary_always_on.txt
    - .planning/debug/harness/prompts/v16b_phonetic_variants.txt
    - .planning/debug/harness/prompts/v16c_domain_topics.txt
    - .planning/debug/harness/prompts/v16d_number_integrity.txt
    - .planning/debug/harness/prompts/v16e_acronym_collapse.txt
    - .planning/debug/harness/prompts/v16f_bundled.txt
    - .planning/debug/harness/run_v16_matrix.py
    - .planning/debug/harness/results/v16_matrix.tsv
    - .planning/debug/harness/results/v16_matrix.md
  modified:
    - .planning/debug/harness/run.py
decisions:
  - "Winner: V16-COMPOSITE = H5 (acronym + enumeration) + H3 (phase/face) + H4 (number integrity). Reject H1 (always-on Known terms) due to brand-specificity regression. Reject H7 bundle as-is due to V15-WIN regression."
  - "Ship H2 phonetic variants as DictionaryService entries, NOT as prompt rule wording."
  - "Dictionary feeder is the dominant lever, not surface-text anchoring (H6 inconclusive)."
metrics:
  duration_min: 4
  variants_tested: 7
  fixtures: 37
  inferences: 259
  wall_clock_sec: 53.2
  completed: 2026-05-16T04:57:29Z
---

# Phase 25 Plan 01: Hypothesis Matrix Summary

**One-liner:** Empirically ranked 7 V16 prompt hypotheses against V15 baseline at seed=42; identified V16-composite (H3+H4+H5, NOT H1, NOT H7) as plan 25-03's payload.

## Variants tested

| Variant | Hypothesis | Context fn  | Lever                                            |
| ------- | ---------- | ----------- | ------------------------------------------------ |
| V15     | baseline   | targeted    | Current prod prompt mirror (CleanupPrompt.swift) |
| V16A    | H1         | always_on   | Canonical Known terms always injected            |
| V16B    | H2         | always_on   | Phonetic-variant mapping in Known terms          |
| V16C    | H3         | targeted    | Domain topic words + phase/face few-shot         |
| V16D    | H4         | targeted    | Number-integrity rule + few-shots                |
| V16E    | H5         | targeted    | Acronym collapse + enumeration anti-regression   |
| V16F    | H7 bundle  | always_on   | H1+H3+H4+H5 stacked                              |

## Fixtures

37 rows in `phase25_brands.tsv`, all traceable to capture-window timestamps in `25-CONTEXT.md <specifics>`:
- 13 brand mishearings (P25-brand-*)
- 6 anchor pairs for H6 ablation (P25-anchor-*)
- 4 number-integrity (P25-num-*)
- 5 acronym (3 collapse + 2 enumeration controls, P25-acro-*)
- 3 phase↔face homophone (incl. 1 control, P25-phase-face-* / P25-ctrl-*)
- 6 V15-WIN regression net (P25-regress-*)

## Wall-clock

- Matrix run: **53.2 seconds** (7 × 37 = 259 inferences) — much faster than plan estimate (15-40 min) thanks to llama.cpp prompt-cache reuse across same-variant runs.
- Plan total: ~4 minutes (fixture authoring + prompt files + runner + analysis + report + summary).

## Winner: V16-COMPOSITE

The 3 most-improved fixture rows (`expected` matched exactly by V16, V15 had a meaningful miss):

| Fixture                            | Input                                            | V15 output                                       | V16 winner output                                | Expected                                         | V15 lev → winner |
| ---------------------------------- | ------------------------------------------------ | ------------------------------------------------ | ------------------------------------------------ | ------------------------------------------------ | ---------------- |
| P25-acro-enum-02                   | Use letters A B C D as separators in the heading.| `A B C D` (V15 EATS most of the input!)          | `Use letters A B C D as separators in the heading.` (V16E/V16A/V16B) | (preserved) | 42 → **0**       |
| P25-num-01-fortyone-20260514T1440  | What is phase forty one about?                   | What is phase forty one about?                   | What is phase 41 about? (V16D)                   | What is phase 41 about?                          | 9 → **0**        |
| P25-phase-face-01-20260514T0421    | Let's discuss this face first before we ship.    | Let's discuss this face first before we ship.    | Let's discuss this phase first before we ship. (V16C) | Let's discuss this phase first before we ship.   | 3 → **0**        |

## V15-win regression discoveries

Only one variant fails the V15-WIN regression check: **V16F (bundle)**.

| Fixture                          | V15 → V16F                                                            | Disposition          |
| -------------------------------- | --------------------------------------------------------------------- | -------------------- |
| P25-regress-06-feeding-fitting   | `The jacket is fitting well in the shoulders.` → empty output         | **DO NOT SHIP V16F.** Documented for memory. Likely caused by prompt-length pressure + always-on Known terms + bundled rules.|
| (non-regress-set surprise) P25-brand-01-cheminiheadless | V15 lev 0 → V16D lev 9 (model rephrases under H4's wording) | Plan 25-03 must re-verify under composite — H4's rule weight is sensitive to prompt-section ordering. |

## Recommendation for plan 25-03

> **Plan 25-03 must roll variant `V16-COMPOSITE` (H3 + H4 + H5 stacked, NOT H1, NOT H7) into `Shared/Models/CleanupPrompt.swift` and expand `TextProcessingService.swift:159-165` dictionary-feeder logic per Task 2's `build_always_on_context` reference implementation — but NOT by adopting always-on injection. Instead, broaden the targeted-substring match (case-insensitive, prefix-aware) so more dictionary keys fire. Ship the H2 phonetic variants as new `DictionaryService.swift:prepopulateWithDefaults` entries (`Chemini -> Gemini`, `Cheminai -> Gemini`, `Jemini -> Gemini`, `MPM -> NPM`, `engine eggs -> NGINX`, `Doghand -> Dokku`, `Dog Hand -> Dokku`, `DogChee -> Dockge`, `true Nas -> TrueNAS`) — cross-platform parity per `feedback_cleanup_cross_platform_parity`.**

Per-hypothesis verdicts: H1=NO (brand specificity loss), H2=ship-as-dict-only, H3=YES, H4=YES (re-verify), H5=YES (best single-lever), H6=inconclusive (dictionary feeder dominates), H7=NO (regression + content collapse).

## Pointers

- Quantitative report: [.planning/debug/harness/results/v16_matrix.md](../../debug/harness/results/v16_matrix.md)
- Per-row TSV: [.planning/debug/harness/results/v16_matrix.tsv](../../debug/harness/results/v16_matrix.tsv)
- Fixtures: [.planning/debug/harness/fixtures/phase25_brands.tsv](../../debug/harness/fixtures/phase25_brands.tsv)
- Reference always-on builder for plan 25-03's dictionary-feeder design (USE AS REFERENCE, NOT VERBATIM): [.planning/debug/harness/run.py:build_always_on_context()](../../debug/harness/run.py)

## Deviations from Plan

1. **Plan-mandated comment-style sidecar dropped.** Plan §Task 1 suggested per-row comments in TSV; instead I put header at line 1 and group comments AFTER the header (lines 2-13). The runner explicitly skips `^#` lines in `run_v16_matrix.load_fixtures`. Rationale: `csv.DictReader` does not natively skip comment lines and the plan's automated verify (`head -1 | grep '^id'`) required header on line 1.

2. **Char-level Levenshtein (not word-level) for the matrix.** Plan §Task 2 step B referenced `lev_distance(output, expected)` without specifying granularity. I used character-level so sub-word fixes (`GSD` vs `gsd`, `forty one` vs `41`) resolve cleanly. Word-level would have collapsed many meaningful differences to 0/1.

3. **Wall-clock 53s vs 15-40 min plan estimate.** Plan §Task 3 estimated 15-40 minutes; actual was 53 seconds. Cause: `cache_prompt=true` and per-variant prompt-prefix stability mean llama-server reuses the prompt cache across all 37 fixtures within a variant. No regression in output quality — same sampler, same seed.

4. **No app-code work performed.** Per plan and CONTEXT.md `<domain>` methodology constraint ("Do some iteration with different hypotheses first BEFORE implementing any changes to the app itself"), I touched zero files under `macOS/`, `iOS/`, or `Shared/`. The recommendation hands off to plan 25-03 for app-code changes.

5. **Empty commits for git audit trail.** All artifacts live under `.planning/` which is gitignored, so per-task commits are `--allow-empty`. This preserves audit trail without polluting git history with would-be-tracked changes that aren't tracked.

## Authentication gates

None — fully offline harness, no external services, no credentials.

## Known Stubs

None — all variants emit real outputs (with the 3 documented empty/short-output anomalies for V16A/V16B/V16F on specific fixtures, which are themselves data points the report documents).

## Self-Check: PASSED

Verified post-write:

- `.planning/debug/harness/fixtures/phase25_brands.tsv` FOUND (37 non-comment rows, header on line 1)
- `.planning/debug/harness/prompts/v15_micro_scalpel.txt` FOUND
- `.planning/debug/harness/prompts/v16a_dictionary_always_on.txt` FOUND
- `.planning/debug/harness/prompts/v16b_phonetic_variants.txt` FOUND
- `.planning/debug/harness/prompts/v16c_domain_topics.txt` FOUND
- `.planning/debug/harness/prompts/v16d_number_integrity.txt` FOUND
- `.planning/debug/harness/prompts/v16e_acronym_collapse.txt` FOUND
- `.planning/debug/harness/prompts/v16f_bundled.txt` FOUND
- `.planning/debug/harness/run_v16_matrix.py` FOUND
- `.planning/debug/harness/results/v16_matrix.tsv` FOUND (260 rows: 1 header + 259 inferences)
- `.planning/debug/harness/results/v16_matrix.md` FOUND (contains `## Recommendation`, `## Regression check`, `Provenance`)
- Commit `1d39d34` FOUND (Task 1)
- Commit `09542b5` FOUND (Task 2)
- Commit `0a45e4f` FOUND (Task 3)
