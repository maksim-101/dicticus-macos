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

    func testGermanLanguagePassedForSingleLanguageText() {
        // Short single-language text should include Language: line
        let prompt = CleanupPrompt.build(for: "Das ist ein Test", language: "de")
        XCTAssertTrue(prompt.contains("Language: German"), "Single-language German must include Language: context")
    }

    func testEnglishLanguagePassedForSingleLanguageText() {
        let prompt = CleanupPrompt.build(for: "This is a test", language: "en")
        XCTAssertTrue(prompt.contains("Language: English"), "Single-language English must include Language: context")
    }

    func testMixedLanguageOmitsLanguageLine() {
        // Text with both German and English should omit Language: line
        let mixedText = "Ich spreche jetzt Deutsch. Now I am speaking English. Das ist ein gemischter Text."
        let prompt = CleanupPrompt.build(for: mixedText, language: "de")
        XCTAssertFalse(prompt.contains("Language:"),
                        "Mixed-language text must NOT include Language: to avoid translation")
    }

    func testSameInstructionForBothLanguages() {
        let de = CleanupPrompt.build(for: "same text", language: "de")
        let en = CleanupPrompt.build(for: "same text", language: "en")
        XCTAssertTrue(de.contains("Polish the following"), "German prompt uses same instruction")
        XCTAssertTrue(en.contains("Polish the following"), "English prompt uses same instruction")
    }

    // MARK: - Mixed language detection

    func testIsMixedLanguageDetectsGermanAndEnglish() {
        // Needs distinct sentences so per-sentence detection works
        let text = "Ich spreche jetzt Deutsch und das sollte verständlich sein. Now I am speaking English and this should be clear."
        XCTAssertTrue(CleanupPrompt.isMixedLanguage(text), "Must detect mixed German/English")
    }

    func testIsMixedLanguageReturnsFalseForPureEnglish() {
        let text = "This is a completely English sentence about testing."
        XCTAssertFalse(CleanupPrompt.isMixedLanguage(text), "Pure English must not be detected as mixed")
    }

    func testIsMixedLanguageReturnsFalseForPureGerman() {
        let text = "Das ist ein komplett deutscher Satz zum Testen."
        XCTAssertFalse(CleanupPrompt.isMixedLanguage(text), "Pure German must not be detected as mixed")
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

    func testDefaultInstructionPreservesMultipleLanguages() {
        let instruction = CleanupPrompt.defaultInstruction
        XCTAssertTrue(instruction.contains("never translate between languages"),
                       "Default must instruct against cross-language translation")
    }

    func testDefaultInstructionHandlesSelfCorrections() {
        let instruction = CleanupPrompt.defaultInstruction
        XCTAssertTrue(instruction.lowercased().contains("corrects themselves"),
                       "Default must instruct handling of mid-sentence self-corrections")
    }

    func testDefaultInstructionForbidsPreamble() {
        let instruction = CleanupPrompt.defaultInstruction
        XCTAssertTrue(instruction.contains("no preamble"),
                       "Default must forbid LLM preamble in output")
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

    func testUserTextAppearsAfterInputLabel() {
        let userText = "my dictated words"
        let prompt = CleanupPrompt.build(for: userText, language: "en")
        XCTAssertTrue(prompt.contains("Input: \(userText)"), "User text must follow 'Input: ' label")
    }

    func testPromptEndsWithOutputPrimer() {
        let prompt = CleanupPrompt.build(for: "hello", language: "en")
        XCTAssertTrue(prompt.hasSuffix("Output: "), "Prompt must end with 'Output: ' to prime model response")
    }
}
