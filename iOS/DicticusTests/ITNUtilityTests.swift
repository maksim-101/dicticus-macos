import XCTest
@testable import Dicticus

/// Wave 0 test scaffold for Swiss German ITN (D-16, D-17).
///
/// **TDD RED state.** Wave 1 adds `ITNUtility.applySwissITN(to:)`. Once the
/// symbol exists, remove the `XCTSkipIf(!isWave1Ready, ...)` lines in each
/// test body AND replace the `callSwissITN` shim below with a direct call
/// to `ITNUtility.applySwissITN(to:)`.
///
/// The tests are currently wired through a compile-time shim (`callSwissITN`)
/// so the iOS test target keeps compiling during Wave 0 while still preserving
/// the full test intent, fixture parsing, and acceptance-criteria method names
/// that 19-VALIDATION.md requires.
final class ITNUtilityTests: XCTestCase {

    /// Wave 1 flipped: `ITNUtility.applySwissITN` exists in Shared/. Assertions run.
    private let isWave1Ready = true

    /// Wave 1 replaced the no-op body with a direct call to the real symbol.
    private func callSwissITN(_ text: String) -> String {
        return ITNUtility.applySwissITN(to: text)
    }

    func testSwissGermanEszett() throws {
        // D-16: ß → ss deterministic
        try XCTSkipIf(!isWave1Ready, "Pending Wave 1: ITNUtility.applySwissITN not yet implemented")
        XCTAssertEqual(callSwissITN("Straße"), "Strasse")
        XCTAssertEqual(callSwissITN("groß und süß"), "gross und süss")
    }

    func testSwissGermanCapitalEszett() throws {
        // D-17: ẞ (U+1E9E) → SS — respect case, uppercase context → SS
        try XCTSkipIf(!isWave1Ready, "Pending Wave 1: ITNUtility.applySwissITN not yet implemented")
        XCTAssertEqual(callSwissITN("STRA\u{1E9E}E"), "STRASSE")
        XCTAssertEqual(callSwissITN("\u{1E9E}"), "SS")
    }

    func testSwissGermanNoOp() throws {
        try XCTSkipIf(!isWave1Ready, "Pending Wave 1: ITNUtility.applySwissITN not yet implemented")
        XCTAssertEqual(callSwissITN("Nix ohne Eszett"), "Nix ohne Eszett")
    }

    func testSwissGermanFixturesCorpus() throws {
        // Fixture parsing runs unconditionally — verifies the JSON shape is
        // always loadable from the test bundle. The assertions-per-pair run
        // only once Wave 1 lands.
        let url = Bundle(for: Self.self).url(forResource: "SwissGerman.fixtures", withExtension: "json")
        let unwrappedUrl = try XCTUnwrap(url, "SwissGerman.fixtures.json must ship in the test bundle")
        let data = try Data(contentsOf: unwrappedUrl)
        struct Pair: Decodable { let input: String; let expected: String }
        let pairs = try JSONDecoder().decode([Pair].self, from: data)
        XCTAssertFalse(pairs.isEmpty, "Fixture file must contain at least one pair")
        XCTAssertGreaterThanOrEqual(pairs.count, 5, "Fixture must have ≥5 entries")

        try XCTSkipIf(!isWave1Ready, "Pending Wave 1: ITNUtility.applySwissITN not yet implemented")
        for pair in pairs {
            XCTAssertEqual(callSwissITN(pair.input), pair.expected,
                           "Swiss ITN mismatch for input=\(pair.input)")
        }
    }
}
