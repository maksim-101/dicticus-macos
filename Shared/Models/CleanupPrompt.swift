import Foundation
import NaturalLanguage

/// Prompt builder for AI text cleanup via Gemma 4 E2B.
/// 
/// 2026-05-03 REFACTOR (Variant I): Shifted to raw text-to-text completion architecture
/// to suppress the model's 'AI Assistant' personality which caused aggressive paraphrasing.
/// Removes all chat template markers (<start_of_turn>) and enforces strict 1:1 preservation
/// rules anchored by a technical glossary and few-shot examples.
struct CleanupPrompt {

    static let customInstructionKey = "cleanupInstruction"

    static let defaultInstruction = """
    Professional transcription polishing.
    Strict Rules:
    1. Preserve all conversational words, preambles, and intent exactly. NO paraphrasing.
    2. Only fix phonetic ASR errors and clear grammar issues.
    3. Reference technical glossary for correct names and project titles.
    """

    static func userInstruction(language: String? = nil) -> String {
        let custom = UserDefaults.standard.string(forKey: customInstructionKey) ?? ""
        if !custom.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return custom
        }
        
        if language == "de" {
            return """
            Objective: Professionelle Bereinigung von Transkripten.
            Strict Rules:
            1. Behalte den Wortlaut, Einleitungen und die Absicht des Sprechers exakt bei. KEINE Paraphrasen.
            2. Korrigiere nur phonetische ASR-Fehler und klare Grammatikprobleme.
            3. Nutze das Glossar für korrekte Fachbegriffe und Namen.
            """
        } else {
            return defaultInstruction
        }
    }

    /// Build the cleanup prompt using raw completion architecture.
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

        let instr = userInstruction(language: language)
        let sanitizedText = sanitizeControlTokens(text)
        
        var prompt = "\(instr)\n\n"

        // Step 1: Technical Glossary
        if let dict = dictionaryContext, !dict.isEmpty {
            prompt += "Glossary:\n"
            for (original, replacement) in dict.sorted(by: { $0.key < $1.key }) {
                if original == replacement {
                    prompt += "- \(replacement)\n"
                } else {
                    prompt += "- \(original) -> \(replacement)\n"
                }
            }
            prompt += "\n"
        }

        // Step 2: Few-Shot Anchors (Language Specific)
        if language == "de" {
            let orthography = swissEnabled ? " (mit Schweizer Rechtschreibung: ss statt ß)" : ""
            prompt += "Rule: Standard-Hochdeutsch\(orthography).\n\n"
            
            prompt += "Original: das sieht gut aus jetzt bitte mach gest housekeeping.\n"
            prompt += "Corrected: Das sieht gut aus, jetzt bitte mach GSD housekeeping.\n\n"
            
            prompt += "Original: ich arbeite mit dectic tools auf truenest.\n"
            prompt += "Corrected: Ich arbeite mit Dicticus auf TrueNAS.\n\n"
            
            prompt += "Original: mein erstes meeting wohl am dienstag um 9 uhr sei ach ein moment das war montag um 8 uhr.\n"
            prompt += "Corrected: Mein erstes Meeting wohl am Montag um 8 Uhr sei.\n\n"
        } else {
            prompt += "Original: this looks good now please do gest the housekeeping.\n"
            prompt += "Corrected: This looks good now, please do GSD housekeeping.\n\n"
            
            prompt += "Original: i agree with your plan though you can set it up yourself in dr chi on truenorth.\n"
            prompt += "Corrected: I agree with your plan, though you can set it up yourself in Dockge on TrueNAS.\n\n"
            
            prompt += "Original: meeting at nine wait actually it is at eight.\n"
            prompt += "Corrected: Meeting at eight.\n\n"
        }

        // Step 3: Input for Completion
        prompt += "Original: \(sanitizedText)\n"
        prompt += "Corrected:"

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
