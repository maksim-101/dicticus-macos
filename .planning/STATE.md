---
gsd_state_version: 1.0
milestone: v1.0
milestone_name: Keyboard Extension & Polish
status: executing
stopped_at: Phase 20.08 SHIPPED — Plan 05 gap closure ACCEPTED on macOS Release UAT iter 3
last_updated: "2026-05-01T12:30:00.000Z"
last_activity: 2026-05-01 -- Phase 20.08 Plan 05 gap closure shipped across 3 macOS UAT iterations (drop priming-trap directive, add naja filler + 6th past-tense exemplar, reorder so currency-preservation exemplar is recency-anchor). User-accepted with sentence-stitching note. R-G15-01 closed.
progress:
  total_phases: 9
  completed_phases: 7
  total_plans: 35
  completed_plans: 33
  percent: 94
---

# Project State: Dicticus

**Last Updated:** 2026-05-01
**Milestone:** v2.1 Keyboard Extension & Polish (IN PROGRESS — Phase 20 + 20.06 + 20.08 SHIPPED)

## Project Reference

See: .planning/PROJECT.md (updated 2026-04-21)

**Core value:** Press a key, speak, release — accurate text appears at your cursor instantly, fully private, no cloud dependency.
**Current focus:** Phase 20.08 SHIPPED — next: DESIGN.md → Phase 19.6 (iOS UX) or Phase 20.07 (rules-only ASR-mishearing recovery).

## Current Position

Phase: 20.08 (llm-swiss-ification-suppression) — SHIPPED 2026-05-01; 5/5 plans shipped (Plan 05 gap closure ACCEPTED on macOS UAT iter 3).
Plan: 5 of 5 — Plan 05 ACCEPTED with sentence-stitching note (see `20.08-05-UAT-RESULTS.md`).
Plans: 20.08-01, 02, 03 shipped; 20.08-04 Tasks A+B shipped (variant g15 prompt restructure); 20.08-05 gap closure shipped across 3 macOS UAT iterations:
  - **iter 1** (`1e08943`): dropped §3 priming-trap directive, kept 5th currency exemplar — closed R-G15-01, surfaced 3 follow-ons (tense, mishear, naja filler).
  - **iter 2**: added `naja` to FillerWordRemover.germanFillers + 6th past-tense ORIGINAL/KORRIGIERT exemplar — closed naja + tense, REGRESSED R-G15-01 (verb-rewrite stole the recency-anchor slot from currency exemplar).
  - **iter 3** (current branch HEAD): reordered so currency-preservation exemplar is again last, tense exemplar one slot earlier — added R6 order-lock test `testVariantG15CurrencyExemplarIsLastExemplar`. macOS UAT ACCEPTED.
Wave-B sibling work shipped: sampler reorder (`78738a4`), SwissNumberFormatter Bridge 1.5 (`17005f3`), apostrophe-strike (`435004b`), spike pipeline mirror + anglicism differentiation (`8daf91a`).
UAT verdict 2026-05-01 final: macOS Release ACCEPTED. R-G15-01 closed (`102.50 Franken` digit-exact). Sentence-stitching residue (Gemma occasionally merges adjacent ASR clauses with comma) below user acceptance bar — carried forward as known limitation. iOS verification deferred to next iOS UAT cycle (shares `Shared/Models/CleanupPrompt.swift`).
Builds verified: macOS Release green (CleanupPromptTests 21/21 pass). Fn hotkey combo (push-to-talk on macOS) confirmed functional during UAT.

Next: DESIGN.md → Phase 19.6 (iOS UX) per ROADMAP, or Phase 20.07 (rules-only ASR-mishearing recovery).

Resume file: .planning/phases/20.08-llm-swiss-ification-suppression/20.08-05-UAT-RESULTS.md (final UAT iteration log + acceptance) + 20.08-VARIANT-G-RATIONALE.md (canonical brief).
Last activity: 2026-05-01 -- Phase 20.08 Plan 05 gap closure shipped across 3 UAT iterations; macOS Release ACCEPTED; STATE + ROADMAP updated.

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

Last session: 2026-04-30T22:00:00.000Z
Stopped at: Phase 20.08 planning artifacts reconciled with variant (g15) reality (post-Plan-03 ad-hoc work captured in VARIANT-G-RATIONALE §10)
Resume file: `.planning/phases/20.08-llm-swiss-ification-suppression/20.08-04-PLAN.md` — implement Plan 04 (variant g15 swap + two-layer conditional + R6 tests + UAT replay)
