import XCTest
@testable import Dicticus

// Tests for TranscriptionService state machine, configuration, and pure logic.
// We do NOT test startRecording()/stopRecordingAndTranscribe() — those require a live
// WhisperKit instance with a loaded model, which is not available in CI (no model download).
// All tests that need a WhisperKit instance use XCTSkipUnless to skip gracefully.
@MainActor
final class TranscriptionServiceTests: XCTestCase {

    // MARK: - TranscriptionError enum tests

    func testTranscriptionErrorCasesExist() {
        // Verify all expected error cases can be constructed (compilation test)
        let tooShort: TranscriptionError = .tooShort
        let silenceOnly: TranscriptionError = .silenceOnly
        let noResult: TranscriptionError = .noResult
        let modelNotReady: TranscriptionError = .modelNotReady

        // Use XCTAssertNotNil with Optional wrapping to avoid "always true" warning
        let errors: [TranscriptionError] = [tooShort, silenceOnly, noResult, modelNotReady]
        XCTAssertEqual(errors.count, 4, "All four TranscriptionError cases should be constructible")
    }

    // MARK: - Language restriction tests
    // restrictLanguage is a non-private method, testable without a WhisperKit instance
    // by using a test helper that invokes it without model initialization.

    func testRestrictLanguageGerman() {
        let result = TranscriptionService.testRestrictLanguage("de")
        XCTAssertEqual(result, "de", "German 'de' should pass through language restriction unchanged")
    }

    func testRestrictLanguageEnglish() {
        let result = TranscriptionService.testRestrictLanguage("en")
        XCTAssertEqual(result, "en", "English 'en' should pass through language restriction unchanged")
    }

    func testRestrictLanguageFrenchFallsBackToEnglish() {
        let result = TranscriptionService.testRestrictLanguage("fr")
        XCTAssertEqual(result, "en", "French 'fr' should fall back to 'en' as the default language")
    }

    func testRestrictLanguageEmptyFallsBackToEnglish() {
        let result = TranscriptionService.testRestrictLanguage("")
        XCTAssertEqual(result, "en", "Empty string should fall back to 'en'")
    }

    func testRestrictLanguageJapaneseFallsBackToEnglish() {
        let result = TranscriptionService.testRestrictLanguage("ja")
        XCTAssertEqual(result, "en", "Japanese 'ja' should fall back to 'en'")
    }

    func testRestrictLanguageSpanishFallsBackToEnglish() {
        let result = TranscriptionService.testRestrictLanguage("es")
        XCTAssertEqual(result, "en", "Spanish 'es' should fall back to 'en'")
    }

    // MARK: - Instance tests (require WhisperKit, skip in CI without model)

    func testInitialStateIsIdle() async throws {
        let service = try await makeServiceOrSkip()
        XCTAssertEqual(service.state, .idle, "Initial state should be .idle")
    }

    func testLastResultIsNilInitially() async throws {
        let service = try await makeServiceOrSkip()
        XCTAssertNil(service.lastResult, "lastResult should be nil on init")
    }

    func testErrorIsNilInitially() async throws {
        let service = try await makeServiceOrSkip()
        XCTAssertNil(service.error, "error should be nil on init")
    }

    func testMinimumDurationValue() async throws {
        let service = try await makeServiceOrSkip()
        XCTAssertEqual(service.minimumDurationSeconds, 0.3, accuracy: 0.001,
                       "minimumDurationSeconds should be 0.3 per D-06")
    }

    func testDefaultSilenceThreshold() async throws {
        let service = try await makeServiceOrSkip()
        XCTAssertEqual(service.silenceThreshold, 0.3, accuracy: 0.001,
                       "default silenceThreshold should be 0.3 matching WhisperAX example")
    }

    func testSilenceThresholdIsConfigurable() async throws {
        let service = try await makeServiceOrSkip()
        service.silenceThreshold = 0.5
        XCTAssertEqual(service.silenceThreshold, 0.5, accuracy: 0.001,
                       "silenceThreshold should accept custom values (D-07)")
    }

    // MARK: - Helpers

    /// Attempts to create a TranscriptionService. Skips the test if WhisperKit is not available.
    /// This allows unit tests to run in CI without downloading the model.
    private func makeServiceOrSkip() async throws -> TranscriptionService {
        // WhisperKit can only init if the model is already cached.
        // In CI (and fresh machines), the model is not present.
        // Skip rather than fail — this is expected behavior for unit tests.
        try XCTSkipUnless(
            TranscriptionService.isWhisperKitAvailable(),
            "Skipping — WhisperKit model not loaded. Run manually after model warmup."
        )
        // If we reach here, the model cache exists. Init may still fail if warmup hasn't completed.
        guard let service = try? await TranscriptionService.makeForTesting() else {
            throw XCTSkip("WhisperKit init failed. Model may still be warming up.")
        }
        return service
    }
}
