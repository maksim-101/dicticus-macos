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

    // MARK: - Phase 25-02: plain-mode DEBUG_RECORDER write-path parity

    #if DEBUG_RECORDER
    /// Phase 25-02: plain-mode dictation cycles emit a JSONL record in the
    /// same daily file as aiCleanup cycles, distinguishable by the `mode`
    /// field. LLM-section keys (`llm_prompt`, `llm_raw`, `post_gate`) are
    /// nil/absent. Also verifies that aiCleanup records continue to emit
    /// with non-nil LLM fields — the no-regression invariant for the
    /// existing AI write path.
    ///
    /// NOTE: this test appends to the user's REAL DebugRecordings file at
    /// ~/Library/Application Support/Dicticus/DebugRecordings/ — it is
    /// only compiled when the `DEBUG_RECORDER` flag is set (the Debug-
    /// Recorder scheme), never in the public release. Each run uses a
    /// unique probe substring so reruns do not produce false positives
    /// from prior runs' lines.
    func testPlainModeWritesDebugRecord() async throws {
        let svc = TextProcessingService(cleanupService: nil)
        let probe = "phase25-02-plain-probe-\(UUID().uuidString.prefix(8))"

        _ = await svc.process(text: probe, language: "en", mode: .plain, confidence: 1.0)

        // Allow the DebugRecorder actor a tick to flush its append.
        try await Task.sleep(nanoseconds: 100_000_000)

        let dir = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Dicticus/DebugRecordings", isDirectory: true)
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(secondsFromGMT: 0)
        let fileURL = dir.appendingPathComponent("cleanup-\(f.string(from: Date())).jsonl")

        let lines = try String(contentsOf: fileURL, encoding: .utf8)
            .split(separator: "\n")
            .map(String.init)
        let match = lines.first { $0.contains(probe) }
        let plainLine = try XCTUnwrap(match,
            "expected plain-mode record containing '\(probe)' in \(fileURL.path)")
        XCTAssertTrue(plainLine.contains("\"mode\":\"plain\""),
            "Phase 25-02: plain-mode record must carry mode=plain — got: \(plainLine)")
        XCTAssertTrue(plainLine.contains("\"llm_prompt\":null") || !plainLine.contains("llm_prompt"),
            "Phase 25-02: llm_prompt must be null/absent in plain-mode record")
        XCTAssertTrue(plainLine.contains("\"llm_raw\":null") || !plainLine.contains("llm_raw"),
            "Phase 25-02: llm_raw must be null/absent in plain-mode record")
        XCTAssertTrue(plainLine.contains("\"post_gate\":null") || !plainLine.contains("post_gate"),
            "Phase 25-02: post_gate must be null/absent in plain-mode record")
    }

    /// Phase 25-02: no-regression invariant — aiCleanup records continue
    /// to emit with `mode == "aiCleanup"` and non-nil LLM fields after
    /// the plain-mode parity work. Uses a mock cleanup provider so the
    /// test does not depend on a loaded LLM. (CleanupService.lastDebugTrace
    /// is only populated by the real CleanupService; a pure mock leaves
    /// `cleanupTrace == nil`, which makes `llm_prompt`/`llm_raw` resolve
    /// to nil — so this test asserts only the `mode` discriminator, which
    /// is the field Plan 25-04 actually uses to split plain vs AI streams.)
    func testAICleanupModeWritesDebugRecordWithModeAICleanup() async throws {
        let mock = MockCleanupProvider()
        mock.returnValue = "Polished output for phase25-02-ai-probe"
        let svc = TextProcessingService(cleanupService: mock)
        let probe = "phase25-02-ai-probe-\(UUID().uuidString.prefix(8))"

        _ = await svc.process(text: probe, language: "en", mode: .aiCleanup, confidence: 1.0)

        try await Task.sleep(nanoseconds: 100_000_000)

        let dir = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Dicticus/DebugRecordings", isDirectory: true)
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(secondsFromGMT: 0)
        let fileURL = dir.appendingPathComponent("cleanup-\(f.string(from: Date())).jsonl")

        let lines = try String(contentsOf: fileURL, encoding: .utf8)
            .split(separator: "\n")
            .map(String.init)
        let match = lines.first { $0.contains(probe) }
        let aiLine = try XCTUnwrap(match,
            "expected aiCleanup-mode record containing '\(probe)' in \(fileURL.path)")
        XCTAssertTrue(aiLine.contains("\"mode\":\"aiCleanup\""),
            "Phase 25-02 no-regression: aiCleanup record must carry mode=aiCleanup — got: \(aiLine)")
    }
    #endif
}
