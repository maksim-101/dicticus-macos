import Foundation
import NaturalLanguage

// Phase 20 D-01: verb changed Rewrite → "Lightly edit" and the LLM is no longer
// asked to remove fillers or convert spelled numbers — those tasks moved to the
// deterministic Swift rules pass (RulesCleanupService, plan 20-03). The LLM is
// now reined in to grammar / punctuation / capitalization fixes only, with the
// Levenshtein gate (CleanupService.gateLLMOutput) as a structural fail-safe.

/// Prompt builder for AI text cleanup via Gemma 4 E2B.
struct CleanupPrompt {

    static let customInstructionKey = "cleanupInstruction"

    static let defaultInstruction = """
    Lightly edit the following transcribed text. Fix obvious grammar, punctuation, and capitalization. \
    Do not paraphrase, summarize, or add information. \
    Apply the dictionary replacements if any. Output ONLY the polished text. \
    If the input is already correct, output it unchanged.
    """

    static func userInstruction() -> String {
        let custom = UserDefaults.standard.string(forKey: customInstructionKey) ?? ""
        return custom.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? defaultInstruction
            : custom
    }

    /// Build the cleanup prompt.
    ///
    /// - Parameters:
    ///   - text: the raw transcribed text to be polished.
    ///   - language: detected language code (`"de"` / `"en"`).
    ///   - dictionaryContext: user-defined replacement pairs.
    ///   - useSwissGerman: explicit Swiss-toggle snapshot. When `nil` (legacy
    ///     callers), the AppGroup `useSwissGerman` key is read once. WR-03 fix
    ///     (Phase 19.5): `CleanupService.cleanup` now snapshots this toggle at
    ///     the top of the call and passes the same value to both this builder
    ///     and the post-LLM Swiss formatting pass, so a mid-inference toggle
    ///     change cannot cause prompt/post-pass disagreement.
    static func build(
        text: String,
        language: String? = nil,
        dictionaryContext: [String: String]? = nil,
        useSwissGerman: Bool? = nil
    ) -> String {
        // WR-03 fix: prefer the explicit `useSwissGerman` argument when provided
        // (CleanupService snapshots it once); fall back to reading the AppGroup
        // for legacy callers / direct unit tests.
        let swissEnabled: Bool = useSwissGerman ?? {
            let suite = UserDefaults(suiteName: "group.com.dicticus") ?? UserDefaults.standard
            return suite.bool(forKey: "useSwissGerman")
        }()

        // Phase 20.08 D-05 / variant-g pivot: for German input, ship variant (g15)
        // verbatim as the entire user-turn body (replaces INSTRUCTION/DICTIONARY/
        // LANGUAGE/INPUT/OUTPUT framing). Two-layer German conditional per
        // VARIANT-G-RATIONALE §4 A2 / D3:
        //   - language == "de"            → variant (g15) INSTRUCTION + 4-shot
        //                                    ORIGINAL/KORRIGIERT frame + RULE 1
        //                                    (Standard-Hochdeutsch). Fires on
        //                                    ALL German input regardless of toggle.
        //   - swissEnabled && language=="de" → orthography clause
        //                                    (`ss statt ß, Umlaute ä/ö/ü bleiben`)
        //                                    embedded inside the INSTRUCTION line.
        // Body verbatim from .planning/phases/20.08-llm-swiss-ification-suppression/
        // 20.08-SPIKE-RESULTS.md "Wave B Update" section. Multi-seed verified at
        // production sampler (temp 0.1, top-k 40, top-p 0.9, seed 0xDEADBEEF):
        // 7/7 fixtures pass, 0/8 muessen ASCII-fold drift on F3.
        //
        // Reference Swift builder: macOS/Dicticus/Views/CleanupSpikeView.swift::
        // SpikeFixtures.buildVariantG15 (Debug-only spike harness).
        //
        // Defense-in-depth: Plan 20.08-02's CleanupService.gateLLMDialect remains
        // the structural backstop if the LLM injects dialect tokens absent from
        // the raw ASR. Currency anti-flip and dictionary-context features are
        // dropped from the German path by the variant (g15) verbatim contract;
        // the third few-shot example (`1250 Franken 20`) demonstrates currency
        // preservation via positive exemplar.
        if language == "de" {
            return buildGermanVariantG15(text: text, swissOrthography: swissEnabled)
        }

        // Non-German path (English / unknown): existing
        // INSTRUCTION / DICTIONARY / LANGUAGE / INPUT / OUTPUT framing per A1
        // (KEEP base defaultInstruction for non-German).
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

    /// Variant (g15) German-language user-turn body. Originally verbatim from
    /// `20.08-SPIKE-RESULTS.md` "Wave B Update" section; additively patched in
    /// Phase 20.08 Plan 05 to close R-G15-01 (currency-digit truncation
    /// reproduced cross-platform on 2026-05-01 UAT — see
    /// `20.08-04-UAT-RESULTS.md` and `20.08-05-PLAN.md`). Plan 05 adds (a) a
    /// positive German directive forbidding digit/amount mutation, and (b) a
    /// 5th ORIGINAL/KORRIGIERT exemplar demonstrating preservation of a 3-digit
    /// decimal currency in colloquial-modal context.
    ///
    /// `swissOrthography` controls ONLY whether the
    /// `mit Schweizer Rechtschreibung (ss statt ß, Umlaute ä/ö/ü bleiben)`
    /// clause appears inside the INSTRUCTION line (per VARIANT-G-RATIONALE §4
    /// D3). All 5 ORIGINAL/KORRIGIERT exemplars, RULE 1 (Standard-Hochdeutsch),
    /// the anti-dialect directive, the anglicism two-tier rule, and the new
    /// digit-preservation directive fire unconditionally on every German input.
    private static func buildGermanVariantG15(text: String, swissOrthography: Bool) -> String {
        let orthographyClause = swissOrthography
            ? " mit Schweizer Rechtschreibung (ss statt ß, Umlaute ä/ö/ü bleiben)"
            : ""
        let sanitizedText = sanitizeControlTokens(text)

        var prompt = "<start_of_turn>user\n"
        prompt += "Bereinige die folgende deutsche Sprachaufnahme. "
        prompt += "Schreibe Standard-Hochdeutsch\(orthographyClause). "
        prompt += "Verwende KEINEN Schweizerdeutsch-Dialekt — schreibe \"Woche\" nicht \"Wuche\", \"Zürich\" nicht \"Züri\", \"ich gehe\" nicht \"i gang\". "
        prompt += "Etablierte englische Fachbegriffe bleiben Englisch (Deadline, Meeting, Workaround, E-Mail, Team, Product Owner, Release). "
        prompt += "Untypische englische Adjektive oder Verben in deutschen Sätzen ins Deutsche übertragen — \"realistic\" → \"realistisch\", \"awesome\" → \"toll\", \"appreciate\" → \"schätzen\". "
        // Phase 20.08 Plan 05 (R-G15-01 fix): the digit-preservation behaviour is
        // taught via the 5th positive ORIGINAL/KORRIGIERT exemplar below — not via
        // a negative-instruction directive. VARIANT-G-RATIONALE §3 documents the
        // priming trap that bit Draft 1: negative-example lists become "things on
        // the table" for Gemma 4 E2B. The 80-cell harness sweep
        // (/tmp/dicticus-harness, 4 prompt variants × 10 seeds × 2 input forms)
        // showed the directive contributed zero measurable signal vs the exemplar
        // alone, while the negative phrasing pattern matched the priming-trap
        // shape called out in §3 — so the directive was dropped before UAT.
        prompt += "Gib genau eine bereinigte Version aus, sonst nichts.\n"
        prompt += "\n"
        prompt += "ORIGINAL: ich habe heute mit dem product owner gesprochen über die deadline und er meinte das ist nicht realistic.\n"
        prompt += "KORRIGIERT: Ich habe heute mit dem Product Owner über die Deadline gesprochen, und er meinte, das ist nicht realistisch.\n"
        prompt += "\n"
        prompt += "ORIGINAL: ich gestern gehen markt und kaufen viele apfel weil ich brauchen für kuchen.\n"
        prompt += "KORRIGIERT: Ich bin gestern auf den Markt gegangen und habe viele Äpfel gekauft, weil ich sie für den Kuchen brauche.\n"
        prompt += "\n"
        prompt += "ORIGINAL: das hotel hat ungefähr 1250 franken 20 gekostet und das war zu viel.\n"
        prompt += "KORRIGIERT: Das Hotel hat ungefähr 1250 Franken 20 gekostet, und das war zu viel.\n"
        prompt += "\n"
        prompt += "ORIGINAL: letzte woche war ich in zürich auf einer grossen konferenz.\n"
        prompt += "KORRIGIERT: Letzte Woche war ich in Zürich auf einer grossen Konferenz.\n"
        prompt += "\n"
        // Phase 20.08 Plan 05 (R-G15-01 fix): 5th exemplar — 3-digit decimal currency
        // in colloquial-modal context. Mirrors the exact failure shape from the
        // 2026-05-01 UAT (`vielleicht sogar um die 102.50 Franken` → variant g15
        // mutated to `12.50 Franken`). Identity edit: only capitalisation + period.
        prompt += "ORIGINAL: ich habe bestimmt über 99 franken ausgegeben vielleicht sogar um die 102.50 franken.\n"
        prompt += "KORRIGIERT: Ich habe bestimmt über 99 Franken ausgegeben. Vielleicht sogar um die 102.50 Franken.\n"
        prompt += "\n"
        prompt += "ORIGINAL: \(sanitizedText)\n"
        prompt += "KORRIGIERT:<end_of_turn>\n"
        prompt += "<start_of_turn>model\n"

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
