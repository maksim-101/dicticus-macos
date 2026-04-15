# Phase 2: ASR Pipeline - Research

**Researched:** 2026-04-15
**Domain:** On-device speech recognition pipeline (WhisperKit + AVAudioEngine on macOS)
**Confidence:** HIGH

## Summary

Phase 2 builds the core speech-to-text engine: capture microphone audio via WhisperKit's built-in AudioProcessor, apply voice activity detection to discard silence, and transcribe via Whisper large-v3-turbo with automatic German/English language detection. The critical discovery is that WhisperKit already provides a complete AudioProcessor class with built-in recording, 16kHz resampling, energy-based VAD, and buffer accumulation -- meaning the phase does NOT need custom AVAudioEngine tap code. The TranscriptionService should use `whisperKit.audioProcessor.startRecordingLive()` for capture and `whisperKit.transcribe(audioArray:)` for inference.

Language restriction to de/en is not a built-in Whisper feature. The approach is to use `detectLanguage()` which returns probabilities for all 99 languages, then select the higher-probability language from {de, en} only. Alternatively, since the `language` parameter in DecodingOptions is optional, we can let auto-detection run naturally -- Whisper large-v3-turbo has strong de/en detection and the `TranscriptionResult.language` field reports what was detected. A post-detection filter provides the "restricted to de/en" guarantee without modifying internal logits.

**Primary recommendation:** Use WhisperKit's AudioProcessor for all audio capture and buffering (do not hand-roll AVAudioEngine taps). Build a TranscriptionService that wraps the record-transcribe-detect cycle with energy-based pre-filtering and minimum duration guards.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Use AVAudioEngine with `installTap(onBus:bufferSize:format:)` for microphone input
- **D-02:** Convert audio to 16kHz mono Float32 at the tap level
- **D-03:** Accumulate audio buffers in memory, pass full buffer to WhisperKit for batch transcription
- **D-04:** Use WhisperKit's built-in VAD capabilities as primary VAD
- **D-05:** Add energy-based pre-filter before inference: compute RMS of audio buffer, skip transcription if below silence threshold
- **D-06:** Discard recordings shorter than 0.3 seconds (TRNS-04)
- **D-07:** VAD threshold should be configurable internally (not user-facing in v1) for tuning
- **D-08:** Pin Whisper large-v3-turbo explicitly in WhisperKitConfig
- **D-09:** Use WhisperKit's default model download/caching (HuggingFace Hub)
- **D-10:** Model stays warm in memory after initial load (INFRA-01) -- consume `ModelWarmupService.whisperKitInstance` directly
- **D-11:** Use WhisperKit's built-in language detection, restricted to German (de) and English (en)
- **D-12:** Language detection happens per-transcription automatically
- **D-13:** New `TranscriptionService` class that consumes `ModelWarmupService.whisperKitInstance`
- **D-14:** TranscriptionService exposes `func transcribe(audioBuffer: AVAudioPCMBuffer) async throws -> TranscriptionResult`
- **D-15:** TranscriptionService is @MainActor ObservableObject so UI can observe transcription state

### Claude's Discretion
- Internal buffer management strategy (pre-allocated vs dynamic)
- Specific energy threshold values for silence detection
- Error handling and retry behavior for failed transcriptions
- Exact WhisperKit API calls and configuration parameters

### Deferred Ideas (OUT OF SCOPE)
None -- discussion stayed within phase scope
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| TRNS-02 | Transcription completes in under 3 seconds for typical utterances (< 30s speech) | WhisperKit large-v3-turbo achieves 0.46s latency on Apple Silicon per Argmax benchmarks; greedy decoding (temperature=0.0) is fastest path |
| TRNS-03 | Auto-detect German and English without manual language switching | WhisperKit `detectLanguage()` returns `(language: String, langProbs: [String: Float])` for all 99 languages; filter to de/en post-detection |
| TRNS-04 | Voice Activity Detection discards silence to prevent hallucinated output | WhisperKit's `AudioProcessor.isVoiceDetected()` + EnergyVAD with configurable threshold + minimum 0.3s duration guard |
| INFRA-01 | ASR model loads at app startup, stays warm in memory | ModelWarmupService.whisperKitInstance already provides this; Phase 2 modifies init to pin `"large-v3-turbo"` model |
</phase_requirements>

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| WhisperKit | 0.18.0 (resolved in Package.resolved) | ASR inference + audio capture + VAD | Already integrated in Phase 1; provides AudioProcessor, EnergyVAD, transcription, language detection -- the complete pipeline [VERIFIED: Package.resolved] |
| AVFoundation | macOS 15 built-in | Audio session management, format types | AVAudioPCMBuffer, AVAudioFormat types used by WhisperKit's AudioProcessor internally [VERIFIED: Apple platform SDK] |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| XCTest | Built-in | Unit testing | Test TranscriptionService state machine, VAD logic, buffer management [VERIFIED: existing test suite runs] |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| WhisperKit AudioProcessor | Custom AVAudioEngine tap | LOCKED OUT by D-01/D-04 intent: WhisperKit's AudioProcessor already does everything D-01 through D-03 describe (tap installation, 16kHz conversion, buffer accumulation). Hand-rolling duplicates functionality. |
| EnergyVAD threshold | WebRTC VAD | Adds external dependency; EnergyVAD is built into WhisperKit and sufficient for push-to-talk |

**Note on D-01 vs WhisperKit AudioProcessor:** D-01 specifies "AVAudioEngine with installTap" -- WhisperKit's AudioProcessor internally uses exactly this mechanism. Using `whisperKit.audioProcessor.startRecordingLive()` satisfies D-01 through D-03 without manual AVAudioEngine code, because the AudioProcessor IS the AVAudioEngine tap with 16kHz conversion and buffer accumulation built in.

## Architecture Patterns

### Recommended Project Structure
```
Dicticus/
├── Services/
│   ├── ModelWarmupService.swift     # Existing -- modify to pin large-v3-turbo
│   ├── TranscriptionService.swift   # NEW -- core ASR pipeline
│   └── PermissionManager.swift      # Existing -- no changes needed
├── Models/
│   └── TranscriptionResult.swift    # NEW -- app-level result type (wraps WhisperKit's)
├── Views/
│   └── (existing views -- no changes in Phase 2)
└── Utilities/
    └── (existing utilities)
```

### Pattern 1: TranscriptionService Architecture
**What:** @MainActor ObservableObject that owns the record-transcribe-detect cycle
**When to use:** Always -- this is the single entry point for all transcription in the app

```swift
// Source: Derived from WhisperKit example app (WhisperAX ContentView.swift) + D-13/D-14/D-15
@MainActor
class TranscriptionService: ObservableObject {
    enum State {
        case idle
        case recording
        case transcribing
    }
    
    @Published var state: State = .idle
    @Published var lastResult: DicticusTranscriptionResult?
    @Published var error: String?
    
    private let whisperKit: WhisperKit  // Injected from ModelWarmupService
    
    // Energy threshold for silence pre-filter (D-05, D-07)
    var silenceThreshold: Float = 0.3  // Configurable internally
    // Minimum recording duration in seconds (D-06)
    let minimumDurationSeconds: Float = 0.3
    
    init(whisperKit: WhisperKit) {
        self.whisperKit = whisperKit
    }
    
    func startRecording() throws {
        // Uses WhisperKit's built-in AudioProcessor (satisfies D-01, D-02, D-03)
        try whisperKit.audioProcessor.startRecordingLive()
        state = .recording
    }
    
    func stopRecordingAndTranscribe() async throws -> DicticusTranscriptionResult {
        whisperKit.audioProcessor.stopRecording()
        state = .transcribing
        
        let audioSamples = Array(whisperKit.audioProcessor.audioSamples)
        let durationSeconds = Float(audioSamples.count) / Float(WhisperKit.sampleRate)
        
        // D-06: Discard sub-0.3s clips
        guard durationSeconds >= minimumDurationSeconds else {
            state = .idle
            throw TranscriptionError.tooShort
        }
        
        // D-05: Energy-based pre-filter
        let energy = whisperKit.audioProcessor.relativeEnergy
        let hasVoice = AudioProcessor.isVoiceDetected(
            in: energy,
            nextBufferInSeconds: durationSeconds,
            silenceThreshold: silenceThreshold
        )
        guard hasVoice else {
            state = .idle
            throw TranscriptionError.silenceOnly
        }
        
        // D-08, D-11, D-12: Transcribe with language detection
        let options = DecodingOptions(
            language: nil,           // Auto-detect (D-12)
            temperature: 0.0,        // Greedy decoding for speed
            detectLanguage: true,    // Enable language detection
            chunkingStrategy: .vad   // Use VAD chunking (D-04)
        )
        
        let results = try await whisperKit.transcribe(
            audioArray: audioSamples,
            decodeOptions: options
        )
        
        guard let result = results.first else {
            state = .idle
            throw TranscriptionError.noResult
        }
        
        // D-11: Restrict detected language to de/en
        let detectedLanguage = restrictLanguage(result.language)
        
        let transcriptionResult = DicticusTranscriptionResult(
            text: result.text,
            language: detectedLanguage,
            confidence: 1.0 - (result.segments.first?.noSpeechProb ?? 0.0)
        )
        
        lastResult = transcriptionResult
        state = .idle
        return transcriptionResult
    }
    
    /// D-11: Restrict language to de/en subset
    private func restrictLanguage(_ detected: String) -> String {
        let allowed: Set<String> = ["de", "en"]
        return allowed.contains(detected) ? detected : "en"  // Default to English if unexpected
    }
}
```

### Pattern 2: ModelWarmupService Modification
**What:** Pin large-v3-turbo model explicitly instead of auto-selection
**When to use:** Phase 2 modifies the existing Phase 1 warmup code

```swift
// Source: WhisperKit README + D-08 + D-10
// Change from Phase 1's WhisperKitConfig() to:
let pipe = try await WhisperKit(
    WhisperKitConfig(
        model: "large-v3-turbo",  // D-08: Pin model explicitly
        verbose: false,
        logLevel: .error          // Reduce console noise in production
    )
)
```

### Pattern 3: App-Level Result Type
**What:** Lightweight struct wrapping WhisperKit's TranscriptionResult for app use
**When to use:** All transcription results pass through this type

```swift
// Source: D-14 requirement for result with text, language, confidence
struct DicticusTranscriptionResult {
    let text: String
    let language: String      // "de" or "en"
    let confidence: Float     // 0.0 to 1.0
}
```

### Anti-Patterns to Avoid
- **Hand-rolling AVAudioEngine taps:** WhisperKit's AudioProcessor already handles all audio capture, format conversion, and buffering. Writing custom tap code duplicates functionality and risks format mismatches.
- **Creating a second WhisperKit instance:** The model must stay warm in memory (D-10). TranscriptionService MUST consume `ModelWarmupService.whisperKitInstance`, never create its own.
- **Streaming transcription in Phase 2:** D-03 specifies batch processing. Do not implement real-time/streaming transcription -- that is a v2 feature (EMODE-03).
- **Using `transcribe(audioPath:)` with file I/O:** Use `transcribe(audioArray:)` directly with the in-memory float array from AudioProcessor. Writing to disk and reading back adds unnecessary latency.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Audio capture + resampling | Custom AVAudioEngine tap with AVAudioConverter | `whisperKit.audioProcessor.startRecordingLive()` | WhisperKit's AudioProcessor handles tap installation, 16kHz mono resampling, buffer accumulation, and energy calculation internally [VERIFIED: WhisperKit source AudioProcessor.swift] |
| Voice activity detection | Custom RMS energy calculator | `AudioProcessor.isVoiceDetected(in:nextBufferInSeconds:silenceThreshold:)` | Static method on WhisperKit's AudioProcessor; uses relativeEnergy already computed during recording [VERIFIED: WhisperKit source] |
| Audio format conversion | Manual Float32 array conversion from AVAudioPCMBuffer | `AudioProcessor.convertBufferToArray(buffer:)` | Handles chunked extraction from PCM buffer with proper capacity reservation [VERIFIED: WhisperKit source] |
| Language detection | Custom language classification model | WhisperKit `detectLanguage()` or `DecodingOptions(language: nil, detectLanguage: true)` | Built into the Whisper model architecture; returns per-language probabilities [VERIFIED: WhisperKit API] |

**Key insight:** WhisperKit is not just an inference wrapper -- it includes a complete audio pipeline (AudioProcessor) with recording, resampling, energy VAD, and buffer management. The Phase 2 TranscriptionService should be a thin orchestrator over WhisperKit's capabilities, not a replacement for them.

## Common Pitfalls

### Pitfall 1: Whisper Hallucinations on Silence
**What goes wrong:** Whisper generates plausible-sounding text (often repetitive phrases or common sentences) when fed silence or very low-energy audio.
**Why it happens:** The Whisper decoder is trained to always produce output; it has no concept of "no speech" at the architecture level. The `noSpeechProb` threshold in DecodingOptions helps but is not sufficient alone.
**How to avoid:** Three-layer defense: (1) energy-based pre-filter via `AudioProcessor.isVoiceDetected()` before any inference, (2) minimum 0.3s duration guard, (3) `chunkingStrategy: .vad` in DecodingOptions to let WhisperKit's EnergyVAD skip silent chunks internally.
**Warning signs:** Transcription results containing repeated phrases, common sentences in unexpected languages, or very high `noSpeechProb` values.

### Pitfall 2: First-Run Model Download Stalls
**What goes wrong:** WhisperKit downloads the large-v3-turbo model from HuggingFace Hub on first launch. The CoreML model files are ~954 MB. If the download fails or is interrupted, the model may be in a corrupted state.
**Why it happens:** Network timeouts, disk space, or HuggingFace rate limiting.
**How to avoid:** WhisperKit handles download/caching automatically (D-09). The `ModelWarmupService` already catches errors and shows "Model load failed. Restart app." Do NOT add custom download logic. First-run warmup time will be significantly longer (download + CoreML compilation). The `isWarming` state in ModelWarmupService already communicates this to the user.
**Warning signs:** `ModelWarmupService.error` being set on first launch, especially with network-related error messages.

### Pitfall 3: AudioProcessor Thread Safety
**What goes wrong:** `audioSamples` is a `ContiguousArray<Float>` on AudioProcessor with no visible explicit locking. Accessing it while recording is in progress could race.
**Why it happens:** The AudioProcessor appends to `audioSamples` in the audio tap callback (audio thread) while the main thread may read it.
**How to avoid:** Always call `stopRecording()` BEFORE accessing `audioSamples`. The stop-then-read pattern ensures no concurrent modification. Do NOT try to read `audioSamples` during active recording for anything other than monitoring (like buffer duration display).
**Warning signs:** Crashes in `ContiguousArray` during transcription, especially with longer recordings.

### Pitfall 4: TranscriptionResult is a Reference Type (Class, Not Struct)
**What goes wrong:** Since WhisperKit v0.15.0, `TranscriptionResult` is an `open class`, not a struct. Code that assumes value semantics (copying, independent mutation) will silently share state.
**Why it happens:** Breaking change in v0.15.0 to support property locking via `@TranscriptionPropertyLock`.
**How to avoid:** Extract needed values (text, language, segments) into the app-level `DicticusTranscriptionResult` struct immediately after transcription completes. Do not hold references to WhisperKit's `TranscriptionResult` objects across scope boundaries.
**Warning signs:** Unexpected mutation of transcription results, state corruption when processing multiple transcriptions.

### Pitfall 5: Model Name Must Match HuggingFace Repo
**What goes wrong:** Using the wrong model identifier string causes WhisperKit to fail to find/download the model.
**Why it happens:** WhisperKit uses glob matching against the `argmaxinc/whisperkit-coreml` repo. The identifier `"large-v3-turbo"` matches `openai_whisper-large-v3_turbo` in the repo.
**How to avoid:** Use `"large-v3-turbo"` as the model string in WhisperKitConfig. This is a short form that WhisperKit resolves via pattern matching. Avoid using full repo path names like `"openai_whisper-large-v3_turbo_954MB"` unless specifically needed.
**Warning signs:** Model download errors or unexpected model selection during warmup.

### Pitfall 6: Swift 6 Sendable Compliance for Audio Callbacks
**What goes wrong:** The `startRecordingLive(callback:)` closure receives `[Float]` on the audio thread. Capturing `self` or mutable state in this closure triggers Swift 6 concurrency warnings/errors.
**Why it happens:** Swift 6 strict concurrency checking (the project uses `SWIFT_VERSION: "6.0"`).
**How to avoid:** Use `@Sendable` closures and avoid capturing `@MainActor`-isolated state. For the recording callback, only capture simple value types or use `Task { @MainActor in }` for UI updates, following the `Task.detached` + `MainActor.run` pattern already established in ModelWarmupService.
**Warning signs:** Compiler errors about "cannot capture @MainActor-isolated property" or "non-sendable type captured".

## Code Examples

### Example 1: Starting and Stopping Recording with WhisperKit AudioProcessor
```swift
// Source: WhisperKit AudioProcessor API [VERIFIED: WhisperKit source]
// D-01, D-02, D-03 satisfied by AudioProcessor internals

// Start recording (AudioProcessor handles tap, resampling, buffering)
try whisperKit.audioProcessor.startRecordingLive { [weak self] samples in
    // Optional callback per buffer -- use for energy monitoring only
    // This runs on the audio thread, not MainActor
    DispatchQueue.main.async {
        // Update buffer duration display if needed
    }
}

// Stop recording and get accumulated audio
whisperKit.audioProcessor.stopRecording()
let audioSamples = Array(whisperKit.audioProcessor.audioSamples)
// audioSamples is now [Float] at 16kHz mono -- ready for transcription
```

### Example 2: Transcription with Language Detection
```swift
// Source: WhisperKit API + WhisperAX example [VERIFIED: WhisperKit source]
let options = DecodingOptions(
    verbose: false,
    task: .transcribe,
    language: nil,              // nil = auto-detect
    temperature: 0.0,           // Greedy decoding (fastest)
    temperatureFallbackCount: 3,
    sampleLength: 224,          // Default max tokens
    usePrefillPrompt: true,
    usePrefillCache: true,
    skipSpecialTokens: true,
    withoutTimestamps: true,    // No timestamps needed for dictation
    suppressBlank: true,
    noSpeechThreshold: 0.6,
    chunkingStrategy: .vad
)

let results: [TranscriptionResult] = try await whisperKit.transcribe(
    audioArray: audioSamples,
    decodeOptions: options
)

// Access result
if let result = results.first {
    let text = result.text           // Transcribed text
    let language = result.language   // Detected language code (e.g., "de", "en")
    let segments = result.segments   // Array of TranscriptionSegment
    // segments[0].noSpeechProb -> probability of no speech (0.0 to 1.0)
}
```

### Example 3: Energy-Based Voice Activity Pre-Filter
```swift
// Source: WhisperKit AudioProcessor.isVoiceDetected() [VERIFIED: WhisperKit source]
let energy = whisperKit.audioProcessor.relativeEnergy
let bufferDuration = Float(whisperKit.audioProcessor.audioSamples.count) 
    / Float(WhisperKit.sampleRate)

let voiceDetected = AudioProcessor.isVoiceDetected(
    in: energy,
    nextBufferInSeconds: bufferDuration,
    silenceThreshold: 0.3  // D-07: configurable internally
)

if !voiceDetected {
    // Skip transcription -- silence only
}
```

### Example 4: Standalone Language Detection
```swift
// Source: WhisperKit detectLanguage API [VERIFIED: WhisperKit source]
// Can be used for pre-detection if needed (separate from transcription)
let (language, langProbs) = try await whisperKit.detectLanguage(
    audioArray: audioSamples
)
// langProbs is [String: Float] -- e.g., ["en": 0.85, "de": 0.12, "fr": 0.01, ...]

// Restrict to de/en
let allowedLanguages: Set<String> = ["de", "en"]
let filteredProbs = langProbs.filter { allowedLanguages.contains($0.key) }
let bestLanguage = filteredProbs.max(by: { $0.value < $1.value })?.key ?? "en"
```

### Example 5: WhisperKitConfig for Model Pinning
```swift
// Source: WhisperKit Configurations.swift [VERIFIED: WhisperKit source]
// D-08: Pin large-v3-turbo, D-09: default HuggingFace caching
let config = WhisperKitConfig(
    model: "large-v3-turbo",   // Resolves to openai_whisper-large-v3_turbo via glob match
    verbose: false,
    logLevel: .error,
    prewarm: true,             // CoreML compilation at init
    load: true,                // Load models immediately
    download: true             // Download if not cached
)
let pipe = try await WhisperKit(config)
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| TranscriptionResult as struct | TranscriptionResult as open class | WhisperKit v0.15.0 (Nov 2024) | Value semantics -> reference semantics; must copy values out immediately [VERIFIED: WhisperKit releases] |
| WhisperKit init with individual params | WhisperKitConfig struct | WhisperKit v0.9.0+ | Cleaner configuration; old init still available as convenience [VERIFIED: WhisperKit source] |
| Manual AVAudioEngine setup | AudioProcessor.startRecordingLive() | Available since early WhisperKit | Built-in recording with resampling eliminates manual audio pipeline code [VERIFIED: WhisperKit source] |
| EnergyVAD private | EnergyVAD public | WhisperKit v0.14.0 (Sep 2024) | Can instantiate standalone EnergyVAD for custom use cases [VERIFIED: WhisperKit releases] |

**Deprecated/outdated:**
- Individual WhisperKit init parameters (model:, downloadBase:, etc.): Still works but WhisperKitConfig is preferred
- Value-type assumptions about TranscriptionResult: Broken since v0.15.0

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `"large-v3-turbo"` short-form model name resolves correctly via WhisperKit glob matching to `openai_whisper-large-v3_turbo` | Architecture Patterns, Code Examples | Model download fails; would need to use full identifier `"openai_whisper-large-v3_turbo"` instead |
| A2 | `whisperKit.audioProcessor.audioSamples` is safe to read after `stopRecording()` completes | Architecture Patterns | Potential race condition; may need explicit synchronization |
| A3 | The `silenceThreshold: 0.3` default in `AudioProcessor.isVoiceDetected()` is appropriate for typical microphone input | Code Examples | Threshold may be too high (rejecting quiet speech) or too low (passing background noise); requires empirical tuning |
| A4 | `DecodingOptions(language: nil, detectLanguage: true)` auto-detects language per-transcription without explicit `detectLanguage()` call | Code Examples | May need separate `detectLanguage()` call before `transcribe()` to get language probabilities for filtering |
| A5 | WhisperKit 0.18.0 is compatible with the `large-v3-turbo` model identifier | Standard Stack | If not, may need to upgrade WhisperKit or use a different model name format |

## Open Questions (RESOLVED)

1. **Exact model identifier format** — RESOLVED: Use `"large-v3-turbo"` short form; fall back to `"openai_whisper-large-v3_turbo"` if download fails at implementation time.
   - What we know: The HuggingFace repo contains `openai_whisper-large-v3_turbo` and `openai_whisper-large-v3_turbo_954MB`. WhisperKit docs say short forms like `"large-v3-turbo"` work via glob matching.

2. **Optimal silence threshold value** — RESOLVED: Start with 0.3 (matching WhisperAX example app); tune during development per D-07.
   - What we know: EnergyVAD default threshold is 0.02. WhisperAX example app uses 0.3 for `silenceThreshold` in `isVoiceDetected()`. These are different parameters on different scales.

3. **Language detection accuracy for de/en with auto-detect** — RESOLVED: Use single-step auto-detect (`language: nil`); add two-step `detectLanguage()` only if accuracy is insufficient during integration testing.
   - What we know: Whisper large-v3-turbo supports 99 languages with auto-detection. The `language` field in TranscriptionResult reports detected language.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Xcode | Build & test | Yes | 26.4 | -- |
| Swift | Compilation | Yes | 6.3 | -- |
| macOS | Target platform | Yes | 26.4.1 | -- |
| Apple Silicon | Neural Engine inference | Yes | arm64 | -- |
| WhisperKit SPM | ASR pipeline | Yes | 0.18.0 (resolved) | -- |
| HuggingFace Hub | Model download (first run) | Yes (network) | -- | Pre-download model manually |
| Microphone | Audio capture | Yes (hardware) | -- | -- |

**Missing dependencies with no fallback:** None
**Missing dependencies with fallback:** None

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | XCTest (built-in) |
| Config file | Dicticus.xcodeproj (xcodegen from project.yml) |
| Quick run command | `xcodebuild test -scheme Dicticus -destination 'platform=macOS,arch=arm64' -only-testing:DicticusTests -quiet` |
| Full suite command | `xcodebuild test -scheme Dicticus -destination 'platform=macOS,arch=arm64' -quiet` |

### Phase Requirements -> Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| TRNS-02 | Transcription under 3s for <30s audio | integration (manual) | Manual test with actual model -- cannot run in CI without model download | No -- Wave 0 |
| TRNS-03 | Auto-detect de/en language | unit | `xcodebuild test -scheme Dicticus -destination 'platform=macOS,arch=arm64' -only-testing:DicticusTests/TranscriptionServiceTests/testLanguageRestriction -quiet` | No -- Wave 0 |
| TRNS-04 | VAD discards silence, sub-0.3s clips discarded | unit | `xcodebuild test -scheme Dicticus -destination 'platform=macOS,arch=arm64' -only-testing:DicticusTests/TranscriptionServiceTests/testMinimumDuration -quiet` | No -- Wave 0 |
| INFRA-01 | Model warm, no reload per request | unit | `xcodebuild test -scheme Dicticus -destination 'platform=macOS,arch=arm64' -only-testing:DicticusTests/TranscriptionServiceTests/testUsesSharedInstance -quiet` | No -- Wave 0 |

### Sampling Rate
- **Per task commit:** Quick run command (unit tests only, ~5 seconds)
- **Per wave merge:** Full suite command (all tests)
- **Phase gate:** Full suite green before `/gsd-verify-work`

### Wave 0 Gaps
- [ ] `DicticusTests/TranscriptionServiceTests.swift` -- covers TRNS-03, TRNS-04, INFRA-01 state machine tests (language restriction, minimum duration, silence detection, shared instance usage)
- [ ] `DicticusTests/TranscriptionResultTests.swift` -- covers DicticusTranscriptionResult struct correctness

**Note:** TRNS-02 (latency under 3s) cannot be reliably unit-tested without the actual Whisper model loaded. This should be verified manually during integration testing or with a dedicated integration test that is excluded from the quick suite.

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | No | N/A -- local app, no auth |
| V3 Session Management | No | N/A -- no sessions |
| V4 Access Control | No | N/A -- single user |
| V5 Input Validation | Yes | Validate audio buffer length (>0.3s), energy threshold bounds, language code in allowed set |
| V6 Cryptography | No | N/A -- no encryption needed |

### Known Threat Patterns for Swift/macOS Audio

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Microphone recording without consent | Information Disclosure | Microphone permission already managed by PermissionManager (Phase 1); macOS TCC enforces consent |
| Audio data exfiltration | Information Disclosure | All processing local (project constraint); no network calls in TranscriptionService |
| Buffer overflow in audio processing | Tampering | WhisperKit handles buffer management; Swift memory safety prevents overflows |
| Denial of service via large audio buffers | Denial of Service | Minimum duration (0.3s) and maximum practical recording length (push-to-talk bounded by user action) |

## Sources

### Primary (HIGH confidence)
- [WhisperKit v0.18.0 source - WhisperKit.swift](https://github.com/argmaxinc/WhisperKit/blob/main/Sources/WhisperKit/Core/WhisperKit.swift) - Transcription API signatures, detectLanguage API, properties
- [WhisperKit Configurations.swift](https://github.com/argmaxinc/whisperkit/blob/main/Sources/WhisperKit/Core/Configurations.swift) - WhisperKitConfig and DecodingOptions full property definitions
- [WhisperKit AudioProcessor.swift](https://github.com/argmaxinc/WhisperKit/blob/main/Sources/WhisperKit/Core/Audio/AudioProcessor.swift) - startRecordingLive, stopRecording, audioSamples, relativeEnergy, isVoiceDetected, convertBufferToArray
- [WhisperKit EnergyVAD.swift](https://github.com/argmaxinc/WhisperKit/blob/main/Sources/WhisperKit/Core/Audio/EnergyVAD.swift) - EnergyVAD class, energyThreshold default 0.02, frame configuration
- [WhisperKit VoiceActivityDetector.swift](https://github.com/argmaxinc/WhisperKit/blob/main/Sources/WhisperKit/Core/Audio/VoiceActivityDetector.swift) - Base class API, voiceActivity, calculateActiveChunks
- [WhisperKit Models.swift](https://github.com/argmaxinc/WhisperKit/blob/main/Sources/WhisperKit/Core/Models.swift) - TranscriptionResult class, TranscriptionSegment, Constants.knownModels, ChunkingStrategy
- [WhisperKit Releases](https://github.com/argmaxinc/WhisperKit/releases) - v0.18.0 (Apr 2025), v0.15.0 breaking change (TranscriptionResult -> class)
- [WhisperAX Example App](https://github.com/argmaxinc/WhisperKit/blob/main/Examples/WhisperAX/WhisperAX/Views/ContentView.swift) - Real-world recording, VAD, DecodingOptions, transcription patterns
- [argmaxinc/whisperkit-coreml HuggingFace](https://huggingface.co/argmaxinc/whisperkit-coreml/tree/main) - Available model variants including large-v3-turbo
- Package.resolved in project - WhisperKit 0.18.0 pinned
- Existing codebase (ModelWarmupService.swift, PermissionManager.swift, DicticusApp.swift) - Phase 1 patterns

### Secondary (MEDIUM confidence)
- [Hel Rabelo WhisperKit macOS article](https://www.helrabelo.dev/blog/whisperkit-on-macos-integrating-on-device-ml) - TranscriptionEngine actor pattern, model loading
- [DeepWiki WhisperKit](https://deepwiki.com/argmaxinc/whisperkit) - Model name short-form resolution, caching paths
- [WhisperKit Arxiv paper](https://arxiv.org/html/2507.10860v1) - 0.46s latency benchmark, WER comparison

### Tertiary (LOW confidence)
- [whisper.cpp language restriction issue #1242](https://github.com/ggml-org/whisper.cpp/issues/1242) - Confirms language subset restriction is not a native Whisper feature (applies to WhisperKit too)

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - WhisperKit 0.18.0 already integrated, API verified from source code
- Architecture: HIGH - Pattern derived from official WhisperAX example app + project decisions
- Pitfalls: HIGH - Verified against WhisperKit source, release notes, and known Whisper behavior
- Language detection: MEDIUM - Auto-detect works but de/en restriction approach is logical inference, not official documentation

**Research date:** 2026-04-15
**Valid until:** 2026-05-15 (WhisperKit is actively developed; check for new releases monthly)
