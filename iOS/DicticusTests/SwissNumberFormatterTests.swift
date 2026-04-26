import XCTest
@testable import Dicticus

final class SwissNumberFormatterTests: XCTestCase {

    func testThousandsApostropheAscii() {
        let result = SwissNumberFormatter.format("1250")
        XCTAssertEqual(result, "1'250")
        // Critical: must be ASCII apostrophe U+0027, never U+2019.
        XCTAssertFalse(result.contains("\u{2019}"),
                       "Thousands separator must be ASCII '. Got: \(result)")
    }

    // B3 LOCK — German-thousands input must NOT be misread as Swiss decimal.
    func testGermanThousandsToSwissApostrophe() {
        // 1.250 (German thousands) → 1'250 (Swiss apostrophe).
        // Pre-B3: would have parsed as 1.25 under en_US_POSIX and corrupted to "1.250".
        let result = SwissNumberFormatter.format("1.250")
        XCTAssertEqual(result, "1'250",
                       "B3: German-thousands input must reformat to Swiss apostrophe (not stay as 1.250)")
    }

    // B3 LOCK — Swiss-thousands input stays Swiss.
    func testSwissApostropheStaysSwiss() {
        let result = SwissNumberFormatter.format("1'250")
        XCTAssertEqual(result, "1'250",
                       "B3: Swiss-thousands input must round-trip unchanged")
    }

    func testGermanCommaDecimalToSwissPeriod() {
        // 5,70 → 5.70.
        let result = SwissNumberFormatter.format("5,70")
        XCTAssertEqual(result, "5.70")
    }

    func testSwissPeriodDecimalRoundtrip() {
        // 5.70 stays 5.70 (already correct).
        let result = SwissNumberFormatter.format("5.70")
        XCTAssertEqual(result, "5.70")
    }

    func testNonNumericTokensUnchanged() {
        let result = SwissNumberFormatter.format("Hello world")
        XCTAssertEqual(result, "Hello world")
    }

    func testMixedTokensFormat() {
        // Each token reformatted independently; non-numeric tokens preserved.
        let result = SwissNumberFormatter.format("CHF 1250")
        XCTAssertEqual(result, "CHF 1'250")
    }

    func testEmptyStringReturnsEmpty() {
        XCTAssertEqual(SwissNumberFormatter.format(""), "")
    }

    // W7 LOCK — currency-glyph-prefixed tokens are reformatted with the glyph preserved.
    func testCurrencyGlyphPrefixedEuroComma() {
        // "€6,70" → "€6.70" (W7 preferred behavior: strip+reattach glyph).
        let result = SwissNumberFormatter.format("€6,70")
        XCTAssertEqual(result, "€6.70",
                       "W7: leading currency glyph must be preserved while numeric core is reformatted")
    }

    func testCurrencyGlyphPrefixedDollar() {
        // "$1250" → "$1'250" (W7).
        let result = SwissNumberFormatter.format("$1250")
        XCTAssertEqual(result, "$1'250")
    }

    // MARK: - Fixture corpus

    func testFixturesCorpus() throws {
        let url = Bundle(for: Self.self).url(forResource: "SwissNumberFormatter.fixtures", withExtension: "json")
        let data = try Data(contentsOf: try XCTUnwrap(url, "fixture must ship"))
        struct Pair: Decodable { let input: String; let expected: String }
        let pairs = try JSONDecoder().decode([Pair].self, from: data)
        XCTAssertGreaterThanOrEqual(pairs.count, 4)
        for p in pairs {
            XCTAssertEqual(SwissNumberFormatter.format(p.input), p.expected,
                           "Fixture failed: input='\(p.input)'")
        }
    }
}
