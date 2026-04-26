import XCTest
@testable import Dicticus

final class CurrencyAntiFlipTests: XCTestCase {

    // MARK: - Type-shape (B5 lock — replaces Plan 03 source-greps)

    func testFamilyHasFourCases() {
        // B5: behavior assertion replaces Plan 03's source-layout grep.
        // Authoritative gate for "the enum has chf, eur, usd, gbp".
        XCTAssertEqual(CurrencyAntiFlip.Family.allCases.count, 4)
    }

    func testFamilyContainsCanonicalCases() {
        // B5: behavior assertion. Survives any legal Swift refactor of
        // the enum declaration (one-case-per-line vs. compound).
        let allCases = Set(CurrencyAntiFlip.Family.allCases)
        XCTAssertTrue(allCases.contains(.chf))
        XCTAssertTrue(allCases.contains(.eur))
        XCTAssertTrue(allCases.contains(.usd))
        XCTAssertTrue(allCases.contains(.gbp))
    }

    func testTokenStructHasFamilyAndText() {
        // B5: confirms the public Token struct exposes the documented fields.
        // Compiles iff the API shape matches; runtime assertion is paranoid double-check.
        let result = CurrencyAntiFlip.detectCurrencies(in: "5 CHF")
        XCTAssertNotNil(result.first)
        XCTAssertEqual(result.first?.family, .chf)
        XCTAssertEqual(result.first?.text, "CHF")
    }

    // MARK: - detectCurrencies

    func testDetectCHFTokens() {
        let result = CurrencyAntiFlip.detectCurrencies(in: "Ich habe 5 Franken bezahlt")
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.family, .chf)
        XCTAssertEqual(result.first?.text, "Franken")
    }

    func testDetectMixedCurrencies() {
        let result = CurrencyAntiFlip.detectCurrencies(in: "5 EUR oder 10 CHF")
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result.map(\.family), [.eur, .chf])
    }

    func testDetectIsCaseInsensitive() {
        let result = CurrencyAntiFlip.detectCurrencies(in: "5 euro")
        XCTAssertEqual(result.first?.family, .eur)
    }

    func testDetectReturnsEmptyOnNoMatch() {
        let result = CurrencyAntiFlip.detectCurrencies(in: "Hello world")
        XCTAssertTrue(result.isEmpty)
    }

    // MARK: - revertCurrencyFlip

    func testRevertNoOpWhenFamiliesMatch() {
        let input = "5 Franken"
        let output = "5 Franken bezahlt"
        XCTAssertEqual(CurrencyAntiFlip.revertCurrencyFlip(input: input, output: output), output)
    }

    func testRevertFlipsEUR_to_CHF_whenInputWasCHF() {
        let input = "Ich habe 5 Franken bezahlt"
        let output = "Ich habe 5 Euro bezahlt"
        let reverted = CurrencyAntiFlip.revertCurrencyFlip(input: input, output: output)
        XCTAssertTrue(reverted.contains("Franken"), "Revert must restore Franken: got \(reverted)")
        XCTAssertFalse(reverted.contains("Euro"), "Revert must remove Euro: got \(reverted)")
    }

    func testRevertCodeFormPreservesCase() {
        let input = "5 CHF"
        let output = "5 EUR"
        let reverted = CurrencyAntiFlip.revertCurrencyFlip(input: input, output: output)
        XCTAssertTrue(reverted.contains("CHF"))
        XCTAssertFalse(reverted.contains("EUR"))
    }

    func testRevertBailsOnCountMismatch() {
        // Input has one currency, output has two — too risky to revert.
        let input = "5 Franken"
        let output = "5 Euro and 10 EUR"
        // Should return output unchanged.
        XCTAssertEqual(CurrencyAntiFlip.revertCurrencyFlip(input: input, output: output), output)
    }

    // MARK: - Fixture corpus

    func testFixturesCorpus() throws {
        let url = Bundle(for: Self.self).url(forResource: "CurrencyAntiFlip.fixtures", withExtension: "json")
        let data = try Data(contentsOf: try XCTUnwrap(url, "fixture must ship"))
        struct Triple: Decodable { let input: String; let llmOutput: String; let expected: String }
        let triples = try JSONDecoder().decode([Triple].self, from: data)
        XCTAssertGreaterThanOrEqual(triples.count, 4)
        for t in triples {
            XCTAssertEqual(
                CurrencyAntiFlip.revertCurrencyFlip(input: t.input, output: t.llmOutput),
                t.expected,
                "Fixture failed: input='\(t.input)' llmOutput='\(t.llmOutput)'"
            )
        }
    }
}
