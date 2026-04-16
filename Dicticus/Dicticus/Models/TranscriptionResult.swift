import Foundation

/// App-level transcription result wrapping WhisperKit output.
///
/// Extracts value-type data from WhisperKit's TranscriptionResult class
/// immediately after transcription to avoid reference-type pitfalls (Pitfall 4 in 02-RESEARCH.md).
/// WhisperKit's TranscriptionResult has been an open class since v0.15.0, so we copy
/// values into this Sendable struct as soon as transcription completes.
struct DicticusTranscriptionResult: Sendable {
    /// Transcribed text output, trimmed of leading/trailing whitespace.
    let text: String
    /// Detected language code, restricted to "de" or "en" (D-11 in 02-RESEARCH.md).
    /// Whisper supports 99 languages; we post-filter to the two app languages.
    let language: String
    /// Confidence score from 0.0 to 1.0, derived from 1 - noSpeechProb of first segment.
    /// Higher values indicate higher confidence that speech was present.
    let confidence: Float
}
