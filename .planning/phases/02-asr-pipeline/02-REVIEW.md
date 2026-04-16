---
phase: 02-asr-pipeline
reviewed: 2026-04-16T04:02:53Z
depth: standard
files_reviewed: 6
files_reviewed_list:
  - Dicticus/Dicticus/DicticusApp.swift
  - Dicticus/Dicticus/Models/TranscriptionResult.swift
  - Dicticus/Dicticus/Services/ModelWarmupService.swift
  - Dicticus/Dicticus/Services/TranscriptionService.swift
  - Dicticus/DicticusTests/TranscriptionResultTests.swift
  - Dicticus/DicticusTests/TranscriptionServiceTests.swift
findings:
  critical: 0
  warning: 5
  info: 4
  total: 9
status: issues_found
---

# Phase 02: Code Review Report

**Reviewed:** 2026-04-16T04:02:53Z
**Depth:** standard
**Files Reviewed:** 6
**Status:** issues_found

## Summary

Reviewed the Phase 02 ASR pipeline implementation: app entry point, transcription result model, warm-up service, transcription service, and their unit tests. The overall structure is solid — the WhisperKit integration pattern is sound, the three-layer VAD defense is well-designed, and the concurrency rationale is documented. No critical security issues found.

Five warnings require attention before Phase 3 hotkey wiring begins, because Phase 3 will surface the state-machine bugs under real usage. The most actionable issues are: `stopRecordingAndTranscribe()` leaving `state` stuck as `.transcribing` on any WhisperKit throw, the missing guard on `stopRecordingAndTranscribe()` for the not-recording case, and the silent `return` in `startRecording()` that gives callers no feedback. The no-timeout warmup and duplicate logic between `restrictLanguage` and `testRestrictLanguage` are lower priority but should be addressed.

---

## Warnings

### WR-01: `state` permanently stuck as `.transcribing` when `whisperKit.transcribe()` throws

**File:** `Dicticus/Dicticus/Services/TranscriptionService.swift:112,158`

**Issue:** `state` is set to `.transcribing` at line 112. The only path that resets it to `.idle` is the happy-path (line 181) or the explicit early-exit guards (lines 120–135). If `whisperKit.transcribe(audioArray:decodeOptions:)` throws at line 158 — e.g., due to an internal WhisperKit error, a CoreML fault, or resource exhaustion — the error propagates to the caller but `state` is never reset. The service is left permanently in `.transcribing` state and all subsequent `startRecording()` calls silently no-op (line 84 guard), making the app completely unresponsive until restarted.

**Fix:**
```swift
func stopRecordingAndTranscribe() async throws -> DicticusTranscriptionResult {
    whisperKit.audioProcessor.stopRecording()
    state = .transcribing

    // Ensure state is always reset, even on throw
    defer { if state == .transcribing { state = .idle } }

    let audioSamples = Array(whisperKit.audioProcessor.audioSamples)
    // ... rest of the method unchanged ...
}
```

Alternatively, wrap the transcribe call in a do/catch that resets state before re-throwing:
```swift
do {
    let results = try await whisperKit.transcribe(audioArray: audioSamples, decodeOptions: options)
    // ... process results ...
} catch {
    state = .idle
    throw error
}
```

---

### WR-02: `stopRecordingAndTranscribe()` not guarded against being called when not recording

**File:** `Dicticus/Dicticus/Services/TranscriptionService.swift:109`

**Issue:** The method calls `whisperKit.audioProcessor.stopRecording()` unconditionally regardless of `state`. If called while `state == .idle` (e.g., a hotkey-release event arrives without a preceding hotkey-press, or during a test setup error), the AudioProcessor is told to stop a recording that was never started. It then reads whatever stale `audioSamples` remain from a prior session and proceeds into VAD and transcription. This can produce a spurious transcription from old audio data.

**Fix:** Add a state guard at the top of the method:
```swift
func stopRecordingAndTranscribe() async throws -> DicticusTranscriptionResult {
    guard state == .recording else {
        throw TranscriptionError.modelNotReady  // or add a new .notRecording case
    }
    whisperKit.audioProcessor.stopRecording()
    state = .transcribing
    // ...
}
```
Consider adding a `.notRecording` case to `TranscriptionError` so callers can distinguish this from model-not-ready.

---

### WR-03: `startRecording()` silently returns without signaling the caller it was ignored

**File:** `Dicticus/Dicticus/Services/TranscriptionService.swift:84`

**Issue:** `guard state == .idle else { return }` silently drops the call when the service is busy. Phase 3 hotkey handlers calling `startRecording()` will receive no feedback — no error thrown, no published state change — that the call was ignored. A rapid double-press of the hotkey could leave the user thinking dictation started when it did not.

**Fix:**
```swift
func startRecording() throws {
    guard state == .idle else {
        throw TranscriptionError.modelNotReady  // or a new .busy error case
    }
    // ...
}
```
Add a `.busy` case to `TranscriptionError` to communicate "already recording or transcribing."

---

### WR-04: `stopRecordingAndTranscribe()` passes `durationSeconds` as `nextBufferInSeconds` to `isVoiceDetected`

**File:** `Dicticus/Dicticus/Services/TranscriptionService.swift:128`

**Issue:** `AudioProcessor.isVoiceDetected(in:nextBufferInSeconds:silenceThreshold:)` takes `nextBufferInSeconds` — the parameter name implies the size of the *upcoming* buffer chunk, not the total recording duration. The implementation passes the full recording duration (e.g., 5.0 seconds for a 5-second dictation). Depending on WhisperKit's internal implementation, this may inflate the energy window used for VAD and cause the silence check to behave incorrectly — potentially never detecting silence for long recordings, or always detecting voice regardless of energy levels.

**Fix:** Verify the WhisperKit source for `AudioProcessor.isVoiceDetected` to determine the expected semantics of `nextBufferInSeconds`. If it expects a chunk duration (e.g., 1.0 second), pass a fixed chunk size constant instead:
```swift
// Use a fixed chunk window matching WhisperKit's internal buffer size
let vadWindowSeconds: Float = 1.0  // or WhisperKit's internal kChunkDuration
let hasVoice = AudioProcessor.isVoiceDetected(
    in: energy,
    nextBufferInSeconds: vadWindowSeconds,
    silenceThreshold: silenceThreshold
)
```

---

### WR-05: `ModelWarmupService` warmup has no timeout, leaving the app stuck indefinitely on network failure

**File:** `Dicticus/Dicticus/Services/ModelWarmupService.swift:51`

**Issue:** The `Task.detached` block calls `WhisperKit(WhisperKitConfig(...))` which performs a HuggingFace Hub download on first launch. There is no timeout. If the network is unavailable, the download blocks indefinitely. `isWarming` stays `true`, `statusText` shows "Preparing models…" forever, and there is no way for the user to cancel or retry without force-quitting the app.

**Fix:** Wrap the initialization in a `withTimeout` or use Swift's `Task` cancellation:
```swift
func warmup() {
    guard !isWarming && !isReady else { return }
    isWarming = true
    error = nil

    Task.detached(priority: .utility) { [weak self] in
        do {
            let pipe = try await withTimeout(seconds: 600) {  // 10-minute ceiling
                try await WhisperKit(WhisperKitConfig(model: "large-v3-turbo", verbose: false, logLevel: .error))
            }
            await MainActor.run {
                self?.whisperKit = pipe
                self?.isWarming = false
                self?.isReady = true
            }
        } catch {
            await MainActor.run {
                self?.isWarming = false
                self?.error = "Model load failed. Restart app."
            }
        }
    }
}
```
Alternatively, expose a `cancelWarmup()` method that cancels the underlying `Task` and store a reference to it. The retry path already works (guard passes when `isWarming == false && isReady == false`), so cancellation + retry is sufficient.

---

## Info

### IN-01: `transcriptionService` created in `DicticusApp` but never injected or consumed

**File:** `Dicticus/Dicticus/DicticusApp.swift:12`

**Issue:** `@State private var transcriptionService: TranscriptionService?` is set in the `onChange` closure but never passed to `MenuBarView` or stored in a way Phase 3 can access it (no `environmentObject`, no `@StateObject` promotion). The value is computed and then immediately inaccessible. This will require refactoring before Phase 3 hotkey wiring.

**Fix:** Either promote to `@StateObject` (requires an intermediate holder class since `TranscriptionService` is optional until warmup), or inject via `environmentObject` in the `MenuBarExtra` content closure once created. A clean pattern:
```swift
// In DicticusApp body:
MenuBarView()
    .environmentObject(permissionManager)
    .environmentObject(warmupService)
    .environmentObject(transcriptionService ?? TranscriptionService.placeholder)
```

---

### IN-02: `restrictLanguage` logic duplicated between production method and `#if DEBUG` test helper

**File:** `Dicticus/Dicticus/Services/TranscriptionService.swift:196,211`

**Issue:** The production `restrictLanguage(_:)` method (lines 196–199) and the `#if DEBUG` static `testRestrictLanguage(_:)` helper (lines 211–213) contain identical logic. They will silently diverge if one is updated without the other — tests would pass while production behavior changed.

**Fix:** Have the static helper delegate to the instance method via a temporary instance, or restructure as a static function and call it from both the instance method and the test helper:
```swift
// Make the core logic a private static (or free function):
private static func restrictLanguageCore(_ detected: String) -> String {
    let allowed: Set<String> = ["de", "en"]
    return allowed.contains(detected) ? detected : "en"
}

func restrictLanguage(_ detected: String) -> String {
    return Self.restrictLanguageCore(detected)
}

#if DEBUG
static func testRestrictLanguage(_ detected: String) -> String {
    return restrictLanguageCore(detected)
}
#endif
```

---

### IN-03: `makeForTesting()` initializes WhisperKit without pinning the production model

**File:** `Dicticus/Dicticus/Services/TranscriptionService.swift:230`

**Issue:** `makeForTesting()` calls `WhisperKit(WhisperKitConfig(verbose: false))` without specifying `model: "large-v3-turbo"`. This defaults to WhisperKit's auto-selection (typically the smallest available cached model). Tests that exercise the real service instance run against a different model than production, which could mask model-specific transcription behavior.

**Fix:**
```swift
static func makeForTesting() async throws -> TranscriptionService? {
    do {
        let pipe = try await WhisperKit(WhisperKitConfig(
            model: "large-v3-turbo",  // Match production model (D-08)
            verbose: false
        ))
        return TranscriptionService(whisperKit: pipe)
    } catch {
        return nil
    }
}
```

---

### IN-04: `makeServiceOrSkip()` swallows initialization errors with `try?`, skipping tests that should fail

**File:** `Dicticus/DicticusTests/TranscriptionServiceTests.swift:108`

**Issue:** `guard let service = try? await TranscriptionService.makeForTesting() else { throw XCTSkip(...) }` uses `try?` which discards any error from `makeForTesting()`. If `makeForTesting()` fails for a programming reason (not a missing model), the test silently skips rather than failing. This can hide real bugs during development.

**Fix:** Distinguish between "model not available" (expected skip) and "unexpected error" (should fail):
```swift
private func makeServiceOrSkip() async throws -> TranscriptionService {
    try XCTSkipUnless(
        TranscriptionService.isWhisperKitAvailable(),
        "Skipping — WhisperKit model not loaded."
    )
    // Let unexpected errors propagate as test failures, not skips
    guard let service = try await TranscriptionService.makeForTesting() else {
        throw XCTSkip("WhisperKit init returned nil. Model may still be warming up.")
    }
    return service
}
```

---

_Reviewed: 2026-04-16T04:02:53Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
