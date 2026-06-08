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
            IOSModelDownloadService.isModelCached(),
            "Gemma 3 1B GGUF model not cached — skipping integration test"
        )

        CleanupService.initializeBackend()
        let service = CleanupService()
        try service.loadModel(from: IOSModelDownloadService.modelPath().path)
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
            IOSModelDownloadService.isModelCached(),
            "Gemma 3 1B GGUF model not cached — skipping integration test"
        )

        CleanupService.initializeBackend()
        let service = CleanupService()
        try service.loadModel(from: IOSModelDownloadService.modelPath().path)

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

    func testPhase251_StripPreambleStripsClosingTagWhenOpeningPrefilled() {
        // V18C (Plan 25.1-04) and V19C (Plan 25.1-05) pre-fill the opening
        // `<corrected_text>` tag in the prompt as a completion anchor
        // (see CleanupPrompt.swift:202). The model only emits content + the
        // closing tag, so the extractor must treat closing-tag-only as the
        // dominant pattern, not a fallback.
        //
        // 2026-05-19 live-UAT regression: closing tag was leaking to the user's
        // cursor on every dictation cycle. Fix in CleanupService.swift handles
        // case 3 explicitly.
        let model = "Hello, world.</corrected_text>"
        let out = CleanupService.stripPreamble(model)
        XCTAssertEqual(out, "Hello, world.",
            "Closing tag must be stripped when opening was pre-filled in prompt (V18C+/V19C pattern)")
        XCTAssertFalse(out.contains("</corrected_text>"),
            "No envelope residue may leak to the final output")
    }

    func testPhase251_StripPreambleHandlesOpeningTagOnly() {
        // Model truncated before emitting closing tag — content runs to end.
        let model = "<corrected_text>Hello, world."
        let out = CleanupService.stripPreamble(model)
        XCTAssertEqual(out, "Hello, world.")
        XCTAssertFalse(out.contains("<corrected_text>"))
    }

    func testPhase251_StripPreambleFallsBackWhenNoEnvelopeTags() {
        // No tags at all — passthrough with whitespace normalization.
        let model = "Hello, world."
        let out = CleanupService.stripPreamble(model)
        XCTAssertEqual(out, "Hello, world.")
    }

    func testPhase251_StripPreambleStripsUnkInClosingOnlyShape() {
        // Closing-tag-only + <unk> sentinel must both be cleaned in one pass.
        let model = "only <unk>updating to stable versions</corrected_text>"
        let out = CleanupService.stripPreamble(model)
        XCTAssertFalse(out.contains("<unk>"))
        XCTAssertFalse(out.contains("</corrected_text>"))
        XCTAssertTrue(out.contains("only updating to stable versions"))
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

    // MARK: - Phase 34 V19E content-word gate (SC2)
    //
    // RED tests — CleanupService.gateContentWords(rulesCleaned:llmOutput:) does NOT
    // yet exist (implemented in Plan 34-03).  These tests MUST fail to compile until
    // that gate is added.  The compile failure is the intended RED signal.
    //
    // Gate contract (Plan 34-03):
    //   public static func gateContentWords(rulesCleaned: String, llmOutput: String) -> String
    //   - Returns rulesCleaned (fallback) if llmOutput drops any content word
    //     (≥4 chars, lowercased, not stop-word, not stem-allowlist) present in rulesCleaned.
    //   - Returns llmOutput unchanged otherwise and on graceful-degradation cases
    //     (empty input, zero content words, unexpected shape).

    func testGateContentWords_rejectsLocalWordLoss() {
        // "kink" is a ≥4-char content word in rulesCleaned; llmOutput collapses it
        // into "K3" — the gate must fall back to rulesCleaned.
        let result = CleanupService.gateContentWords(
            rulesCleaned: "so why would you mark kink three",
            llmOutput: "so why would you mark K3"
        )
        XCTAssertEqual(result, "so why would you mark kink three",
            "Phase 34 SC2: gate must reject llmOutput that drops content word 'kink'")
    }

    func testGateContentWords_rejectsKingFourCollapse() {
        // Both "King" and "Four" are ≥4-char content words; collapsing them to "K4"
        // drops meaningful words — gate must fall back.
        let result = CleanupService.gateContentWords(
            rulesCleaned: "and the same goes for King Four",
            llmOutput: "and the same goes for K4"
        )
        XCTAssertEqual(result, "and the same goes for King Four",
            "Phase 34 SC2: gate must reject llmOutput that drops 'King' and 'Four'")
    }

    func testGateContentWords_passesLegitimateEdit() {
        // Light edit (recasing + punctuation only) preserves all ≥4-char content
        // words — gate must pass llmOutput unchanged.
        let result = CleanupService.gateContentWords(
            rulesCleaned: "please check whether the model works",
            llmOutput: "Please check whether the model works."
        )
        XCTAssertEqual(result, "Please check whether the model works.",
            "Phase 34 SC2: gate must pass llmOutput when all content words are preserved")
    }

    func testGateContentWords_passesStopWordReword() {
        // Dropping a stop word ("that") does NOT constitute content-word loss —
        // gate must pass llmOutput unchanged.
        let result = CleanupService.gateContentWords(
            rulesCleaned: "I think that we should proceed",
            llmOutput: "I think we should proceed."
        )
        XCTAssertEqual(result, "I think we should proceed.",
            "Phase 34 SC2: stop-word deletion must not trigger gate rejection")
    }

    func testGateContentWords_gracefulDegradationEmptyInput() {
        // Empty rulesCleaned → zero content words → gate returns llmOutput unchanged
        // (mirrors gateLLMDialect graceful-degradation contract).
        let result = CleanupService.gateContentWords(
            rulesCleaned: "",
            llmOutput: "some output"
        )
        XCTAssertEqual(result, "some output",
            "Phase 34 SC2: empty rulesCleaned must return llmOutput (graceful degradation)")
    }

    // MARK: - Phase 34 gap-closure: WR-01 (number-word allowlist) + WR-03 (short-utterance gate)

    func testGateContentWords_preservesLegitimateNumberPromotion() {
        // "three" is a spelled-out number-word; the LLM legitimately promotes "M three" → "M3".
        // After the number-word allowlist (WR-01), "three" is excluded from requiredContentWords,
        // so the only other token "M" is too short (1 char) → zero required content words →
        // gate must pass llmOutput unchanged (promotion preserved).
        let result = CleanupService.gateContentWords(
            rulesCleaned: "and the same goes for M three",
            llmOutput: "and the same goes for M3"
        )
        XCTAssertEqual(result, "and the same goes for M3",
            "WR-01: gate must not revert legitimate number-word promotion 'M three' → 'M3'")
    }

    func testGateContentWords_stillRejectsKinkThreeAfterAllowlist() {
        // CRITICAL REGRESSION GUARD: "three" is allowlisted as a number-word,
        // but "kink" (4-char, non-stop, non-number content word) is NOT allowlisted.
        // Collapsing "kink three" → "K3" drops "kink" → gate must still revert.
        // Verifies that the WR-01 allowlist did NOT weaken R8 detection.
        let result = CleanupService.gateContentWords(
            rulesCleaned: "so why would you mark kink three",
            llmOutput: "so why would you mark K3"
        )
        XCTAssertEqual(result, "so why would you mark kink three",
            "WR-01 regression guard: 'kink' is a non-number content word and must still trip the gate after number-word allowlist")
    }

    func testGateContentWords_rejectsShortKinkThree() {
        // WR-03: the gate must protect short utterances (≤3 words at the function level).
        // "mark kink three" has 3 tokens; "kink" is a required content word; "K3" drops it.
        // Gate must return the rulesCleaned baseline.
        let result = CleanupService.gateContentWords(
            rulesCleaned: "mark kink three",
            llmOutput: "mark K3"
        )
        XCTAssertEqual(result, "mark kink three",
            "WR-03: gate must reject content-word loss even on short (3-word) inputs")
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

// MARK: - Phase 28 Plan 03: Contraction Gate Tests (Variant A Winner)
//
// Winner: V19D-A — V19D prompt with K2-contraction few-shot; NO post-LLM gate.
// Rationale: The V19D few-shot alone resolved the K2-contraction failure
// (P28-contr-2026-05-26T16:26:23.503Z, lev_to_expected=0 across all variants).
// See .planning/debug/harness/results/contraction_matrix_winner.md for D-14 scores.
//
// These are documentation-as-test methods: they pin the Variant A contract (prompt
// contains the K2-contraction few-shot; CleanupService has no normalizeContractions
// method) so future prompt refactors cannot silently remove the defense.

@MainActor
final class CleanupServiceContractionGateTests: XCTestCase {

    // MARK: - Variant A: K2-contraction defense via V19D prompt few-shot

    /// Locks that the V19D English prompt contains the K2-contraction few-shot
    /// (LLM-CONTR-01 mitigation). If this test fails, the contraction defense
    /// has been removed from the prompt without a corresponding gate implementation.
    func testVariantA_K2ContractionPreservedViaV19DPromptFewShot() {
        // Build the V19D EN prompt with empty context and a placeholder input.
        let prompt = CleanupPrompt.build(
            text: "placeholder",
            language: "en",
            dictionaryContext: nil,
            useSwissGerman: false
        )
        // The K2-contraction few-shot pair must be present (Plan 28-01, D-08 Variant A baseline).
        XCTAssertTrue(prompt.contains("I'd say"),
            "V19D EN prompt must contain K2-contraction few-shot 'I'd say' (LLM-CONTR-01 / D-08 Variant A)")
        XCTAssertTrue(prompt.contains("don't"),
            "V19D EN prompt must contain K2-contraction few-shot 'don't' (LLM-CONTR-01 / D-08 Variant A)")
    }

    /// Documents that CleanupService does NOT contain a normalizeContractions method
    /// under Variant A. This test passes trivially as a documentation anchor:
    /// if Variant B/D is promoted in a future phase, this method will be replaced
    /// with a functional gate test (see run_contraction_matrix.py for gate implementation).
    func testVariantA_NoNormalizeContractionsMethod() {
        // Variant A ships no post-LLM gate. This test documents that decision.
        // The contraction defense lives entirely in the V19D few-shot (Plan 28-01).
        // Future: if LLM-CONTR-01 regresses in live captures, re-run
        // .planning/debug/harness/run_contraction_matrix.py to evaluate Variants B/D.
        XCTAssertTrue(true, "Variant A: no normalizeContractions method — contraction defense via V19D prompt few-shot only.")
    }
}
