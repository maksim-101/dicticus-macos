import SwiftUI
import FluidAudio
import AVFoundation
import NaturalLanguage

/// Errors thrown by TranscriptionService during the record-transcribe cycle.
enum TranscriptionError: Error, Sendable {
    /// Recording was shorter than minimumDurationSeconds (D-06 in 02-RESEARCH.md).
    case tooShort
    /// Silero VAD detected no voice activity (D-10 in 02.1-RESEARCH.md).
    case silenceOnly
    /// ASR engine returned no transcription results.
    case noResult
    /// ASR models not available (model not warmed up).
    case modelNotReady
    /// stopRecordingAndTranscribe() called when not recording.
    case notRecording
    /// startRecording() called while already recording or transcribing.
    case busy
}

/// Core ASR pipeline: record audio via AVAudioEngine, apply three-layer VAD,
/// transcribe via Parakeet TDT v3 (FluidAudio), and detect language post-hoc
/// with NLLanguageRecognizer.
///
/// Three-layer VAD defense against Parakeet silence hallucinations:
///   1. Minimum duration guard: discard clips shorter than 0.3s (D-11 in 02.1-CONTEXT.md)
///   2. Silero VAD pre-filter: skip inference if VadManager detects no voice (VadManager)
///   3. Empty result guard: discard if ASR returns only whitespace
///
/// Consumes ModelWarmupService.asrManagerInstance + vadManagerInstance directly.
/// Does NOT create its own FluidAudio instances.
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

    /// Silero VAD probability threshold. Higher = more strict voice detection.
    /// Starting at 0.5 per RESEARCH.md recommendation for push-to-talk.
    /// Range 0.0 to 1.0; values above this probability are classified as voice.
    var silenceThreshold: Float = 0.5

    /// Minimum recording duration in seconds (D-11 in 02.1-CONTEXT.md).
    /// Sub-0.3s clips are noise or accidental key presses, not speech.
    let minimumDurationSeconds: Float = 0.3

    // MARK: - Private

    private let asrManager: AsrManager
    private let vadManager: VadManager
    private let audioEngine = AVAudioEngine()
    /// Accumulated raw audio samples at the hardware sample rate during recording.
    private var audioSamples: [Float] = []
    /// Target sample rate for Parakeet TDT v3 (16kHz mono).
    private let sampleRate: Double = 16000

    // MARK: - Initialization

    /// Initialize with warm FluidAudio instances from ModelWarmupService.
    /// - Parameter asrManager: Initialized AsrManager from ModelWarmupService.asrManagerInstance
    /// - Parameter vadManager: Initialized VadManager from ModelWarmupService.vadManagerInstance
    init(asrManager: AsrManager, vadManager: VadManager) {
        self.asrManager = asrManager
        self.vadManager = vadManager
    }

    // MARK: - Recording

    /// Start recording via AVAudioEngine.
    ///
    /// Installs a tap on the input node to accumulate raw Float32 samples.
    /// The hardware's native sample rate is captured; resampling to 16kHz
    /// occurs in stopRecordingAndTranscribe() before ASR inference.
    ///
    /// - Throws: TranscriptionError.busy if already recording or transcribing.
    /// - Throws: AVFoundation error if microphone access is denied or hardware unavailable.
    func startRecording() throws {
        guard state == .idle else { throw TranscriptionError.busy }
        audioSamples = []

        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        // Install tap on input node to capture audio buffers.
        // We capture at the hardware's native format and resample later.
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) {
            [weak self] buffer, _ in
            guard let self else { return }
            if let channelData = buffer.floatChannelData?[0] {
                let frameCount = Int(buffer.frameLength)
                let samples = Array(UnsafeBufferPointer(start: channelData, count: frameCount))
                Task { @MainActor in
                    self.audioSamples.append(contentsOf: samples)
                }
            }
        }

        try audioEngine.start()
        state = .recording
    }

    // MARK: - Transcription

    /// Stop recording and run the full transcription pipeline.
    ///
    /// Pipeline steps:
    ///   1. Stop AVAudioEngine recording (always stop before reading samples)
    ///   2. Resample from hardware rate to 16kHz mono (Parakeet expects 16kHz)
    ///   3. Check minimum duration (D-11: reject clips shorter than 0.3s)
    ///   4. Silero VAD pre-filter (VadManager: skip inference if silence only)
    ///   5. Transcribe via Parakeet TDT v3 via AsrManager
    ///   6. Detect language post-hoc with NLLanguageRecognizer (D-13)
    ///   7. Build DicticusTranscriptionResult
    ///
    /// - Returns: DicticusTranscriptionResult with text, language, and confidence
    /// - Throws: TranscriptionError for pipeline failures (tooShort, silenceOnly, noResult)
    func stopRecordingAndTranscribe() async throws -> DicticusTranscriptionResult {
        guard state == .recording else { throw TranscriptionError.notRecording }

        // Always stop before accessing audioSamples
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        state = .transcribing

        // Ensure state always resets to .idle even if transcription throws
        defer { if state == .transcribing { state = .idle } }

        let samples = audioSamples

        // Resample to 16kHz mono if hardware sample rate differs.
        // Parakeet TDT v3 requires 16kHz Float32 mono input.
        let inputSampleRate = audioEngine.inputNode.outputFormat(forBus: 0).sampleRate
        let resampledSamples: [Float]
        if abs(inputSampleRate - sampleRate) > 1.0 {
            resampledSamples = resampleAudio(samples, from: inputSampleRate, to: sampleRate)
        } else {
            resampledSamples = samples
        }

        let durationSeconds = Float(resampledSamples.count) / Float(sampleRate)

        // Layer 1: Minimum duration guard (D-11)
        guard durationSeconds >= minimumDurationSeconds else {
            throw TranscriptionError.tooShort  // defer resets to .idle
        }

        // Layer 2: Silero VAD pre-filter (VadManager replaces energy-based VAD per D-10)
        let vadResults = try await vadManager.process(resampledSamples)
        let hasVoice = vadResults.contains { $0.probability > silenceThreshold }
        guard hasVoice else {
            throw TranscriptionError.silenceOnly  // defer resets to .idle
        }

        // Layer 3: Transcribe via Parakeet TDT v3
        let result = try await asrManager.transcribe(resampledSamples)

        guard !result.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw TranscriptionError.noResult  // defer resets to .idle
        }

        // Post-hoc language detection (Parakeet outputs no language code — D-13)
        let detectedLanguage = detectLanguage(result.text)

        let transcriptionResult = DicticusTranscriptionResult(
            text: result.text.trimmingCharacters(in: .whitespacesAndNewlines),
            language: detectedLanguage,
            confidence: result.confidence
        )

        lastResult = transcriptionResult
        state = .idle
        return transcriptionResult
    }

    // MARK: - Resampling

    /// Resample audio from one sample rate to another.
    ///
    /// Primary path: AVAudioConverter (Apple's high-quality resampler, recommended per RESEARCH.md).
    /// Fallback: Linear interpolation if AVAudioConverter setup fails.
    ///
    /// - Parameter samples: Input audio samples at sourceSampleRate
    /// - Parameter sourceSampleRate: Native hardware sample rate (typically 44.1kHz or 48kHz)
    /// - Parameter targetSampleRate: Parakeet's required rate (16kHz)
    private func resampleAudio(_ samples: [Float], from sourceSampleRate: Double, to targetSampleRate: Double) -> [Float] {
        // Primary path: AVAudioConverter
        guard let sourceFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sourceSampleRate,
            channels: 1,
            interleaved: false
        ),
        let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: targetSampleRate,
            channels: 1,
            interleaved: false
        ),
        let converter = AVAudioConverter(from: sourceFormat, to: targetFormat),
        let sourceBuffer = AVAudioPCMBuffer(pcmFormat: sourceFormat, frameCapacity: AVAudioFrameCount(samples.count))
        else {
            // Fallback to linear interpolation if AVAudioConverter setup fails
            return resampleLinear(samples, from: sourceSampleRate, to: targetSampleRate)
        }

        // Copy samples into source buffer
        sourceBuffer.frameLength = AVAudioFrameCount(samples.count)
        if let channelData = sourceBuffer.floatChannelData?[0] {
            for i in 0..<samples.count {
                channelData[i] = samples[i]
            }
        }

        let ratio = targetSampleRate / sourceSampleRate
        let outputFrameCount = AVAudioFrameCount(Double(samples.count) * ratio)
        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: outputFrameCount) else {
            return resampleLinear(samples, from: sourceSampleRate, to: targetSampleRate)
        }

        var conversionError: NSError?
        converter.convert(to: outputBuffer, error: &conversionError) { inNumPackets, outStatus in
            outStatus.pointee = .haveData
            return sourceBuffer
        }

        if conversionError != nil {
            return resampleLinear(samples, from: sourceSampleRate, to: targetSampleRate)
        }

        let frameCount = Int(outputBuffer.frameLength)
        guard let outputData = outputBuffer.floatChannelData?[0] else {
            return resampleLinear(samples, from: sourceSampleRate, to: targetSampleRate)
        }
        return Array(UnsafeBufferPointer(start: outputData, count: frameCount))
    }

    /// Fallback resampler using linear interpolation.
    /// Used when AVAudioConverter setup fails (e.g., invalid format parameters).
    private func resampleLinear(_ samples: [Float], from sourceSampleRate: Double, to targetSampleRate: Double) -> [Float] {
        let ratio = targetSampleRate / sourceSampleRate
        let outputLength = Int(Double(samples.count) * ratio)
        var output = [Float](repeating: 0, count: outputLength)

        for i in 0..<outputLength {
            let sourceIndex = Double(i) / ratio
            let lower = Int(sourceIndex)
            let upper = min(lower + 1, samples.count - 1)
            let fraction = Float(sourceIndex - Double(lower))
            output[i] = samples[lower] * (1.0 - fraction) + samples[upper] * fraction
        }

        return output
    }

    // MARK: - Language detection

    /// Detect language of transcribed text, restricted to {de, en} (D-13 in 02.1-CONTEXT.md).
    ///
    /// Parakeet TDT v3 does not output language codes, so we use Apple's
    /// NLLanguageRecognizer post-hoc on the transcribed text.
    func detectLanguage(_ text: String) -> String {
        let recognizer = NLLanguageRecognizer()
        recognizer.languageConstraints = [.german, .english]
        recognizer.processString(text)
        guard let language = recognizer.dominantLanguage else { return "en" }
        switch language {
        case .german: return "de"
        case .english: return "en"
        default: return "en"
        }
    }

    // MARK: - Language restriction

    /// Restrict a detected language code to the allowed set {de, en} (D-13 in 02.1-CONTEXT.md).
    ///
    /// Used as a validation layer after post-hoc language detection.
    /// Any other detected language defaults to English.
    ///
    /// - Parameter detected: Language code string
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
    /// a FluidAudio instance. This avoids a protocol-based architecture just for testing.
    ///
    /// Tests call: `TranscriptionService.testRestrictLanguage("fr") == "en"`
    static func testRestrictLanguage(_ detected: String) -> String {
        let allowed: Set<String> = ["de", "en"]
        return allowed.contains(detected) ? detected : "en"
    }

    /// Static wrapper for `detectLanguage` allowing unit tests to call it without
    /// a FluidAudio instance.
    ///
    /// Tests call: `TranscriptionService.testDetectLanguage("Dies ist ein Satz") == "de"`
    static func testDetectLanguage(_ text: String) -> String {
        let recognizer = NLLanguageRecognizer()
        recognizer.languageConstraints = [.german, .english]
        recognizer.processString(text)
        guard let language = recognizer.dominantLanguage else { return "en" }
        switch language {
        case .german: return "de"
        case .english: return "en"
        default: return "en"
        }
    }

    /// Returns true if FluidAudio Parakeet model files are cached on this machine.
    /// Used by tests to conditionally skip model-dependent tests.
    static func isFluidAudioAvailable() -> Bool {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        guard let base = appSupport else { return false }
        let fluidAudioModels = base.appendingPathComponent("FluidAudio/Models")
        return (try? FileManager.default.contentsOfDirectory(atPath: fluidAudioModels.path))?.isEmpty == false
    }

    /// Attempt to create a TranscriptionService using FluidAudio-backed managers.
    /// Returns nil if initialization fails (model not cached, etc.).
    /// Used by tests that need an actual service instance.
    static func makeForTesting() async throws -> TranscriptionService? {
        do {
            let models = try await AsrModels.downloadAndLoad(version: .v3)
            let manager = AsrManager(config: .default)
            try await manager.loadModels(models)
            let vad = try await VadManager(config: VadConfig(defaultThreshold: 0.75))
            return TranscriptionService(asrManager: manager, vadManager: vad)
        } catch {
            return nil
        }
    }
}
#endif
