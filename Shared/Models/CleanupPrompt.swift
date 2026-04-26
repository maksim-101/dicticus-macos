import Foundation
import NaturalLanguage

/// Prompt builder for AI text cleanup via Gemma 4 E2B.
struct CleanupPrompt {

    static let customInstructionKey = "cleanupInstruction"

    static let defaultInstruction = """
    Rewrite the following transcribed text to be polished and grammatically correct. \
    Remove filler words and repetition. Write numbers as digits. \
    Apply the dictionary replacements if any. Output ONLY the polished text.
    """

    static func userInstruction() -> String {
        let custom = UserDefaults.standard.string(forKey: customInstructionKey) ?? ""
        return custom.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? defaultInstruction
            : custom
    }

    static func build(text: String, language: String? = nil, dictionaryContext: [String: String]? = nil) -> String {
        let instruction = userInstruction()
        
        var prompt = "<start_of_turn>user\n"
        prompt += "INSTRUCTION: \(instruction)\n"
        
        if let dict = dictionaryContext, !dict.isEmpty {
            prompt += "DICTIONARY:\n"
            for (original, replacement) in dict.sorted(by: { $0.key < $1.key }) {
                prompt += "- \(original) -> \(replacement)\n"
            }
        }
        
        if let lang = language {
            prompt += "LANGUAGE: \(lang == "de" ? "German" : "English")\n"
        }

        // D-18: Swiss German orthography prompt extension (scoped to German only).
        // Gated on BOTH the shared useSwissGerman AppGroup toggle AND language == "de".
        // Standard-German dictation stays untouched even if the Swiss toggle is ON.
        let swissDefaults = UserDefaults(suiteName: "group.com.dicticus") ?? UserDefaults.standard
        if swissDefaults.bool(forKey: "useSwissGerman") && language == "de" {
            prompt += "STYLE: Use Swiss German orthography (never use ß, always ss). "
            prompt += "Use Swiss thousands separator style (e.g. 1'250, not 1.250).\n"
            // D-D2 (Phase 19.5): Helvetism preservation block.
            prompt += "HELVETISMS: Prefer these Swiss German words when applicable: "
            prompt += SwissHelvetisms.words.joined(separator: ", ")
            prompt += ".\n"
        }

        // D-B1b (Phase 19.5): Currency anti-flip prompt anchor. Fires on ANY
        // de-language input that contains a currency token, regardless of the
        // Swiss toggle (per D-B2 — Gemma's EUR bias is a German-language issue,
        // not a Swiss-only one).
        // W8 lock: detect on raw `text`. sanitizeControlTokens only strips
        // Gemma turn tokens (never present in user dictation), so detection
        // on raw text is equivalent and avoids reordering existing code.
        if language == "de" {
            let detectedCurrencies = CurrencyAntiFlip.detectCurrencies(in: text)
            if !detectedCurrencies.isEmpty {
                let labels = detectedCurrencies.map(\.text).joined(separator: ", ")
                prompt += "STRICT: Keep currency exactly as written ("
                prompt += labels
                prompt += "). Do NOT translate, convert, or substitute one currency for another.\n"
            }
        }

        let sanitizedText = sanitizeControlTokens(text)
        prompt += "INPUT: \(sanitizedText)<end_of_turn>\n"
        prompt += "<start_of_turn>model\n"
        prompt += "OUTPUT:"
        
        return prompt
    }

    static func sanitizeControlTokens(_ text: String) -> String {
        var result = text
        for token in ["<start_of_turn>", "<end_of_turn>", "<bos>", "<eos>"] {
            result = result.replacingOccurrences(of: token, with: "")
        }
        return result
    }

    static func containsMixedLanguages(_ text: String) -> Bool {
        let recognizer = NLLanguageRecognizer()
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard sentences.count > 1 else { return false }

        var languages = Set<String>()
        for sentence in sentences {
            recognizer.processString(sentence)
            if let lang = recognizer.dominantLanguage?.rawValue {
                languages.insert(lang)
            }
            if languages.count >= 2 { return true }
        }

        return false
    }
}
