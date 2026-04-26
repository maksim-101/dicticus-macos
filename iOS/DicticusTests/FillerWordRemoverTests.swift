import XCTest
@testable import Dicticus

/// FillerWordRemover unit tests (Phase 20.01 — Wave 0 RED).
///
/// References `FillerWordRemover` which does NOT exist yet — the type
/// lands in plan 20.03 at `Shared/Utilities/FillerWordRemover.swift`.
/// The test target will FAIL TO BUILD until that plan ships.
///
/// Contract being locked:
///   ```
///   public enum FillerWordRemover {
///       public static let germanFillers: Set<String>      // {äh, ähm, ehm, hmm}
///       public static let englishFillers: Set<String>     // {uh, um, umm, er, erm}
///       public static func strip(_ text: String, language: String) -> String
///   }
///   ```
///
/// Ship-list discipline: the German list is intentionally 4 tokens and
/// the English list 5 tokens. Words like `also`, `ja`, `genau`, `well`,
/// `so`, `like`, `you know` are NOT fillers — they are content. The
/// adversarial cases below lock that boundary.
final class FillerWordRemoverTests: XCTestCase {

    // MARK: - Ship-list constants

    func testGermanFillerShipList() {
        // Exactly 4 — adding new tokens without explicit planner approval
        // weakens the false-positive defense for `also`/`ja`/`genau`.
        XCTAssertEqual(FillerWordRemover.germanFillers,
                       ["äh", "ähm", "ehm", "hmm"])
    }

    func testEnglishFillerShipList() {
        XCTAssertEqual(FillerWordRemover.englishFillers,
                       ["uh", "um", "umm", "er", "erm"])
    }

    // MARK: - Positive German cases

    func testGermanLeadingFillerWithComma() {
        XCTAssertEqual(
            FillerWordRemover.strip("äh, das ist gut", language: "de"),
            "das ist gut"
        )
    }

    func testGermanMidSentenceFillerOrphanComma() {
        // "Das ist, äh, gut" → "Das ist gut"
        // Both surrounding commas must be cleaned up — orphan-comma cleanup.
        XCTAssertEqual(
            FillerWordRemover.strip("Das ist, äh, gut", language: "de"),
            "Das ist gut"
        )
    }

    func testGermanSentenceInitialRecap() {
        // "Äh, das ist..." → "Das ist..."
        // Capitalization of the next word must be preserved (sentence-initial recap).
        XCTAssertEqual(
            FillerWordRemover.strip("Äh, das ist gut.", language: "de"),
            "Das ist gut."
        )
    }

    func testGermanÄhmVariant() {
        XCTAssertEqual(
            FillerWordRemover.strip("ähm, vielleicht", language: "de"),
            "vielleicht"
        )
    }

    // MARK: - Adversarial German preservation

    func testGermanAlsoNotStripped() {
        // `also` = "therefore" / "so" — content, not filler.
        let input = "also gut"
        XCTAssertEqual(FillerWordRemover.strip(input, language: "de"), input)
    }

    func testGermanJaNotStripped() {
        let input = "ja, das stimmt"
        XCTAssertEqual(FillerWordRemover.strip(input, language: "de"), input)
    }

    func testGermanGenauNotStripped() {
        let input = "genau, so meine ich es"
        XCTAssertEqual(FillerWordRemover.strip(input, language: "de"), input)
    }

    // MARK: - Positive English cases

    func testEnglishLeadingFiller() {
        XCTAssertEqual(
            FillerWordRemover.strip("uh, this is good", language: "en"),
            "this is good"
        )
    }

    func testEnglishMidSentenceFillerOrphanComma() {
        XCTAssertEqual(
            FillerWordRemover.strip("This is, um, good", language: "en"),
            "This is good"
        )
    }

    func testEnglishUmmVariant() {
        XCTAssertEqual(
            FillerWordRemover.strip("umm, maybe", language: "en"),
            "maybe"
        )
    }

    // MARK: - Adversarial English preservation

    func testEnglishILikeItNotStripped() {
        // No filler appears here; "I" / "like" / "it" all preserved.
        let input = "I like it"
        XCTAssertEqual(FillerWordRemover.strip(input, language: "en"), input)
    }

    func testEnglishWellNotStripped() {
        // `well` is intentionally NOT in the ship list — too high false-positive
        // rate (e.g. "I am well", "well-spoken").
        let input = "well, I am well"
        XCTAssertEqual(FillerWordRemover.strip(input, language: "en"), input)
    }

    func testEnglishSoNotStripped() {
        let input = "so it goes"
        XCTAssertEqual(FillerWordRemover.strip(input, language: "en"), input)
    }

    // MARK: - Language gating

    func testGermanFillersNotStrippedFromEnglish() {
        // German fillers must NOT be stripped from English text.
        let input = "äh, this is good"
        XCTAssertEqual(FillerWordRemover.strip(input, language: "en"), input,
                       "Language gate: German fillers must not be touched in English text")
    }

    func testEnglishFillersNotStrippedFromGerman() {
        let input = "uh, das ist gut"
        XCTAssertEqual(FillerWordRemover.strip(input, language: "de"), input,
                       "Language gate: English fillers must not be touched in German text")
    }
}
