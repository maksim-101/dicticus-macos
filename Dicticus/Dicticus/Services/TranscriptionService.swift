import SwiftUI
import FluidAudio
import AVFoundation
import NaturalLanguage
import os

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
    /// ASR output contains non-Latin script (Cyrillic, CJK, Arabic, etc.) — likely a
    /// Parakeet hallucination when the spoken language doesn't match model expectations.
    case unexpectedLanguage
}

/// Thread-safe audio sample buffer for real-time AVAudioEngine tap callbacks.
/// Extracted as a standalone Sendable class so the tap closure doesn't inherit
/// @MainActor isolation from TranscriptionService — Swift 6 enforces actor
/// isolation on closures defined inside @MainActor methods even when self
/// isn't captured, causing a runtime crash on the audio thread.
final class AudioSampleBuffer: @unchecked Sendable {
    private var samples: [Float] = []
    private let lock = NSLock()

    func append(_ newSamples: [Float]) {
        lock.lock()
        samples.append(contentsOf: newSamples)
        lock.unlock()
    }

    func drain() -> [Float] {
        lock.lock()
        let result = samples
        samples.removeAll()
        lock.unlock()
        return result
    }

    func clear() {
        lock.lock()
        samples.removeAll()
        lock.unlock()
    }
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

    /// Shared VAD probability threshold used by both VadManager (internal decision
    /// boundary via VadConfig.defaultThreshold) and TranscriptionService (post-filter
    /// on frame probabilities). Keeping these in sync avoids a split where VadManager
    /// classifies a frame as silence but TranscriptionService passes it as voice.
    static let vadProbabilityThreshold: Float = 0.75

    /// Silero VAD probability threshold. Higher = more strict voice detection.
    /// Defaults to vadProbabilityThreshold (0.75) to stay aligned with VadManager.
    /// Range 0.0 to 1.0; values above this probability are classified as voice.
    var silenceThreshold: Float = TranscriptionService.vadProbabilityThreshold

    /// Minimum recording duration in seconds (D-11 in 02.1-CONTEXT.md).
    /// Sub-0.3s clips are noise or accidental key presses, not speech.
    let minimumDurationSeconds: Float = 0.3

    // MARK: - Private

    private let asrManager: AsrManager
    private let vadManager: VadManager
    private let audioEngine = AVAudioEngine()
    /// Thread-safe buffer for audio samples — see AudioSampleBuffer doc comment.
    private let sampleBuffer = AudioSampleBuffer()
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
        sampleBuffer.clear()

        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        // Install tap via nonisolated helper to prevent the closure from
        // inheriting @MainActor isolation (Swift 6 strict concurrency).
        Self.installTap(on: inputNode, format: inputFormat, buffer: sampleBuffer)

        try audioEngine.start()
        state = .recording
    }

    /// Install audio tap in a nonisolated context so the closure has no actor affinity.
    /// Swift 6 strict concurrency makes closures inside @MainActor methods inherit
    /// that isolation — even @Sendable closures check actor identity at runtime,
    /// crashing when AVAudioEngine calls them on the real-time audio thread.
    nonisolated private static func installTap(
        on inputNode: AVAudioInputNode,
        format: AVAudioFormat,
        buffer: AudioSampleBuffer
    ) {
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: format) {
            pcmBuffer, _ in
            if let channelData = pcmBuffer.floatChannelData?[0] {
                let frameCount = Int(pcmBuffer.frameLength)
                let samples = Array(UnsafeBufferPointer(start: channelData, count: frameCount))
                buffer.append(samples)
            }
        }
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

        let samples = sampleBuffer.drain()

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

        let trimmedText = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            throw TranscriptionError.noResult  // defer resets to .idle
        }

        // Script validation: reject non-Latin output (Parakeet may output Cyrillic/CJK/Arabic
        // when spoken language doesn't match expectations — T-03-13 mitigation)
        guard !Self.containsNonLatinScript(trimmedText) else {
            throw TranscriptionError.unexpectedLanguage
        }

        // Post-hoc language detection (Parakeet outputs no language code — D-13)
        let detectedLanguage = detectLanguage(result.text)

        let transcriptionResult = DicticusTranscriptionResult(
            text: trimmedText,
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
        var didProvideData = false
        converter.convert(to: outputBuffer, error: &conversionError) { inNumPackets, outStatus in
            if didProvideData {
                outStatus.pointee = .endOfStream
                return nil
            }
            didProvideData = true
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

    // MARK: - Script validation

    /// Latin Unicode scalar ranges that are allowed in transcription output.
    /// Covers Basic Latin, Latin Extended-A/B, Latin Extended Additional,
    /// Latin Extended-C, and Latin Extended-D blocks.
    private static let latinRanges: [ClosedRange<UInt32>] = [
        0x0000...0x007F,   // Basic Latin (ASCII)
        0x0080...0x00FF,   // Latin-1 Supplement (umlauts, accented chars)
        0x0100...0x024F,   // Latin Extended-A + B
        0x1E00...0x1EFF,   // Latin Extended Additional
        0x2C60...0x2C7F,   // Latin Extended-C
        0xA720...0xA7FF,   // Latin Extended-D
        0x0300...0x036F,   // Combining Diacritical Marks (accents on Latin base)
    ]

    /// Check if text contains non-Latin script characters (Cyrillic, CJK, Arabic, etc.).
    ///
    /// Parakeet TDT v3 may output characters from unexpected scripts when the spoken
    /// language doesn't match well. This guard prevents garbled text from being injected
    /// at the user's cursor.
    ///
    /// Logic: any Unicode letter that is NOT in the Latin character sets is flagged.
    /// Numbers, punctuation, symbols, and combining marks are always allowed.
    ///
    /// Static so it can be unit tested without a FluidAudio instance.
    static func containsNonLatinScript(_ text: String) -> Bool {
        let letters = CharacterSet.letters
        for scalar in text.unicodeScalars {
            // Skip non-letter scalars (numbers, punctuation, symbols, whitespace, combining marks)
            guard letters.contains(scalar) else { continue }
            // Check if this letter scalar falls within any Latin range
            let value = scalar.value
            let isLatin = latinRanges.contains { $0.contains(value) }
            if !isLatin {
                return true  // Found a non-Latin letter
            }
        }
        return false
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
            let vad = try await VadManager(config: VadConfig(defaultThreshold: Float(vadProbabilityThreshold)))
            return TranscriptionService(asrManager: manager, vadManager: vad)
        } catch {
            return nil
        }
    }
}
#endif
