import XCTest
@testable import Dicticus

final class CleanupPromptTests: XCTestCase {

    override func tearDown() {
        // Clear any custom instruction between tests
        UserDefaults.standard.removeObject(forKey: CleanupPrompt.customInstructionKey)
        super.tearDown()
    }

    // MARK: - Gemma format

    func testPromptContainsGemmaControlTokens() {
        let prompt = CleanupPrompt.build(text: "hello", language: "en")
        XCTAssertTrue(prompt.contains("<start_of_turn>user"), "Must contain user turn start token")
        XCTAssertTrue(prompt.contains("<end_of_turn>"), "Must contain turn end token")
        XCTAssertTrue(prompt.contains("<start_of_turn>model"), "Must contain model turn start token")
    }

    // MARK: - Language context

    // Phase 20.08 D-05 / variant-g pivot: German inputs no longer use the
    // INSTRUCTION/DICTIONARY/LANGUAGE/INPUT/OUTPUT framing — the entire user
    // turn is replaced by variant (g15). The `LANGUAGE: German` marker is
    // intentionally absent from German prompts; see R6 tests below for the
    // new German-shape contract.

    func testEnglishLanguagePassed() {
        let prompt = CleanupPrompt.build(text: "This is a test", language: "en")
        XCTAssertTrue(prompt.contains("LANGUAGE: English"), "English language context must be included")
    }

    // MARK: - Dictionary context

    func testDictionaryContextIncluded() {
        let context = ["swiss quote": "Swissquote"]
        let prompt = CleanupPrompt.build(text: "I use swiss quote", language: "en", dictionaryContext: context)
        XCTAssertTrue(prompt.contains("DICTIONARY:"), "Dictionary section must be included")
        XCTAssertTrue(prompt.contains("- swiss quote -> Swissquote"), "Dictionary entry must be included")
    }

    // MARK: - Mixed language detection

    func testContainsMixedLanguagesDetectsGermanAndEnglish() {
        let text = "Ich spreche jetzt Deutsch. Now I am speaking English."
        XCTAssertTrue(CleanupPrompt.containsMixedLanguages(text), "Must detect mixed German/English")
    }

    func testContainsMixedLanguagesReturnsFalseForPureEnglish() {
        let text = "This is a completely English sentence about testing."
        XCTAssertFalse(CleanupPrompt.containsMixedLanguages(text), "Pure English must not be detected as mixed")
    }

    // MARK: - Default instruction content

    func testDefaultInstructionContent() {
        let instruction = CleanupPrompt.defaultInstruction
        // Phase 20.02 ACT-1 reined in the LLM verb from "Rewrite" to
        // "Lightly edit"; digit conversion moved to ITN/SwissNumberFormatter.
        XCTAssertTrue(instruction.contains("Lightly edit"), "Default must use the reined-in verb")
        XCTAssertTrue(instruction.contains("polished"), "Default must instruct polishing")
        XCTAssertTrue(instruction.contains("grammar"), "Default must cover grammar")
        XCTAssertTrue(instruction.contains("dictionary"), "Default must instruct dictionary usage")
        XCTAssertTrue(instruction.contains("Do not paraphrase"), "Default must forbid paraphrasing")
    }

    // MARK: - Custom instruction

    func testCustomInstructionOverridesDefault() {
        let custom = "Just fix typos."
        UserDefaults.standard.set(custom, forKey: CleanupPrompt.customInstructionKey)
        let prompt = CleanupPrompt.build(text: "test", language: "en")
        XCTAssertTrue(prompt.contains("INSTRUCTION: Just fix typos"), "Custom instruction must be used in prompt")
        XCTAssertFalse(prompt.contains("Rewrite the following"), "Default instruction must not appear")
    }

    // testEmptyCustomInstructionFallsBackToDefault: removed.
    // The V5 prompt rewrite collapsed the userInstruction() helper into
    // build() — there is no longer a public fallback API to test.
    // V5 also no longer wires custom instruction into the prompt body
    // (it's a strict-verbatim contract); remaining assertions in this
    // file that target the pre-V5 prompt shape are flagged for
    // separate cleanup, but the build must pass first.

    // MARK: - User text placement

    func testUserTextAppearsAfterInputLabel() {
        let userText = "my dictated words"
        let prompt = CleanupPrompt.build(text: userText, language: "en")
        XCTAssertTrue(prompt.contains("INPUT: \(userText)"), "User text must follow 'INPUT: ' label")
    }

    func testPromptEndsWithOutputPrimer() {
        let prompt = CleanupPrompt.build(text: "hello", language: "en")
        XCTAssertTrue(prompt.hasSuffix("OUTPUT:"), "Prompt must end with 'OUTPUT:' to prime model response")
    }

    // MARK: - Phase 20.08 R6 — variant (g15) contract tests
    //
    // Variant (g15) is the production German cleanup prompt per
    // .planning/phases/20.08-llm-swiss-ification-suppression/20.08-VARIANT-G-RATIONALE.md
    // (canonical brief) and the verbatim prompt block in
    // 20.08-SPIKE-RESULTS.md "Wave B Update" section.
    //
    // The two-layer German conditional (§4 D3): the variant (g15) INSTRUCTION
    // body, the 4-shot ORIGINAL/KORRIGIERT frame, and RULE 1
    // (Standard-Hochdeutsch) fire on EVERY German input regardless of toggle
    // state. The Swiss toggle gates ONLY the embedded orthography clause
    // (`mit Schweizer Rechtschreibung (ss statt ß, Umlaute ä/ö/ü bleiben)`)
    // inside the INSTRUCTION sentence.
    //
    // Supersedes: Phase 20.06 F-20-UAT-01 (HELVETISMS preservation-first
    // block) and F-20-UAT-02 (STRICT currency anchor) — both removed from
    // the German path by the variant (g15) verbatim contract. Currency
    // preservation is now demonstrated implicitly by the third few-shot
    // example (`1250 Franken 20`).

    /// R6 positive: variant (g15) markers ship verbatim on Swiss + de.
    func testHelvetismsBlockEmitsVariantG15Header() {
        let prompt = CleanupPrompt.build(
            text: "irgendwas",
            language: "de",
            dictionaryContext: nil,
            useSwissGerman: true
        )
        XCTAssertTrue(
            prompt.contains("Standard-Hochdeutsch"),
            "Variant (g15) RULE 1 directive 'Standard-Hochdeutsch' must appear in the prompt body."
        )
        XCTAssertTrue(
            prompt.contains("ORIGINAL:"),
            "Variant (g15) 4-shot frame requires the literal 'ORIGINAL:' marker."
        )
        XCTAssertTrue(
            prompt.contains("KORRIGIERT:"),
            "Variant (g15) 4-shot frame requires the literal 'KORRIGIERT:' marker."
        )
        XCTAssertTrue(
            prompt.contains("KEINEN Schweizerdeutsch-Dialekt"),
            "Variant (g15) anti-dialect directive must appear verbatim."
        )
    }

    /// R6 two-layer gating: orthography clause appears ONLY when the Swiss
    /// toggle is ON. The variant (g15) INSTRUCTION + 4-shot frame still fire
    /// on Swiss-toggle-OFF German input (per VARIANT-G-RATIONALE §4 D3).
    func testGermanDeOnlyDoesNotIncludeSwissOrthographyClause() {
        let promptSwissOff = CleanupPrompt.build(
            text: "irgendwas",
            language: "de",
            dictionaryContext: nil,
            useSwissGerman: false
        )
        XCTAssertTrue(
            promptSwissOff.contains("Standard-Hochdeutsch"),
            "Variant (g15) RULE 1 must fire on ALL German input regardless of Swiss toggle."
        )
        XCTAssertFalse(
            promptSwissOff.contains("ss statt ß"),
            "Swiss orthography clause must NOT appear when useSwissGerman == false (D3 gating)."
        )
        XCTAssertFalse(
            promptSwissOff.contains("Umlaute ä/ö/ü bleiben"),
            "Swiss umlaut-preservation clause must NOT appear when useSwissGerman == false."
        )
    }

    /// R6 two-layer gating (positive): orthography clause embedded inside
    /// the INSTRUCTION sentence when Swiss toggle is ON.
    func testGermanWithSwissIncludesOrthographyClause() {
        let prompt = CleanupPrompt.build(
            text: "irgendwas",
            language: "de",
            dictionaryContext: nil,
            useSwissGerman: true
        )
        XCTAssertTrue(
            prompt.contains("ss statt ß"),
            "Swiss orthography clause must appear when useSwissGerman == true && language == 'de'."
        )
        XCTAssertTrue(
            prompt.contains("Umlaute ä/ö/ü bleiben"),
            "Swiss umlaut-preservation clause (six-token g15 addition) must appear."
        )
    }

    /// R6 regression guard: variant (g15) directives must not leak into
    /// non-German prompts (English path keeps the existing
    /// INSTRUCTION/DICTIONARY/LANGUAGE/INPUT/OUTPUT framing per A1).
    func testHelvetismsDirectiveGatedOnGerman() {
        let promptEnglish = CleanupPrompt.build(
            text: "anything",
            language: "en",
            dictionaryContext: nil,
            useSwissGerman: true
        )
        XCTAssertFalse(
            promptEnglish.contains("Standard-Hochdeutsch"),
            "Variant (g15) directive must not appear in English prompts."
        )
        XCTAssertFalse(
            promptEnglish.contains("KORRIGIERT:"),
            "German few-shot frame must not appear in English prompts."
        )
        XCTAssertTrue(
            promptEnglish.contains("INSTRUCTION:"),
            "English path must retain the existing INSTRUCTION: framing."
        )
    }

    // MARK: - Phase 20.08 Plan 05 R6 — R-G15-01 currency-digit truncation fix
    //
    // Plan 05 closes R-G15-01 (`vielleicht sogar um die 102.50 Franken` mutated
    // to `12.50 Franken` cross-platform in the 2026-05-01 UAT) via a single
    // additive change: one new 5th ORIGINAL/KORRIGIERT exemplar mirroring the
    // exact failure shape. The earlier directive-sentence approach was dropped
    // before UAT — see CleanupPrompt.swift::buildGermanVariantG15 inline comment
    // and 20.08-05-UAT-RESULTS.md for the harness data + VARIANT-G-RATIONALE §3
    // priming-trap rationale.

    /// R6 positive: new 5th ORIGINAL/KORRIGIERT exemplar present on Swiss + de.
    /// Mirrors the exact failure shape from the 2026-05-01 UAT.
    func testVariantG15IncludesDecimalCurrencyExemplar() {
        let prompt = CleanupPrompt.build(
            text: "irgendwas",
            language: "de",
            dictionaryContext: nil,
            useSwissGerman: true
        )
        XCTAssertTrue(
            prompt.contains("vielleicht sogar um die 102.50 franken"),
            "Plan 05 new exemplar ORIGINAL line (lowercase) must appear in variant (g15)."
        )
        XCTAssertTrue(
            prompt.contains("Vielleicht sogar um die 102.50 Franken"),
            "Plan 05 new exemplar KORRIGIERT line (capitalised) must appear in variant (g15)."
        )
    }

    /// R6 D3-gating: new 5th exemplar fires on de-only (Swiss OFF).
    /// Per VARIANT-G-RATIONALE §4 D3, only the orthography clause is toggle-gated;
    /// the 5th exemplar must fire on ALL German input.
    func testVariantG15ExemplarFiresOnDeOnly() {
        let prompt = CleanupPrompt.build(
            text: "irgendwas",
            language: "de",
            dictionaryContext: nil,
            useSwissGerman: false
        )
        XCTAssertTrue(
            prompt.contains("Vielleicht sogar um die 102.50 Franken"),
            "Plan 05 5th exemplar must fire on ALL German input (de-only branch must include it)."
        )
    }

    /// R6 negative: the dropped directive must NOT reappear. Pure regression
    /// guard against a future re-introduction of negative-instruction phrasing
    /// (the priming-trap pattern documented in VARIANT-G-RATIONALE §3).
    func testVariantG15DoesNotIncludeDigitDirective() {
        let prompt = CleanupPrompt.build(
            text: "irgendwas",
            language: "de",
            dictionaryContext: nil,
            useSwissGerman: true
        )
        XCTAssertFalse(
            prompt.contains("Zahlen, Beträge und Mengenangaben bleiben unverändert"),
            "Plan 05 directive was dropped — re-introducing negative-instruction phrasing risks the §3 priming trap."
        )
    }

    /// R6 regression guard: Plan 05 5th exemplar must not leak into the English
    /// path (the EN branch keeps INSTRUCTION/DICTIONARY/LANGUAGE/INPUT/OUTPUT
    /// framing per VARIANT-G-RATIONALE §4 A1).
    func testPlan05AdditionsGatedOnGerman() {
        let promptEnglish = CleanupPrompt.build(
            text: "anything",
            language: "en",
            dictionaryContext: nil,
            useSwissGerman: true
        )
        XCTAssertFalse(
            promptEnglish.contains("vielleicht sogar um die 102.50 franken"),
            "Plan 05 5th exemplar must not appear in English prompts."
        )
        XCTAssertFalse(
            promptEnglish.contains("Gestern musste ich früh aufstehen"),
            "Plan 05 iteration-2 6th exemplar must not appear in English prompts."
        )
    }

    // MARK: - Phase 20.08-05 iteration 2 — past-tense correction exemplar
    //
    // After the 2026-05-01 macOS UAT confirmed R-G15-01 closure but surfaced a
    // residual gap: `Gestern muss ich dann auch noch einkaufen` was left in
    // present tense despite the sentence-initial past-tense time adverb. A 6th
    // positive ORIGINAL/KORRIGIERT exemplar was added to teach the
    // time-adverb→tense agreement pattern via in-context demonstration (no
    // negative directive — VARIANT-G-RATIONALE §3 priming-trap discipline).

    /// R6 positive: 6th tense-correction exemplar present on Swiss + de.
    func testVariantG15IncludesPastTenseExemplar() {
        let prompt = CleanupPrompt.build(
            text: "irgendwas",
            language: "de",
            dictionaryContext: nil,
            useSwissGerman: true
        )
        XCTAssertTrue(
            prompt.contains("gestern muss ich früh aufstehen weil ich einen termin hatte."),
            "Iteration-2 6th exemplar ORIGINAL line (lowercase, present tense) must appear."
        )
        XCTAssertTrue(
            prompt.contains("Gestern musste ich früh aufstehen, weil ich einen Termin hatte."),
            "Iteration-2 6th exemplar KORRIGIERT line (capitalised, past tense) must appear."
        )
    }

    /// R6 D3-gating: 6th exemplar fires on de-only (Swiss OFF) — same as 5th.
    func testVariantG15PastTenseExemplarFiresOnDeOnly() {
        let prompt = CleanupPrompt.build(
            text: "irgendwas",
            language: "de",
            dictionaryContext: nil,
            useSwissGerman: false
        )
        XCTAssertTrue(
            prompt.contains("Gestern musste ich früh aufstehen, weil ich einen Termin hatte."),
            "Iteration-2 6th exemplar must fire on ALL German input regardless of Swiss toggle."
        )
    }

    /// R6 iteration-3 order lock: the currency-preservation exemplar
    /// (`102.50 Franken`) must appear AFTER the tense-correction exemplar
    /// (`Gestern musste ich früh aufstehen`). Iteration 2's UAT regressed
    /// R-G15-01 because the tense-rewrite sat closest to the runtime ORIGINAL,
    /// biasing Gemma's recency-weighted edit budget away from digit identity.
    /// The currency exemplar must remain the LAST exemplar (anchor position).
    func testVariantG15CurrencyExemplarIsLastExemplar() {
        let prompt = CleanupPrompt.build(
            text: "irgendwas",
            language: "de",
            dictionaryContext: nil,
            useSwissGerman: true
        )
        guard let tenseRange = prompt.range(of: "Gestern musste ich früh aufstehen"),
              let currencyRange = prompt.range(of: "Vielleicht sogar um die 102.50 Franken")
        else {
            XCTFail("Both tense and currency exemplars must be present in the prompt.")
            return
        }
        XCTAssertLessThan(
            tenseRange.lowerBound,
            currencyRange.lowerBound,
            "Currency-preservation exemplar must appear AFTER the tense exemplar (anchor-position contract — see iteration-3 reorder)."
        )
    }
}
