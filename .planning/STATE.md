---
gsd_state_version: 1.0
milestone: v1.0
milestone_name: milestone
status: verifying
stopped_at: Phase 3 context gathered
last_updated: "2026-04-17T06:58:03.748Z"
last_activity: 2026-04-16
progress:
  total_phases: 6
  completed_phases: 3
  total_plans: 7
  completed_plans: 7
  percent: 100
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-04-14)

**Core value:** Press a key, speak, release -- accurate text appears at your cursor instantly, fully private, no cloud dependency.
**Current focus:** Phase 02.1 — asr-engine-swap-whisperkit-to-fluidaudio-parakeet-tdt-v3

## Current Position

Phase: 3
Plan: Not started
Status: Phase complete — ready for verification
Last activity: 2026-04-16

Progress: [░░░░░░░░░░] 0%

## Performance Metrics

**Velocity:**

- Total plans completed: 7
- Average duration: -
- Total execution time: 0 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 01 | 3 | - | - |
| 02 | 2 | - | - |
| 02.1 | 2 | - | - |

**Recent Trend:**

- Last 5 plans: -
- Trend: -

*Updated after each plan completion*
| Phase 01-foundation-app-shell P01 | 3 | 2 tasks | 11 files |
| Phase 01-foundation-app-shell P02 | 5 minutes | 2 tasks | 9 files |
| Phase 01-foundation-app-shell P03 | 2 minutes | 2 tasks | 6 files |
| Phase 02-asr-pipeline P01 | 30 minutes | 1 tasks | 5 files |
| Phase 02-asr-pipeline P02 | 2 minutes | 2 tasks | 3 files |
| Phase 02.1-asr-engine-swap P01 | 3 minutes | 2 tasks | 4 files |
| Phase 02.1-asr-engine-swap P02 | 4 minutes | 2 tasks | 4 files |

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- [Roadmap]: Parakeet V3 disqualified (English-only); using Whisper large-v3-turbo via whisper.cpp
- [Roadmap]: LLM cleanup via llama.cpp with Gemma 3 1B (not MLX, for future Windows portability)
- [Roadmap]: Unsandboxed distribution (DMG) -- App Store sandbox blocks global hotkeys and text injection
- [Roadmap]: VAD mandatory in ASR pipeline to prevent Whisper silence hallucinations
- [Roadmap]: WhisperKit for macOS ASR with Core ML warm-up at launch
- [Phase 01-01]: xcodegen used to generate reproducible project.pbxproj from project.yml declarative spec
- [Phase 01-01]: menuBarExtraStyle(.window) chosen for dropdown to support future custom UI components in Plans 02/03
- [Phase 01-02]: @preconcurrency import ApplicationServices used for Swift 6 concurrency compliance with kAXTrustedCheckOptionPrompt C global
- [Phase 01-02]: startPolling() called from MenuBarView.onAppear so timer lifecycle is tied to dropdown visibility
- [Phase 01-03]: warmup() called in MenuBarView.onAppear (not App.init) — consistent with Plan 02 permission polling pattern, both tied to dropdown lifetime
- [Phase 01-03]: WhisperKitConfig() auto-recommendation for Phase 1; Phase 2 will pin large-v3-turbo after ASR pipeline integration
- [Phase 02-asr-pipeline]: nonisolated(unsafe) on TranscriptionService.whisperKit property for Swift 6 concurrency compliance with WhisperKit.transcribe() nonisolated async method
- [Phase 02-asr-pipeline]: #if DEBUG static test helpers on TranscriptionService instead of protocol abstraction — avoids overhead for Phase 2 scope
- [Phase 02-asr-pipeline]: XCTSkipUnless pattern for WhisperKit model-dependent tests — 6 tests skip gracefully in CI without 954MB model download
- [Phase 02-asr-pipeline]: WhisperKitConfig(model:'large-v3-turbo') pins model explicitly — auto-select replaced with deterministic model choice (D-08, D-09)
- [Phase 02-asr-pipeline]: TranscriptionService wired via @State + onChange(of:warmupService.isReady) — Phase 3 hotkey wiring can immediately consume the service (D-10, D-13)
- [Phase 02.1-asr-engine-swap]: FluidAudio 0.13.6 replaces WhisperKit 0.18.0 as sole ASR SPM dependency in project.yml
- [Phase 02.1-asr-engine-swap]: ModelWarmupService initializes AsrManager + VadManager via FluidAudio; whisperKitInstance renamed to asrManagerInstance, vadManagerInstance added
- [Phase 02.1-asr-engine-swap]: AVAudioConverter chosen as primary resampler with linear interpolation fallback
- [Phase 02.1-asr-engine-swap]: silenceThreshold default changed from 0.3 (energy-based) to 0.5 (Silero VAD probability)
- [Phase 02.1-asr-engine-swap]: NLLanguageRecognizer constrained to [.german, .english] for post-hoc language detection since Parakeet TDT v3 outputs no language code
- [Phase 02.1-asr-engine-swap]: nonisolated(unsafe) removed from TranscriptionService — not needed for actor-based AsrManager

### Pending Todos

None yet.

### Roadmap Evolution

- Phase 02.1 inserted after Phase 2: ASR Engine Swap: WhisperKit to FluidAudio + Parakeet TDT v3 (URGENT)

### Blockers/Concerns

None yet.

## Session Continuity

Last session: 2026-04-17T06:58:03.745Z
Stopped at: Phase 3 context gathered
Resume file: .planning/phases/03-system-wide-dictation/03-CONTEXT.md
