---
phase: 02-asr-pipeline
plan: "01"
subsystem: asr-pipeline
tags: [whisperkit, transcription, vad, swift6, tdd]
dependency_graph:
  requires:
    - 01-03-SUMMARY.md  # ModelWarmupService providing whisperKitInstance
  provides:
    - TranscriptionService  # Core ASR pipeline service
    - DicticusTranscriptionResult  # App-level result value type
  affects:
    - Phase 03 (hotkey wiring will call startRecording/stopRecordingAndTranscribe)
tech_stack:
  added: []
  patterns:
    - nonisolated(unsafe) for Swift 6 compliance with WhisperKit nonisolated async methods
    - #if DEBUG extension for test helpers without protocol overhead
    - XCTSkipUnless for model-dependent tests that skip gracefully in CI
key_files:
  created:
    - Dicticus/Dicticus/Models/TranscriptionResult.swift
    - Dicticus/Dicticus/Services/TranscriptionService.swift
    - Dicticus/DicticusTests/TranscriptionResultTests.swift
    - Dicticus/DicticusTests/TranscriptionServiceTests.swift
  modified:
    - Dicticus/Dicticus.xcodeproj/project.pbxproj  # xcodegen added Models group
decisions:
  - "nonisolated(unsafe) on whisperKit property to satisfy Swift 6 strict concurrency — WhisperKit.transcribe() is nonisolated but the instance is @MainActor-isolated"
  - "#if DEBUG static test helpers on TranscriptionService instead of protocol abstraction — avoids architectural overhead for Phase 2 scope"
  - "XCTSkipUnless pattern for model-dependent tests — allows CI to run without 954MB model download"
metrics:
  duration: "~30 minutes"
  completed: "2026-04-16"
  tasks_completed: 1
  files_created: 4
  files_modified: 1
---

# Phase 2 Plan 1: TranscriptionService and DicticusTranscriptionResult Summary

**One-liner:** WhisperKit-backed TranscriptionService with three-layer VAD (0.3s guard + energy pre-filter + VAD chunking), greedy decoding for sub-3s latency, and post-hoc de/en language restriction via DicticusTranscriptionResult value type.

## What Was Built

### DicticusTranscriptionResult (`Models/TranscriptionResult.swift`)
A `Sendable` value-type struct that holds the output of a transcription cycle:
- `text: String` — trimmed transcribed speech
- `language: String` — restricted to "de" or "en"
- `confidence: Float` — derived from `1.0 - noSpeechProb`

Copying WhisperKit's `TranscriptionResult` class values into this struct immediately after transcription avoids reference-type pitfalls (WhisperKit v0.15.0 changed TranscriptionResult from struct to open class).

### TranscriptionService (`Services/TranscriptionService.swift`)
`@MainActor ObservableObject` implementing the full audio-to-text pipeline:

- **State machine:** `.idle → .recording → .transcribing → .idle`
- **`startRecording()`:** delegates to `whisperKit.audioProcessor.startRecordingLive()` — satisfies D-01/D-02/D-03 via WhisperKit internals without manual AVAudioEngine code
- **`stopRecordingAndTranscribe()`:** three-layer VAD then Whisper inference
- **`restrictLanguage(_:)`:** post-hoc filter to {de, en}
- **`TranscriptionError`:** `.tooShort`, `.silenceOnly`, `.noResult`, `.modelNotReady`

Three-layer VAD (Pitfall 1 defense):
1. Minimum duration guard: rejects clips < 0.3s (D-06)
2. Energy pre-filter: `AudioProcessor.isVoiceDetected()` with configurable threshold (D-05, D-07)
3. VAD chunking: `chunkingStrategy: .vad` in DecodingOptions (D-04)

Decoding: `temperature: 0.0` (greedy), `withoutTimestamps: true`, `suppressBlank: true`, `noSpeechThreshold: 0.6`.

### Unit Tests
- `TranscriptionResultTests` — 7 tests covering struct initialization, language codes, confidence bounds, text content
- `TranscriptionServiceTests` — 12 tests: 6 pure-logic (language restriction, error enum), 6 model-dependent (skip via XCTSkipUnless when WhisperKit model not cached)

**Test results:** 55 total, 0 failures, 6 skipped (model-dependent, expected in CI)

## Decisions Made

| Decision | Rationale |
|----------|-----------|
| `nonisolated(unsafe)` on `whisperKit` property | Swift 6 strict concurrency: `WhisperKit.transcribe()` is nonisolated but the instance is `@MainActor`-isolated by default. This is safe because `transcribe()` is only called after `stopRecording()` completes and audio samples are copied to a local value. |
| `#if DEBUG` static test helpers | Avoids protocol abstraction overhead for Phase 2. `testRestrictLanguage()`, `isWhisperKitAvailable()`, `makeForTesting()` exist only in debug builds. |
| `XCTSkipUnless` for model-dependent tests | Tests that require a live WhisperKit instance (state machine, configuration) skip gracefully when the 954MB model is not cached — correct behavior for CI environments. |
| `restrictLanguage` as internal func (not private) | Allows test target to call it directly via `@testable import`, enabling pure-logic testing without a WhisperKit instance. |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Swift 6 concurrency error: WhisperKit.transcribe() sending risk**
- **Found during:** Task 1, GREEN phase build
- **Issue:** `whisperKit.transcribe()` is a nonisolated async method, but `self.whisperKit` is `@MainActor`-isolated. Swift 6 strict concurrency rejects sending a main actor-isolated value to a nonisolated context.
- **Fix:** Changed `private let whisperKit: WhisperKit` to `nonisolated(unsafe) private let whisperKit: WhisperKit`. Safety: the instance is owned by ModelWarmupService and its lifecycle is stable.
- **Files modified:** `Dicticus/Dicticus/Services/TranscriptionService.swift`
- **Commit:** 77ef7eb

**2. [Rule 1 - Bug] Test helper `makeServiceOrSkip()` missing `async`**
- **Found during:** Task 1, test run after GREEN phase
- **Issue:** `makeServiceOrSkip()` called `TranscriptionService.makeForTesting()` which is `async throws`, but the helper was declared as `throws` only. Swift compiler error at build time.
- **Fix:** Changed `makeServiceOrSkip()` to `async throws` and added `await` at all 6 call sites.
- **Files modified:** `Dicticus/DicticusTests/TranscriptionServiceTests.swift`
- **Commit:** 77ef7eb (same commit, same build cycle)

**3. [Rule 1 - Bug] Non-optional `result.language` with nil-coalescing operator**
- **Found during:** Task 1, GREEN phase build (warning)
- **Issue:** `result.language ?? "en"` — WhisperKit 0.18.0 has `language: String` (non-optional), so `??` was unreachable and triggered a compiler warning.
- **Fix:** Removed nil-coalescing: `restrictLanguage(result.language)`.
- **Files modified:** `Dicticus/Dicticus/Services/TranscriptionService.swift`
- **Commit:** 77ef7eb

## Known Stubs

None. `TranscriptionService` wires directly to WhisperKit's AudioProcessor and transcription API. `DicticusTranscriptionResult` derives confidence from actual `noSpeechProb` values. No hardcoded placeholders in the pipeline.

## Threat Flags

No new trust boundaries introduced beyond those in the plan's threat model. `TranscriptionService` contains no `import Network`, `URLSession`, or `URLRequest`. The `#if DEBUG` test helpers are excluded from Release builds and do not affect the production security surface.

## Self-Check

Checking files and commits exist:

- `/Users/mowehr/code/dicticus/Dicticus/Dicticus/Models/TranscriptionResult.swift` — created
- `/Users/mowehr/code/dicticus/Dicticus/Dicticus/Services/TranscriptionService.swift` — created
- `/Users/mowehr/code/dicticus/Dicticus/DicticusTests/TranscriptionResultTests.swift` — created
- `/Users/mowehr/code/dicticus/Dicticus/DicticusTests/TranscriptionServiceTests.swift` — created
- Commit `77ef7eb` — feat(02-01): implement TranscriptionService and DicticusTranscriptionResult
