import XCTest
@testable import Dicticus

/// Wave 0 scaffold — CleanupService tests (CLEAN-02, D-04, D-06, D-19, D-28).
///
/// **TDD RED state.** Wave 1 extracts/ports `CleanupService` into `Shared/Services/`
/// (per 19-PATTERNS.md §1) conforming to `CleanupProvider`. Once the service lands,
/// flip `isCleanupServiceReady` to true and replace the test bodies with real
/// assertions against the service.
///
/// Integration tests are gated on `DICTICUS_TEST_MODEL_PATH`. They skip cleanly on
/// CI / local runs where the 3 GB GGUF is not available.
@MainActor
final class CleanupServiceTests: XCTestCase {

    /// Flip in Wave 1 when the shared `CleanupService` is available.
    private let isCleanupServiceReady = false

    private var modelPathFromEnv: String? {
        ProcessInfo.processInfo.environment["DICTICUS_TEST_MODEL_PATH"]
    }

    // MARK: - D-04: Timeout fallback

    func testTimeoutFallback() async throws {
        try XCTSkipIf(!isCleanupServiceReady,
                      "Pending Wave 1: CleanupService not yet available")
        // Wave 1 implementation:
        // 1. Build a CleanupService with injected slow inference (>8 s).
        // 2. await service.cleanup(text: "hello", language: "en", dictionaryContext: nil)
        // 3. XCTAssertEqual(result, "hello")  // raw text returned
    }

    // MARK: - D-28: Concurrent call guard

    func testConcurrentCallGuard() async throws {
        try XCTSkipIf(!isCleanupServiceReady,
                      "Pending Wave 1: CleanupService not yet available")
        // Wave 1 implementation:
        // async let a = service.cleanup(text: "one", language: "en", dictionaryContext: nil)
        // async let b = service.cleanup(text: "two", language: "en", dictionaryContext: nil)
        // let (first, second) = await (a, b)
        // One of {first, second} must equal its raw input (rejected concurrent call).
    }

    // MARK: - D-19: Swiss safety-net gating

    func testSwissSafetyNetGating() async throws {
        try XCTSkipIf(!isCleanupServiceReady,
                      "Pending Wave 1: CleanupService not yet available")
        // Wave 1 implementation:
        // With useSwissGerman=true → cleanup output contains no "ß".
        // With useSwissGerman=false → raw "ß" passes through unchanged.
    }

    // MARK: - D-06: Back-to-back independence (integration)

    func testBackToBackCallsIndependent() async throws {
        try XCTSkipIf(modelPathFromEnv == nil,
                      "Integration test skipped — set DICTICUS_TEST_MODEL_PATH to enable")
        try XCTSkipIf(!isCleanupServiceReady,
                      "Pending Wave 1: CleanupService not yet available")
        // Wave 1 implementation:
        // let s = CleanupService(...); try s.loadModel(from: modelPathFromEnv!)
        // let r1 = await s.cleanup(text: "hallo velt", language: "de", dictionaryContext: nil)
        // let r2 = await s.cleanup(text: "hello world", language: "en", dictionaryContext: nil)
        // XCTAssertFalse(r2.contains("velt"))  // no KV-cache bleed from prior call
    }

    // MARK: - CLEAN-02: Real-model inference (integration)

    func testRealModelInference() async throws {
        try XCTSkipIf(modelPathFromEnv == nil,
                      "Integration test skipped — set DICTICUS_TEST_MODEL_PATH to enable")
        try XCTSkipIf(!isCleanupServiceReady,
                      "Pending Wave 1: CleanupService not yet available")

        // Wave 1 implementation:
        // 1. Load the real GGUF at modelPathFromEnv!.
        // 2. Load CanaryPrompts.json from the test bundle.
        // 3. For each canary, call cleanup() and assert output contains the
        //    expected substrings (fuzzy equality — no strict string match).
        let url = Bundle(for: Self.self).url(forResource: "CanaryPrompts", withExtension: "json")
        _ = try XCTUnwrap(url, "CanaryPrompts.json must ship in the test bundle")
    }

    // MARK: - Fixture sanity (runs unconditionally)

    func testCanaryPromptsFixtureIsBundled() throws {
        let url = Bundle(for: Self.self).url(forResource: "CanaryPrompts", withExtension: "json")
        let unwrappedUrl = try XCTUnwrap(url, "CanaryPrompts.json must ship in the test bundle")
        let data = try Data(contentsOf: unwrappedUrl)
        struct Prompt: Decodable {
            let lang: String
            let input: String
            let expectedContains: [String]
            enum CodingKeys: String, CodingKey {
                case lang, input
                case expectedContains = "expected_contains"
            }
        }
        let prompts = try JSONDecoder().decode([Prompt].self, from: data)
        XCTAssertGreaterThanOrEqual(prompts.count, 6, "Need ≥3 DE + ≥3 EN canaries")
        let de = prompts.filter { $0.lang == "de" }.count
        let en = prompts.filter { $0.lang == "en" }.count
        XCTAssertGreaterThanOrEqual(de, 3)
        XCTAssertGreaterThanOrEqual(en, 3)
    }
}
