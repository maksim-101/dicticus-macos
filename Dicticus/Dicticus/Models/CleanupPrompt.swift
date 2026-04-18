import Foundation

/// Language-specific Gemma 3 prompt templates for text polishing.
///
/// The LLM receives ASR output that already has filler words removed by the
/// transcription pipeline. Its job is to polish the text into readable written
/// form: fix grammar, smooth awkward spoken phrasing, and replace profanity
/// with clean alternatives — while preserving the original meaning.
///
/// Per D-02: Language-specific prompts — German and English have different grammar rules.
/// Per D-03: Output must be plain text only — no markdown, no formatting, no explanations.
/// Per D-13: Language auto-selected from DicticusTranscriptionResult.language ("de" or "en").
///
/// Uses Gemma 3 single-turn chat format:
///   <start_of_turn>user\n{instruction}\n\nText: {text}<end_of_turn>\n<start_of_turn>model\n
///
/// Source: https://ai.google.dev/gemma/docs/core/prompt-structure
struct CleanupPrompt {

    /// German polish instruction.
    ///
    /// Covers: Grammatik, Zeichensetzung, Grossschreibung, gesprochene Formulierungen
    /// in Schriftsprache umwandeln, Schimpfwoerter durch neutrale Alternativen ersetzen.
    static let germanInstruction = """
        Poliere den folgenden diktierten Text fuer die Schriftform. Korrigiere Grammatik, \
        Zeichensetzung und Grossschreibung. Glaette unbeholfene gesprochene Formulierungen, \
        damit der Text fluessig und professionell lesbar ist. Ersetze Schimpfwoerter und \
        vulgaere Ausdruecke durch neutrale Alternativen. Bewahre die urspruengliche \
        Bedeutung. Gib NUR den polierten Text aus, ohne Erklaerungen.
        """

    /// English polish instruction.
    ///
    /// Covers: grammar, punctuation, capitalization, smooth spoken phrasing into
    /// written form, replace profanity with clean alternatives.
    static let englishInstruction = """
        Polish the following dictated text for written form. Fix grammar, punctuation, \
        and capitalization. Smooth awkward spoken phrasing so the text reads fluently \
        and professionally. Replace profanity and vulgar language with clean alternatives. \
        Preserve the original meaning. Output ONLY the polished text, no explanations.
        """

    /// Build a complete Gemma 3 single-turn cleanup prompt.
    ///
    /// - Parameters:
    ///   - text: Raw ASR transcription to clean up
    ///   - language: "de" or "en" from DicticusTranscriptionResult.language
    /// - Returns: Complete prompt string with Gemma 3 control tokens
    static func build(for text: String, language: String) -> String {
        let instruction: String
        switch language {
        case "de":
            instruction = germanInstruction
        default:
            instruction = englishInstruction
        }
        return "<start_of_turn>user\n\(instruction)\n\nText: \(text)<end_of_turn>\n<start_of_turn>model\n"
    }
}
