---
phase: 02-asr-pipeline
fixed_at: 2026-04-16T04:15:10Z
review_path: .planning/phases/02-asr-pipeline/02-REVIEW.md
iteration: 1
findings_in_scope: 5
fixed: 5
skipped: 0
status: all_fixed
---

# Phase 02: Code Review Fix Report

**Fixed at:** 2026-04-16T04:15:10Z
**Source review:** .planning/phases/02-asr-pipeline/02-REVIEW.md
**Iteration:** 1

**Summary:**
- Findings in scope: 5
- Fixed: 5
- Skipped: 0

## Fixed Issues

### WR-01: `state` permanently stuck as `.transcribing` when `whisperKit.transcribe()` throws

**Files modified:** `Dicticus/Dicticus/Services/TranscriptionService.swift`
**Commit:** 04dfc8c
**Applied fix:** Added `defer { if state == .transcribing { state = .idle } }` immediately after `state = .transcribing` in `stopRecordingAndTranscribe()`. This ensures state is always reset to `.idle` when the method exits, whether via normal return or via a throw from `whisperKit.transcribe()`. The conditional check (`if state == .transcribing`) avoids interfering with the existing early-exit guards that already reset state before throwing.

### WR-02: `stopRecordingAndTranscribe()` not guarded against being called when not recording

**Files modified:** `Dicticus/Dicticus/Services/TranscriptionService.swift`
**Commit:** 57b493f
**Applied fix:** Added a new `TranscriptionError.notRecording` case and a `guard state == .recording else { throw TranscriptionError.notRecording }` at the top of `stopRecordingAndTranscribe()`, before `stopRecording()` is called. This prevents processing stale audio samples from a prior session when the method is called outside the recording state.

### WR-03: `startRecording()` silently returns without signaling the caller it was ignored

**Files modified:** `Dicticus/Dicticus/Services/TranscriptionService.swift`
**Commit:** 527cab3
**Applied fix:** Added a new `TranscriptionError.busy` case and changed `guard state == .idle else { return }` to `guard state == .idle else { throw TranscriptionError.busy }` in `startRecording()`. Phase 3 hotkey handlers can now catch this error to provide user feedback (e.g., ignore the double-press gracefully with a known reason).

### WR-04: `stopRecordingAndTranscribe()` passes `durationSeconds` as `nextBufferInSeconds` to `isVoiceDetected`

**Files modified:** `Dicticus/Dicticus/Services/TranscriptionService.swift`
**Commit:** 3bd67bf
**Status:** fixed: requires human verification
**Applied fix:** Replaced `nextBufferInSeconds: durationSeconds` with a fixed `vadWindowSeconds: Float = 1.0` constant. The `nextBufferInSeconds` parameter name in WhisperKit's `AudioProcessor.isVoiceDetected()` implies a chunk window size, not the total recording duration. Using 1.0s aligns with typical VAD chunk granularity. However, the exact semantics depend on WhisperKit's internal implementation -- the developer should verify this value against WhisperKit source if VAD behavior changes.

### WR-05: `ModelWarmupService` warmup has no timeout, leaving the app stuck indefinitely on network failure

**Files modified:** `Dicticus/Dicticus/Services/ModelWarmupService.swift`
**Commit:** d82f3cd
**Applied fix:** Stored the warmup `Task` reference in a `warmupTask` property. Wrapped the WhisperKit initialization in a `withThrowingTaskGroup` that races the init against a 600-second (10-minute) timeout watchdog task. Added a `cancelWarmup()` method that cancels the stored task. On timeout or cancellation, `isWarming` is reset to `false` and an error message is displayed. The existing retry path works automatically -- after cancellation/timeout, calling `warmup()` again will retry since `isWarming == false && isReady == false`.

## Skipped Issues

None -- all findings were fixed.

---

_Fixed: 2026-04-16T04:15:10Z_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
