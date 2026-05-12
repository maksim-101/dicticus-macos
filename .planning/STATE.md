---
gsd_state_version: 1.0
milestone: v2.2
milestone_name: Adaptive Cleanup & Stability Post-v2.1
status: in_progress
last_updated: "2026-05-12T20:50:00.000Z"
progress:
  total_phases: 12
  completed_phases: 10
  total_plans: 41
  completed_plans: 41
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

## Next Action

The system is now in a 3-day **Capture Window** (May 12–15) using the `Debug-Recorder` scheme
to gather production-like JSONL logs.

1. Analyze the 3-day JSONL capture logs starting May 15th to verify V15 prompt efficacy.
2. Address Phase 23 (Decimal Words & Digit Grouping) or plan Milestone v2.3.

Plans:
- [x] `24-PLAN.md` — SHIPPED 2026-05-12. V15 prompt + Idiom Guard + Recorder fix. macOS/iOS suite 100% green.
- [ ] `23-PLAN.md` — PENDING. Decimal Words & Digit Grouping.
