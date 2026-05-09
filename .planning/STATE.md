---
gsd_state_version: 1.0
milestone: v2.2
milestone_name: Adaptive Cleanup & Stability Post-v2.1
status: in_progress
last_updated: "2026-05-09T07:00:00.000Z"
progress:
  total_phases: 12
  completed_phases: 8
  total_plans: 38
  completed_plans: 38
  percent: 100
---

# Project State: Dicticus

**Last Updated:** 2026-05-09
**Milestone:** v2.2 Adaptive Cleanup & Stability — Phase 22 SHIPPED + production UAT 2/3 PASSED (2026-05-09); Phase 24 (AI Cleanup Quality v2) scaffolded as blocked on capture window
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
- 22 — Resolver Regression Hotfix — SHIPPED 2026-05-08; production UAT 2026-05-09 PASSED 2/3 (live dictation 7/7 fixtures verbatim in both modes; WR-01 scope-narrowing accepted; iOS xcodebuild gate deferred — iOS 26.4 sim runtime missing)
- 23 — Decimal Words & Digit Grouping — BACKLOG (ITN regression class)
- 24 — AI Cleanup Quality v2 — BLOCKED on capture window (2026-05-09 → 2026-05-12). Triggered by Phase 22 UAT G-01 (self-correction not dropped). Dicticus-Debug-Recorder build at `/Applications/Dicticus.app` accumulating JSONL. Run `/gsd-plan-phase 24` after window closes. Context: `.planning/phases/24-ai-cleanup-quality-v2/24-CONTEXT.md`

**UAT verdict 2026-05-03 (Phase 21):** AI cleanup quality and system stability ACCEPTED. GSD
and Technical terms mapped correctly. Intent and preambles preserved verbatim. The "T"/"W"
degenerate-collapse residue observed afterward is now attributed to the resolver regex (Phase 22),
not a Phase 21 regression.

## Next Action

Phase 22 is fully shipped AND production-UAT'd (2026-05-09, 2/3 passed, 1 deferred for env reason).
The branch `feature/debug-recording-and-cleanup` now carries Phase 21 cleanup, Phase 22 (both plans
+ UAT artifact), and the Phase 24 scaffolding. Branch should be pushed (currently 42+ commits ahead
of origin/main, well past the "stop and push" threshold from CLAUDE.md).

**Phase 24 capture window in progress until 2026-05-12.** Dicticus-Debug-Recorder build is installed
at `/Applications/Dicticus.app` (Developer ID re-signed, TeamIdentifier `VTWHBCCP36`). User dictates
normally; cleanup pipeline I/O is logged to `~/Library/Application Support/Dicticus/DebugRecordings/cleanup-YYYY-MM-DD.jsonl`.
After 2026-05-12: restore Release build (sitting at `macOS/build/Build/Products/Release/Dicticus.app`,
already Developer ID re-signed) and run `/gsd-plan-phase 24` against the captured corpus.

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
