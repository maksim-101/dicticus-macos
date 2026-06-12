import XCTest
@testable import Dicticus

// Phase 36.1 Wave 0 RED scaffolding.
// These tests call RulesCleanupService().clean(_:language:) and assert the
// trailing-artifact strip behavior that Plan 36.1-04 adds to that method.
// Until that plan lands, the strip behavior is absent and these tests will fail
// — that is the intended RED state.

final class RulesCleanupServiceTests: XCTestCase {

    // MARK: - Trailing-artifact strip

    func testArtifactStrip_terminalYeah_stripped() {
        // Terminal standalone "Yeah" (media bleed) must be stripped.
        // The preceding sentence terminal punctuation must be preserved.
        let service = RulesCleanupService()
        let result = service.clean("This is the transcribed text. Yeah", language: "en")
        XCTAssertEqual(result, "This is the transcribed text.",
            "Phase 36.1: artifact strip — terminal Yeah must be removed, sentence punct preserved")
    }

    func testArtifactStrip_terminalMmHmm_stripped() {
        // Terminal "Mm-hmm" is a media bleed artifact — must be stripped.
        let service = RulesCleanupService()
        let result = service.clean("That sounds right okay Mm-hmm", language: "en")
        XCTAssertEqual(result, "That sounds right okay",
            "Phase 36.1: artifact strip — terminal Mm-hmm must be removed")
    }

    func testArtifactStrip_interiorYeah_preserved() {
        // Interior "yeah" (not terminal) must NOT be stripped — only terminal artifacts are removed.
        let service = RulesCleanupService()
        let result = service.clean("Yeah that makes sense to me", language: "en")
        XCTAssertTrue(result.lowercased().contains("yeah"),
            "Phase 36.1: artifact strip — interior yeah must be preserved, only terminal artifacts stripped")
    }
}
