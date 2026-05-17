import Foundation
import NaturalLanguage

/// Prompt builder for AI text cleanup via Gemma 4 E2B.
///
/// Phase 25.1-02 (2026-05-17) — paper §6.2 XML output tags:
///
/// Gemma 4 E2B Q4_K_M is now instructed to wrap its final output in
/// `<corrected_text>...</corrected_text>` tags. The parser (CleanupService.
/// stripPreamble) extracts the envelope contents BEFORE the existing
/// whitespace / contractions / chat-template normalization runs. When the
/// envelope is missing or malformed (quantized 2B models occasionally forget
/// the closing tag on long outputs — paper §6.2 known risk), the parser
/// falls back to the raw text verbatim — no new failure mode.
///
/// This addresses defect Class D from 25-03 (live capture 2026-05-17 05:36:19:
/// `<unk>` token leakage). The envelope contract is the boundary at which
/// the parser also strips `<unk>` sentinels that ASR leaks and the LLM
/// faithfully echoes per the smart-verbatim contract.
///
/// Trailing-period-on-fragment artifacts (Class D second exemplar:
/// `...spelling acronyms not being.`) are NOT addressed here — those are
/// dialect/idiom-territory and routed to Plan 25.1-04 disfluency work.
/// Output safety gates (NLD/Jaccard) are routed to Plan 25.1-06.
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
    static let defaultInstruction = "Minimal cleanup of dictated speech (V16-COMPOSITE smart-verbatim + XML envelope, H3+H4)."

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

        // Step 1: Smart-verbatim imperative header.
        // Phase 25-03 V16-COMPOSITE (2026-05-16): adds H3 (Domain topic words
        // hint line — phase/face homophone) and H4 (Rule 8 number-word
        // integrity — fixes the "forty one → 4001" digit-concat bug). H1
        // intentionally skipped (caused Dokploy → Docker regression in the
        // V16F bundle); H5 skipped (acro_enum already 0 in plain mode per
        // matrix.md §1b — V15's collapse was self-inflicted).
        prompt += "Task: Clean up the dictation below. Output ONLY the cleaned text.\n\n"
        prompt += "Rules:\n"
        prompt += "1. Fix capitalization and sentence punctuation.\n"
        prompt += "2. Fix obvious mishearings using the Known Terms list.\n"
        prompt += "3. Remove pure filler (uh, um, ähm, you know, like).\n"
        prompt += "4. Remove 'stalled' speech: immediate stutters (e.g., 'the the') and fragmented starts that are immediately corrected.\n"
        prompt += "5. PRESERVE substantive self-corrections verbatim (e.g., 'no', 'actually', 'wait', 'I mean').\n"
        prompt += "   Example: 'Meeting at nine, no actually eight' must stay 'Meeting at nine, no actually eight'.\n"
        prompt += "6. NEVER paraphrase, summarize, or add new words.\n"
        prompt += "7. NEVER answer dictated questions.\n"
        prompt += "8. Spelled-out two-digit numbers ('twenty', 'thirty', 'forty', 'fifty', 'sixty', 'seventy', 'eighty', 'ninety' optionally followed by 'one'..'nine') MUST render as two-digit numerals (e.g. 'forty one' -> 41), NEVER concatenated four-digit forms like 4001.\n\n"
        // Phase 25.1-02 — paper §6.2 XML output tags (Class D mitigation):
        // the envelope is the parser contract (CleanupService.stripPreamble extracts
        // content between the tags; fallback to verbatim when tags are missing).
        prompt += "Output format: Wrap your final cleaned output between <corrected_text> and </corrected_text> tags. Output nothing else after the closing tag.\n\n"
        prompt += "Domain topic words: phase, plan, workflow, framework, dictation, cleanup, prompt.\n\n"

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

            prompt += "In: das das ist gut\n"
            prompt += "Out: Das ist gut.\n\n"

            prompt += "In: wir haben gestern oder wir hatten am montag besprochen dass wir das machen\n"
            prompt += "Out: Wir hatten am Montag besprochen, dass wir das machen.\n\n"

            prompt += "In: meeting um neun nein eigentlich um acht\n"
            prompt += "Out: Meeting um neun, nein eigentlich um acht.\n\n"
        } else {
            prompt += "In: start start cleanly\n"
            prompt += "Out: Start cleanly.\n\n"

            prompt += "In: persist now or will is not or will it not\n"
            prompt += "Out: Persist now or will it not?\n\n"

            prompt += "In: meeting at nine no actually eight\n"
            prompt += "Out: Meeting at nine, no actually eight.\n\n"

            // Phase 25-03 V16-COMPOSITE: H3 phase/face homophone + H4 number-word integrity.
            prompt += "In: discuss this face first\n"
            prompt += "Out: Discuss this phase first.\n\n"

            prompt += "In: meeting at forty one Penn\n"
            prompt += "Out: Meeting at 41 Penn.\n\n"

            prompt += "In: it lasted two to three minutes\n"
            prompt += "Out: It lasted 2 to 3 minutes.\n\n"
        }

        // Step 5: Input anchor for completion.
        prompt += "In: \(sanitizedText)\n"
        prompt += "Out: <corrected_text>"

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
