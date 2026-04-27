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

    func testGermanLanguagePassed() {
        let prompt = CleanupPrompt.build(text: "Das ist ein Test", language: "de")
        XCTAssertTrue(prompt.contains("LANGUAGE: German"), "German language context must be included")
    }

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

    // MARK: - Phase 20.06 F-20-UAT-01 — HELVETISMS preservation-first

    func testHelvetismsBlockIsPreservationFirst() {
        let prompt = CleanupPrompt.build(text: "ich gehe auf die andere Seite", language: "de", useSwissGerman: true)
        XCTAssertTrue(
            prompt.contains("Preserve the speaker's dialect register exactly."),
            "HELVETISMS block must lead with the preservation-first sentence (F-20-UAT-01)"
        )
    }

    func testHelvetismsBlockAllowsOnlyOrthographyAndDecimalNormalizations() {
        let prompt = CleanupPrompt.build(text: "x", language: "de", useSwissGerman: true)
        XCTAssertTrue(
            prompt.contains("Only change ß→ss and decimal-comma→period."),
            "HELVETISMS must restrict allowed normalizations to ß→ss and decimal-comma→period"
        )
    }

    func testHelvetismsBlockForbidsHighGermanToSwissGermanReplacement() {
        let prompt = CleanupPrompt.build(text: "x", language: "de", useSwissGerman: true)
        XCTAssertTrue(
            prompt.contains("Do NOT replace High German words with Swiss German equivalents."),
            "HELVETISMS must explicitly forbid HG→CH-G word replacement"
        )
    }

    func testHelvetismsBlockEnumeratesNegativeTraps() {
        let prompt = CleanupPrompt.build(text: "x", language: "de", useSwissGerman: true)
        let traps = [
            "auf→uf", "ausgeflogen→usgfloge", "gekostet→choschtet",
            "einkaufen→iikaufe", "natürlich→natürli", "Dingen→Sache",
            "gegessen→gässe", "später→speter", "beiden→beidne",
            "Seite→Siite", "etwas→öppis", "Kleines→chliins",
            "gekauft→chauft"
        ]
        for trap in traps {
            XCTAssertTrue(
                prompt.contains(trap),
                "HELVETISMS NEGATIVE list must contain trap '\(trap)' (F-20-UAT-01)"
            )
        }
    }

    func testHelvetismsBlockOnlyEmittedWhenSwissAndGerman() {
        let withoutSwiss = CleanupPrompt.build(text: "x", language: "de", useSwissGerman: false)
        XCTAssertFalse(
            withoutSwiss.contains("Preserve the speaker's dialect register"),
            "HELVETISMS must NOT be emitted when Swiss toggle is OFF"
        )
        let englishWithSwiss = CleanupPrompt.build(text: "x", language: "en", useSwissGerman: true)
        XCTAssertFalse(
            englishWithSwiss.contains("Preserve the speaker's dialect register"),
            "HELVETISMS must NOT be emitted when language is not 'de' (existing gate preserved)"
        )
    }

    func testHelvetismsBlockStillReferencesPositiveWordList() {
        let prompt = CleanupPrompt.build(text: "x", language: "de", useSwissGerman: true)
        // At least one canonical Helvetism from SwissHelvetisms.words must still appear
        // so the LLM has a positive vocabulary anchor when the speaker uses Swiss words.
        XCTAssertTrue(
            prompt.contains("Velo") || prompt.contains("Trottoir") || prompt.contains("Spital"),
            "HELVETISMS must still surface at least one canonical Swiss word as a positive anchor"
        )
    }

    // MARK: - Phase 20.06 F-20-UAT-02 — STRICT speaker-explicit currency anchor

    func testStrictBlockContainsSpeakerExplicitCurrencyAnchor() {
        let prompt = CleanupPrompt.build(text: "Das hat 5 Franken gekostet", language: "de", useSwissGerman: true)
        XCTAssertTrue(
            prompt.contains("Explicit currency words from the speaker are authoritative — never substitute Franken with Euro or vice versa."),
            "STRICT block must contain the speaker-explicit currency anchor (F-20-UAT-02). Got prompt:\n\(prompt)"
        )
    }

    func testStrictBlockNotEmittedWithoutCurrency() {
        let prompt = CleanupPrompt.build(text: "Heute ist ein schöner Tag", language: "de", useSwissGerman: true)
        XCTAssertFalse(
            prompt.contains("Explicit currency words from the speaker are authoritative"),
            "STRICT speaker-explicit anchor must only fire when input contains a currency token"
        )
    }
}
