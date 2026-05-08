---
gsd_state_version: 1.0
milestone: v2.2
milestone_name: Adaptive Cleanup & Stability Post-v2.1
status: in_progress
last_updated: "2026-05-08T20:00:00.000Z"
last_activity: 2026-05-08 -- Phase 22 planned. RESEARCH + PATTERNS + VALIDATION + 22-01-PLAN (regex fix at SelfCorrectionResolver.swift:75 + 7 negative-fixture XCTests on macOS+iOS) + 22-02-PLAN (CleanupPrompt 8a79e6b regression net) written and verified by plan-checker. Next action -- /gsd-execute-phase 22.
progress:
  total_phases: 10
  completed_phases: 9
  percent: 90
active_debug_session: ai-cleanup-quality-regression
active_branch: feature/debug-recording-and-cleanup
---

# Project State: Dicticus

**Last Updated:** 2026-05-08
**Milestone:** v2.2 Adaptive Cleanup & Stability — IN PROGRESS (Phase 22 planned, ready to execute)
**Next milestone:** v2.3 (TBD — likely iCloud Sync + TestFlight)

## Current Position

**Milestone v2.2:** Phase 21 SHIPPED 2026-05-03. Phase 22 (Resolver Regression Hotfix) queued from
DebugRecorder evidence captured 2026-05-08.

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
- 22 — Resolver Regression Hotfix — PLANNED 2026-05-08 (2 plans, 5 tasks; next: `/gsd-execute-phase 22`)
- 23 — Decimal Words & Digit Grouping — BACKLOG (ITN regression class)

**UAT verdict 2026-05-03 (Phase 21):** AI cleanup quality and system stability ACCEPTED. GSD
and Technical terms mapped correctly. Intent and preambles preserved verbatim. The "T"/"W"
degenerate-collapse residue observed afterward is now attributed to the resolver regex (Phase 22),
not a Phase 21 regression.

## Next Action

Run `/gsd-execute-phase 22` to execute the resolver hotfix. Plans live in
`.planning/phases/22-resolver-regression-hotfix/`:
- `22-01-PLAN.md` — Wave 1: regex fix at `SelfCorrectionResolver.swift:75` + 7 negative-fixture
  XCTests added to macOS + iOS in one atomic commit (3 tasks).
- `22-02-PLAN.md` — Wave 2: `8a79e6b` CleanupPrompt regression net (pre-flight grep + one
  `XCTAssertFalse` test; no production source touched — V5 rewrite already removed the residue).

Plan-checker verified PASSED. Acceptance criteria: all 7 verbatim JSONL fixtures must produce
`post_rules == raw`; existing 18 positive resolver tests must still pass; macOS + iOS test files
must be byte-for-byte identical.
