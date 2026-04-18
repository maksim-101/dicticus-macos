import XCTest
@testable import Dicticus

final class CleanupPromptTests: XCTestCase {

    override func tearDown() {
        // Clear any custom instruction between tests
        UserDefaults.standard.removeObject(forKey: CleanupPrompt.customInstructionKey)
        super.tearDown()
    }

    // MARK: - Gemma 3 format

    func testPromptContainsGemmaControlTokens() {
        let prompt = CleanupPrompt.build(for: "hello", language: "en")
        XCTAssertTrue(prompt.contains("<start_of_turn>user"), "Must contain user turn start token")
        XCTAssertTrue(prompt.contains("<end_of_turn>"), "Must contain turn end token")
        XCTAssertTrue(prompt.contains("<start_of_turn>model"), "Must contain model turn start token")
    }

    // MARK: - Language context

    func testGermanLanguagePassedAsContext() {
        let prompt = CleanupPrompt.build(for: "test", language: "de")
        XCTAssertTrue(prompt.contains("Language: German"), "German language must be passed as context")
    }

    func testEnglishLanguagePassedAsContext() {
        let prompt = CleanupPrompt.build(for: "test", language: "en")
        XCTAssertTrue(prompt.contains("Language: English"), "English language must be passed as context")
    }

    func testUnknownLanguageDefaultsToEnglish() {
        let prompt = CleanupPrompt.build(for: "test", language: "fr")
        XCTAssertTrue(prompt.contains("Language: English"), "Unknown language must default to English")
    }

    func testSameInstructionForBothLanguages() {
        let de = CleanupPrompt.build(for: "same text", language: "de")
        let en = CleanupPrompt.build(for: "same text", language: "en")
        // Both use the same instruction, only the Language: line differs
        XCTAssertTrue(de.contains("Polish the following"), "German prompt uses same instruction")
        XCTAssertTrue(en.contains("Polish the following"), "English prompt uses same instruction")
    }

    // MARK: - Default instruction content

    func testDefaultInstructionContainsPolishingInstruction() {
        let instruction = CleanupPrompt.defaultInstruction
        XCTAssertTrue(instruction.contains("Polish"), "Default must instruct polishing")
        XCTAssertTrue(instruction.contains("grammar"), "Default must cover grammar")
    }

    func testDefaultInstructionContainsProfanityFilter() {
        let instruction = CleanupPrompt.defaultInstruction
        XCTAssertTrue(instruction.lowercased().contains("profanity"), "Default must address profanity")
    }

    func testDefaultInstructionContainsAsrArtifactFix() {
        let instruction = CleanupPrompt.defaultInstruction
        XCTAssertTrue(instruction.contains("speech recognition artifacts"),
                       "Default must address ASR artifacts like misrecognized filler words")
    }

    func testDefaultInstructionPreservesMeaning() {
        let instruction = CleanupPrompt.defaultInstruction
        XCTAssertTrue(instruction.lowercased().contains("preserve the original meaning"),
                       "Default must instruct meaning preservation")
    }

    func testDefaultInstructionRequestsPlainTextOnly() {
        let instruction = CleanupPrompt.defaultInstruction
        XCTAssertTrue(instruction.contains("ONLY the polished text"), "Must request plain text only")
        XCTAssertTrue(instruction.contains("no explanations"), "Must forbid explanations")
    }

    // MARK: - Custom instruction

    func testCustomInstructionOverridesDefault() {
        let custom = "Just fix typos."
        UserDefaults.standard.set(custom, forKey: CleanupPrompt.customInstructionKey)
        let prompt = CleanupPrompt.build(for: "test", language: "en")
        XCTAssertTrue(prompt.contains("Just fix typos"), "Custom instruction must be used in prompt")
        XCTAssertFalse(prompt.contains("Polish the following"), "Default instruction must not appear")
    }

    func testEmptyCustomInstructionFallsBackToDefault() {
        UserDefaults.standard.set("   ", forKey: CleanupPrompt.customInstructionKey)
        let instruction = CleanupPrompt.activeInstruction
        XCTAssertEqual(instruction, CleanupPrompt.defaultInstruction,
                        "Whitespace-only custom instruction must fall back to default")
    }

    func testNoCustomInstructionUsesDefault() {
        UserDefaults.standard.removeObject(forKey: CleanupPrompt.customInstructionKey)
        let instruction = CleanupPrompt.activeInstruction
        XCTAssertEqual(instruction, CleanupPrompt.defaultInstruction,
                        "No custom instruction must use default")
    }

    // MARK: - User text placement

    func testUserTextAppearsAfterDelimiter() {
        let userText = "my dictated words"
        let prompt = CleanupPrompt.build(for: userText, language: "en")
        XCTAssertTrue(prompt.contains("Text: \(userText)"), "User text must follow 'Text: ' delimiter")
    }
}
