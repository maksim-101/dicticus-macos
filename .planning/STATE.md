---
gsd_state_version: 1.0
milestone: v2.5
milestone_name: iOS Release & Context-Aware Dictation
status: executing
stopped_at: Completed 36.3-03-PLAN.md
last_updated: "2026-06-13T16:18:48.286Z"
last_activity: 2026-06-13 -- Phase 36.3 execution started
progress:
  total_phases: 33
  completed_phases: 24
  total_plans: 105
  completed_plans: 109
  percent: 73
---

# Project State: Dicticus

**Last Updated:** 2026-06-09 — v2.5 roadmap created (5 phases, 12 requirements)
**Milestone:** v2.5 iOS Release & Context-Aware Dictation
**Previous milestone:** v2.4 Public-Release Readiness + Dictionary as Platform — shipped 2026-06-09

## Current Position

Phase: 36.3 (macos-app-group-removal-storage-migration) — EXECUTING
Plan: 4 of 4
Status: Ready to execute
Last activity: 2026-06-13 -- Phase 36.3 execution started

### Next Action

1. **Plan Phase 36.2 (next).** macOS Build Reliability & Permission UX — inserted 2026-06-13. Two tracks: (a) local-build signing/TCC reliability (Developer ID key pruning from the custom keychain, `install-local.sh` relaunching a stale binary, dead multi-copy detector querying wrong bundle id); (b) permission-loss UX — surface which of mic/Accessibility/Input-Monitoring is missing at ANY time, with a correct settings deep link per permission (Accessibility AND Input Monitoring). Sources: `backlog/local-build-signing-tcc-reliability.md` + `backlog/permission-popover-misleading-cta.md`. Run `/gsd-plan-phase 36.2`. Phase 36.1 debug-log UAT (v20 build installed 2026-06-13, commit 00132fa) runs in background — user reports in ~3-4 days.
2. ✅ macOS `1.4.0` shipped — GitHub release `macos-v1.4.0` (2026-06-09) live. iOS `ios-v2.4.0` (TestFlight / device install) still pending verification.
3. Backlog `999.1` (post-ASR / AI-cleanup robustness) captured 2026-06-10 from log sweep — promote via `/gsd-review-backlog` when ready.
4. Backlog (new, 2026-06-10): Action Button → deep-link into Dicticus Settings (setup UX) — clarify exact intent + log via `/gsd-capture`.
5. ✅ GSD tiering confirmed (2026-06-12, Phase 36.1 execution): `init.execute-phase` emitted explicit `claude-sonnet-4-6` for executor + verifier; all subagents dispatched on Sonnet. `NOTES-model-tiering.md` deleted as planned.

## Phase Overview

| Phase | Goal | Requirements | Status |
|-------|------|--------------|--------|
| 36. iOS Background Dictation | User can dictate, leave app / lock screen, and get a complete transcript — spike-first, App-Review-aware | IOSBG-01, IOSBG-02, IOSBG-03 | Re-scoped (deferred delivery) — ready to plan 02-04 |
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

### Roadmap Evolution

- Phase 36.1 inserted (2026-06-12): Cleanup Pipeline Quality — implements spike 004–007 validated findings (gate V2.1 rework, ITN number guards + NumberRevert, v20 prompt). Inserted as decimal after Phase 36 because the user wants it shipped before iOS Distribution. Blueprint: skill spike-findings-dicticus, references/cleanup-pipeline-fixes.md.

### Architecture notes for v2.5

- Phase 36: `UIBackgroundModes: audio` must be declared in iOS target Info.plist; AVAudioSession must remain active through the background task; `beginBackgroundTask` wrapper needed for post-stop transcription tail
- Phase 36: `StopDictationIntent` and `DictationLiveActivity.swift` are dormant in the codebase (removed misleading Live Activity in interim fix commit 82f2860) — re-enable path is known
- Phase 37: Background Assets framework (iOS 16+) is the preferred mechanism for the ~2.7 GB model download; ODR is the fallback; neither bundles the model in the binary
- Phase 38: `NSWorkspace.shared.frontmostApplication` (macOS) gives the active app bundle ID; pass to `CleanupPrompt` as a context hint; no new network calls
- Phase 39: Voice edit commands follow the spoken-punctuation precedent (Phase 32): deterministic pre-LLM layer in `Shared/Utilities/`; command recognition is a standalone utterance check, not inline with transcription

### Quality baselines to preserve

- 471 macOS XCTest passing, 0 failures (`testBlocksUntilCleaned` fixture repaired 2026-06-12, commit a1aab45 — no accepted failures remain)
- 482 iOS XCTest passing (8 device-only skips)
- V2.1 content-word gate (`gateContentWords`, unconditional since 36.1-05) must remain active through all Shared/ changes

### Constraints active in v2.5

- Strictly local: no audio, transcript, or app-name data sent to any server (CTXFMT-02 makes this explicit for Phase 38)
- Cross-platform parity: Shared/ changes in Phase 38 ship macOS + iOS in the same phase
- App-Review risk in Phase 36 and 37: document the spike findings and review justifications before submitting to App Store

## Session Continuity

Last session: 2026-06-13T16:18:48.281Z
Stopped at: Completed 36.3-03-PLAN.md
Next: Phase 36 verification (code review + verifier pass). Then Phase 37 (iOS Distribution).

New capability this session: sim audio injection via BlackHole (memory `reference_sim_audio_injection_blackhole`) — feed audio into the sim mic to sustain recordings; unlocks app-faithful Live-Activity + ASR verification on-sim.

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

## Performance Metrics

| Phase | Plan | Duration | Notes |
|-------|------|----------|-------|
| Phase 36-ios-background-dictation P02 | 10 | 3 tasks | 8 files |
| Phase 36-ios-background-dictation P03 | 3 | 2 tasks | 4 files |
| Phase 36.1-cleanup-pipeline-quality P01 | 5min | 3 tasks | 8 files |
| Phase 36.1-cleanup-pipeline-quality P02 | 4min | 2 tasks | 1 files |
| Phase 36.1-cleanup-pipeline-quality P03 | 15min | 3 tasks | 2 files |
| Phase 36.1-cleanup-pipeline-quality P04 | 5min | 2 tasks | 1 files |
| Phase 36.1-cleanup-pipeline-quality P05 | 15min | 3 tasks | 2 files |
| Phase 36.1-cleanup-pipeline-quality P06 | 30min | 3 tasks | 3 files |
| Phase 36.1-cleanup-pipeline-quality P07 | 11min | 2 tasks | 6 files |
| Phase 36.2-macos-local-build-signing-tcc-reliability-and-permission-los P01 | 30min | 3 tasks | 4 files |
| Phase 36.2 P03 | 25min | 3 tasks | 2 files |
| Phase 36.2-macos-local-build-signing-tcc-reliability-and-permission-los P02 | continuation-agent | 3 tasks | 3 files |
| Phase 36.3-macos-app-group-removal-storage-migration P01 | 6min | 2 tasks | 5 files |
| Phase 36.3 P02 | 12min | 2 tasks | 9 files |
| Phase 36.3-macos-app-group-removal-storage-migration P03 | 10 | 2 tasks | 2 files |

## Decisions

- [Phase ?]: Widget-autonomous Live Activity timer uses startedAt:Date + Text(timerInterval:) — app activity.update() is blocked in background audio mode
- [Phase ?]: selectMode(wantsAiCleanup:llmReady:) static seam extracts D-13/D-23/D-26 cleanup mode selection for unit testing
- [Phase ?]: Root cause of Dynamic Island no-Stop: .bottom-only expanded Stop + no lock-screen button; fix: add Stop to lock-screen body, move expanded Stop to .trailing
- [36-04]: Background stop forces mode=.plain (no GPU/LLM) — deferred to foreground. isLlmReady retry cleans+persists once LLM warms up.
- [36-04]: Second-session crash root cause: AVAudioSession not deactivated after stop → next AudioRecordingIntent fatal-asserted invariant. Fix: setActive(false) on every exit path of stopRecordingAndTranscribe().
- [Phase ?]: [36.1-04]: ArtifactStrip confined to clean() AI-mode only; try! NSRegularExpression for compile-time pattern; named trail group prevents double-punctuation
- [Phase ?]: [36.1-05]: NumberRevert ordinal strip fix — preserve trailing period so DE ordinals (vierten→4.) match inverse map
- [Phase ?]: [36.1-05]: Step 3a.5 inside AI-cleanup branch only — NumberRevert compares baseline vs LLM output, only meaningful when LLM ran
- [Phase 36.1-07]: cardinalCore checks inverse[token] not inverse[stripped]: protects DE ordinals, exposes EN cardinals at sentence end
- [Phase 36.1-07]: WR-05 In:/Out: neutralization scoped to sanitizeDictValue() (dict values only), not extended into sanitizeControlTokens() — avoids clobbering legitimate dictated text
- [Phase ?]: D-02: Guard lives inside build scripts (user interactive terminal), never Claude-run — op Touch ID only works interactively
- [Phase ?]: D-05: Root cause of Dev ID key pruning inconclusive (reproduction not attempted); build-time guard accepted as durable mitigation
- [Phase ?]: [36.2-03]: Input Monitoring routes to Privacy_ListenEvent; dead-end loop fixed
- [Phase ?]: [36.2-03]: accessibilityElement(children: .ignore) scoped to status dot/headline HStack only — restores PermissionRow VoiceOver
- [Phase ?]: Simpler and more robust than ps/pgrep for LS-registered bundle paths
- [Phase ?]: Fixes multi-copy detection which was silently broken with wrong id
- [Phase ?]: [36.3-01]: Wave 0 tests in RED state — reference DicticusDefaults/AppLocalMigrationService/vm.historyService which are created in Plans 02-04
- [Phase ?]: [36.3-01]: runForTesting() seam documented in AppLocalMigrationServiceTests — Plan 04 must expose this exact injectable signature
- [Phase ?]: testTwoBackgroundStopsAppendTwoPendingUUIDs isolates from real DB via makeForTesting; remaining .shared refs in tests are comments/identity assertions
