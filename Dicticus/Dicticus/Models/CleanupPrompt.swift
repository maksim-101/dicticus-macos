import Foundation

/// Prompt builder for AI text cleanup via Gemma 3.
///
/// Uses a single user-configurable instruction for both languages.
/// The detected language is passed as context so the LLM applies
/// language-appropriate grammar rules automatically.
///
/// Per D-03: Output must be plain text only — no markdown, no formatting, no explanations.
/// Per D-13: Language auto-selected from DicticusTranscriptionResult.language ("de" or "en").
///
/// Uses Gemma 3 single-turn chat format:
///   <start_of_turn>user\n{instruction}\n\nLanguage: {lang}\nText: {text}<end_of_turn>\n<start_of_turn>model\n
///
/// Source: https://ai.google.dev/gemma/docs/core/prompt-structure
struct CleanupPrompt {

    /// UserDefaults key for the custom cleanup instruction.
    static let customInstructionKey = "cleanupInstruction"

    /// Default cleanup instruction — used when no custom prompt is configured.
    ///
    /// Covers: grammar, punctuation, capitalization, smooth spoken phrasing,
    /// fix ASR artifacts (misrecognized filler words like "ähm" → "am"),
    /// replace profanity, preserve meaning, plain text output only.
    static let defaultInstruction = """
        Polish the following dictated text for written form. \
        Fix grammar, punctuation, and capitalization. \
        Smooth awkward spoken phrasing so the text reads fluently and professionally. \
        Fix speech recognition artifacts such as misrecognized filler words. \
        Replace profanity and vulgar language with clean alternatives. \
        Preserve the original meaning. \
        Output ONLY the polished text, no explanations.
        """

    /// The active instruction — custom if set, otherwise default.
    static var activeInstruction: String {
        let custom = UserDefaults.standard.string(forKey: customInstructionKey) ?? ""
        return custom.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? defaultInstruction
            : custom
    }

    /// Build a complete Gemma 3 single-turn cleanup prompt.
    ///
    /// - Parameters:
    ///   - text: Raw ASR transcription to clean up
    ///   - language: "de" or "en" from DicticusTranscriptionResult.language
    /// - Returns: Complete prompt string with Gemma 3 control tokens
    static func build(for text: String, language: String) -> String {
        let languageName = language == "de" ? "German" : "English"
        let instruction = activeInstruction
        return """
            <start_of_turn>user
            \(instruction)

            Language: \(languageName)
            Text: \(text)<end_of_turn>
            <start_of_turn>model
            """
    }
}
