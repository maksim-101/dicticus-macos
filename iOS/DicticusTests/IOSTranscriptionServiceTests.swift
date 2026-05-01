import XCTest
import FluidAudio
@testable import Dicticus

@MainActor
final class IOSTranscriptionServiceTests: XCTestCase {
    // Language restriction tests — call IOSTranscriptionService.testRestrictLanguage()
    func testRestrictLanguageGerman() {
        XCTAssertEqual(IOSTranscriptionService.testRestrictLanguage("de"), "de")
    }
    func testRestrictLanguageEnglish() {
        XCTAssertEqual(IOSTranscriptionService.testRestrictLanguage("en"), "en")
    }
    func testRestrictLanguageFrenchFallsBackToEnglish() {
        XCTAssertEqual(IOSTranscriptionService.testRestrictLanguage("fr"), "en")
    }
    func testRestrictLanguageEmptyFallsBackToEnglish() {
        XCTAssertEqual(IOSTranscriptionService.testRestrictLanguage(""), "en")
    }

    // Language detection tests — call IOSTranscriptionService.testDetectLanguage()
    func testDetectLanguageGerman() {
        XCTAssertEqual(
            IOSTranscriptionService.testDetectLanguage("Dies ist ein Testsatz in deutscher Sprache"), "de"
        )
    }
    func testDetectLanguageEnglish() {
        XCTAssertEqual(
            IOSTranscriptionService.testDetectLanguage("This is a test sentence in English language"), "en"
        )
    }

    // Non-Latin script detection tests
    func testContainsNonLatinScriptPureLatinReturnsFalse() {
        XCTAssertFalse(IOSTranscriptionService.containsNonLatinScript("Hello world"))
    }
    func testContainsNonLatinScriptGermanReturnsFalse() {
        XCTAssertFalse(IOSTranscriptionService.containsNonLatinScript("Guten Tag"))
    }
    func testContainsNonLatinScriptCyrillicReturnsTrue() {
        XCTAssertTrue(IOSTranscriptionService.containsNonLatinScript("Привет мир"))
    }
    func testContainsNonLatinScriptCJKReturnsTrue() {
        XCTAssertTrue(IOSTranscriptionService.containsNonLatinScript("你好世界"))
    }
    func testContainsNonLatinScriptArabicReturnsTrue() {
        XCTAssertTrue(IOSTranscriptionService.containsNonLatinScript("مرحبا"))
    }
    func testContainsNonLatinScriptEmptyReturnsFalse() {
        XCTAssertFalse(IOSTranscriptionService.containsNonLatinScript(""))
    }
    func testContainsNonLatinScriptNumbersAndPunctuationReturnsFalse() {
        XCTAssertFalse(IOSTranscriptionService.containsNonLatinScript("123 !@#"))
    }

    // Configuration tests (require FluidAudio model)
    func testInitialStateIsIdle() async throws {
        let service = try await makeServiceOrSkip()
        XCTAssertEqual(service.state, .idle)
    }
    func testMinimumDurationValue() async throws {
        let service = try await makeServiceOrSkip()
        XCTAssertEqual(service.minimumDurationSeconds, 0.3, accuracy: 0.001)
    }
    func testDefaultSilenceThreshold() async throws {
        let service = try await makeServiceOrSkip()
        XCTAssertEqual(service.silenceThreshold, IOSTranscriptionService.vadProbabilityThreshold, accuracy: 0.001)
    }

    func testPostProcessingTogglesDefaultToTrue() async throws {
        let service = try await makeServiceOrSkip()
        XCTAssertTrue(service.useCustomDictionary)
        XCTAssertTrue(service.useITN)
    }

    private func makeServiceOrSkip() async throws -> IOSTranscriptionService {
        try XCTSkipUnless(
            IOSTranscriptionService.isFluidAudioAvailable(),
            "Skipping — FluidAudio Parakeet model not loaded."
        )
        guard let service = try? await IOSTranscriptionService.makeForTesting() else {
            throw XCTSkip("FluidAudio init failed.")
        }
        return service
    }
}
