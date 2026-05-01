import XCTest
@testable import Dicticus

/// RulesCleanupService integration tests (Phase 20.01 — Wave 0 RED).
///
/// References `RulesCleanupService` which does NOT exist yet — the type
/// lands in plan 20.03 at `Shared/Services/RulesCleanupService.swift`.
/// The test target will FAIL TO BUILD until that plan ships.
///
/// Contract being locked:
///   ```
///   public final class RulesCleanupService {
///       public init()
///       public func clean(_ text: String, language: String) -> String
///   }
///   ```
///
/// Pipeline order (D-03):
///   FillerWordRemover
///     → SelfCorrectionResolver
///     → SwissNumberFormatter.foldCurrency
///     → whitespace collapse
///
/// Idempotency invariant (D-03): `clean(clean(x))` ≡ `clean(x)` for ALL
/// fixtures. This is the rules-engine equivalent of the SwissNumberFormatter
/// "Swiss apostrophe round-trips" guarantee — without idempotency, the
/// post-LLM gate path could double-apply rules and corrupt output.
final class RulesCleanupServiceTests: XCTestCase {

    // MARK: - Fixture model

    private struct Fixture: Decodable {
        let id: String
        let language: String
        let input: String
        let expected: String
        let category: String
    }

    private func loadFixtures() throws -> [Fixture] {
        let url = Bundle(for: Self.self)
            .url(forResource: "RulesCleanup.fixtures", withExtension: "json")
        let data = try Data(contentsOf: try XCTUnwrap(url, "RulesCleanup.fixtures.json must ship in the test bundle"))
        return try JSONDecoder().decode([Fixture].self, from: data)
    }

    // MARK: - Headline composition contract

    /// Sanity: the headline composition case from the planner —
    /// filler removed, currency-fold applied, whitespace collapsed in one go.
    func testHeadlineCompositionGerman() {
        let service = RulesCleanupService()
        XCTAssertEqual(
            service.clean("äh, das kostet 15 Franken 50 Rappen", language: "de"),
            "das kostet CHF 15.50",
            "Headline composition: filler + currency-fold + whitespace must compose deterministically"
        )
    }

    // MARK: - Pipeline order assertion

    /// The pipeline MUST be: filler → self-correction → currency-fold → whitespace.
    /// This case verifies the ORDER not just the OUTCOME: if self-correction
    /// ran BEFORE filler, the leading "ähm," would still be present in the
    /// reparandum window and the resolver could glitch. The assertion is on
    /// the final output, but the input is constructed so that wrong order
    /// produces a different result.
    func testPipelineOrderFillerBeforeSelfCorrection() {
        let service = RulesCleanupService()
        // Input: `ähm, drei Stück, oder besser fünf Stück.`
        // Correct order:
        //   1. filler removes leading "ähm, " → "drei Stück, oder besser fünf Stück."
        //   2. self-correction sees `, oder besser` → drops "drei Stück" → "fünf Stück."
        //   3. currency-fold: no-op
        //   4. whitespace: no-op
        // Wrong order (self-correction first) would see `ähm, drei Stück, oder besser`
        // and the connector `oder besser` is no longer immediately after a clean
        // reparandum — implementation-dependent failure surface.
        XCTAssertEqual(
            service.clean("ähm, drei Stück, oder besser fünf Stück.", language: "de"),
            "fünf Stück."
        )
    }

    // MARK: - Fixture-driven correctness

    func testAllFixturesProduceExpectedOutput() throws {
        let service = RulesCleanupService()
        let fixtures = try loadFixtures()
        XCTAssertGreaterThanOrEqual(fixtures.count, 30,
            "RulesCleanup.fixtures.json must ship ≥ 30 cases")
        for f in fixtures {
            XCTAssertEqual(
                service.clean(f.input, language: f.language),
                f.expected,
                "[\(f.category)] \(f.id): clean('\(f.input)', \(f.language))"
            )
        }
    }

    // MARK: - Idempotency

    func testCleanIsIdempotentForAllFixtures() throws {
        let service = RulesCleanupService()
        let fixtures = try loadFixtures()
        for f in fixtures {
            let once = service.clean(f.input, language: f.language)
            let twice = service.clean(once, language: f.language)
            XCTAssertEqual(twice, once,
                "Idempotency violated for [\(f.category)] \(f.id): once='\(once)' twice='\(twice)'")
        }
    }

    // MARK: - Language gating

    /// Swiss-flavored rules (Franken→CHF fold, German fillers) must NOT fire
    /// when language is "en". This case feeds a German-input string under
    /// language="en" and asserts the German fillers + Franken fold are
    /// untouched (German fillers preserved as content, currency string
    /// preserved verbatim because en-mode does not fold Franken/Rappen).
    func testLanguageGatingEnglishLeavesGermanFlavoredInputUntouched() {
        let service = RulesCleanupService()
        let input = "äh, das kostet 15 Franken 50 Rappen"
        let result = service.clean(input, language: "en")
        // The "äh" stays because en-mode FillerWordRemover does not strip German fillers.
        // The Franken/Rappen stays because en-mode currency-fold does not touch CHF currencies.
        // This is the language-gate contract: en-mode is a no-op for de-flavored input.
        XCTAssertTrue(result.contains("äh"),
            "Language gate: German filler 'äh' must survive en-mode (en-mode does not strip de fillers)")
        XCTAssertTrue(result.contains("Franken"),
            "Language gate: 'Franken' must survive en-mode (en-mode does not fold CHF)")
        XCTAssertTrue(result.contains("Rappen"),
            "Language gate: 'Rappen' must survive en-mode")
    }

    // MARK: - Adversarial idempotency spotlight

    /// Currency-fold idempotency is the highest-risk regression surface
    /// (post-LLM bridge already runs and could re-fold an already-folded
    /// price). Spot-check the canonical case explicitly.
    func testCurrencyFoldIdempotencyCHF() {
        let service = RulesCleanupService()
        let folded = service.clean("CHF 15.50", language: "de")
        XCTAssertEqual(folded, "CHF 15.50",
            "Idempotency: pre-folded CHF 15.50 must not be re-folded or mangled")
        XCTAssertEqual(service.clean(folded, language: "de"), folded,
            "Idempotency: clean(clean('CHF 15.50')) must equal clean('CHF 15.50')")
    }
}
