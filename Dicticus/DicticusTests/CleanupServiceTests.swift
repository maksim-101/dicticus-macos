import XCTest
@testable import Dicticus

@MainActor
final class CleanupServiceTests: XCTestCase {

    // MARK: - Initial state

    func testInitialStateIsIdle() {
        let service = CleanupService()
        XCTAssertEqual(service.state, .idle)
    }

    func testIsLoadedIsFalseInitially() {
        let service = CleanupService()
        XCTAssertFalse(service.isLoaded)
    }

    // MARK: - D-19: Fallback when model not loaded

    func testCleanupReturnsOriginalTextWhenModelNotLoaded() async {
        let service = CleanupService()
        let original = "this is um my dictated text"
        let result = await service.cleanup(text: original, language: "en")
        XCTAssertEqual(result, original,
                        "Must return raw text when model not loaded (D-19)")
    }

    func testCleanupReturnsOriginalTextForGermanWhenNotLoaded() async {
        let service = CleanupService()
        let original = "das ist aehm mein diktierter Text"
        let result = await service.cleanup(text: original, language: "de")
        XCTAssertEqual(result, original,
                        "Must return raw German text when model not loaded (D-19)")
    }

    // MARK: - Preamble stripping (Pitfall 4)

    func testStripPreambleRemovesEnglishPreamble() {
        let input = "Here is the corrected text: This is my text."
        let result = CleanupService.stripPreamble(input)
        XCTAssertEqual(result, "This is my text.")
    }

    func testStripPreambleRemovesGermanPreamble() {
        let input = "Hier ist der korrigierte Text: Das ist mein Text."
        let result = CleanupService.stripPreamble(input)
        XCTAssertEqual(result, "Das ist mein Text.")
    }

    func testStripPreamblePreservesTextWithoutPreamble() {
        let input = "This is clean text without any preamble."
        let result = CleanupService.stripPreamble(input)
        XCTAssertEqual(result, input)
    }

    func testStripPreambleRemovesSurePreamble() {
        let input = "Sure! This is the corrected version."
        let result = CleanupService.stripPreamble(input)
        XCTAssertEqual(result, "This is the corrected version.")
    }

    func testStripPreambleTrimsWhitespace() {
        let input = "  Here is the corrected text:  cleaned output  "
        let result = CleanupService.stripPreamble(input)
        XCTAssertEqual(result, "cleaned output")
    }

    func testStripPreambleRemovesPleaseProvideRefusalWithContent() {
        let input = "Please provide the text you would like me to polish. Okay, let me rephrase this."
        let result = CleanupService.stripPreamble(input)
        XCTAssertEqual(result, "Okay, let me rephrase this.")
    }

    func testStripPreambleReturnsEmptyForPleaseProvideOnly() {
        let input = "Please provide the text you would like me to polish."
        let result = CleanupService.stripPreamble(input)
        XCTAssertTrue(result.isEmpty, "Full refusal with no content must return empty for raw text fallback")
    }

    func testStripPreambleRemovesPolishedTextPreamble() {
        let input = "Here is the polished text: This reads much better now."
        let result = CleanupService.stripPreamble(input)
        XCTAssertEqual(result, "This reads much better now.")
    }

    func testStripPreambleCollapsesDoubleSpaces() {
        let input = "This  is  a  test  sentence."
        let result = CleanupService.stripPreamble(input)
        XCTAssertEqual(result, "This is a test sentence.")
    }

    func testStripPreambleFixesSpacesBeforePunctuation() {
        let input = "Hello , how are you ? I am fine ."
        let result = CleanupService.stripPreamble(input)
        XCTAssertEqual(result, "Hello, how are you? I am fine.")
    }

    func testStripPreambleCaseInsensitive() {
        let input = "here is the corrected text: lowercase preamble works"
        let result = CleanupService.stripPreamble(input)
        XCTAssertEqual(result, "lowercase preamble works")
    }

    func testStripPreambleRemovesSorryPreamble() {
        let input = "Sorry ,  here ' s  a  polished  version  of  the  text :  This is clean output."
        let result = CleanupService.stripPreamble(input)
        XCTAssertEqual(result, "This is clean output.")
    }

    func testStripPreambleRemovesSurroundingQuotes() {
        let input = "\"One thing that gets on my nerves.\""
        let result = CleanupService.stripPreamble(input)
        XCTAssertEqual(result, "One thing that gets on my nerves.")
    }

    func testStripPreambleHandlesCombinedPreambleAndQuotes() {
        let input = "Sorry ,  here ' s  a  polished  version :  \"Clean text here.\""
        let result = CleanupService.stripPreamble(input)
        XCTAssertEqual(result, "Clean text here.")
    }

    func testStripPreambleRemovesMiddleQuotes() {
        let input = "He said \"hello\" to me."
        let result = CleanupService.stripPreamble(input)
        XCTAssertEqual(result, "He said hello to me.")
    }

    func testStripPreambleRemovesAllUnicodeQuoteVariants() {
        let input = "“Smart quotes” and „German quotes“ and «Guillemets» and ‘Single’ quotes."
        let result = CleanupService.stripPreamble(input)
        XCTAssertEqual(result, "Smart quotes and German quotes and Guillemets and Single quotes.")
    }

    // MARK: - CleanupError

    func testCleanupErrorCasesExist() {
        // Verify the error enum has all expected cases
        let errors: [CleanupError] = [.modelLoadFailed, .contextCreationFailed, .timeout]
        XCTAssertEqual(errors.count, 3)
    }

    // MARK: - Integration tests (require model)

    /// Test actual LLM cleanup with cached model.
    /// Skipped in CI or on machines without the GGUF model cached.
    func testCleanupProducesOutputWithModel() async throws {
        try XCTSkipUnless(
            ModelDownloadService.isModelCached(),
            "Gemma 3 1B GGUF model not cached — skipping integration test"
        )

        CleanupService.initializeBackend()
        let service = CleanupService()
        try service.loadModel(from: ModelDownloadService.modelPath().path)
        XCTAssertTrue(service.isLoaded)

        let result = await service.cleanup(
            text: "um so i went to the uh store and i buyed some milk",
            language: "en"
        )

        // The cleaned text should not be empty
        XCTAssertFalse(result.isEmpty, "Cleanup must produce non-empty output")
        // The cleaned text should differ from input (filler words removed at minimum)
        XCTAssertNotEqual(
            result,
            "um so i went to the uh store and i buyed some milk",
            "Cleanup should modify the text"
        )
    }

    func testCleanupStateTransitionsDuringInference() async throws {
        try XCTSkipUnless(
            ModelDownloadService.isModelCached(),
            "Gemma 3 1B GGUF model not cached — skipping integration test"
        )

        CleanupService.initializeBackend()
        let service = CleanupService()
        try service.loadModel(from: ModelDownloadService.modelPath().path)

        XCTAssertEqual(service.state, .idle, "State must be idle before cleanup")
        // After cleanup completes, state returns to idle
        _ = await service.cleanup(text: "hello world", language: "en")
        XCTAssertEqual(service.state, .idle, "State must return to idle after cleanup")
    }
}
