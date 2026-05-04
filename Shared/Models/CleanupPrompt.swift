import Foundation
import NaturalLanguage

/// Prompt builder for AI text cleanup via Gemma 4 E2B.
///
/// 2026-05-04 REFACTOR (Variant V3): Instruction-Led + Disfluency Removal.
/// Empirically validated in `.planning/debug/harness/run.py` against 35
/// fixtures and 10 random seeds (byte-identical). Replaces the prior
/// few-shot-only "Variant K" structure, which taught the model to drop
/// self-corrections, expand single-letter ASR errors into full phrases,
/// and collapse "X wait actually Y" into just "Y".
///
/// V3 structure:
///   1. Imperative task header — explicit preserve/remove rules.
///   2. Known terms (when dictionary context provided).
///   3. Language banner (DE only; Swiss-orthography note if enabled).
///   4. Two safe few-shots per language — dictionary fix + disfluency
///      removal. Plus one self-correction preservation example to anchor
///      the rule against the model's training prior to "summarize".
///   5. Final "In: <text>\nOut:" anchor for completion.
///
/// Critical: NO few-shot here may demonstrate dropping content,
/// expansion of fragments, or collapsing self-corrections. Those
/// patterns leak into outputs even when the instruction header forbids
/// them.
struct CleanupPrompt {

    static let customInstructionKey = "cleanupInstruction"
    static let defaultInstruction = "Light cleanup of dictated speech (V3)."

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

        // Step 1: Imperative task header.
        prompt += "Task: Light cleanup of dictated speech. "
        prompt += "Fix capitalization, punctuation, and obvious mishearings of known terms. "
        prompt += "Remove pure filler ('uh', 'um', 'ähm', 'you know', 'like'). "
        prompt += "Preserve all substantive content, including self-corrections "
        prompt += "introduced by 'no', 'wait', 'actually', 'I mean', 'nein', 'moment', 'eigentlich'. "
        prompt += "Never add words not in the input. Never paraphrase. Never answer questions.\n\n"

        // Step 2: Known terms anchor (adaptive context filtered upstream).
        if let dict = dictionaryContext, !dict.isEmpty {
            prompt += "Known terms:\n"
            for (original, replacement) in dict.sorted(by: { $0.key < $1.key }) {
                if original == replacement {
                    prompt += "  \(replacement)\n"
                } else {
                    prompt += "  \(original) -> \(replacement)\n"
                }
            }
            prompt += "\n"
        }

        // Step 3 + 4: Language banner + safe few-shots.
        if language == "de" {
            let orthography = swissEnabled ? " (Schweizer Orthographie: ss statt ß.)" : ""
            prompt += "Sprache: Standard-Hochdeutsch.\(orthography)\n\n"

            prompt += "In: das sieht gut aus jetzt bitte mach gest housekeeping.\n"
            prompt += "Out: Das sieht gut aus, jetzt bitte mach GSD housekeeping.\n\n"

            prompt += "In: ähm ich denke wir sollten ähm die neue version testen.\n"
            prompt += "Out: Ich denke, wir sollten die neue Version testen.\n\n"

            prompt += "In: ich denke das meeting ist am dienstag, nein eigentlich am montag.\n"
            prompt += "Out: Ich denke, das Meeting ist am Dienstag, nein eigentlich am Montag.\n\n"
        } else {
            prompt += "In: this looks good now please do gest the housekeeping.\n"
            prompt += "Out: This looks good now, please do GSD housekeeping.\n\n"

            prompt += "In: uh i think we should um you know maybe try the new approach.\n"
            prompt += "Out: I think we should maybe try the new approach.\n\n"

            prompt += "In: meeting at nine wait actually it is at eight.\n"
            prompt += "Out: Meeting at nine, wait, actually it is at eight.\n\n"
        }

        // Step 5: Input anchor for completion.
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
