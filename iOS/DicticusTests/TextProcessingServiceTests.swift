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
}
