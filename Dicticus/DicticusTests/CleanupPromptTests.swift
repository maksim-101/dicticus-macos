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
        XCTAssertTrue(instruction.contains("polished"), "Default must instruct polishing")
        XCTAssertTrue(instruction.contains("grammatically correct"), "Default must cover grammar")
        XCTAssertTrue(instruction.contains("digits"), "Default must instruct digits for numbers")
        XCTAssertTrue(instruction.contains("dictionary"), "Default must instruct dictionary usage")
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
}
