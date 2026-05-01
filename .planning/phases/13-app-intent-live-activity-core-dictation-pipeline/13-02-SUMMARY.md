# Phase 13-02 Summary: Core Dictation Pipeline Port

Ported the core ASR pipeline services from macOS to iOS, ensuring compatibility with mobile hardware and iOS-specific audio requirements.

## Key Changes

### IOSTranscriptionService
- Created `iOS/Dicticus/Services/IOSTranscriptionService.swift` by porting the macOS `TranscriptionService`.
- Added `AVAudioSession` management in `startRecording()` to handle iOS-specific audio session activation.
- Maintained the three-layer VAD defense:
  1. Minimum 0.3s duration guard.
  2. Silero VAD pre-filter at 0.75 probability threshold.
  3. Empty result and non-Latin script guards.
- Implemented resampling from hardware rate to 16kHz mono using `AVAudioConverter` with a linear interpolation fallback.
- Integrated `NaturalLanguage` for post-hoc language detection (restricted to English and German).

### IOSModelWarmupService
- Created `iOS/Dicticus/Services/IOSModelWarmupService.swift` by porting the macOS `ModelWarmupService`.
- Removed all LLM-related logic (AI cleanup) to minimize memory pressure and binary size on iOS.
- Implemented background warming for Parakeet TDT v3 and Silero VAD models using `Task.detached`.
- Included a 10-minute timeout watchdog for model download and compilation.

### Unit Tests
- Created `iOS/DicticusTests/IOSTranscriptionServiceTests.swift` covering:
  - Language restriction logic.
  - Language detection using `NaturalLanguage`.
  - Comprehensive non-Latin script validation (Latin, Cyrillic, CJK, Arabic, etc.).
  - Service configuration validation.
- Created `iOS/DicticusTests/IOSModelWarmupServiceTests.swift` verifying the initial state and warmup lifecycle.

## Verification Results

### Automated Tests
- `xcodebuild test` for the `Dicticus` scheme succeeded on iOS Simulator (iPhone 17 Pro).
- All pure-logic tests (language detection, script validation, warmup state machine) passed.
- Model-dependent tests were gracefully skipped as expected in the simulator environment.

### Code Quality
- Verified `IOSTranscriptionService` is `@MainActor` isolated.
- Confirmed audio tap installation is `nonisolated` to prevent Swift 6 strict concurrency crashes on the audio thread.
- Ensured LLM-related properties and logic are completely absent from the iOS warmup service.
