---
gsd_state_version: 1.0
milestone: v1.0
milestone_name: Keyboard Extension & Polish
status: executing
stopped_at: Phase 20 code-complete; UAT 2026-04-27 surfaced behavioural regressions — LLM translates High German → Swiss German dialect when Swiss toggle ON (HELVETISMS prompt too broad), wrong-direction currency flip (Franken→Euro on iOS, "Euro Euro" duplication on macOS), iOS long-press shows path/link instead of text, iOS truncation discoverability gap (HistoryDetailView shipped but tap not surfaced). 4 findings + 1 minor logged in 20-UAT-FINDINGS.md. Phase 20.06 needed to fix behaviourally (artifact-level Phase 20 verification still 12/12 GREEN).
last_updated: "2026-04-27T00:00:00.000Z"
last_activity: 2026-04-27 -- Phase 20 UAT complete; Phase 20.06 plan needed
progress:
  total_phases: 6
  completed_phases: 5
  total_plans: 27
  completed_plans: 27
  percent: 100
---

# Project State: Dicticus

**Last Updated:** 2026-04-25
**Milestone:** v2.1 Keyboard Extension & Polish (IN PROGRESS - Phase 19.7 context gathered)

## Project Reference

See: .planning/PROJECT.md (updated 2026-04-21)

**Core value:** Press a key, speak, release — accurate text appears at your cursor instantly, fully private, no cloud dependency.
**Current focus:** Phase 20 — ai-cleanup-demotion-uat-visibility

## Current Position

Phase: 20 (ai-cleanup-demotion-uat-visibility) — CODE COMPLETE; UAT REGRESSIONS LOGGED
Plan: 5 of 5 plans shipped
Status: Phase 20.06 needed (behavioural hotfix). UAT findings: .planning/phases/20-ai-cleanup-demotion-uat-visibility/20-UAT-FINDINGS.md
Resume: `/gsd-plan-phase 20.06` — see UAT-FINDINGS.md for scope (4 findings: HELVETISMS dialect preservation, currency idempotency, iOS long-press gesture, iOS chevron discoverability)

UAT hotfix commits:
  • 6268f11 — fix(19.5): strip leaked Gemma chat-template fragments
  • e8c665e — fix(19.5): post-LLM Swiss formatter hardening (Decimal guards + cross-token bridges)

Next: `/gsd-plan-phase 20` — AI Cleanup Demotion + UAT Visibility (rules-first deterministic, optional LLM polish, raw/polished toggle, iOS history detail view, HistoryService graceful degradation).

Resume file: ROADMAP.md → Phase 20 (to be planned)
Last activity: 2026-04-26 -- Phase 20 execution started

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
- ~~**macOS hotkey regression (M1):**~~ Resolved by Phase 19.7 — Repair banner + Re-register button + multi-copy probe + install-local.sh consolidator. (Long-term fix: ship as DMG with Sparkle in v2.2.)
- ~~**macOS app icon missing on latest build (D1):**~~ Resolved by Phase 19.7 — canonical `assets/icon-master.png` + `scripts/generate-icons.sh` regenerated 10 macOS PNGs; user UAT confirmed Finder shows icon 2026-04-25.
- **Parakeet ASR cache regression (B2):** After app relaunch, prompts to re-download Parakeet model that was already cached. Phase-14 territory; integrated into 19.5 as hotfix; needs `/gsd-debug` to scope.

## Roadmap Evolution

- Phase 17.5 inserted after Phase 17: Inline Shortcut Dictation — Auto-Return Flow (URGENT). Replaces keyboard extension bounce approach blocked by iOS 26.
- 2026-04-25: Phase 19 UAT split into 4 follow-on tracks: DESIGN.md (next, prerequisite for 19.6), 19.5 (CH-determinism + B2 hotfix), 19.6 (iOS UX), 19.7 (macOS hygiene). Findings inventory: `.planning/phases/19-ai-cleanup-ios/19-UAT-FINDINGS.md`. Phase 18 iCloud Sync deferred.

## Session Continuity

Last session: 2026-04-25T07:30:00Z
Stopped at: Phase 19.7 (macOS Hygiene) complete — 4/4 plans shipped (15 atomic commits + 1 hotfix), verifier 22/22 must-haves passed, code review advisory (0 critical / 5 warning / 6 info), D1 Finder UAT user-approved 2026-04-25. M1/M2/M3/D1 all resolved. macOS Debug build SUCCEEDED.
Resume file: Run `/gsd-discuss-phase` for next phase candidate (DESIGN.md generation, 19.5 CH-determinism, or 19.6 iOS UX)
