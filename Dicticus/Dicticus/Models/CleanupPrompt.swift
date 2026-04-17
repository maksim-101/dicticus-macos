import Foundation

/// Language-specific Gemma 3 prompt templates for conservative text cleanup.
///
/// Per D-01: Conservative cleanup only — grammar, punctuation, capitalization, filler removal.
/// Per D-02: Language-specific prompts — German and English have different grammar rules.
/// Per D-03: Output must be plain text only — no markdown, no formatting, no explanations.
/// Per D-13: Language auto-selected from DicticusTranscriptionResult.language ("de" or "en").
///
/// Uses Gemma 3 single-turn chat format:
///   <start_of_turn>user\n{instruction}\n\nText: {text}<end_of_turn>\n<start_of_turn>model\n
///
/// Source: https://ai.google.dev/gemma/docs/core/prompt-structure
struct CleanupPrompt {

    /// German cleanup instruction.
    ///
    /// Covers: Grammatik, Zeichensetzung, Grossschreibung, Fuellwoerter.
    /// Explicit "KEINE Woerter aendern" and "NICHT umformulieren" guards.
    /// Filler words listed: aehm, halt, also, quasi, sozusagen, ja, ne, genau.
    static let germanInstruction = """
        Korrigiere den folgenden diktierten Text. Behebe Grammatik-, Zeichensetzungs- und \
        Grossschreibungsfehler. Entferne Fuellwoerter (aehm, halt, also, quasi, sozusagen, \
        ja, ne, genau). Aendere KEINE Woerter und formuliere NICHT um. Gib NUR den \
        korrigierten Text aus, ohne Erklaerungen.
        """

    /// English cleanup instruction.
    ///
    /// Covers: grammar, punctuation, capitalization, filler words.
    /// Explicit "do NOT change any words" and "do NOT rephrase" guards.
    /// Filler words listed: um, uh, like, you know, so, basically, I mean, right.
    static let englishInstruction = """
        Fix the following dictated text. Correct grammar, punctuation, and capitalization \
        errors. Remove filler words (um, uh, like, you know, so, basically, I mean, right). \
        Do NOT change any words and do NOT rephrase. Output ONLY the corrected text, \
        no explanations.
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
