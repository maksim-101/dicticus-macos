---
gsd_state_version: 1.0
milestone: v2.2
milestone_name: Adaptive Cleanup & Stability Post-v2.1
status: in_progress
last_updated: "2026-05-08T20:20:00.000Z"
progress:
  total_phases: 11
  completed_phases: 8
  total_plans: 38
  completed_plans: 38
  percent: 100
---

# Project State: Dicticus

**Last Updated:** 2026-05-08
**Milestone:** v2.2 Adaptive Cleanup & Stability — Phase 22 SHIPPED (both plans complete)
**Next milestone:** v2.3 (TBD — likely iCloud Sync + TestFlight)

## Current Position

Phase: 22 (resolver-regression-hotfix) — SHIPPED 2026-05-08
Plan: 2 of 2 complete (Plan 01 SHIPPED 2026-05-08, Plan 02 SHIPPED 2026-05-08)
**Milestone v2.2:** Phase 21 SHIPPED 2026-05-03. Phase 22 Plan 01 (regex hotfix at
`SelfCorrectionResolver.swift:75` + 7 JSONL regression fixtures cross-platform) SHIPPED 2026-05-08
across 3 atomic commits (ba2b01b, 7fce68b, d4af189). macOS resolver suite reports 25/25 green
in 0.015s (`** TEST SUCCEEDED **`); iOS file byte-identical via `diff -q` (iOS xcodebuild gate
deferred — iOS 26.4 Simulator runtime not installed on this machine). Phase 22 Plan 02
(CleanupPrompt 8a79e6b few-shot regression net — pre-flight grep + 1 `XCTAssertFalse` test)
SHIPPED 2026-05-08 (commit 7df3376). macOS `testWFewShotFromCommit8a79e6bIsAbsent` reports
`** TEST SUCCEEDED **` in 0.001s; no production source touched.

**Active investigation:** `ai-cleanup-quality-regression` — debug session NO LONGER BLOCKED.
Live capture under the `Dicticus-Debug-Recorder` scheme produced 30 JSONL records at
`~/Library/Application Support/Dicticus/DebugRecordings/cleanup-2026-05-08.jsonl`.
Root cause confirmed: `Shared/Utilities/SelfCorrectionResolver.swift:75` regex matches
connectors (`no`, `wait`, `ne`, `wart`, `actually`) as substrings of unrelated words and fires
without a comma prefix. Findings persisted in `.planning/debug/ai-cleanup-quality-regression.md`
and remediation queued as Phase 22 (`.planning/phases/22-resolver-regression-hotfix/22-CONTEXT.md`).

A second class of bug (ITN doesn't fold spoken decimal markers `Punkt`/`Komma`/`point`; English
ITN concatenates comma-separated digit words) was found in the same capture. Deferred to Phase 23
so Phase 22 ships clean.

**Phase inventory:**

- ... (Phases 12-20.08 preserved in history)
- 21 — Adaptive Cleanup & Stability — SHIPPED 2026-05-03 (Debounce fix, Surgical Completion, 6-token repair window)
- 22 — Resolver Regression Hotfix — SHIPPED 2026-05-08 (2/2 plans: Plan 01 — regex L75 fix + 7 JSONL fixtures cross-platform; Plan 02 — CleanupPrompt 8a79e6b few-shot regression net)
- 23 — Decimal Words & Digit Grouping — BACKLOG (ITN regression class)

**UAT verdict 2026-05-03 (Phase 21):** AI cleanup quality and system stability ACCEPTED. GSD
and Technical terms mapped correctly. Intent and preambles preserved verbatim. The "T"/"W"
degenerate-collapse residue observed afterward is now attributed to the resolver regex (Phase 22),
not a Phase 21 regression.

## Next Action

Phase 22 is fully shipped. Recommend `/gsd-verify-work` then a phase-22 PR push (or fold into the
existing `feature/debug-recording-and-cleanup` PR) before starting Phase 23 (DecimalWordsAndDigitGrouping).
The branch `feature/debug-recording-and-cleanup` now carries Phase 21 cleanup, the Phase 22 resolver
regex fix (Plan 01), and the Phase 22 CleanupPrompt regression net (Plan 02).

Plans:
- [x] `22-01-PLAN.md` — SHIPPED 2026-05-08 (commits ba2b01b, 7fce68b, d4af189). macOS suite 25/25
  green; iOS file byte-identical via `diff -q`. iOS xcodebuild gate deferred — iOS 26.4 Simulator
  runtime not installed on this machine. Summary: `.planning/phases/22-resolver-regression-hotfix/22-01-SUMMARY.md`.
- [x] `22-02-PLAN.md` — SHIPPED 2026-05-08 (commit 7df3376). Pre-flight grep gate confirmed
  `8a79e6b` residue strings already absent from `Shared/Models/CleanupPrompt.swift`. Added
  `testWFewShotFromCommit8a79e6bIsAbsent` to `macOS/DicticusTests/CleanupPromptTests.swift` under
  MARK `// MARK: - Phase 22 regression: 8a79e6b few-shot must be absent`. Targeted xcodebuild
  test reports `** TEST SUCCEEDED **` (1/1 in 0.001s, with `CODE_SIGNING_ALLOWED=NO`). No
  production source touched. macOS-only (CleanupPromptTests has no iOS counterpart by 20.06-01
  precedent). Summary: `.planning/phases/22-resolver-regression-hotfix/22-02-SUMMARY.md`.

**Followup (env, not blocking next phase):** install iOS 26.4 SDK components via Xcode > Settings >
Components so iOS xcodebuild gates can run locally. Until then, iOS test execution falls back
to byte-parity verification via `diff -q` against the green macOS file.
