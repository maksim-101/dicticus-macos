import XCTest
@testable import Dicticus

/// SelfCorrectionResolver unit tests (Phase 20.01 — Wave 0 RED).
///
/// References `SelfCorrectionResolver` which does NOT exist yet —
/// the type lands in plan 20.03 at
/// `Shared/Utilities/SelfCorrectionResolver.swift`.
///
/// Contract being locked:
///   ```
///   public enum SelfCorrectionResolver {
///       public static func resolve(_ text: String, language: String) -> String
///   }
///   ```
///
/// Critical guards:
///   1. Connector must be preceded by `", "` to fire — defends against
///      "I mean it" / "Ich meine es ernst" false positives.
///   2. Backward window ≤ 3 tokens — never deletes more than the most
///      recent reparandum candidate.
///   3. Abort path: if no clear replacement candidate exists, leave the
///      text fully unchanged (do NOT strip the connector pair, do NOT
///      drop tokens past it).
///
/// Connector list (case-insensitive, German + English):
///   de: ich meine, besser gesagt, genauer gesagt, oder vielmehr, oder besser
///   en: I mean, I meant, or rather, or better, scratch that
final class SelfCorrectionResolverTests: XCTestCase {

    // MARK: - Positive German cases

    func testGermanIchMeineCurrencyCorrection() {
        XCTAssertEqual(
            SelfCorrectionResolver.resolve(
                "Das kostet 110 Franken, ich meine 110 Euro.",
                language: "de"
            ),
            "Das kostet 110 Euro."
        )
    }

    func testGermanGenauerGesagt() {
        XCTAssertEqual(
            SelfCorrectionResolver.resolve(
                "Ich gehe nach Bern, genauer gesagt nach Thun.",
                language: "de"
            ),
            "Ich gehe nach Thun."
        )
    }

    func testGermanBesserGesagt() {
        XCTAssertEqual(
            SelfCorrectionResolver.resolve(
                "Wir treffen uns morgen, besser gesagt übermorgen.",
                language: "de"
            ),
            "Wir treffen uns übermorgen."
        )
    }

    func testGermanOderVielmehr() {
        XCTAssertEqual(
            SelfCorrectionResolver.resolve(
                "Es war Montag, oder vielmehr Dienstag.",
                language: "de"
            ),
            "Es war Dienstag."
        )
    }

    func testGermanOderBesser() {
        XCTAssertEqual(
            SelfCorrectionResolver.resolve(
                "Drei Stück, oder besser fünf Stück.",
                language: "de"
            ),
            "fünf Stück."
        )
    }

    // MARK: - Comma-prefix guards (German)

    /// "Ich meine es ernst" — `ich meine` is content, not connector.
    /// Without preceding `", "`, the resolver MUST NOT fire.
    func testGermanIchMeineWithoutCommaUnchanged() {
        let input = "Ich meine es ernst"
        XCTAssertEqual(
            SelfCorrectionResolver.resolve(input, language: "de"),
            input,
            "Comma-prefix guard: 'Ich meine' without preceding ', ' must remain content"
        )
    }

    // MARK: - Positive English cases

    func testEnglishIMeanCityCorrection() {
        XCTAssertEqual(
            SelfCorrectionResolver.resolve(
                "Send to Boston, I mean to Denver.",
                language: "en"
            ),
            "Send to Denver."
        )
    }

    func testEnglishOrRather() {
        XCTAssertEqual(
            SelfCorrectionResolver.resolve(
                "the red car, or rather the blue one",
                language: "en"
            ),
            "the blue one"
        )
    }

    func testEnglishIMeantPastTense() {
        XCTAssertEqual(
            SelfCorrectionResolver.resolve(
                "Call him Tuesday, I meant Wednesday.",
                language: "en"
            ),
            "Call him Wednesday."
        )
    }

    func testEnglishOrBetter() {
        XCTAssertEqual(
            SelfCorrectionResolver.resolve(
                "Use red, or better blue.",
                language: "en"
            ),
            "Use blue."
        )
    }

    func testEnglishScratchThat() {
        XCTAssertEqual(
            SelfCorrectionResolver.resolve(
                "ten dollars, scratch that twelve dollars",
                language: "en"
            ),
            "twelve dollars"
        )
    }

    // MARK: - Comma-prefix guards (English) — false-positive defense

    /// Classic "I mean it" — `I mean` is content, not connector.
    func testEnglishIMeanItUnchanged() {
        let input = "I mean it"
        XCTAssertEqual(
            SelfCorrectionResolver.resolve(input, language: "en"),
            input,
            "Comma-prefix guard: 'I mean it' is the canonical false-positive defense case"
        )
    }

    func testEnglishIMeanWhatISayUnchanged() {
        let input = "I mean what I say"
        XCTAssertEqual(
            SelfCorrectionResolver.resolve(input, language: "en"),
            input
        )
    }

    // MARK: - Window-boundary semantics

    /// Backward window ≤ 3 tokens: in `"a b c d e f g h, ich meine X"`
    /// only the trailing 3 tokens `f g h` are dropped. `a b c d e` survive.
    func testGermanBackwardWindowCappedAtThree() {
        XCTAssertEqual(
            SelfCorrectionResolver.resolve(
                "a b c d e f g h, ich meine X",
                language: "de"
            ),
            "a b c d e X",
            "Backward window must be capped at 3 tokens — earlier tokens survive"
        )
    }

    // MARK: - Abort-path semantics

    /// If the post-connector phrase is too long / ambiguous to be a clear
    /// replacement (e.g. clausal continuation), the resolver MUST leave
    /// the text fully unchanged. It MUST NOT strip the connector pair
    /// (would corrupt the sentence) and MUST NOT drop the trailing word.
    func testGermanAbortPathLeavesTextUnchanged() {
        let input = "Ich gehe heute ins Kino, ich meine, mit der ganzen Familie."
        XCTAssertEqual(
            SelfCorrectionResolver.resolve(input, language: "de"),
            input,
            "Abort path: clausal continuation has no clear replacement candidate — leave fully unchanged, do not drop 'Familie'"
        )
    }
}
