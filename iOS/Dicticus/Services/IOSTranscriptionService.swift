import Foundation
import SwiftUI
import FluidAudio
@preconcurrency import AVFoundation
import NaturalLanguage
import os

/// Errors thrown by IOSTranscriptionService during the record-transcribe cycle.
enum TranscriptionError: Error, Sendable {
    /// Recording was shorter than minimumDurationSeconds.
    case tooShort
    /// Silero VAD detected no voice activity.
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

/// Core ASR pipeline for iOS: record audio via AVAudioEngine, apply three-layer VAD,
/// transcribe via Parakeet TDT v3 (FluidAudio), and detect language post-hoc
/// with NLLanguageRecognizer.
@MainActor
class IOSTranscriptionService: ObservableObject {

    // MARK: - State machine

    enum State: Equatable, Sendable {
        case idle
        case recording
        case transcribing
    }

    @Published var state: State = .idle
    @Published var lastResult: DicticusTranscriptionResult?
    @Published var error: String?

    @AppStorage("useCustomDictionary") var useCustomDictionary = true
    @AppStorage("useITN") var useITN = true

    // MARK: - Configuration

    static let vadProbabilityThreshold: Float = 0.75
    var silenceThreshold: Float = IOSTranscriptionService.vadProbabilityThreshold
    let minimumDurationSeconds: Float = 0.3

    // MARK: - Private

    private let asrManager: AsrManager
    private let vadManager: VadManager
    private let audioEngine = AVAudioEngine()
    private let sampleBuffer = AudioSampleBuffer()
    private let sampleRate: Double = 16000

    // MARK: - Initialization

    init(asrManager: AsrManager, vadManager: VadManager) {
        self.asrManager = asrManager
        self.vadManager = vadManager
    }

    // MARK: - Recording

    /// Start recording via AVAudioEngine.
    /// On iOS, this requires explicit AVAudioSession management.
    func startRecording() throws {
        guard state == .idle else { throw TranscriptionError.busy }
        sampleBuffer.clear()

        // iOS ONLY: activate AVAudioSession
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .default)
        try session.setActive(true)

        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        Self.installTap(on: inputNode, format: inputFormat, buffer: sampleBuffer)

        try audioEngine.start()
        state = .recording
    }

    /// Install audio tap in a nonisolated context so the closure has no actor affinity.
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

    func stopRecordingAndTranscribe() async throws -> DicticusTranscriptionResult {
        guard state == .recording else { throw TranscriptionError.notRecording }

        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        state = .transcribing

        defer { if state == .transcribing { state = .idle } }

        let samples = sampleBuffer.drain()

        let inputSampleRate = audioEngine.inputNode.outputFormat(forBus: 0).sampleRate
        let resampledSamples: [Float]
        if abs(inputSampleRate - sampleRate) > 1.0 {
            resampledSamples = resampleAudio(samples, from: inputSampleRate, to: sampleRate)
        } else {
            resampledSamples = samples
        }

        let durationSeconds = Float(resampledSamples.count) / Float(sampleRate)

        // Layer 1: Minimum duration guard
        guard durationSeconds >= minimumDurationSeconds else {
            throw TranscriptionError.tooShort
        }

        // Layer 2: Silero VAD pre-filter
        let vadResults = try await vadManager.process(resampledSamples)
        let hasVoice = vadResults.contains { $0.probability > silenceThreshold }
        guard hasVoice else {
            throw TranscriptionError.silenceOnly
        }

        // Layer 3: Transcribe via Parakeet TDT v3
        let result = try await asrManager.transcribe(resampledSamples)

        var processedText = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !processedText.isEmpty else {
            throw TranscriptionError.noResult
        }

        // Script validation
        guard !Self.containsNonLatinScript(processedText) else {
            throw TranscriptionError.unexpectedLanguage
        }

        let detectedLanguage = detectLanguage(processedText)

        // Post-processing: Custom Dictionary
        if useCustomDictionary {
            processedText = DictionaryService.shared.apply(to: processedText)
        }

        // Post-processing: ITN (Inverse Text Normalization)
        if useITN {
            processedText = ITNUtility.applyITN(to: processedText, language: detectedLanguage)
        }

        let transcriptionResult = DicticusTranscriptionResult(
            text: processedText,
            language: detectedLanguage,
            confidence: result.confidence
        )

        lastResult = transcriptionResult
        state = .idle
        return transcriptionResult
    }

    // MARK: - Resampling

    private func resampleAudio(_ samples: [Float], from sourceSampleRate: Double, to targetSampleRate: Double) -> [Float] {
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
            return resampleLinear(samples, from: sourceSampleRate, to: targetSampleRate)
        }

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
        final class ConversionState: @unchecked Sendable { var didProvideData = false }
        let state = ConversionState()
        
        converter.convert(to: outputBuffer, error: &conversionError) { _, outStatus in
            if state.didProvideData {
                outStatus.pointee = .endOfStream
                return nil
            }
            state.didProvideData = true
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

    private static let latinRanges: [ClosedRange<UInt32>] = [
        0x0000...0x007F,
        0x0080...0x00FF,
        0x0100...0x024F,
        0x1E00...0x1EFF,
        0x2C60...0x2C7F,
        0xA720...0xA7FF,
        0x0300...0x036F,
    ]

    static func containsNonLatinScript(_ text: String) -> Bool {
        let log = Logger(subsystem: "com.dicticus", category: "validation")
        let letters = CharacterSet.letters
        let allowedSymbols = CharacterSet(charactersIn: "$€£¥©®™°%‰#@&*-+=/\\|<>{}[]()\"'`^~_")
        let allowedPunctuation = CharacterSet.punctuationCharacters
        let allowedNumbers = CharacterSet.decimalDigits
        
        for scalar in text.unicodeScalars {
            if allowedNumbers.contains(scalar) || allowedPunctuation.contains(scalar) || allowedSymbols.contains(scalar) {
                continue
            }
            if letters.contains(scalar) {
                let value = scalar.value
                let isLatin = latinRanges.contains { $0.contains(value) }
                if !isLatin {
                    log.warning("Blocked non-Latin character: \(String(scalar)) (U+\(String(value, radix: 16)))")
                    return true
                }
            }
        }
        return false
    }

    // MARK: - Language detection

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

    func restrictLanguage(_ detected: String) -> String {
        let allowed: Set<String> = ["de", "en"]
        return allowed.contains(detected) ? detected : "en"
    }
}

// MARK: - Test support

#if DEBUG
extension IOSTranscriptionService {
    static func testRestrictLanguage(_ detected: String) -> String {
        let allowed: Set<String> = ["de", "en"]
        return allowed.contains(detected) ? detected : "en"
    }

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

    static func isFluidAudioAvailable() -> Bool {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        guard let base = appSupport else { return false }
        let fluidAudioModels = base.appendingPathComponent("FluidAudio/Models")
        return (try? FileManager.default.contentsOfDirectory(atPath: fluidAudioModels.path))?.isEmpty == false
    }

    static func makeForTesting() async throws -> IOSTranscriptionService? {
        do {
            let models = try await AsrModels.downloadAndLoad(version: .v3)
            let manager = AsrManager(config: .default)
            try await manager.loadModels(models)
            let vad = try await VadManager(config: VadConfig(defaultThreshold: Float(vadProbabilityThreshold)))
            return IOSTranscriptionService(asrManager: manager, vadManager: vad)
        } catch {
            return nil
        }
    }
}
#endif
