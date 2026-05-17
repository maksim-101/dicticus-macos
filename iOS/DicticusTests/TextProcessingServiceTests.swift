import XCTest
@testable import Dicticus

/// Wave 0 scaffold — TextProcessingService integration with CleanupProvider
/// (D-13, D-23, CLEAN-01).
///
/// These tests are CONCRETE and run today — `TextProcessingService` and
/// `CleanupProvider` already exist in `Shared/`. A local `MockCleanupProvider`
/// stands in for the Wave 1 `CleanupService`.
@MainActor
final class TextProcessingServiceTests: XCTestCase {

    /// Minimal mock conforming to the existing `CleanupProvider` protocol.
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

    // MARK: - D-23 / CLEAN-01: Cleanup path is wired

    func testCleanupPath() async {
        let mock = MockCleanupProvider()
        mock.returnValue = "Hallo Welt, das ist ein Test."
        let service = TextProcessingService(cleanupService: mock)

        let output = await service.process(
            text: "hallo welt das ist ein test",
            language: "de",
            mode: .aiCleanup
        )

        XCTAssertEqual(mock.callCount, 1, "Cleanup mock must be invoked once in .aiCleanup mode")
        XCTAssertEqual(mock.lastLanguage, "de")
        XCTAssertEqual(output, "Hallo Welt, das ist ein Test.")
    }

    // MARK: - Plain mode bypasses cleanup

    func testPlainModeSkipsCleanup() async {
        let mock = MockCleanupProvider()
        let service = TextProcessingService(cleanupService: mock)

        let output = await service.process(
            text: "hallo welt",
            language: "de",
            mode: .plain
        )

        XCTAssertEqual(mock.callCount, 0, "Cleanup mock must NOT run in .plain mode")
        // Dictionary + ITN passes still run, but with no cleanup the text survives
        // in recognizable form.
        XCTAssertTrue(output.contains("welt") || output.contains("Welt"),
                      "Plain output should preserve the input text")
    }

    // MARK: - D-13: Blocks until cleaned (no raw-then-replace)

    func testBlocksUntilCleaned() async {
        let mock = MockCleanupProvider()
        mock.artificialDelayMs = 250
        mock.returnValue = "polished"
        let service = TextProcessingService(cleanupService: mock)

        let start = Date()
        let output = await service.process(
            text: "hello",
            language: "en",
            mode: .aiCleanup
        )
        let elapsed = Date().timeIntervalSince(start)

        XCTAssertEqual(output, "polished",
                       "process() must return the cleaned value, not the raw input")
        XCTAssertGreaterThanOrEqual(elapsed, 0.2,
                                    "process() must block until cleanup completes (D-13)")
    }

    // MARK: - Cleanup skipped when provider reports !isLoaded

    func testCleanupSkippedWhenProviderNotLoaded() async {
        let mock = MockCleanupProvider()
        mock.isLoaded = false
        let service = TextProcessingService(cleanupService: mock)

        _ = await service.process(text: "hello", language: "en", mode: .aiCleanup)

        XCTAssertEqual(mock.callCount, 0,
                       "Cleanup must be skipped when provider.isLoaded == false")
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
    /// Phase 25-02 (iOS parity): plain-mode dictation cycles emit a JSONL
    /// record in the same daily file as aiCleanup cycles, distinguishable
    /// by the `mode` field. LLM-section keys (`llm_prompt`, `llm_raw`,
    /// `post_gate`) are nil/absent. Also verifies that aiCleanup records
    /// continue to emit with the `aiCleanup` mode tag.
    ///
    /// NOTE: this test appends to the app's REAL DebugRecordings file under
    /// the iOS simulator's Application Support sandbox — it is only
    /// compiled when the `DEBUG_RECORDER` flag is set. Each run uses a
    /// unique probe substring so reruns do not produce false positives.
    ///
    /// Cross-platform parity (feedback_cleanup_cross_platform_parity):
    /// mirrors macOS/DicticusTests/TextProcessingServiceTests.swift.
    func testPlainModeWritesDebugRecord() async throws {
        let svc = TextProcessingService(cleanupService: nil)
        let probe = "phase25-02-plain-probe-\(UUID().uuidString.prefix(8))"

        _ = await svc.process(text: probe, language: "en", mode: .plain, confidence: 1.0)

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

    /// Phase 25-02 (iOS parity): no-regression invariant — aiCleanup
    /// records continue to emit with `mode == "aiCleanup"`. Mirrors the
    /// macOS test of the same name.
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

    // MARK: - Phase 25.1-01: telemetry parity (lang_used + emission_counter)
    //
    // Closes the 25-04 SUMMARY's two telemetry gaps:
    //   Gap 1 (lang_used null in 100% of records) — was a schema-name mismatch;
    //          this test asserts the new alias is populated whenever `lang` is.
    //   Gap 2 (plain-mode emission near-zero, ambiguous cause) — this test asserts
    //          two sequential invocations produce records with counter delta == 1,
    //          which means future capture windows can prove dual-emission fires by
    //          checking counter monotonicity across all records in a file.
    //
    // Pattern follows Phase 25-02 (UUID probe + today's-JSONL scan).
    // Cross-platform parity (feedback_cleanup_cross_platform_parity):
    // mirrors macOS/DicticusTests/TextProcessingServiceTests.swift.

    func testPhase251_LangUsedMirrorsLang() async throws {
        let probe = "phase251-lang-probe-\(UUID().uuidString.prefix(8))"
        let svc = TextProcessingService(cleanupService: nil)

        _ = await svc.process(text: probe, language: "de", mode: .plain, confidence: 1.0)

        try await Task.sleep(nanoseconds: 150_000_000)  // 150ms — DebugRecorder actor flush

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
        let line = try XCTUnwrap(match, "Probe record missing from today's JSONL at \(fileURL.path)")
        guard let data = line.data(using: .utf8),
              let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            return XCTFail("Failed to parse probe JSONL line as JSON")
        }
        XCTAssertEqual(obj["lang"] as? String, "de",
            "Phase 25.1-01: lang field must equal the language passed to process()")
        XCTAssertEqual(obj["lang_used"] as? String, "de",
            "Phase 25.1-01: lang_used must mirror lang (closes 25-04 §Gap 1)")
    }

    func testPhase251_EmissionCounterMonotonicAcrossModes() async throws {
        let probeA = "phase251-emit-plain-\(UUID().uuidString.prefix(8))"
        let probeB = "phase251-emit-ai-\(UUID().uuidString.prefix(8))"
        let mock = MockCleanupProvider()
        mock.returnValue = "ai output \(probeB)"
        let svc = TextProcessingService(cleanupService: mock)

        _ = await svc.process(text: probeA, language: "en", mode: .plain, confidence: 1.0)
        _ = await svc.process(text: probeB, language: "en", mode: .aiCleanup, confidence: 1.0)

        try await Task.sleep(nanoseconds: 200_000_000)  // 200ms — both actor flushes

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
        let lineA = lines.first { $0.contains(probeA) }
        let lineB = lines.first { $0.contains(probeB) }
        let a = try XCTUnwrap(lineA, "Plain-mode probe record missing from JSONL")
        let b = try XCTUnwrap(lineB, "AI-mode probe record missing from JSONL")
        guard let dataA = a.data(using: .utf8), let dataB = b.data(using: .utf8),
              let oa = (try? JSONSerialization.jsonObject(with: dataA)) as? [String: Any],
              let ob = (try? JSONSerialization.jsonObject(with: dataB)) as? [String: Any] else {
            return XCTFail("Failed to parse probe JSONL lines as JSON")
        }
        guard let ca = oa["emission_counter"] as? Int, let cb = ob["emission_counter"] as? Int else {
            return XCTFail("emission_counter missing or wrong type in one or both records (closes 25-04 §Gap 2)")
        }
        XCTAssertEqual(cb - ca, 1,
            "Phase 25.1-01: two sequential process() invocations must produce emission_counter delta == 1 (closes 25-04 §Gap 2)")
    }
    #endif
}
