import Foundation
import NaturalLanguage

/// Prompt builder for AI text cleanup via Gemma 4 E2B.
///
/// Uses a single user-configurable instruction for all languages.
/// For single-language text, passes `Language:` context so the LLM applies
/// correct grammar rules. For mixed-language text (detected via NLLanguageRecognizer),
/// omits the `Language:` line to prevent Gemma 4 E2B from translating
/// the minority language to the dominant one.
///
/// Per D-03: Output must be plain text only — no markdown, no formatting, no explanations.
///
/// Uses Gemma 4 single-turn chat format with Input/Output priming:
///   <start_of_turn>user\n{instruction}\n\n[Language: {lang}\n]Input: {text}<end_of_turn>\n<start_of_turn>model\nOutput:
///
/// Source: https://ai.google.dev/gemma/docs/core/prompt-structure
struct CleanupPrompt {

    /// UserDefaults key for the custom cleanup instruction.
    static let customInstructionKey = "cleanupInstruction"

    /// Default cleanup instruction — used when no custom prompt is configured.
    ///
    /// Covers: minimal edits, phonetic/dialect intent inference, semantic word correction,
    /// grammar, punctuation, capitalization, ITN, and plain text output.
    static let defaultInstruction = """
        You are an expert editor specializing in correcting dictated text from non-native speakers. Your task is to fix grammar, punctuation, and capitalization while inferring the speaker's true intent from phonetic approximations and incorrect word choices.
        
        Rules:
        1. Perform minimal edits necessary to make the text grammatically correct and semantically logical.
        2. Recognize phonetic errors where the speech recognition misheard a dialect, accent, or spoken abbreviation (e.g., "mini chef het" -> "mein Chef hat").
        3. Identify and replace semantically incorrect words with the intended word based on context (e.g., using "gestanden" instead of "gefragt").
        4. Fix obvious ASR artifacts and filler words (ähm, also, ja).
        5. Preserve the original meaning and tone — do NOT rewrite for style if the meaning is clear.
        6. Do NOT add quotation marks around the output.
        7. Write all numbers as digits (e.g., 'twenty three' -> '23', 'dreiundzwanzig' -> '23'). Use German ordinal convention (3. = dritte).
        8. Output ONLY the polished text — no preamble, no explanations.

        ### Examples:
        Input: also ich habe mit einem Minischefeld geredet
        Output: Also, ich habe mit meinem Chef geredet.
        
        Input: ich habe ihn gestanden ob er zeit hat
        Output: Ich habe ihn gefragt, ob er Zeit hat.
        
        Input: das ist ein sehr gutes projekt wo wir machen
        Output: Das ist ein sehr gutes Projekt, das wir machen.
        """

    /// The active instruction — custom if set, otherwise default.
    static var activeInstruction: String {
        let custom = UserDefaults.standard.string(forKey: customInstructionKey) ?? ""
        return custom.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? defaultInstruction
            : custom
    }

    /// Build a complete Gemma 4 single-turn cleanup prompt.
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
