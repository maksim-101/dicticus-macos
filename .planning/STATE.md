---
gsd_state_version: 1.0
milestone: v2.2
milestone_name: Adaptive Cleanup & Stability Post-v2.1
status: in_progress
last_updated: "2026-05-16T04:51:17.488Z"
progress:
  total_phases: 13
  completed_phases: 9
  total_plans: 41
  completed_plans: 38
  percent: 93
---

# Project State: Dicticus

**Last Updated:** 2026-05-12
**Milestone:** v2.2 Adaptive Cleanup & Stability — Phase 24 SHIPPED 2026-05-12 (Micro-Scalpel V15 + Idiom Guard)
**Next milestone:** v2.3 (TBD — likely iCloud Sync + TestFlight)

## Current Position

Phase: 25 (ai-cleanup-quality-v3-brand-acronym-recognition) — EXECUTING
Plan: 2 of 4 complete (Wave 1 done — 25-01 hypothesis matrix + 25-02 plain-mode-logging)

**Wave 1 outcome (2026-05-16):**
- 25-01 SHIPPED: V16 matrix run (259 inferences, seed=42, 53s wall-clock). Initial winner was V16-COMPOSITE = H3+H4+H5.
- 25-02 SHIPPED with **discovery-driven pivot**: plain-mode JSONL emission was ALREADY happening today (the `#if DEBUG_RECORDER` block in `TextProcessingService.swift` is at OUTER scope, line 224, NOT gated by `mode == .aiCleanup`). The "218/218 aiCleanup records" reflected the user's usage pattern, not code suppression. Plan pivoted from "add a write path" to "document the existing contract + lock with parity tests on macOS + iOS".
- **25-01 H8/H9 follow-up** (commit 4b93acc, mandated by user after Wave 1): added rules-only baselines to the matrix. Showed that the dictionary layer does ~90% of brand-fixing work; LLM contributes ~2 records out of 256 (V15-era). H9 (rules-only + expanded dict) aggregate 72 (second-best of 9 variants). Brand 35→2, anchor 28→0, all via dictionary, zero LLM cost. Memory: `project_dictionary_dominates_brand_fixing`.
- **Plan 25-03 RE-PLANNED** (2026-05-16) per matrix.md §5 hybrid recommendation. New 5-task structure: Task 1 dictionary expansion (highest ROI), Task 2 V16-COMPOSITE prompt (H3+H4 only, skip H1, conditional H5), Task 3 V17 harness verification (gates Task 2 commit), Task 4 regression-net tests, Task 5 human UAT.

**Open items for Wave 2 (next session):**
1. xcodebuild verification of 25-02 tests was deferred — parallel-build cache contention in worktree mode prevented test runs. Do a clean `xcodebuild test -only-testing:DicticusTests/TextProcessingServiceTests` on macOS + iOS first thing in Wave 2.
2. Plan 25-03 Task 3 (V17 verification) Step C shows a Python CLI invocation with flags that don't exist on `run_v16_matrix.py` (`--variant` should be `--variants`; `--fixture-file` should be `--fixtures`; `--append-tsv` doesn't exist — script overwrites). Executor needs to either add those flags or wrap in a small script (like `run_h8_h9.py` does).
3. Plan 25-03 was re-planned via Write (not Edit, since Edit was unavailable to the subagent) — grew from 393 → 631 lines, no truncation, but worth a quick read-through before launching the executor.
4. Branch is 10 commits ahead of origin/feature/debug-recording-and-cleanup. Per CLAUDE.md push cadence, push at Wave 2 start.
**Milestone v2.2:** Phase 22 SHIPPED 2026-05-08. Phase 24 (AI Cleanup Quality v2) SHIPPED 2026-05-12.
Remediation for Phase 22 UAT Gap G-01 (self-correction not dropped) implemented via **V15 "Micro-Scalpel"** 
prompt in `Shared/Models/CleanupPrompt.swift`. V15 moves to a "rules-first" instructions structure
that explicitly permits dropping stutters and abandoned fragments while preserving substantive 
repair-chains verbatim.

Phase 24 is officially synchronized across macOS and iOS. Both platforms are 100% green.
A persistent 'permissions not sticking' issue on macOS was identified and fixed through
Developer ID signing and build artifact cleanup; this workflow is now mandated in `GEMINI.md`
and automated in `install-local.sh`.

Rules layer hardened via **Abort 3c: Idiom Guard** in `SelfCorrectionResolver.swift`. The guard
prevents over-correction on idiomatic comma-terminated phrases identified in weekend logs 
(e.g., "by the way", "wie gesagt"). Unit test suite `SelfCorrectionResolverTests` reports 27/27 green.
`CleanupPromptTests` reports 10/10 green.

DebugRecorder state bleed bug fixed in `TextProcessingService.swift` (clearing `lastDebugTrace`
at start of cycle).

**Phase inventory:**

- ... (Phases 12-20.08 preserved in history)
- 21 — Adaptive Cleanup & Stability — SHIPPED 2026-05-03
- 22 — Resolver Regression Hotfix — SHIPPED 2026-05-08
- 23 — Decimal Words & Digit Grouping — BACKLOG (ITN regression class)
- 24 — AI Cleanup Quality v2 — SHIPPED 2026-05-12
- 25 — AI Cleanup Quality v3 — Brand & Acronym Recognition — ADDED 2026-05-16 (planning pending)

### Roadmap Evolution

- 2026-05-16: Phase 25 added — AI Cleanup Quality v3 (Brand & Acronym Recognition). Scoped from V15 capture-window analysis (see `project_v15_capture_findings` memory). Four-plan structure proposed: 25-01 offline hypothesis matrix in harness, 25-02 plain-mode logging, 25-03 V16 prompt + dictionary feeder, 25-04 capture window v2 + UAT.

## Next Action

The system is now in a 3-day **Capture Window** (May 12–15) using the `Debug-Recorder` scheme
to gather production-like JSONL logs.

1. Analyze the 3-day JSONL capture logs starting May 15th to verify V15 prompt efficacy.
2. Address Phase 23 (Decimal Words & Digit Grouping) or plan Milestone v2.3.

Plans:

- [x] `24-PLAN.md` — SHIPPED 2026-05-12. V15 prompt + Idiom Guard + Recorder fix. macOS/iOS suite 100% green.
- [ ] `23-PLAN.md` — PENDING. Decimal Words & Digit Grouping.
