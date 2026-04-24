import XCTest
@testable import Dicticus

/// CleanupService tests (CLEAN-02, D-04, D-06, D-19, D-26, D-28).
///
/// Wave 1 landed `Shared/Services/CleanupService.swift` conforming to
/// `CleanupProvider`. The unloaded-service tests below exercise the D-26
/// fallback contract without a model file; real-inference tests gate on
/// `DICTICUS_TEST_MODEL_PATH` so the 3 GB GGUF is opt-in per run.
@MainActor
final class CleanupServiceTests: XCTestCase {

    private var modelPathFromEnv: String? {
        ProcessInfo.processInfo.environment["DICTICUS_TEST_MODEL_PATH"]
    }

    /// Reset Swiss toggle before every test so the safety-net gating test is
    /// deterministic regardless of previous-run residue in the AppGroup suite.
    override func setUp() async throws {
        try await super.setUp()
        let suite = UserDefaults(suiteName: "group.com.dicticus") ?? .standard
        suite.removeObject(forKey: "useSwissGerman")
    }

    override func tearDown() async throws {
        let suite = UserDefaults(suiteName: "group.com.dicticus") ?? .standard
        suite.removeObject(forKey: "useSwissGerman")
        try await super.tearDown()
    }

    // MARK: - D-04 / D-26: Fallback contract on unloaded service

    /// A CleanupService that has not had `loadModel` called must return the
    /// raw text from `cleanup()` (the first guard at line ~156 of
    /// Shared/Services/CleanupService.swift). This validates the D-26 graceful-
    /// degradation contract that the rest of the pipeline depends on — the
    /// 8 s timeout (D-04) is the *second* fallback; this "no model" fallback
    /// is the *first*. The DictationViewModel's `llmReady` gate ensures we
    /// don't even reach this path in practice, but the contract must hold.
    func testTimeoutFallback() async throws {
        let service = CleanupService(inferenceTimeoutSeconds: 0.5)  // fast failure budget
        XCTAssertFalse(service.isLoaded,
                       "Fresh CleanupService must report !isLoaded before loadModel()")

        let output = await service.cleanup(
            text: "hello world",
            language: "en",
            dictionaryContext: nil
        )

        XCTAssertEqual(output, "hello world",
                       "cleanup() must return raw text when model is not loaded (D-26)")
    }

    // MARK: - D-28: Concurrent call guard (integration)

    /// Requires a loaded model — the isInferring guard only fires after the
    /// isLoaded guard. Without a real GGUF, both concurrent calls return at
    /// the first guard, so the race cannot be exercised here.
    func testConcurrentCallGuard() async throws {
        try XCTSkipIf(modelPathFromEnv == nil,
                      "Integration test skipped — set DICTICUS_TEST_MODEL_PATH to enable (D-28 needs a loaded model)")

        let service = CleanupService(inferenceTimeoutSeconds: 8.0)
        try service.loadModel(from: modelPathFromEnv!)

        async let a = service.cleanup(text: "hello one", language: "en", dictionaryContext: nil)
        async let b = service.cleanup(text: "hello two", language: "en", dictionaryContext: nil)
        let (first, second) = await (a, b)

        // One of the calls must fall back to raw input (D-28 rejection).
        let bothContentful = !first.isEmpty && !second.isEmpty
        XCTAssertTrue(bothContentful, "Both awaits must complete")
        let anyRaw = first == "hello one" || first == "hello two" ||
                     second == "hello one" || second == "hello two"
        XCTAssertTrue(anyRaw,
                      "One concurrent call must return raw text (D-28 guard rejects overlap)")
    }

    // MARK: - D-19: Swiss safety-net gating (integration)

    /// The ß→ss safety-net runs inside `cleanup()` AFTER inference, so it
    /// requires a loaded model to exercise. Gate on DICTICUS_TEST_MODEL_PATH.
    func testSwissSafetyNetGating() async throws {
        try XCTSkipIf(modelPathFromEnv == nil,
                      "Integration test skipped — set DICTICUS_TEST_MODEL_PATH to enable (D-19 needs a loaded model)")

        let service = CleanupService(inferenceTimeoutSeconds: 8.0)
        try service.loadModel(from: modelPathFromEnv!)

        let suite = UserDefaults(suiteName: "group.com.dicticus") ?? .standard

        // Toggle ON → output must not contain ß.
        suite.set(true, forKey: "useSwissGerman")
        let swissOut = await service.cleanup(text: "ich esse draußen", language: "de", dictionaryContext: nil)
        XCTAssertFalse(swissOut.contains("ß"),
                       "Swiss safety-net must eliminate ß when useSwissGerman=true")

        // Toggle OFF → ß from the LLM (if any) passes through verbatim.
        suite.set(false, forKey: "useSwissGerman")
        // We can't assert the LLM emits ß, but we can assert the code path
        // doesn't apply the regex: feed obvious ß-bearing input and verify
        // the return is whatever the LLM produced (no regex short-circuit).
        let stdOut = await service.cleanup(text: "ich esse draußen", language: "de", dictionaryContext: nil)
        // Standard output is LLM-dependent; at minimum it must not crash and
        // must return non-empty text (graceful-degradation contract).
        XCTAssertFalse(stdOut.isEmpty,
                       "cleanup() must return text when toggle=OFF and model is loaded")
    }

    // MARK: - D-06: Back-to-back independence (integration)

    func testBackToBackCallsIndependent() async throws {
        try XCTSkipIf(modelPathFromEnv == nil,
                      "Integration test skipped — set DICTICUS_TEST_MODEL_PATH to enable (D-06 needs a loaded model)")

        let service = CleanupService(inferenceTimeoutSeconds: 8.0)
        try service.loadModel(from: modelPathFromEnv!)

        let r1 = await service.cleanup(text: "hallo velt", language: "de", dictionaryContext: nil)
        let r2 = await service.cleanup(text: "hello world", language: "en", dictionaryContext: nil)

        XCTAssertFalse(r1.isEmpty, "First call must produce output")
        XCTAssertFalse(r2.isEmpty, "Second call must produce output")
        XCTAssertFalse(r2.lowercased().contains("velt"),
                       "No KV-cache bleed between calls (D-06) — 'velt' from call 1 must not appear in call 2")
    }

    // MARK: - CLEAN-02: Real-model inference (integration)

    func testRealModelInference() async throws {
        try XCTSkipIf(modelPathFromEnv == nil,
                      "Integration test skipped — set DICTICUS_TEST_MODEL_PATH to enable")

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

        let service = CleanupService(inferenceTimeoutSeconds: 8.0)
        try service.loadModel(from: modelPathFromEnv!)

        for prompt in prompts {
            let output = await service.cleanup(
                text: prompt.input,
                language: prompt.lang,
                dictionaryContext: nil
            )
            for expected in prompt.expectedContains {
                XCTAssertTrue(output.lowercased().contains(expected.lowercased()),
                              "Canary [\(prompt.lang)] '\(prompt.input)' -> '\(output)' missing expected substring '\(expected)'")
            }
        }
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
