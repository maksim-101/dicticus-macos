---
gsd_state_version: 1.0
milestone: v1.0
milestone_name: milestone
status: executing
stopped_at: "Completed Plan 19-03 (Wave 2 — iOS downloader + D-03 device gate). 2 atomic task commits (45bae61 Task 1 IOSModelDownloadService; 5be43d2 Task 2 requiredPhysicalMemoryBytes + isAiCleanupSupported). iOS: 59 tests / 9 skipped / 0 failures on iPhone 17. macOS: BUILD SUCCEEDED (ad-hoc). Dropped Wave 0 skipped count by 5 (3 download tests + 2 device tests flipped to green)."
last_updated: "2026-04-24T19:15:29.770Z"
last_activity: 2026-04-24
progress:
  total_phases: 3
  completed_phases: 2
  total_plans: 13
  completed_plans: 11
  percent: 85
---

# Project State: Dicticus

**Last Updated:** 2026-04-24
**Milestone:** v2.1 Keyboard Extension & Polish (IN PROGRESS - Phase 19 discussed)

## Project Reference

See: .planning/PROJECT.md (updated 2026-04-21)

**Core value:** Press a key, speak, release — accurate text appears at your cursor instantly, fully private, no cloud dependency.
**Current focus:** v2.1 — Keyboard Extension (text at cursor without app switching)

## Current Position

Phase: 19 (AI Cleanup iOS)
Plan: 4 of 6 (Wave 2 complete — iOS downloader + D-03 device gate)
Status: Wave 3 ready — SettingsView toggles + inline download UI + Step 4 warmup wiring
Last activity: 2026-04-24 — Executed Plan 19-03 (Wave 2): Landed IOSModelDownloadService (URLSession delegate, progress/pause-resume/backup-exclusion) and D-03 device RAM gate (requiredPhysicalMemoryBytes = 5 GiB; isAiCleanupSupported: Bool) on IOSModelWarmupService. 2 atomic task commits; both iOS + macOS targets green; Wave 0 download + device tests flipped from 5 skipped → 5 green (iOS: 59 / 9 skipped / 0 failures).

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
- **D-31:** `@MainActor` classes expose their static helpers as `nonisolated` whenever those helpers need to be called synchronously from `URLSession` delegate callbacks (e.g. `IOSModelDownloadService.modelPath()` is called by the non-main delegate queue to move the file before the temp URL is invalidated). Instance state remains `@MainActor`-isolated; `@Published` mutations still hop via `Task { @MainActor in … }` (Phase 19 Wave 2).
- **D-32:** D-03 RAM threshold is exactly `5 * 1024 * 1024 * 1024` bytes (5 GiB) — authoritative constant `IOSModelWarmupService.requiredPhysicalMemoryBytes`. `isAiCleanupSupported` reads `ProcessInfo.processInfo.physicalMemory` against this at call time, so there is no cached gate to invalidate when moving between devices / simulators (Phase 19 Wave 2).

## Active Concerns / Risks

- Phase 17: Keyboard extension dictation bounce blocked by iOS 26 restrictions — Apple broke all programmatic URL-opening from keyboard extensions. Keyboard typing works; dictation pivot to Phase 17.5.
- Phase 18: iCloud Sync conflict resolution for Dictionary entries.
- iOS 26 `SpeechAnalyzer` supports German — benchmark vs Parakeet v3 before committing to model download flow long-term.

## Roadmap Evolution

- Phase 17.5 inserted after Phase 17: Inline Shortcut Dictation — Auto-Return Flow (URGENT). Replaces keyboard extension bounce approach blocked by iOS 26.

## Session Continuity

Last session: 2026-04-24T19:20:00Z
Stopped at: Completed Plan 19-03 (Wave 2 — iOS downloader + D-03 device gate). 2 atomic task commits (45bae61 Task 1 IOSModelDownloadService; 5be43d2 Task 2 requiredPhysicalMemoryBytes + isAiCleanupSupported). iOS: 59 tests / 9 skipped / 0 failures on iPhone 17. macOS: BUILD SUCCEEDED. Dropped Wave 0 skipped count by 5 (3 download tests + 2 device tests flipped to green).
Resume file: Run `/gsd-execute-phase 19` to execute Plan 19-04 (Wave 3 — SettingsView toggles + inline download UI + Step 4 warmup wiring)
