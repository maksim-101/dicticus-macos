import Foundation
import NaturalLanguage

/// Prompt builder for AI text cleanup via Gemma 4 E2B.
///
/// 2026-05-05 REFACTOR (Variant V5): Strict Verbatim.
/// Iterates on V4 (also 2026-05-05). V4's "drop original phrase before
/// connector self-correction" instruction was empirically catastrophic on
/// long-form dictation — the model over-generalized "drop preamble before
/// connector" and ate legitimate filler-y intros ("I would say, and...",
/// "And so in between..."), plus collapsed multi-corrections to last-only.
///
/// Harness evidence (.planning/debug/harness/results/v4_vs_v5_v6_v7_keyset.tsv,
/// 2026-05-05 with the production Gemma 4 E2B GGUF, seed=42):
///   F11 long-form: V4 lev=11 (drops "And so", paraphrases prefix);
///                  V5 lev=0  (perfect preservation).
///   F36 filler-prefix: V4 drops "I would say, and..." entirely;
///                      V5 lev=1 (preserves all content, "30"→"thirty").
///   F38 short self-correction: V4 collapses "Wednesday, no actually
///                              Monday" to just "Monday"; V5 preserves
///                              with comma punctuation.
///   F43 "and so in between": V4 strips "and so"; V5 preserves.
///   F16/F27/F28 multi-correction: V4 collapses to last-only;
///                                 V5 preserves all options.
///
/// V5 trades the auto-resolve feature ("9 Uhr, ach ich meine 8 Uhr" →
/// "8 Uhr") for content safety. Self-corrections are now preserved
/// VERBATIM with comma flanking. Tradeoff is acceptable because:
///   • Auto-resolve was a niche win that broke far more common cases.
///   • Output stays ASR-faithful — no hallucination risk.
///   • User can manually edit if a literal repair-string output is
///     undesirable; they cannot recover content the model deleted.
///
/// V5 structure:
///   1. Strict imperative header — only capitalization, punctuation,
///      known-term fixes, and pure-filler removal allowed. Self-
///      corrections and all other tokens preserved verbatim.
///   2. Known terms (when dictionary context provided).
///   3. Language banner (DE only; Swiss-orthography note if enabled).
///   4. Two safe few-shots per language — one dictionary/grammar fix,
///      one self-correction-PRESERVED example to anchor the rule.
///   5. Final "In: <text>\nOut:" anchor for completion.
struct CleanupPrompt {

    static let customInstructionKey = "cleanupInstruction"
    static let defaultInstruction = "Minimal cleanup of dictated speech (V5 strict-verbatim)."

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

        // Step 1: Strict-verbatim imperative header.
        prompt += "Task: Minimal cleanup of dictated speech. "
        prompt += "Only fix capitalization, sentence-final punctuation, and obvious mishearings of the known terms below. "
        prompt += "Remove only pure filler: 'uh', 'um', 'ähm'. "
        prompt += "Keep EVERY other word the speaker said, including all self-corrections "
        prompt += "('no', 'wait', 'actually', 'I mean', 'nein', 'eigentlich', 'moment', 'ach ich meine') verbatim. "
        prompt += "Never delete substantive content. Never add words not in the input. "
        prompt += "Never paraphrase. Never answer questions.\n\n"

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

        // Step 3 + 4: Language banner + safe few-shots (dictionary + preserved self-correction).
        if language == "de" {
            let orthography = swissEnabled ? " (Schweizer Orthographie: ss statt ß.)" : ""
            prompt += "Sprache: Standard-Hochdeutsch.\(orthography)\n\n"

            prompt += "In: das sieht gut aus jetzt bitte mach gest housekeeping.\n"
            prompt += "Out: Das sieht gut aus, jetzt bitte mach GSD housekeeping.\n\n"

            prompt += "In: ähm ich denke das meeting ist am dienstag, nein eigentlich am montag.\n"
            prompt += "Out: Ich denke, das Meeting ist am Dienstag, nein eigentlich am Montag.\n\n"
        } else {
            prompt += "In: this looks good now please do gest the housekeeping.\n"
            prompt += "Out: This looks good now, please do GSD housekeeping.\n\n"

            prompt += "In: uh i think the meeting is at nine wait actually it is at eight.\n"
            prompt += "Out: I think the meeting is at nine, wait, actually it is at eight.\n\n"
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
