---
gsd_state_version: 1.0
milestone: v2.5
milestone_name: iOS Release & Context-Aware Dictation
status: executing
stopped_at: Phase 36 spike (36-01) returned CONDITIONAL-GO — plans 02-04 superseded, re-scope needed
last_updated: "2026-06-10T07:54:48.091Z"
last_activity: 2026-06-10 -- Phase 36 spike complete (conditional-GO, deferred-delivery re-scope)
progress:
  total_phases: 30
  completed_phases: 21
  total_plans: 91
  completed_plans: 92
  percent: 70
---

# Project State: Dicticus

**Last Updated:** 2026-06-09 — v2.5 roadmap created (5 phases, 12 requirements)
**Milestone:** v2.5 iOS Release & Context-Aware Dictation
**Previous milestone:** v2.4 Public-Release Readiness + Dictionary as Platform — shipped 2026-06-09

## Current Position

Phase: 36 (ios-background-dictation) — SPIKE COMPLETE, NEEDS RE-SCOPE
Plan: 36-01 complete (spike); 36-02/03/04 superseded
Status: Phase 36 spike returned CONDITIONAL-GO (deferred-delivery re-scope)
Last activity: 2026-06-10 -- Phase 36 spike complete (conditional-GO)

### Next Action

1. **Re-scope Phase 36.** Spike (36-01) proved background audio capture + ASR (ANE) work, but iOS hard-blocks LLM cleanup (GPU/Metal) AND clipboard (UIPasteboard) from the background. Plans 02-04 (background finalize → cleanup → clipboard) cannot ship. Re-run `/gsd-discuss-phase 36` then `/gsd-plan-phase 36` for the deferred-delivery design (background capture → foreground cleanup + clipboard → "transcript ready" notification). See `36-SPIKE-FINDINGS.md` §Constraints.
2. ✅ macOS `1.4.0` shipped — GitHub release `macos-v1.4.0` (2026-06-09) live. iOS `ios-v2.4.0` (TestFlight / device install) still pending verification.
3. Backlog `999.1` (post-ASR / AI-cleanup robustness) captured 2026-06-10 from log sweep — promote via `/gsd-review-backlog` when ready.
4. Backlog (new, 2026-06-10): Action Button → deep-link into Dicticus Settings (setup UX) — clarify exact intent + log via `/gsd-capture`.

## Phase Overview

| Phase | Goal | Requirements | Status |
|-------|------|--------------|--------|
| 36. iOS Background Dictation | User can dictate, leave app / lock screen, and get a complete transcript — spike-first, App-Review-aware | IOSBG-01, IOSBG-02, IOSBG-03 | Spike done (cond-GO) — re-scope to deferred delivery |
| 37. iOS Distribution | TestFlight + App Store install, Background Assets model download, privacy labels | IOSDIST-01, IOSDIST-02, IOSDIST-03 | Not started |
| 38. Context-Aware Formatting | Active-app → AI-cleanup tone/format adaptation (macOS-primary, Shared/ cross-platform) | CTXFMT-01, CTXFMT-02, CTXFMT-03 | Not started |
| 39. Voice Edit Commands | Deterministic spoken edit commands ("scratch that", "new paragraph", "capitalize X") | VEDIT-01, VEDIT-02 | Not started |
| 40. Windows Feasibility Spike | Written feasibility report for Windows port; no shipping code | WIN-01 | Not started |

## Key Decisions (v2.5)

| Decision | Rationale |
|----------|-----------|
| Phase 36 before Phase 37 | iOS distribution (App Review) depends on background dictation being settled; no point submitting without the feature |
| Phases 38, 39, 40 independent | CTXFMT, VEDIT, WIN are fully decoupled from iOS work and from each other; can be planned and executed in any order or in parallel |
| IOSBG-03 (spike) is Phase 36 plan 1, not a separate phase | The spike IS the safety gate for IOSBG-01/02 implementation; separating them into distinct phases would create a trivially-small phase and split coherent work |
| WIN-01 is a research-only phase (no code) | Research report scopes the Windows port; production code is Future scope |
| Context-aware formatting is macOS-primary | Active-app detection via `AXUIElement` / `NSWorkspace` is macOS-only; iOS equivalent (if any) derives from shared prompt path |
| Cross-platform parity applies to Phase 38 (CTXFMT) | CTXFMT modifies the AI-cleanup prompt path in Shared/; per project convention, Shared/ changes ship macOS + iOS together |

## Accumulated Context

### Architecture notes for v2.5

- Phase 36: `UIBackgroundModes: audio` must be declared in iOS target Info.plist; AVAudioSession must remain active through the background task; `beginBackgroundTask` wrapper needed for post-stop transcription tail
- Phase 36: `StopDictationIntent` and `DictationLiveActivity.swift` are dormant in the codebase (removed misleading Live Activity in interim fix commit 82f2860) — re-enable path is known
- Phase 37: Background Assets framework (iOS 16+) is the preferred mechanism for the ~2.7 GB model download; ODR is the fallback; neither bundles the model in the binary
- Phase 38: `NSWorkspace.shared.frontmostApplication` (macOS) gives the active app bundle ID; pass to `CleanupPrompt` as a context hint; no new network calls
- Phase 39: Voice edit commands follow the spoken-punctuation precedent (Phase 32): deterministic pre-LLM layer in `Shared/Utilities/`; command recognition is a standalone utterance check, not inline with transcription

### Quality baselines to preserve

- 443 macOS XCTest passing (1 pre-existing failure `testBlocksUntilCleaned`)
- 435 iOS XCTest passing
- V19E content-word gate (`gateContentWords`) must remain active through all Shared/ changes

### Constraints active in v2.5

- Strictly local: no audio, transcript, or app-name data sent to any server (CTXFMT-02 makes this explicit for Phase 38)
- Cross-platform parity: Shared/ changes in Phase 38 ship macOS + iOS in the same phase
- App-Review risk in Phase 36 and 37: document the spike findings and review justifications before submitting to App Store

## Session Continuity

Last session: 2026-06-10T07:54:48.086Z
Stopped at: Phase 36 context gathered
Next: Cut v2.4 public release, then plan Phase 36 (iOS Background Dictation)

---

**(archived context below — v2.4 closeout)**

v2.4 shipped 2026-06-09. All 5 phases (31-35) complete. Phase 35 (UI Reorganization) UAT approved on Developer-ID-signed build. UIORG-01..04 verified. 453 macOS / 435 iOS tests GREEN. macOS v1.3.0 build 5 locally validated; public DMG + Sparkle + ios-v2.4.0 pending at milestone close.

## Deferred Items (acknowledged and deferred at v2.4 close — 2026-06-09)

Total: **28** — predominantly historical items carried across milestones. None block v2.5.

| Category | Item / Slug | Status |
|----------|-------------|--------|
| Debug session | ai-cleanup-quality-regression | partially-resolved (2026-05-09) |
| Debug session | log-analysis-2026-05-26 | unknown |
| Debug session | log-analysis-2026-06-04 | unknown |
| Debug session | recording-interruption-cleanup-quality | completed (2026-05-03) |
| UAT gap | Phase 19 — 19-UAT-CATALOG.md | awaiting_user_signoff |
| UAT gap | Phase 19 — 19-UAT-FINDINGS-postship.md | unknown (historical) |
| UAT gap | Phase 19 — 19-UAT-FINDINGS.md | unknown (historical) |
| UAT gap | Phase 20 — 20-UAT-FINDINGS.md | triaged-pending-20.06-plan (historical) |
| UAT gap | Phase 20.06 — 20.06-04-UAT-RESULTS.md | unknown (historical) |
| UAT gap | Phase 20.08 — 20.08-04-UAT-RESULTS.md | unknown (historical) |
| UAT gap | Phase 20.08 — 20.08-05-UAT-RESULTS.md | pass-with-notes, user-accepted 2026-05-01 |
| UAT gap | Phase 22 — 22-HUMAN-UAT.md | partial (1 open scenario) |
| UAT gap | Phase 27 — 27-HUMAN-UAT.md | partial (5 open scenarios) |
| UAT gap | Phase 30 — 30-02-UAT-RESULTS.md | unknown |
| UAT gap | Phase 30 — 30-03-UAT-RESULTS.md | unknown |
| UAT gap | Phase 31 — 31-HUMAN-UAT.md | passed |
| UAT gap | Phase 32 — 32-HUMAN-UAT.md | passed |
| UAT gap | Phase 33 — 33-HUMAN-UAT.md | resolved |
| UAT gap | Phase 34 — 34-HUMAN-UAT.md | partial (3 open scenarios; SC3 harness non-app-faithful) |
| Verification gap | Phase 17.5 — 17.5-VERIFICATION.md | human_needed (historical) |
| Verification gap | Phase 22 — 22-VERIFICATION.md | human_needed |
| Verification gap | Phase 27 — 27-VERIFICATION.md | human_needed (closed via debug-log evidence) |
| Verification gap | Phase 28 — 28-VERIFICATION.md | human_needed (closed via debug-log evidence) |
| Verification gap | Phase 31 — 31-VERIFICATION.md | human_needed |
| Verification gap | Phase 33 — 33-VERIFICATION.md | human_needed |
| Verification gap | Phase 34 — 34-VERIFICATION.md | human_needed |
| Verification gap | Phase 35 — 35-VERIFICATION.md | human_needed |
| Context question | Phase 35 — 35-CONTEXT.md Q-02 | open (degraded-state placement — Q-01 and Q-03 resolved in Phase 35) |

## Operator Notes

- `.planning/` is gitignored — no GSD commits target `.planning/*` files
- Cross-platform parity per `feedback_cleanup_cross_platform_parity` — all Shared/ changes ship macOS + iOS together
- English-first UAT acceptable per `project_usage_pattern_english_dominant`; German regressions validated via corpus
- Phase 36 is App-Review-risky: spike findings must be documented and justify the `UIBackgroundModes: audio` declaration before App Store submission
