import Foundation
import NaturalLanguage

/// Prompt builder for AI text cleanup via Gemma 4 E2B.
/// 
/// 2026-05-03 REFACTOR (Variant K): Minimalist Structured Completion.
/// Removes ALL headers (Task, Glossary, Examples) to completely suppress the 
/// model's 'Assistant' personality and meta-comments. Uses a minimalist 
/// 'Term: / In: / Out:' structure that anchors the model as a pure transformer.
struct CleanupPrompt {

    static let customInstructionKey = "cleanupInstruction"
    static let defaultInstruction = "Professional transcription polishing. (Minimalist)"

    static func build(
        text: String,
        language: String? = nil,
        dictionaryContext: [String: String]? = nil,
        useSwissGerman: Bool? = nil
    ) -> String {
        let swissEnabled: Bool = useSwissGerman ?? {
            let suite = UserDefaults(suiteName: "group.com.dicticus") ?? UserDefaults.standard
            return suite.bool(forKey: "useSwissGerman")
        }()

        let sanitizedText = sanitizeControlTokens(text)
        var prompt = ""

        // Step 1: Flat Glossary (No header)
        if let dict = dictionaryContext, !dict.isEmpty {
            for (original, replacement) in dict.sorted(by: { $0.key < $1.key }) {
                if original == replacement {
                    prompt += "Term: \(replacement)\n"
                } else {
                    prompt += "Term: \(original) -> \(replacement)\n"
                }
            }
            prompt += "\n"
        }

        // Step 2: Structured Examples (Minimal labels)
        if language == "de" {
            let orthography = swissEnabled ? " (ss statt ß)" : ""
            prompt += "Rule: Standard-Hochdeutsch\(orthography)\n\n"
            
            prompt += "In: das sieht gut aus jetzt bitte mach gest housekeeping.\n"
            prompt += "Out: Das sieht gut aus, jetzt bitte mach GSD housekeeping.\n\n"
            
            prompt += "In: ich arbeite mit dectic tools auf truenest.\n"
            prompt += "Out: Ich arbeite mit Dicticus auf TrueNAS.\n\n"
            
            prompt += "In: mein erstes meeting wohl am dienstag um 9 uhr sei ach ein moment das war montag um 8 uhr.\n"
            prompt += "Out: Mein erstes Meeting wohl am Montag um 8 Uhr sei.\n\n"
        } else {
            prompt += "In: this looks good now please do gest the housekeeping.\n"
            prompt += "Out: This looks good now, please do GSD housekeeping.\n\n"
            
            prompt += "In: let's see whether w and if so you can continue with gest housekeeping.\n"
            prompt += "Out: Let's see whether this is good, and if so, you can continue with GSD housekeeping.\n\n"
            
            prompt += "In: i agree with your plan though you can set it up yourself in dr chi on truenorth.\n"
            prompt += "Out: I agree with your plan, though you can set it up yourself in Dockge on TrueNAS.\n\n"
            
            prompt += "In: meeting at nine wait actually it is at eight.\n"
            prompt += "Out: Meeting at eight.\n\n"
        }

        // Step 3: Input for Completion
        prompt += "In: \(sanitizedText)\n"
        prompt += "Out:"

        return prompt
    }

    static func sanitizeControlTokens(_ text: String) -> String {
        var result = text
        for token in ["<start_of_turn>", "<end_of_turn>", "<bos>", "<eos>", "<|channel>", "Thinking Process:", "Thinking Process"] {
            result = result.replacingOccurrences(of: token, with: "")
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
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
