import XCTest
@testable import Dicticus

final class CleanupPromptTests: XCTestCase {

    override func tearDown() {
        // Clear any custom instruction between tests
        UserDefaults.standard.removeObject(forKey: CleanupPrompt.customInstructionKey)
        super.tearDown()
    }

    // MARK: - Prompt Structure (V15)

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

        // Phase 25.1-05: V19C German branch — updated few-shots (V15 stutter replaced by V19C native block).
        XCTAssertTrue(prompt.contains("In: das das Meeting ist um fünf"), "Must contain German repetition-disfluency example (V19C)")
        XCTAssertTrue(prompt.contains("In: wir hatten am Montag besprochen dass wir das machen"), "Must contain German fragment example (V19C)")
        XCTAssertTrue(prompt.contains("In: meeting um neun nein eigentlich um acht"), "Must contain German self-correction example (V15 anchor preserved)")
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
        XCTAssertTrue(instruction.contains("V19D"), "Default instruction must reference V19D version (Phase 28 winner)")
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

    // MARK: - Phase 25.1-04: V18C Rule 1 drop + disfluency few-shots

    func testPhase251_V18C_DropsRule1_PunctuationStillCorrect() {
        // Rule 1 ("Fix capitalization and sentence punctuation") is dropped in V18C.
        // Parakeet TDT v3 emits punctuation natively (paper §1); the rule was redundant.
        let prompt = CleanupPrompt.build(text: "test", language: "en")
        XCTAssertFalse(
            prompt.contains("Fix capitalization and sentence punctuation"),
            "V18C must NOT contain Rule 1 cap/punct directive — Parakeet emits punctuation natively"
        )
        // Punctuation is demonstrated via few-shots (e.g. "Start cleanly." with period).
        XCTAssertTrue(
            prompt.contains("Out: Start cleanly."),
            "Punctuation correctness still demonstrated via few-shot output"
        )
    }

    func testPhase251_V18C_ResolvesClassCDisfluency() {
        // Class C targeted few-shot (defect 25-03): lev=5 in iter-1, lev=0 in iter-2.
        let prompt = CleanupPrompt.build(text: "command i or and uh settings of the video player", language: "en")
        XCTAssertTrue(
            prompt.contains("In: command i or and uh settings of the video player"),
            "Class C exemplar must be present as few-shot In: anchor"
        )
        XCTAssertTrue(
            prompt.contains("Out: command i and settings of the video player."),
            "Class C exemplar output must be present as few-shot Out: anchor"
        )
    }

    // MARK: - Phase 25.1-05: V19C German language isolation (paper §5)

    func testPhase251_V19GermanBannerPresent() {
        let p = CleanupPrompt.build(text: "x", language: "de", useSwissGerman: false)
        XCTAssertTrue(p.contains("Sprache: Standard-Hochdeutsch."),
                      "V19C German banner must be present")
        XCTAssertFalse(p.contains("Schweizer Orthographie"),
                       "Swiss banner must be absent when useSwissGerman=false")
    }

    func testPhase251_V19SwissOrthographyBannerWhenEnabled() {
        let p = CleanupPrompt.build(text: "x", language: "de", useSwissGerman: true)
        XCTAssertTrue(p.contains("Schweizer Orthographie: ss statt ß."),
                      "Swiss orthography banner must appear when useSwissGerman=true")
    }

    func testPhase251_V19GermanNativeRulesPresent() {
        // V19C uses native German rules (paper §5.2 language isolation).
        let p = CleanupPrompt.build(text: "x", language: "de")
        XCTAssertTrue(p.contains("Regeln (auf Deutsch):"),
                      "V19C must contain native German rules block")
        XCTAssertTrue(p.contains("V2-Stellung im Hauptsatz"),
                      "V19C must contain V2-positioning rule")
        XCTAssertTrue(p.contains("Komposita"),
                      "V19C must contain compound-noun rule")
    }

    func testPhase251_V19GermanV2PositioningFewShot() {
        // V19C explicit V2-positioning few-shot (paper §5.2 exemplar, Gate 2 fixture).
        let p = CleanupPrompt.build(text: "x", language: "de")
        XCTAssertTrue(p.contains("In: Ich möchte machen ein Termin"),
                      "V19C must contain V2 positioning few-shot input")
        XCTAssertTrue(p.contains("Out: Ich möchte einen Termin machen."),
                      "V19C must contain V2 positioning few-shot output")
    }

    func testPhase251_V19GermanCompoundNounFewShot() {
        // V19C explicit compound-noun reconnection few-shot (paper §5.2, Gate 3 fixture).
        let p = CleanupPrompt.build(text: "x", language: "de")
        XCTAssertTrue(p.contains("In: Wir gehen ins Kranken Haus"),
                      "V19C must contain compound-noun few-shot input")
        XCTAssertTrue(p.contains("Out: Wir gehen ins Krankenhaus."),
                      "V19C must contain compound-noun few-shot output")
    }

    func testPhase251_V19GermanSelfCorrectionPreserveFewShot() {
        // V15 German micro-scalpel anchor must NOT be deleted by V19C (plan guardrail).
        let p = CleanupPrompt.build(text: "x", language: "de")
        XCTAssertTrue(p.contains("meeting um neun nein eigentlich um acht"),
                      "V15 German micro-scalpel few-shot input must be preserved in V19C")
        XCTAssertTrue(p.contains("Meeting um neun, nein eigentlich um acht."),
                      "V15 German micro-scalpel few-shot output must be preserved in V19C")
    }

    func testPhase251_V19EnglishBranchUnchanged() {
        // V19C only touches the de branch. English few-shots from V18C must still be present.
        let p = CleanupPrompt.build(text: "x", language: "en")
        XCTAssertTrue(p.contains("In: command i or and uh settings of the video player"),
                      "V18C Class C English few-shot must be preserved by V19C (English branch unchanged)")
        XCTAssertTrue(p.contains("In: start start cleanly"),
                      "V18C English repetition few-shot must be preserved by V19C")
        XCTAssertFalse(p.contains("Sprache: Standard-Hochdeutsch"),
                       "German banner must NOT appear in English branch")
    }

    // MARK: - Regression guards

    func testWFewShotFromCommit8a79e6bIsAbsent() {
        let prompt = CleanupPrompt.build(text: "test", language: "en")
        XCTAssertFalse(
            prompt.contains("let's see whether"),
            "8a79e6b few-shot must be absent from V15 prompt."
        )
    }

    // MARK: - Phase 28: V19D prompt content tests

    func testPhase28_V19D_DropsTopicWordsLine() {
        let prompt = CleanupPrompt.build(text: "test", language: "en")
        XCTAssertFalse(prompt.contains("Domain topic words"), "V19D must NOT contain 'Domain topic words' line (LLM-PROMPT-AUDIT-01)")
    }

    func testPhase28_V19D_RulesIncludesK4NumberPolicy() {
        let prompt = CleanupPrompt.build(text: "test", language: "en")
        XCTAssertTrue(prompt.contains("8."), "V19D EN prompt must contain Rule 8 (K4 number policy)")
        // Rule 8 body must reference identifier-adjacent policy
        let hasIdentifierAdjacentRef = prompt.contains("identifier-adjacent") || prompt.contains("capitalized stem")
        XCTAssertTrue(hasIdentifierAdjacentRef, "V19D Rule 8 must reference 'identifier-adjacent' or 'capitalized stem' (LLM-NUM-01)")
    }

    func testPhase28_V19D_Rule8PreservesExistingDigits() {
        let prompt = CleanupPrompt.build(text: "test", language: "en")
        XCTAssertTrue(prompt.contains("Preserve digits"), "V19D EN Rule 8 must contain 'Preserve digits' clause (W-01 dual-defense)")
        XCTAssertTrue(prompt.contains("already present"), "V19D EN Rule 8 must contain 'already present' clause (W-01 dual-defense)")
    }

    func testPhase28_V19D_K2ClauseFewShotPresent() {
        let prompt = CleanupPrompt.build(text: "test", language: "en")
        XCTAssertTrue(prompt.contains("in the meantime"), "V19D EN prompt must contain 'in the meantime' K2-clause few-shot (LLM-CLAUSE-01)")
        XCTAssertTrue(prompt.contains("as minimal as possible"), "V19D EN prompt must contain 'as minimal as possible' K2-clause few-shot (LLM-CLAUSE-01)")
    }

    func testPhase28_V19D_K2ContractionFewShotPresent() {
        let prompt = CleanupPrompt.build(text: "test", language: "en")
        XCTAssertTrue(prompt.contains("I'd say"), "V19D EN prompt must contain 'I'd say' contraction few-shot (LLM-CONTR-01)")
        XCTAssertTrue(prompt.contains("don't"), "V19D EN prompt must contain 'don't' in K2-contraction few-shot (LLM-CONTR-01)")
    }

    func testPhase28_V19D_K5DedupFewShotsPresent() {
        let prompt = CleanupPrompt.build(text: "test", language: "en")
        XCTAssertTrue(prompt.contains("that that"), "V19D EN prompt must contain 'that that' K5-dedup few-shot (LLM-DEDUP-01)")
        XCTAssertTrue(prompt.contains("for for"), "V19D EN prompt must contain 'for for' K5-dedup few-shot (LLM-DEDUP-01)")
    }

    func testPhase28_V19D_K4IdentifierFewShotPresent() {
        let prompt = CleanupPrompt.build(text: "test", language: "en")
        XCTAssertTrue(prompt.contains("E1"), "V19D EN prompt must contain 'E1' in K4-identifier few-shot (LLM-NUM-01)")
        XCTAssertTrue(prompt.contains("M3"), "V19D EN prompt must contain 'M3' in K4-identifier few-shot (LLM-NUM-01)")
    }

    func testPhase28_V19D_K4ProseFewShotPresent() {
        let prompt = CleanupPrompt.build(text: "test", language: "en")
        XCTAssertTrue(prompt.contains("I have three meetings today"), "V19D EN prompt must contain 'I have three meetings today' K4-prose few-shot (LLM-NUM-01)")
    }

    func testPhase28_V19D_TheTheRegressionPreserved() {
        let prompt = CleanupPrompt.build(text: "test", language: "en")
        XCTAssertTrue(prompt.contains("the the"), "V19D EN prompt must still contain 'the the' Rule 3 example (D-09 regression guard)")
    }

    func testPhase28_V19D_GermanK4FewShotPresent() {
        let prompt = CleanupPrompt.build(text: "test", language: "de")
        XCTAssertTrue(prompt.contains("Version zwei"), "V19D DE prompt must contain 'Version zwei' K4-identifier few-shot (LLM-NUM-01 DE)")
        XCTAssertTrue(prompt.lowercased().contains("version 2"), "V19D DE prompt must contain 'version 2' in K4-identifier few-shot output (LLM-NUM-01 DE)")
    }

    func testPhase28_V19D_GermanRegel8PreservesExistingDigits() {
        let prompt = CleanupPrompt.build(text: "test", language: "de")
        XCTAssertTrue(prompt.contains("Behalte"), "V19D DE Regel 8 must contain 'Behalte' (W-01 DE parity)")
        XCTAssertTrue(prompt.contains("Ziffern"), "V19D DE Regel 8 must contain 'Ziffern' (W-01 DE parity)")
    }

    func testPhase28_V19D_GermanK2ClauseFewShotPresent() {
        let prompt = CleanupPrompt.build(text: "test", language: "de")
        XCTAssertTrue(prompt.contains("in der Zwischenzeit"), "V19D DE prompt must contain 'in der Zwischenzeit' K2-clause few-shot (LLM-CLAUSE-01 DE)")
    }

    func testPhase28_V19D_GermanDedupFewShotPresent() {
        let prompt = CleanupPrompt.build(text: "test", language: "de")
        // DE dedup few-shot: 'für für' (non-'das das' exemplar per D-09)
        XCTAssertTrue(prompt.contains("für für"), "V19D DE prompt must contain 'für für' K5-dedup few-shot (LLM-DEDUP-01 DE)")
    }

    func testPhase28_V19D_DefaultInstructionUpdated() {
        XCTAssertTrue(CleanupPrompt.defaultInstruction.contains("V19D"), "defaultInstruction must reference V19D (Phase 28 winner)")
        XCTAssertTrue(CleanupPrompt.defaultInstruction.contains("smart-verbatim"), "defaultInstruction must reference smart-verbatim policy")
    }

    func testPhase28_V19D_ExistingAnchorsStillPresent() {
        let enPrompt = CleanupPrompt.build(text: "test", language: "en")
        let dePrompt = CleanupPrompt.build(text: "test", language: "de")
        XCTAssertTrue(enPrompt.contains("meeting at forty one Penn"), "Phase 25 anchor 'meeting at forty one Penn' must survive V19D (regression guard)")
        XCTAssertTrue(enPrompt.contains("command i"), "Class C anchor 'command i' must survive V19D (regression guard)")
        XCTAssertTrue(dePrompt.contains("Regeln (auf Deutsch):"), "DE 'Regeln (auf Deutsch):' block must survive V19D (regression guard)")
    }
}
