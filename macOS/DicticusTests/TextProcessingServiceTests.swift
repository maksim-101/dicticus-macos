import XCTest
@testable import Dicticus

@MainActor
final class TextProcessingServiceTests: XCTestCase {

    /// Mirror of iOS MockCleanupProvider for cross-platform parity (Phase 20.08 R7).
    /// Per feedback_cleanup_cross_platform_parity memory.
    final class MockCleanupProvider: CleanupProvider {
        var isLoaded: Bool = true
        private(set) var callCount = 0
        private(set) var lastLanguage: String = ""
        private(set) var lastInput: String = ""
        var returnValue: String = "cleaned output"
        var artificialDelayMs: UInt64 = 0

        func cleanup(text: String, language: String, dictionaryContext: [String: String]?) async -> String {
            callCount += 1
            lastLanguage = language
            lastInput = text
            if artificialDelayMs > 0 {
                try? await Task.sleep(nanoseconds: artificialDelayMs * 1_000_000)
            }
            return returnValue
        }
    }

    var service: TextProcessingService!
    var dictionaryService: DictionaryService!

    override func setUp() {
        super.setUp()
        // Use a fresh dictionary service for isolation
        UserDefaults.standard.removeObject(forKey: DictionaryService.dictionaryKey)
        dictionaryService = DictionaryService.shared
        dictionaryService.removeAll()
        service = TextProcessingService(dictionaryService: dictionaryService, cleanupService: nil)
    }

    func testPipelineOrder() async {
        // 1. Set up dictionary: "bird" -> "one hundred"
        dictionaryService.setReplacement(for: "bird", with: "one hundred")

        let input = "I have a bird"
        // Expected: "I have a bird" -> "I have a one hundred" (Dictionary) -> "I have a 100" (ITN)
        let output = await service.process(text: input, language: "en", mode: .plain)

        XCTAssertEqual(output, "I have a 100")
    }

    func testGermanPipeline() async {
        dictionaryService.setReplacement(for: "Apfel", with: "einhundert")

        let input = "Ich habe einen Apfel"
        // Expected: "Ich habe einen Apfel" -> "Ich habe einen einhundert" -> "Ich habe einen 100"
        let output = await service.process(text: input, language: "de", mode: .plain)

        XCTAssertEqual(output, "Ich habe einen 100")
    }

    // MARK: - Phase 20.08 R7: dialect gate stacks before Levenshtein

    /// Phase 20.08 R7: dialect gate runs BEFORE Levenshtein gate.
    /// Mock LLM returns Swiss-ified output — final processedText must NOT
    /// contain Swiss dialect tokens (gate demoted to rules-cleaned baseline),
    /// proving the dialect gate fires BEFORE the structural Levenshtein gate.
    ///
    /// Word-boundary check: substring "uf " is also inside "auf ", so
    /// dialect-token presence is verified via the same tokenizer the gate
    /// uses (`tokenizeForDialectGate`), not raw substring `.contains`.
    func testDialectGateRunsBeforeLevenshteinAndDemotes() async {
        let mock = MockCleanupProvider()
        mock.returnValue = "uf de andere Siite"
        let service = TextProcessingService(cleanupService: mock)

        let output = await service.process(
            text: "auf der anderen seite",
            language: "de",
            mode: .aiCleanup
        )

        let outputTokens = Set(CleanupService.tokenizeForDialectGate(output))
        XCTAssertFalse(outputTokens.contains("uf"),
            "Phase 20.08 R7: dialect gate must demote — output must not contain Swiss form 'uf' as a word token")
        XCTAssertFalse(outputTokens.contains("siite"),
            "Phase 20.08 R7: dialect gate must demote — output must not contain Swiss form 'siite' as a word token")
    }
}
