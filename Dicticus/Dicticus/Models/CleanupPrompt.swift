import Foundation
import NaturalLanguage

/// Prompt builder for AI text cleanup via Gemma 3.
///
/// Uses a single user-configurable instruction for all languages.
/// For single-language text, passes `Language:` context so the LLM applies
/// correct grammar rules. For mixed-language text (detected via NLLanguageRecognizer),
/// omits the `Language:` line to prevent Gemma 3 1B from translating
/// the minority language to the dominant one.
///
/// Per D-03: Output must be plain text only — no markdown, no formatting, no explanations.
///
/// Uses Gemma 3 single-turn chat format with Input/Output priming:
///   <start_of_turn>user\n{instruction}\n\n[Language: {lang}\n]Input: {text}<end_of_turn>\n<start_of_turn>model\nOutput:
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
        When the speaker corrects themselves mid-sentence, keep only the final corrected version. \
        Replace profanity and vulgar language with clean alternatives. \
        Keep each language exactly as spoken — never translate between languages. \
        Preserve the original meaning. \
        Output ONLY the polished text — no preamble, no quotes, no explanations.
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
    /// Uses Input/Output format which small models (1B) handle reliably.
    /// The instruction comes first, then the raw text labeled "Input:",
    /// and the model is primed to continue after "Output:" with the polished text.
    ///
    /// - Parameters:
    ///   - text: Raw ASR transcription to clean up
    ///   - language: "de" or "en" from DicticusTranscriptionResult.language
    /// - Returns: Complete prompt string with Gemma 3 control tokens
    static func build(for text: String, language: String) -> String {
        let instruction = activeInstruction
        let languageLine: String

        if isMixedLanguage(text) {
            // Mixed language: omit Language line to avoid translation of minority language
            languageLine = ""
        } else {
            let languageName = language == "de" ? "German" : "English"
            languageLine = "Language: \(languageName)\n"
        }

        // Sanitize control tokens from ASR text to prevent prompt injection
        let sanitizedText = sanitizeControlTokens(text)

        return "<start_of_turn>user\n\(instruction)\n\n\(languageLine)Input: \(sanitizedText)<end_of_turn>\n<start_of_turn>model\nOutput: "
    }

    /// Strip Gemma control tokens from user text to prevent prompt injection.
    /// ASR output rarely contains angle-bracket sequences, but if it does,
    /// these could be parsed as format tokens by the LLM tokenizer.
    static func sanitizeControlTokens(_ text: String) -> String {
        var result = text
        for token in ["<start_of_turn>", "<end_of_turn>", "<bos>", "<eos>"] {
            result = result.replacingOccurrences(of: token, with: "")
        }
        return result
    }

    /// Detect whether the text contains multiple languages via per-sentence analysis.
    ///
    /// NLLanguageRecognizer only reports one dominant language for the full text.
    /// This splits into sentences and detects language per sentence, returning true
    /// if at least two different languages are found. Prevents the `Language:` line
    /// from causing the LLM to translate the minority language.
    ///
    /// **Known limitation (Gemma 3 1B):** Even with the `Language:` line omitted,
    /// the 1B model is too small to reliably follow the "never translate between
    /// languages" instruction. It defaults to its dominant training language (English)
    /// and translates the minority language. Mixed-language AI cleanup is therefore
    /// unreliable with the current model. Single-language cleanup works correctly
    /// for both German and English. A larger model (e.g. Phi-3 Mini 3.8B) or a
    /// split-per-language-then-reassemble strategy would be needed to fix this.
    static func isMixedLanguage(_ text: String) -> Bool {
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = text
        var languages = Set<String>()

        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let sentence = String(text[range])
            let recognizer = NLLanguageRecognizer()
            recognizer.processString(sentence)
            if let lang = recognizer.dominantLanguage?.rawValue {
                languages.insert(lang)
            }
            return languages.count < 2  // Stop early once we find 2 languages
        }

        return languages.count >= 2
    }
}
