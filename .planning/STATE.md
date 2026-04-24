# Project State: Dicticus

**Last Updated:** 2026-04-24
**Milestone:** v2.1 Keyboard Extension & Polish (IN PROGRESS - Phase 19 discussed)

## Project Reference

See: .planning/PROJECT.md (updated 2026-04-21)

**Core value:** Press a key, speak, release — accurate text appears at your cursor instantly, fully private, no cloud dependency.
**Current focus:** v2.1 — Keyboard Extension (text at cursor without app switching)

## Current Position

Phase: 19 (AI Cleanup iOS)
Plan: 1 of 6 (Wave 0 complete — test scaffolding)
Status: Wave 1 ready — Swiss ITN + CleanupService extraction can begin
Last activity: 2026-04-24 — Executed Plan 19-01 (Wave 0): 9 XCTest scaffold files created covering all 14 Req→Test rows in 19-VALIDATION.md; full DicticusTests suite green (58 tests, 18 skipped pending Waves 1/2, 0 failures) on iPhone 17 simulator.

Progress: [▓▓▓▓▓▓▓▓▓▓] 100% (v2.0 phases)
Progress (v2.1): [▓▓▓▓▓▓▓▓░░] 80%

## Completed Milestones

- **v1.0 MVP** — Phases 1-5 — SHIPPED 2026-04-18
- **v1.1 Cleanup Intelligence & Distribution** — Phases 6-11 — SHIPPED 2026-04-21 (v1.1.1)
- **v2.0 iOS App — Shortcut Dictation** — Phases 12-16 — SHIPPED 2026-04-22
- **v2.1 Keyboard Extension & Polish** — Phase 17 — COMPLETED 2026-04-23

## Key Decisions

### Technical
- **D-15:** Used `NavigationSplitView` with adaptive logic for iPad sidebar support (Phase 16).
- **D-16:** Integrated `GRDB` for shared transcription history between app and future extensions (Phase 15).
- **D-17:** Implemented "Whats New" flow to highlight v2.0 features to upgrading users (Phase 16).
- **D-18:** Consistently clear `kbSource` and set `kbResultReady` in `DictationViewModel` regardless of success/failure to ensure reliable state and stop keyboard polling (Phase 17).
- **D-19:** Used `Timer`-based polling in `KeyboardViewController` (0.5s interval) as planned for simplicity and reliability (Phase 17).
- **D-20:** Switched `StopDictationIntent` to `LiveActivityIntent` for better interactive support in Dynamic Island (Phase 17).
- **D-21:** isShortcutLaunch flag read synchronously before async Task in checkPendingIntent to prevent race conditions (Phase 17.5).
- **D-22:** Flag reset in stopDictation ensures manual dictation after shortcut does not inherit shortcut mode (Phase 17.5).
- **D-23:** DicticusHostBridge uses @MainActor with nonisolated static darwinCallback and Unmanaged pointer pattern from KeyVox (Phase 17.5).
- **D-24:** publishTranscriptionReady writes text to UserDefaults BEFORE posting Darwin notification to prevent race condition (Phase 17.5).
- **D-25:** Heartbeat timer runs continuously so keyboard can always check isSessionWarm() between dictation sessions (Phase 17.5).
- **D-26:** DicticusIPCBridge imports only Foundation for dual-target compilation in app and extension (Phase 17.5).
- **D-27:** Responder-chain URL opener uses legacy openURL: selector for keyboard extension compatibility (Phase 17.5).
- **D-28:** Smart text insertion lowercases first char mid-sentence but preserves acronyms via two-consecutive-uppercase detection (Phase 17.5).
- **D-29:** Warm-start grace period of 0.5s before falling back to URL launch matches KeyVox default (Phase 17.5).
- **D-30:** Long-press gesture (0.5s) on mic button cancels active dictation as escape hatch (Phase 17.5).

## Active Concerns / Risks
- Phase 17: Keyboard extension dictation bounce blocked by iOS 26 restrictions — Apple broke all programmatic URL-opening from keyboard extensions. Keyboard typing works; dictation pivot to Phase 17.5.
- Phase 18: iCloud Sync conflict resolution for Dictionary entries.
- iOS 26 `SpeechAnalyzer` supports German — benchmark vs Parakeet v3 before committing to model download flow long-term.

## Roadmap Evolution
- Phase 17.5 inserted after Phase 17: Inline Shortcut Dictation — Auto-Return Flow (URGENT). Replaces keyboard extension bounce approach blocked by iOS 26.

## Session Continuity

Last session: 2026-04-24
Stopped at: Completed Plan 19-01 (Wave 0 test scaffolding) — 9 files, 3 atomic commits, full DicticusTests suite green on iPhone 17 sim
Resume file: Run `/gsd-execute-phase 19` to execute Plan 19-02 (Wave 1 — Swiss ITN + CleanupService extraction)
