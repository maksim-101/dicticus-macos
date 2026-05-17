import XCTest
@testable import Dicticus

final class CleanupPromptTests: XCTestCase {

    override func tearDown() {
        // Clear any custom instruction between tests
        UserDefaults.standard.removeObject(forKey: CleanupPrompt.customInstructionKey)
        super.tearDown()
    }

    // MARK: - Prompt Structure (V16-COMPOSITE)

    func testV15PromptHeaderContainsRules() {
        let prompt = CleanupPrompt.build(text: "test", language: "en")

        XCTAssertTrue(prompt.contains("Task: Clean up the dictation below."), "Must contain task header")
        XCTAssertTrue(prompt.contains("Rules:"), "Must contain rules label")
        XCTAssertTrue(prompt.contains("Remove 'stalled' speech"), "Must contain stutter/fragment rule")
        XCTAssertTrue(prompt.contains("PRESERVE substantive self-corrections"), "Must contain preservation rule")
        XCTAssertTrue(prompt.contains("NEVER paraphrase"), "Must contain anti-paraphrase rule")
    }

    func testEnglishFewShotsPresent() {
        let prompt = CleanupPrompt.build(text: "test", language: "en")

        XCTAssertTrue(prompt.contains("In: start start cleanly"), "Must contain stutter example")
        XCTAssertTrue(prompt.contains("Out: Start cleanly."), "Must contain stutter output")
        XCTAssertTrue(prompt.contains("In: persist now or will is not or will it not"), "Must contain fragment example")
        XCTAssertTrue(prompt.contains("In: meeting at nine no actually eight"), "Must contain repair example")
    }

    func testGermanFewShotsPresent() {
        let prompt = CleanupPrompt.build(text: "test", language: "de")

        XCTAssertTrue(prompt.contains("In: das das ist gut"), "Must contain German stutter example")
        XCTAssertTrue(prompt.contains("In: wir haben gestern oder wir hatten am montag"), "Must contain German fragment example")
        XCTAssertTrue(prompt.contains("In: meeting um neun nein eigentlich um acht"), "Must contain German repair example")
    }

    // MARK: - Dictionary context

    func testDictionaryContextIncluded() {
        let context = ["swiss quote": "Swissquote"]
        let prompt = CleanupPrompt.build(text: "I use swiss quote", language: "en", dictionaryContext: context)
        XCTAssertTrue(prompt.contains("Known terms:"), "Dictionary section must be included")
        XCTAssertTrue(prompt.contains("swiss quote -> Swissquote"), "Dictionary entry must be included")
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

    // MARK: - Default instruction metadata

    func testDefaultInstructionString() {
        let instruction = CleanupPrompt.defaultInstruction
        XCTAssertTrue(instruction.contains("V16-COMPOSITE"), "Default instruction must reference V16-COMPOSITE version")
        XCTAssertTrue(instruction.contains("smart-verbatim"), "Default instruction must reference smart-verbatim policy")
    }

    // MARK: - User text placement

    func testUserTextAppearsAfterInLabel() {
        let userText = "my dictated words"
        let prompt = CleanupPrompt.build(text: userText, language: "en")
        XCTAssertTrue(prompt.contains("In: \(userText)"), "User text must follow 'In: ' label")
    }

    func testPromptEndsWithOutPrimer() {
        let prompt = CleanupPrompt.build(text: "hello", language: "en")
        XCTAssertTrue(prompt.hasSuffix("Out: <corrected_text>"), "Prompt must end with 'Out: <corrected_text>' to prime completion (Phase 25.1-02 XML envelope)")
    }

    // MARK: - Regression guards

    func testWFewShotFromCommit8a79e6bIsAbsent() {
        let prompt = CleanupPrompt.build(text: "test", language: "en")
        XCTAssertFalse(
            prompt.contains("let's see whether"),
            "8a79e6b few-shot must be absent from V15 prompt."
        )
    }

    // MARK: - Phase 25.1-02: XML envelope instruction (paper §6.2)

    func testPhase251_V16PromptContainsCorrectedTextEnvelopeInstruction() {
        let promptEn = CleanupPrompt.build(text: "test", language: "en")
        let promptDe = CleanupPrompt.build(text: "test", language: "de")
        XCTAssertTrue(promptEn.contains("Output format: Wrap your final cleaned output between <corrected_text> and </corrected_text> tags."),
                      "EN prompt missing §6.2 envelope instruction")
        XCTAssertTrue(promptDe.contains("Output format: Wrap your final cleaned output between <corrected_text> and </corrected_text> tags."),
                      "DE prompt missing §6.2 envelope instruction")
    }

    func testPhase251_V16PromptOutAnchorPrimesEnvelope() {
        let prompt = CleanupPrompt.build(text: "hello", language: "en")
        XCTAssertTrue(prompt.hasSuffix("Out: <corrected_text>"),
                      "Prompt must end with `Out: <corrected_text>` to prime Gemma's first emitted token as envelope content")
    }
}
