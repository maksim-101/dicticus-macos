import SwiftUI
import WhisperKit

/// Errors thrown by TranscriptionService during the record-transcribe cycle.
enum TranscriptionError: Error, Sendable {
    /// Recording was shorter than minimumDurationSeconds (D-06 in 02-RESEARCH.md).
    case tooShort
    /// Energy-based VAD detected no voice activity (D-05 in 02-RESEARCH.md).
    case silenceOnly
    /// WhisperKit returned no transcription results.
    case noResult
    /// WhisperKit instance not available (model not warmed up).
    case modelNotReady
    /// stopRecordingAndTranscribe() called when not recording.
    case notRecording
    /// startRecording() called while already recording or transcribing.
    case busy
}

/// Core ASR pipeline: record audio via WhisperKit AudioProcessor, apply three-layer VAD,
/// transcribe via Whisper large-v3-turbo with automatic German/English language detection.
///
/// Three-layer VAD defense against Whisper silence hallucinations (Pitfall 1):
///   1. Minimum duration guard: discard clips shorter than 0.3s (D-06)
///   2. Energy-based pre-filter: skip inference if below silence threshold (D-05)
///   3. VAD chunking strategy: WhisperKit internal EnergyVAD skips silent chunks (D-04)
///
/// Consumes ModelWarmupService.whisperKitInstance directly (D-10, D-13).
/// Does NOT create its own WhisperKit instance.
///
/// Phase 3 will call startRecording() on hotkey press and
/// stopRecordingAndTranscribe() on hotkey release.
@MainActor
class TranscriptionService: ObservableObject {

    // MARK: - State machine

    /// Pipeline state. Phase 3 observes this for UI feedback (e.g., pulsing icon during recording).
    enum State: Equatable, Sendable {
        case idle
        case recording
        case transcribing
    }

    @Published var state: State = .idle
    @Published var lastResult: DicticusTranscriptionResult?
    @Published var error: String?

    // MARK: - Configuration

    /// Energy threshold for silence pre-filter (D-05, D-07).
    /// Configurable internally for development tuning; not user-facing in v1.
    /// Starting value 0.3 matches WhisperAX example app (see 02-RESEARCH.md).
    var silenceThreshold: Float = 0.3

    /// Minimum recording duration in seconds (D-06).
    /// Sub-0.3s clips are noise or accidental key presses, not speech.
    let minimumDurationSeconds: Float = 0.3

    // MARK: - Private

    // nonisolated(unsafe) is required for Swift 6 strict concurrency compliance.
    // WhisperKit's transcribe() method is nonisolated but self.whisperKit is
    // @MainActor-isolated by default. Marking it nonisolated(unsafe) allows
    // sending it to nonisolated async methods. Safety: we only call transcribe()
    // from within an async throws context after copying audio samples, and
    // ModelWarmupService is the sole owner of the WhisperKit instance lifecycle.
    nonisolated(unsafe) private let whisperKit: WhisperKit

    // MARK: - Initialization

    /// Initialize with a warm WhisperKit instance from ModelWarmupService (D-10, D-13).
    /// - Parameter whisperKit: Initialized WhisperKit from ModelWarmupService.whisperKitInstance
    init(whisperKit: WhisperKit) {
        self.whisperKit = whisperKit
    }

    // MARK: - Recording

    /// Start recording via WhisperKit's AudioProcessor (D-01, D-02, D-03).
    ///
    /// AudioProcessor internally installs an AVAudioEngine tap at 16kHz mono
    /// and accumulates buffers — no manual AVAudioEngine code needed.
    /// This satisfies D-01, D-02, D-03 via WhisperKit internals.
    ///
    /// - Throws: AVFoundation error if microphone access is denied or hardware unavailable.
    func startRecording() throws {
        // WR-03: Throw instead of silently returning so callers know the call was ignored.
        guard state == .idle else { throw TranscriptionError.busy }
        // The startRecordingLive closure runs on the audio thread (Pitfall 6: Swift 6 Sendable).
        // We intentionally do nothing in the callback to stay Swift 6-compliant.
        // Energy monitoring (relativeEnergy) is polled from the main actor when needed.
        try whisperKit.audioProcessor.startRecordingLive { _ in
            // Intentionally empty — audio thread callback.
            // Buffer accumulation is handled internally by AudioProcessor.
        }
        state = .recording
    }

    // MARK: - Transcription

    /// Stop recording and run the full transcription pipeline.
    ///
    /// Pipeline steps:
    ///   1. Stop AudioProcessor recording (Pitfall 3: stop before reading samples)
    ///   2. Check minimum duration (D-06: reject clips shorter than 0.3s)
    ///   3. Energy-based VAD pre-filter (D-05: skip inference if silence only)
    ///   4. Transcribe with auto language detection (D-08, D-11, D-12)
    ///   5. Restrict detected language to de/en (D-11)
    ///   6. Build DicticusTranscriptionResult (Pitfall 4: copy values into struct immediately)
    ///
    /// - Returns: DicticusTranscriptionResult with text, language, and confidence
    /// - Throws: TranscriptionError for pipeline failures (tooShort, silenceOnly, noResult)
    func stopRecordingAndTranscribe() async throws -> DicticusTranscriptionResult {
        // WR-02: Guard against calling stop when not recording.
        // Without this, stale audioSamples from a prior session could produce spurious transcription.
        guard state == .recording else {
            throw TranscriptionError.notRecording
        }

        // Pitfall 3: Always stop before accessing audioSamples
        whisperKit.audioProcessor.stopRecording()
        state = .transcribing

        // Ensure state is always reset to .idle, even if whisperKit.transcribe() throws
        // (WR-01: without this, a WhisperKit/CoreML error leaves state stuck as .transcribing
        // and all subsequent startRecording() calls silently no-op).
        defer { if state == .transcribing { state = .idle } }

        // Copy audio samples after stop — safe to read now (Pitfall 3)
        let audioSamples = Array(whisperKit.audioProcessor.audioSamples)
        let durationSeconds = Float(audioSamples.count) / Float(WhisperKit.sampleRate)

        // D-06: Discard sub-0.3s clips (noise, accidental keypresses)
        guard durationSeconds >= minimumDurationSeconds else {
            state = .idle
            throw TranscriptionError.tooShort
        }

        // D-05: Energy-based pre-filter before inference.
        // AudioProcessor.isVoiceDetected() uses relativeEnergy already computed during recording.
        // WR-04: nextBufferInSeconds expects a chunk window size, not the full recording duration.
        // Using the full duration could inflate the energy window and cause incorrect VAD behavior.
        // A fixed 1.0s window aligns with WhisperKit's internal chunking granularity.
        let vadWindowSeconds: Float = 1.0
        let energy = whisperKit.audioProcessor.relativeEnergy
        let hasVoice = AudioProcessor.isVoiceDetected(
            in: energy,
            nextBufferInSeconds: vadWindowSeconds,
            silenceThreshold: silenceThreshold
        )
        guard hasVoice else {
            state = .idle
            throw TranscriptionError.silenceOnly
        }

        // D-08, D-11, D-12: Transcribe with language auto-detection.
        // temperature 0.0 = greedy decoding for fastest inference (TRNS-02, sub-3s latency).
        // language nil = let Whisper auto-detect; we restrict the result post-hoc (D-11).
        // chunkingStrategy .vad = WhisperKit internal EnergyVAD skips silent chunks (D-04).
        // withoutTimestamps true = dictation does not need segment timestamps.
        let options = DecodingOptions(
            verbose: false,
            task: .transcribe,
            language: nil,
            temperature: 0.0,
            temperatureFallbackCount: 3,
            sampleLength: 224,
            usePrefillPrompt: true,
            usePrefillCache: true,
            skipSpecialTokens: true,
            withoutTimestamps: true,
            suppressBlank: true,
            noSpeechThreshold: 0.6,
            chunkingStrategy: .vad
        )

        let results = try await whisperKit.transcribe(
            audioArray: audioSamples,
            decodeOptions: options
        )

        guard let result = results.first else {
            state = .idle
            throw TranscriptionError.noResult
        }

        // D-11: Restrict detected language to the {de, en} subset.
        // result.language is non-optional in WhisperKit 0.18.0 (String, not String?).
        let detectedLanguage = restrictLanguage(result.language)

        // Pitfall 4: TranscriptionResult is an open class since WhisperKit v0.15.0.
        // Copy values into our Sendable value-type struct immediately.
        let transcriptionResult = DicticusTranscriptionResult(
            text: result.text.trimmingCharacters(in: .whitespacesAndNewlines),
            language: detectedLanguage,
            confidence: 1.0 - (result.segments.first?.noSpeechProb ?? 0.0)
        )

        lastResult = transcriptionResult
        state = .idle
        return transcriptionResult
    }

    // MARK: - Language restriction

    /// Restrict a detected language code to the allowed set {de, en} (D-11).
    ///
    /// Whisper large-v3-turbo detects all 99 supported languages. For this app,
    /// only German and English are supported. Any other detected language defaults
    /// to English (the more likely correct detection when German was intended but
    /// mis-detected, vs. genuinely speaking a third language).
    ///
    /// - Parameter detected: Language code from WhisperKit TranscriptionResult.language
    /// - Returns: "de" or "en"
    func restrictLanguage(_ detected: String) -> String {
        let allowed: Set<String> = ["de", "en"]
        return allowed.contains(detected) ? detected : "en"
    }
}

// MARK: - Test support

#if DEBUG
extension TranscriptionService {

    /// Static wrapper for `restrictLanguage` allowing unit tests to call it without
    /// a WhisperKit instance. This avoids a protocol-based architecture just for testing.
    ///
    /// Tests call: `TranscriptionService.testRestrictLanguage("fr") == "en"`
    static func testRestrictLanguage(_ detected: String) -> String {
        let allowed: Set<String> = ["de", "en"]
        return allowed.contains(detected) ? detected : "en"
    }

    /// Returns true if a WhisperKit model cache exists on this machine.
    /// Used by tests to conditionally skip model-dependent tests.
    static func isWhisperKitAvailable() -> Bool {
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
        guard let cache = cacheDir else { return false }
        let whisperKitCache = cache.appendingPathComponent("huggingface/models/argmaxinc/whisperkit-coreml")
        return (try? FileManager.default.contentsOfDirectory(atPath: whisperKitCache.path))?.isEmpty == false
    }

    /// Attempt to create a TranscriptionService using a synchronously-loaded WhisperKit.
    /// Returns nil if initialization fails (model not cached, etc.).
    /// Used by tests that need an actual service instance.
    static func makeForTesting() async throws -> TranscriptionService? {
        do {
            let pipe = try await WhisperKit(WhisperKitConfig(verbose: false))
            return TranscriptionService(whisperKit: pipe)
        } catch {
            return nil
        }
    }
}
#endif
