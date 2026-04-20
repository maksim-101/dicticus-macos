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
