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

    func testEmptyCustomInstructionFallsBackToDefault() {
        UserDefaults.standard.set("   ", forKey: CleanupPrompt.customInstructionKey)
        let instruction = CleanupPrompt.userInstruction()
        XCTAssertEqual(instruction, CleanupPrompt.defaultInstruction,
                        "Whitespace-only custom instruction must fall back to default")
    }

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
}
