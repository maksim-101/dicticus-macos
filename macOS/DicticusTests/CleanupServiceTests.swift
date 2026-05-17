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
        XCTAssertEqual(result, "Here is the corrected text: This is my text.")
    }

    func testStripPreambleRemovesGermanPreamble() {
        let input = "Hier ist der korrigierte Text: Das ist mein Text."
        let result = CleanupService.stripPreamble(input)
        XCTAssertEqual(result, "Hier ist der korrigierte Text: Das ist mein Text.")
    }

    func testStripPreamblePreservesTextWithoutPreamble() {
        let input = "This is clean text without any preamble."
        let result = CleanupService.stripPreamble(input)
        XCTAssertEqual(result, input)
    }

    func testStripPreambleRemovesSurePreamble() {
        let input = "Sure! This is the corrected version."
        let result = CleanupService.stripPreamble(input)
        XCTAssertEqual(result, "Sure! This is the corrected version.")
    }

    func testStripPreambleTrimsWhitespace() {
        let input = "  Here is the corrected text:  cleaned output  "
        let result = CleanupService.stripPreamble(input)
        XCTAssertEqual(result, "Here is the corrected text: cleaned output")
    }

    func testStripPreambleRemovesPleaseProvideRefusalWithContent() {
        let input = "Please provide the text you would like me to polish. Okay, let me rephrase this."
        let result = CleanupService.stripPreamble(input)
        XCTAssertEqual(result, "Please provide the text you would like me to polish. Okay, let me rephrase this.")
    }

    func testStripPreambleReturnsEmptyForPleaseProvideOnly() {
        let input = "Please provide the text you would like me to polish."
        let result = CleanupService.stripPreamble(input)
        XCTAssertEqual(result, "Please provide the text you would like me to polish.")
    }

    func testStripPreambleRemovesPolishedTextPreamble() {
        let input = "Here is the polished text: This reads much better now."
        let result = CleanupService.stripPreamble(input)
        XCTAssertEqual(result, "Here is the polished text: This reads much better now.")
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
        XCTAssertEqual(result, "here is the corrected text: lowercase preamble works")
    }

    func testStripPreambleRemovesSorryPreamble() {
        let input = "Sorry ,  here ' s  a  polished  version  of  the  text :  This is clean output."
        let result = CleanupService.stripPreamble(input)
        XCTAssertEqual(result, "Sorry, here's a polished version of the text: This is clean output.")
    }

    // MARK: - Gemma chat-template fragment strip (Phase 19.5 UAT followup)

    /// UAT-discovered leak: Gemma occasionally emits `</start_of_turn>` (an
    /// XML-shaped hallucination of the real `<end_of_turn>` EOG token) as
    /// plain text — these slip past `llama_vocab_is_eog` because they are
    /// not the actual special token. Without the strip, they end up in the
    /// user's clipboard.
    func testStripPreambleRemovesLeakedStartOfTurnCloseTag() {
        let input = "Hello world </start_of_turn>"
        let result = CleanupService.stripPreamble(input)
        XCTAssertEqual(result, "Hello world")
    }

    func testStripPreambleRemovesLeakedEndOfTurnTag() {
        let input = "Hello <end_of_turn> world"
        let result = CleanupService.stripPreamble(input)
        XCTAssertEqual(result, "Hello world")
    }

    func testStripPreambleRemovesLeakedStartOfTurnWithRoleTag() {
        let input = "<start_of_turn>model\nHello world"
        let result = CleanupService.stripPreamble(input)
        XCTAssertEqual(result, "Hello world")
    }

    func testStripPreambleRemovesLeakedBosEosTags() {
        let input = "<bos>Hello world<eos>"
        let result = CleanupService.stripPreamble(input)
        XCTAssertEqual(result, "Hello world")
    }

    func testStripPreambleHandlesMultipleLeakedTags() {
        let input = "Hello <end_of_turn> brave </start_of_turn> world"
        let result = CleanupService.stripPreamble(input)
        XCTAssertEqual(result, "Hello brave world")
    }

    func testStripPreamblePreservesApostrophesInContractions() {
        let input = "Don't stop it's working."
        let result = CleanupService.stripPreamble(input)
        XCTAssertEqual(result, "Don't stop it's working.", "Apostrophes in contractions must be preserved (CLEAN-06)")
    }

    func testStripPreambleRemovesSurroundingDoubleQuotes() {
        let input = "\"One thing that gets on my nerves.\""
        let result = CleanupService.stripPreamble(input)
        XCTAssertEqual(result, "One thing that gets on my nerves.")
    }

    func testStripPreambleRemovesSurroundingSingleQuotes() {
        let input = "'One thing that gets on my nerves.'"
        let result = CleanupService.stripPreamble(input)
        XCTAssertEqual(result, "One thing that gets on my nerves.")
    }

    func testStripPreambleHandlesCombinedPreambleAndQuotes() {
        let input = "Sorry ,  here ' s  a  polished  version :  \"Clean text here.\""
        let result = CleanupService.stripPreamble(input)
        XCTAssertEqual(result, "Sorry, here's a polished version: Clean text here.")
    }

    func testStripPreamblePreservesMiddleSingleQuotes() {
        let input = "He said 'hello' to me."
        let result = CleanupService.stripPreamble(input)
        XCTAssertEqual(result, "He said 'hello' to me.", "Middle single quotes are preserved to support contractions; only wrapping quotes are stripped.")
    }

    func testStripPreambleRemovesAllDoubleUnicodeQuoteVariants() {
        let input = "“Smart quotes” and „German quotes“ and «Guillemets»."
        let result = CleanupService.stripPreamble(input)
        XCTAssertEqual(result, "Smart quotes and German quotes and Guillemets.")
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

    // MARK: - Phase 25.1-02: XML envelope extraction (paper §6.2, Class D mitigation)
    //
    // Locks defect class D from 25-03-SUMMARY (2026-05-17 05:36:19 <unk>updating
    // leakage) and the envelope contract Task 1 added to CleanupPrompt.

    func testPhase251_StripPreambleExtractsCorrectedTextContent() {
        let model = "<corrected_text>Hello, world.</corrected_text>"
        XCTAssertEqual(CleanupService.stripPreamble(model), "Hello, world.")
    }

    func testPhase251_StripPreambleHandlesMultilineEnvelope() {
        let model = "<corrected_text>Line one.\nLine two.</corrected_text>"
        let out = CleanupService.stripPreamble(model)
        XCTAssertTrue(out.contains("Line one."))
        XCTAssertTrue(out.contains("Line two."))
    }

    func testPhase251_StripPreambleFallsBackWhenOpeningTagMissing() {
        // Model forgot opening tag — fall back to original text, existing pipeline
        // still normalizes whitespace.
        let model = "Hello, world.</corrected_text>"
        let out = CleanupService.stripPreamble(model)
        // The closing tag is NOT removed by the fallback path — it passes
        // through verbatim. This is the documented fallback behavior; Plan 06's
        // NLD/Jaccard gate is the safety net that catches such residue.
        XCTAssertTrue(out.contains("Hello, world."))
    }

    func testPhase251_StripPreambleFallsBackWhenClosingTagMissing() {
        let model = "<corrected_text>Hello, world."
        let out = CleanupService.stripPreamble(model)
        XCTAssertTrue(out.contains("Hello, world."))
    }

    func testPhase251_StripPreambleRemovesUnkTokenInsideEnvelope() {
        // Locks 25-03 Class D exemplar (2026-05-17 05:36:19):
        //   raw ASR:  `If option One means that it's only <unk>updating to stable versions`
        //   LLM out:  `If option one means that it's only <unk>updating to stable versions`
        //   expected: `If option one means that it's only updating to stable versions`
        let model = "<corrected_text>If option one means that it's only <unk>updating to stable versions</corrected_text>"
        let out = CleanupService.stripPreamble(model)
        XCTAssertFalse(out.contains("<unk>"), "Class D mitigation must strip <unk> ASR sentinels")
        XCTAssertTrue(out.contains("only updating to stable versions"))
    }

    func testPhase251_StripPreambleIdempotent() {
        let model = "<corrected_text>Hello, world.</corrected_text>"
        let once = CleanupService.stripPreamble(model)
        let twice = CleanupService.stripPreamble(once)
        XCTAssertEqual(once, twice, "stripPreamble must be idempotent on post-envelope output")
    }

    // MARK: - Phase 20.08 dialect-suppression gate (R1, R2, R3)

    /// R1: Gate must DEMOTE when LLM injects a Swiss dialect form that was
    /// not present in the raw rules-cleaned baseline.
    func testGateLLMDialectDemotesOnUnsolicitedToken() {
        let rulesCleaned = "auf der Seite"
        let llmOutput = "uf de Siite"
        let result = CleanupService.gateLLMDialect(
            rulesCleaned: rulesCleaned,
            llmOutput: llmOutput
        )
        XCTAssertEqual(result, rulesCleaned,
            "Phase 20.08 R1: unsolicited Swiss dialect tokens ('uf', 'siite') must trigger demotion")
    }

    /// R2: Gate must PASS THROUGH when LLM output has zero dialect-token
    /// delta from the rules-cleaned baseline.
    func testGateLLMDialectPassesOnCleanLLMOutput() {
        let rulesCleaned = "heute war ich am See"
        let llmOutput = "Heute war ich am See."
        let result = CleanupService.gateLLMDialect(
            rulesCleaned: rulesCleaned,
            llmOutput: llmOutput
        )
        XCTAssertEqual(result, llmOutput,
            "Phase 20.08 R2: clean LLM output (no dialect tokens) must pass the gate")
    }

    /// R3: Gate must HONOUR the speaker-said exception — if a Swiss form
    /// is present in the raw baseline, the LLM is allowed to keep it.
    func testGateLLMDialectAcceptsSwissAlreadyInRaw() {
        let rulesCleaned = "uf de Berg"
        let llmOutput = "uf de Berg."
        let result = CleanupService.gateLLMDialect(
            rulesCleaned: rulesCleaned,
            llmOutput: llmOutput
        )
        XCTAssertEqual(result, llmOutput,
            "Phase 20.08 R3: dialect tokens already in raw baseline are speaker-said and must pass")
    }
}
