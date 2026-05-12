---
gsd_state_version: 1.0
milestone: v2.2
milestone_name: Adaptive Cleanup & Stability Post-v2.1
status: in_progress
last_updated: "2026-05-12T04:00:00.000Z"
progress:
  total_phases: 12
  completed_phases: 9
  total_plans: 39
  completed_plans: 39
  percent: 100
---

# Project State: Dicticus

**Last Updated:** 2026-05-12
**Milestone:** v2.2 Adaptive Cleanup & Stability — Phase 24 SHIPPED 2026-05-12 (Micro-Scalpel V15 + Idiom Guard)
**Next milestone:** v2.3 (TBD — likely iCloud Sync + TestFlight)

## Current Position

Phase: 24 (ai-cleanup-quality-v2) — SHIPPED 2026-05-12
Plan: 1 of 1 complete (Plan 24-01 SHIPPED 2026-05-12)
**Milestone v2.2:** Phase 22 SHIPPED 2026-05-08. Phase 24 (AI Cleanup Quality v2) SHIPPED 2026-05-12.
Remediation for Phase 22 UAT Gap G-01 (self-correction not dropped) implemented via **V15 "Micro-Scalpel"** 
prompt in `Shared/Models/CleanupPrompt.swift`. V15 moves to a "rules-first" instructions structure
that explicitly permits dropping stutters and abandoned fragments while preserving substantive 
repair-chains verbatim.

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

## Next Action

Phase 24 is fully shipped. The branch `feature/debug-recording-and-cleanup` now carries all 
Milestone v2.2 fixes. Branch should be pushed (well past the "stop and push" threshold from CLAUDE.md).

**Next Step:** Address Phase 23 (Decimal Words & Digit Grouping) if requested, or move toward 
Milestone v2.3 scope.

Plans:
- [x] `24-PLAN.md` — SHIPPED 2026-05-12. V15 prompt + Idiom Guard + Recorder fix. macOS suite green.
