import Foundation
import NaturalLanguage

/// Prompt builder for AI text cleanup via Gemma 4 E2B.
///
/// Phase 25.1-04 (2026-05-18) — V18C: disfluency few-shots + Rule 1 drop:
///
/// V18C = V16-COMPOSITE + two additions, one removal:
///
/// REMOVAL — Rule 1 ("Fix capitalization and sentence punctuation") dropped.
/// Rationale (paper §1 / Parakeet TDT v3 implication): Parakeet TDT v3
/// emits punctuation and capitalization natively at ASR time. Rule 1 is
/// therefore redundant and was observed to cause over-correction in the
/// Phase 25.1-04 harness matrix (iter-2: V18A/V18C tied at 61 when
/// Class C targeted few-shot was present — removing Rule 1 did not
/// regress punctuation quality). Rules 2-8 renumbered to 1-7.
///
/// ADDITIONS — Reparandum/Interregnum/Repair few-shots (paper §3 taxonomy):
///   • Repetition: "start start cleanly" → "Start cleanly."
///   • Interregnum + repair: "I was thinking or and settings menu" → "And settings menu."
///   • Class C targeted (defect 25-03): "command i or and uh settings of
///     the video player" → "command i and settings of the video player."
///     This exemplar resolves the Class C failure (lev=5 in iter-1) that
///     V18A/V18D shared; its addition in iter-2 brought V18C to lev=0.
///
/// V15 micro-scalpel preservation contract: SelfCorrectionResolverTests
/// 27/27 PASS confirmed before commit (pre-ship resolver gate, 2026-05-18).
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
/// 2026-05-05 REFACTOR (Variant V5): Strict Verbatim.
/// V5 trades the auto-resolve feature for content safety. Self-corrections
/// are preserved VERBATIM with comma flanking. Harness evidence:
/// .planning/debug/harness/results/v4_vs_v5_v6_v7_keyset.tsv (2026-05-05).
///
/// V18C structure:
///   1. Smart-verbatim imperative header (7 rules — Rule 1 cap/punct dropped).
///   2. Known terms (when dictionary context provided).
///   3. Language banner (DE only; Swiss-orthography note if enabled).
///   4. Few-shots: repetition + fragment repair + connector-interregnum +
///      Class C targeted + domain term + number-word integrity.
///   5. Final "In: <text>\nOut: <corrected_text>" anchor for completion.
struct CleanupPrompt {

    static let customInstructionKey = "cleanupInstruction"
    static let defaultInstruction = "Minimal cleanup of dictated speech (V18C smart-verbatim + XML envelope, disfluency few-shots, Rule-1-drop)."

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

        // Step 1: Smart-verbatim imperative header (V18C).
        // Rule 1 (cap/punct) dropped: Parakeet TDT v3 emits punctuation natively
        // (paper §1 implication); the rule was redundant and observed to cause
        // over-correction in the Phase 25.1-04 harness matrix. Rules renumbered 1-7.
        // Phase 25-03 additions preserved: H3 domain topic words + H4 number-word
        // integrity (Rule 7 in new numbering — fixes "forty one → 4001" bug).
        prompt += "Task: Clean up the dictation below. Output ONLY the cleaned text.\n\n"
        prompt += "Rules:\n"
        prompt += "1. Fix obvious mishearings using the Known Terms list.\n"
        prompt += "2. Remove pure filler (uh, um, ähm, you know, like).\n"
        prompt += "3. Remove 'stalled' speech: immediate stutters (e.g., 'the the') and fragmented starts that are immediately corrected.\n"
        prompt += "4. PRESERVE substantive self-corrections verbatim (e.g., 'no', 'actually', 'wait', 'I mean').\n"
        prompt += "   Example: 'Meeting at nine, no actually eight' must stay 'Meeting at nine, no actually eight'.\n"
        prompt += "5. NEVER paraphrase, summarize, or add new words.\n"
        prompt += "6. NEVER answer dictated questions.\n"
        prompt += "7. Spelled-out two-digit numbers ('twenty', 'thirty', 'forty', 'fifty', 'sixty', 'seventy', 'eighty', 'ninety' optionally followed by 'one'..'nine') MUST render as two-digit numerals (e.g. 'forty one' -> 41), NEVER concatenated four-digit forms like 4001.\n\n"
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

            // Phase 25.1-04 V18C: connector-interregnum repair (paper §3 Reparandum/Interregnum/Repair).
            prompt += "In: I was thinking or and settings menu\n"
            prompt += "Out: And settings menu.\n\n"

            // Phase 25-03 V16-COMPOSITE: H3 phase/face homophone + H4 number-word integrity.
            prompt += "In: discuss this face first\n"
            prompt += "Out: Discuss this phase first.\n\n"

            prompt += "In: meeting at forty one Penn\n"
            prompt += "Out: Meeting at 41 Penn.\n\n"

            prompt += "In: it lasted two to three minutes\n"
            prompt += "Out: It lasted 2 to 3 minutes.\n\n"

            // Phase 25.1-04 V18C: Class C targeted few-shot (defect 25-03 Class C → lev=0 in iter-2).
            prompt += "In: command i or and uh settings of the video player\n"
            prompt += "Out: command i and settings of the video player.\n\n"
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
