import Foundation
import NaturalLanguage

/// Prompt builder for AI text cleanup via Gemma 4 E2B.
///
/// 2026-05-05 REFACTOR (Variant V4): Self-Correction Resolution.
/// Iterates on V3 (2026-05-04). V3's "preserve self-corrections" rule
/// was too conservative — users dictating "9 Uhr, ach ich meine 8 Uhr"
/// expect cleanup to RESOLVE the repair (drop "9 Uhr", keep "8 Uhr"),
/// not preserve the corrected-twice phrase verbatim.
///
/// V4 flips that rule: connector-introduced self-corrections are
/// RESOLVED. Structural negations ("nicht X, sondern Y") are explicitly
/// called out as preservation cases since they share surface markers
/// with self-corrections but are rhetorical patterns, not repairs.
///
/// V4 structure:
///   1. Imperative task header — fix surface, remove filler, RESOLVE
///      self-corrections, preserve structural negations.
///   2. Known terms (when dictionary context provided).
///   3. Language banner (DE only; Swiss-orthography note if enabled).
///   4. Few-shots per language — dictionary fix, disfluency removal,
///      self-correction resolution, structural-negation preservation.
///   5. Final "In: <text>\nOut:" anchor for completion.
///
/// Risk note: V0 also collapsed self-corrections, but V0 lacked an
/// explicit instruction header and over-extended into paraphrasing
/// arbitrary content. V4 retains the strict task header + the "never
/// add words / never paraphrase / never answer questions" rails to
/// keep the resolution scope tight to comma/period-prefixed connector
/// patterns only.
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
        prompt += "When the speaker corrects themselves mid-sentence with "
        prompt += "'no', 'wait', 'actually', 'I mean', 'nein', 'moment', 'eigentlich', 'ach ich meine', "
        prompt += "drop the original phrase and keep only the corrected version "
        prompt += "(e.g. '9 Uhr, ach ich meine 8 Uhr' → '8 Uhr'). "
        prompt += "Preserve all OTHER substantive content, including structural negations "
        prompt += "like 'nicht X, sondern Y' or 'not X but Y' — those are not self-corrections. "
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
            prompt += "Out: Ich denke, das Meeting ist am Montag.\n\n"

            prompt += "In: das war nicht dienstag sondern montag um 9 uhr ach ich meine 8 uhr.\n"
            prompt += "Out: Das war nicht Dienstag, sondern Montag um 8 Uhr.\n\n"
        } else {
            prompt += "In: this looks good now please do gest the housekeeping.\n"
            prompt += "Out: This looks good now, please do GSD housekeeping.\n\n"

            prompt += "In: uh i think we should um you know maybe try the new approach.\n"
            prompt += "Out: I think we should maybe try the new approach.\n\n"

            prompt += "In: meeting at nine wait actually it is at eight.\n"
            prompt += "Out: Meeting at eight.\n\n"

            prompt += "In: the demo is on tuesday no actually wednesday at three pm.\n"
            prompt += "Out: The demo is on Wednesday at 3 PM.\n\n"
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
