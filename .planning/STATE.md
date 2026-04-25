---
gsd_state_version: 1.0
milestone: v1.0
milestone_name: milestone
status: executing
stopped_at: "Phase 19.7 (macOS Hygiene) context gathered. 18 decisions across M1 hotkey re-auth (sticky banner + always-visible re-register button + AX/KeyboardShortcuts liveness check + mdfind multi-copy launch warning), M2 multi-install (dev-only scripts/install-local.sh + scripts/uninstall.sh; DMG unchanged), M3 permission status (add Input Monitoring 3rd row + correct wrong PermissionManager comment + per-pane deep-links + hide-when-all-granted), D1 app icon (assets/icon-master.png + scripts/generate-icons.sh + same glyph/shape iOS↔macOS + rebuild-first-then-debug). CONTEXT.md + DISCUSSION-LOG.md written to .planning/phases/19.7-macos-hygiene/."
last_updated: "2026-04-25T00:00:00Z"
last_activity: 2026-04-25
progress:
  total_phases: 3
  completed_phases: 2
  total_plans: 13
  completed_plans: 13
  percent: 100
---

# Project State: Dicticus

**Last Updated:** 2026-04-25
**Milestone:** v2.1 Keyboard Extension & Polish (IN PROGRESS - Phase 19.7 context gathered)

## Project Reference

See: .planning/PROJECT.md (updated 2026-04-21)

**Core value:** Press a key, speak, release — accurate text appears at your cursor instantly, fully private, no cloud dependency.
**Current focus:** v2.1 — Keyboard Extension (text at cursor without app switching)

## Current Position

Phase: 19.7 (macOS Hygiene) — context gathered 2026-04-25; ready for `/gsd-plan-phase 19.7`
Plan: 0 of TBD
Status: 18 implementation decisions captured across M1/M2/M3/D1. **Next:** `/gsd-plan-phase 19.7` (or proceed with DESIGN.md → 19.5 → 19.6 in parallel). Phase 18 iCloud Sync deferred.
Last activity: 2026-04-24 — Executed Plan 19-06 (Wave 5): Added `cleanupService: CleanupProvider?` property-injection seam to DictationViewModel; rewrote stopDictation() to route through TextProcessingService.process(text:language:mode:confidence:) with mode branching on AppGroup aiCleanupEnabled AND provider.isLoaded (D-13/D-23/D-26). Removed direct HistoryService.save from DictationViewModel to avoid double-saves (TextProcessingService Step 4 is the sole save site). Added .onChange(of: warmupService.isLlmReady) in DicticusApp to inject cleanupServiceInstance on Step 4 success, clear on failure. Flipped Wave 0 CleanupService test shims (testTimeoutFallback now runs as D-26 unloaded-fallback test; rest env-gated on DICTICUS_TEST_MODEL_PATH with clean skip messages). 4 atomic commits: d43d4a4 (RED), d994e8f (TextProcessingService routing), 4d2834e (DicticusApp injection), f5e49df (CleanupService test flip). iOS: 70 tests / 62 passed / 8 skipped / 0 failed on iPhone 17; zero Swift 6 concurrency warnings. macOS: BUILD SUCCEEDED.

Progress: [▓▓▓▓▓▓▓▓▓▓] 100% (v2.0 phases)
Progress (v2.1): [▓▓▓▓▓▓▓▓▓▓] 100% code-complete pending physical-device UAT

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
- **D-33:** `CleanupService.initializeBackend()` is invoked exactly once per app lifetime via a file-scoped `private static let backendInitToken: Void = { ... }()` on `IOSModelWarmupService`, referenced by `_ = IOSModelWarmupService.backendInitToken` inside `init(...)`. Swift's thread-safe once-only static initializer guarantees the backend init runs on first service construction and never again — no app-delegate coupling required (Phase 19 Wave 3).
- **D-34:** iOS `LlmStatus` intentionally omits `.downloading` (present on macOS `LlmStatus`). Rationale: on iOS the GGUF download is Settings-UI-initiated (D-09/D-10), not warmup-driven, so warmup never occupies the `.downloading` state. If the GGUF isn't cached when Step 4 fires, Step 4 skips and `llmStatus` stays `.idle` (Phase 19 Wave 3).
- **D-35:** `AiCleanupSection` owns an ephemeral `@StateObject IOSModelDownloadService` scoped to the Settings view lifetime — NOT the same instance that `IOSModelWarmupService.Step 4` uses. Step 4 simply reads the cached GGUF from disk on next launch. Consequence: dismissing Settings mid-download cancels the in-flight task (T-19-05-03 accepted scope); user must re-open Settings and tap Retry. Background downloads are deferred to a future wave (Phase 19 Wave 4).
- **D-36:** `appGroupBinding(_:default:)` helper is duplicated in `AiCleanupSection` instead of being shared with `SettingsView`. Rationale: plan task 2 mandated "make no other changes to `SettingsView.swift`" beyond the one-line mount. Duplication is 11 LOC, zero runtime cost; future consolidation is trivial if a third consumer appears (Phase 19 Wave 4).
- **D-37:** `DictationViewModel.cleanupService` is a plain `var` property (not `@Published`). Rationale: the provider is consumed lazily at `stopDictation()` time via `cleanupService?.isLoaded`, not by SwiftUI views — so SwiftUI invalidation on warmup transitions is unnecessary. Keeps the view-model free of `isLlmReady` observation while still picking up injection the moment `DicticusApp` writes the seam (Phase 19 Wave 5).
- **D-38:** `DictationViewModel.stopDictation()` no longer calls `HistoryService.shared.save()` directly — `TextProcessingService.process()` performs the save as Step 4 of the pipeline. This is a silent contract change from v2.0 where the view-model saved before any processing: history `text` column is now the POST-pipeline output (dictionary + ITN + Swiss ITN + optional LLM), `rawText` column remains raw ASR verbatim (Phase 19 Wave 5).
- **D-39:** `DicticusApp.onChange(of: warmupService.isLlmReady)` clears `viewModel.cleanupService` to nil when `isLlmReady` transitions to false (Step 4 failure / cancel), instead of preserving the last-known instance. Rationale: a stale `CleanupService` whose `loadModel` failed could still be referenced even though `isLoaded=false` prevents use. Explicit clear = explicit fall-back to `.plain` mode and cleaner post-failure state (Phase 19 Wave 5).

## Active Concerns / Risks

- Phase 17: Keyboard extension dictation bounce blocked by iOS 26 restrictions — Apple broke all programmatic URL-opening from keyboard extensions. Keyboard typing works; dictation pivot to Phase 17.5.
- Phase 18: iCloud Sync conflict resolution for Dictionary entries — DEFERRED, polish phases (19.5/19.6/19.7) take priority.
- iOS 26 `SpeechAnalyzer` supports German — benchmark vs Parakeet v3 before committing to model download flow long-term.
- **macOS hotkey regression (M1):** Multi-install TCC pollution — 4 Dicticus.app copies on disk produce conflicting permission entries. Blocks daily macOS dictation. Owned by Phase 19.7.
- **macOS app icon missing on latest build (D1):** Today 06:08 (23.8 MB) build shows no Finder icon. Investigate `AppIcon.appiconset` config; owned by Phase 19.7.
- **Parakeet ASR cache regression (B2):** After app relaunch, prompts to re-download Parakeet model that was already cached. Phase-14 territory; integrated into 19.5 as hotfix; needs `/gsd-debug` to scope.

## Roadmap Evolution

- Phase 17.5 inserted after Phase 17: Inline Shortcut Dictation — Auto-Return Flow (URGENT). Replaces keyboard extension bounce approach blocked by iOS 26.
- 2026-04-25: Phase 19 UAT split into 4 follow-on tracks: DESIGN.md (next, prerequisite for 19.6), 19.5 (CH-determinism + B2 hotfix), 19.6 (iOS UX), 19.7 (macOS hygiene). Findings inventory: `.planning/phases/19-ai-cleanup-ios/19-UAT-FINDINGS.md`. Phase 18 iCloud Sync deferred.

## Session Continuity

Last session: 2026-04-24T19:44:28Z
Stopped at: Completed Plan 19-05 (Wave 4 — Settings UI: AiCleanupSection + inline download panel + RAM-gated explainer + Swiss German toggle). 2 atomic commits (8156489 create, 89babf3 mount). SettingsToggleTests 4/4 green. iOS: 68 tests / 59 passed / 9 skipped / 0 failed on iPhone 17; zero Swift 6 concurrency warnings. macOS: BUILD SUCCEEDED.
Resume file: Run `/gsd-execute-phase 19` to execute Plan 19-06 (Wave 5 — DictationViewModel pipeline integration: inject cleanupServiceInstance into TextProcessingService when aiCleanupEnabled AppGroup key is ON)
