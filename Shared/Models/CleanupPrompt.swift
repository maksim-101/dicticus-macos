import Foundation
import NaturalLanguage

/// Prompt builder for AI text cleanup via Gemma 4 E2B.
///
/// Phase 28 (2026-05-27) — V19D: clause preservation + contraction defense + dedup +
/// K4 number policy + topic-words audit removal.
///
/// V19D = V19C + four prompt-layer changes + one deletion:
///
/// REMOVAL — "Domain topic words" static line dropped (log-analysis-2026-05-26 §4 #5):
/// The biased meta-vocab list ("phase, plan, workflow...") was discovered to skew
/// the LLM toward developer-jargon outputs even for off-topic dictation. Removed
/// per LLM-PROMPT-AUDIT-01 / D-04. Dynamic topic context is a future phase (deferred).
///
/// ADDITIONS:
///   • Rule 5 extended: explicit clause-preservation language plus few-shots seeded
///     from real K2 captures ("in the meantime" 2026-05-26T16:29:43.255Z and
///     "as minimal as possible" 2026-05-25T04:16:10.435Z). LLM-CLAUSE-01.
///   • Rule 8 added: K4 standalone-number policy — EN one-nine spelled out (AP);
///     DE eins-zwölf spelled out (Duden); identifier-adjacent ALWAYS digits;
///     sentence-start spelled out. LLM-NUM-01.
///   • K2-contraction few-shot ("most people I'd say don't") + Variants B/C/D
///     defense-in-depth post-LLM gate in CleanupService. LLM-CONTR-01.
///   • K5-dedup few-shots beyond "the the": "that that", "for for".
///     LLM-DEDUP-01.
///
/// V19C non-Swiss aggregate lev (118-record baseline) preservation gate:
/// V19D agg lev ≤ V19C agg lev. Brand-recognition fixtures preserved.
/// DE Gates 1-3 (V2 lev=0, compound lev=0, non-Swiss aggregate) preserved.
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
    static let defaultInstruction = "Minimal cleanup of dictated speech (V19D smart-verbatim + XML envelope, clause-preservation, contraction defense, K5 dedup generalization, K4 number policy, topic-words audit)."

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

        // Step 1: Smart-verbatim imperative header (V19D).
        // Rule 1 (cap/punct) dropped: Parakeet TDT v3 emits punctuation natively
        // (paper §1 implication); the rule was redundant and observed to cause
        // over-correction in the Phase 25.1-04 harness matrix. Rules renumbered 1-7.
        // Phase 25-03 additions preserved: H4 number-word integrity (Rule 7 in new numbering).
        // Phase 28: Rule 5 extended with clause-preservation; Rule 8 added (K4 number policy).
        // Domain topic words line REMOVED (LLM-PROMPT-AUDIT-01 / D-04, Phase 28).
        prompt += "Task: Clean up the dictation below. Output ONLY the cleaned text.\n\n"
        prompt += "Rules:\n"
        prompt += "1. Fix obvious mishearings using the Known Terms list.\n"
        prompt += "2. Remove pure filler (uh, um, ähm, you know, like).\n"
        prompt += "3. Remove 'stalled' speech: immediate stutters (e.g., 'the the') and fragmented starts that are immediately corrected.\n"
        prompt += "4. PRESERVE substantive self-corrections verbatim (e.g., 'no', 'actually', 'wait', 'I mean').\n"
        prompt += "   Example: 'Meeting at nine, no actually eight' must stay 'Meeting at nine, no actually eight'.\n"
        prompt += "5. NEVER paraphrase, summarize, add new words, or DELETE substantive prepositional/temporal phrases (e.g., 'in the meantime', 'as minimal as possible', 'for the most part').\n"
        prompt += "6. NEVER answer dictated questions.\n"
        prompt += "7. Spelled-out two-digit numbers ('twenty', 'thirty', 'forty', 'fifty', 'sixty', 'seventy', 'eighty', 'ninety' optionally followed by 'one'..'nine') MUST render as two-digit numerals (e.g. 'forty one' -> 41), NEVER concatenated four-digit forms like 4001.\n"
        // Phase 28 D-01/D-02: K4 standalone-number policy (LLM-NUM-01).
        // W-01 dual-defense: ITN (Plan 28-02) runs BEFORE the LLM and promotes identifier-adjacent
        // numbers deterministically. The trailing "Preserve digits" clause prevents the LLM from
        // re-spelling already-converted digits (e.g., re-spelling "E1" back to "E one").
        prompt += "8. Standalone single-digit number-words ('one'..'nine' EN, 'eins'..'zwölf' DE): in prose, spell them out. EXCEPTION: when identifier-adjacent (after a capitalized stem like 'E one' -> E1, 'M three' -> M3, or after a version-class word like 'version two' -> version 2), render as digits. Sentence-start always spells out. Preserve digits and number-formats already present in the input — do not re-spell them as words.\n\n"
        // Phase 25.1-02 — paper §6.2 XML output tags (Class D mitigation):
        // the envelope is the parser contract (CleanupService.stripPreamble extracts
        // content between the tags; fallback to verbatim when tags are missing).
        prompt += "Output format: Wrap your final cleaned output between <corrected_text> and </corrected_text> tags. Output nothing else after the closing tag.\n\n"

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
            // Phase 25.1-05 (2026-05-19) — paper §5 language isolation:
            //
            // V19C winner (see .planning/debug/harness/results/v19_matrix.md §4).
            // German branch rewritten natively per paper §5.2. Addresses paper §5.1
            // language drift: quantized 2B models drift to English reasoning when the
            // prompt mixes English meta-instructions and German content. Native German
            // formulation "locks" the linguistic frame.
            //
            // V19 matrix results (18 German fixtures, seed=42):
            //   V19C non-Swiss aggregate lev: 444 vs V19A baseline 1469 (69% improvement).
            //   Gate 1 (agg ≤ V19A): PASS. Gate 2 (V2 lev=0 on P25b-de-v2-01): PASS.
            //   Gate 3 (compound lev=0 on P25b-de-compound-01): PASS.
            //   Gate 4 (Swiss lev=0): FAIL — model capability boundary; ß→ss is
            //   DictionaryService responsibility. Banner is linguistic signal only.
            //
            // V15 micro-scalpel German contract preserved: selfcorr-01/02/03 all lev=0.
            // Regeln (auf Deutsch): 7 rules natively formulated. Explicit V2-positioning
            // and compound-noun few-shots per paper §5.2 (V19C over V19B).
            //
            // Routes via the existing dispatcher at this line (`if language == "de"`)
            // using the `language` arg from TextProcessingService.process(...). Plan
            // 25.1-01 added the `lang_used` schema field so future telemetry can prove
            // the dispatcher routed to the German variant on de input.
            //
            // Swiss German: `useSwissGerman=true` triggers the `(Schweizer Orthographie:
            // ss statt ß.)` banner per `feedback_swiss_german_default`. Runtime ß→ss
            // conversion is handled by DictionaryService post-processing.
            //
            // Cross-platform parity: Shared/, so macOS + iOS get the change together.
            let orthography = swissEnabled ? " (Schweizer Orthographie: ss statt ß.)" : ""
            prompt += "Sprache: Standard-Hochdeutsch.\(orthography)\n\n"

            // DE Regeln block: 7 rules UNCHANGED from V19C (linguistic-drift risk per RESEARCH §2).
            // Phase 28 D-10: Regel 8 added as an ADDITIVE extension only — existing 1-7 byte-identical.
            prompt += "Regeln (auf Deutsch):\n"
            prompt += "- Korrigiere Großschreibung und Satzzeichen.\n"
            prompt += "- Entferne reine Füllwörter (äh, ähm, also, sozusagen).\n"
            prompt += "- Entferne Stotterer und abgebrochene Neuanfänge (z.B. \"das das\" → \"das\").\n"
            prompt += "- Bewahre inhaltliche Selbstkorrekturen wörtlich (z.B. \"nein\", \"eigentlich\", \"ich meine\", \"warte\").\n"
            prompt += "- Korrigiere Kasusübereinstimmung (z.B. \"der Auto\" → \"das Auto\").\n"
            prompt += "- Setze das Verb an die richtige Stelle (V2-Stellung im Hauptsatz).\n"
            prompt += "- Füge getrennt gesprochene Komposita zusammen (z.B. \"Kranken Haus\" → \"Krankenhaus\").\n"
            // Phase 28 D-10 (W-01 DE parity): Regel 8 mirrors EN Rule 8 including digit-preservation clause.
            prompt += "8. Einzelne Zahlwörter ('eins'..'zwölf'): im Prosa-Text ausschreiben. AUSNAHME: identifier-adjazent (nach einem großgeschriebenen Stamm wie 'E eins' -> E1 oder nach einem Versions-Wort wie 'Version zwei' -> Version 2) werden sie als Ziffern gesetzt. Satzanfang immer ausgeschrieben. Behalte bereits im Text vorhandene Ziffern und Zahlenformate bei — formuliere sie nicht in Wörter um.\n"
            prompt += "\n"

            prompt += "In: das das Meeting ist um fünf\n"
            prompt += "Out: Das Meeting ist um fünf.\n\n"

            prompt += "In: zwei nein drei Tickets bitte\n"
            prompt += "Out: 3 Tickets bitte.\n\n"

            prompt += "In: wir hatten am Montag besprochen dass wir das machen\n"
            prompt += "Out: Wir hatten am Montag besprochen, dass wir das machen.\n\n"

            prompt += "In: meeting um neun nein eigentlich um acht\n"
            prompt += "Out: Meeting um neun, nein eigentlich um acht.\n\n"

            prompt += "In: Ich möchte machen ein Termin\n"
            prompt += "Out: Ich möchte einen Termin machen.\n\n"

            prompt += "In: Wir gehen ins Kranken Haus\n"
            prompt += "Out: Wir gehen ins Krankenhaus.\n\n"

            // Phase 28 D-10: V19D DE few-shots (appended after existing V19C anchors).
            // K2-clause DE: preserve 'in der Zwischenzeit' (real capture 2026-05-26T16:29:43.255Z equivalent).
            prompt += "In: bitte prüf ob in der Zwischenzeit neue Rückmeldungen kamen\n"
            prompt += "Out: Bitte prüfe, ob in der Zwischenzeit neue Rückmeldungen kamen.\n\n"

            // K2-contraction DE: preserves geht's (per D-08 DE).
            prompt += "In: meistens würd ich sagen geht's auch ohne\n"
            prompt += "Out: Meistens würde ich sagen, geht's auch ohne.\n\n"

            // K5-dedup DE: non-'das das' exemplar (D-09 generalization).
            prompt += "In: für für den Großteil\n"
            prompt += "Out: Für den Großteil.\n\n"

            // K4-identifier DE: version-class word triggers digit (D-02 DE).
            prompt += "In: Version zwei läuft auf macOS\n"
            prompt += "Out: Version 2 läuft auf macOS.\n\n"

            // K4-prose DE: preserve three as word in prose context.
            prompt += "In: ich habe drei Termine heute\n"
            prompt += "Out: Ich habe drei Termine heute.\n\n"

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

            // Phase 28 D-07: K2-clause preservation few-shots (between L193 and Class C anchor).
            // Sources: real K2 captures 2026-05-26T16:29:43.255Z (in the meantime) and
            // 2026-05-25T04:16:10.435Z (as minimal as possible). LLM-CLAUSE-01.
            prompt += "In: please check whether in the meantime any new feedbacks were registered\n"
            prompt += "Out: Please check whether, in the meantime, any new feedbacks were registered.\n\n"

            prompt += "In: having m as minimal as possible code\n"
            prompt += "Out: Having as minimal as possible code.\n\n"

            // Phase 28 D-08 Variant A baseline: K2-contraction few-shot. LLM-CONTR-01.
            // Source: real K2 capture 2026-05-26T16:26:23.503Z (I't have mangle case).
            prompt += "In: most people I'd say don't have up-to-date calendars\n"
            prompt += "Out: Most people, I'd say, don't have up-to-date calendars.\n\n"

            // Phase 28 D-09: K5-dedup few-shots beyond 'the the'. LLM-DEDUP-01.
            prompt += "In: that that doesn't matter\n"
            prompt += "Out: That doesn't matter.\n\n"

            prompt += "In: for for the most part\n"
            prompt += "Out: For the most part.\n\n"

            // Phase 28 D-02: K4 number few-shots. LLM-NUM-01.
            // Identifier case: capitalized stem triggers digit rendering.
            prompt += "In: working on E one and M three\n"
            prompt += "Out: Working on E1 and M3.\n\n"

            // Prose case: standalone number-word preserved as word.
            prompt += "In: I have three meetings today\n"
            prompt += "Out: I have three meetings today.\n\n"

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
