import Foundation

/// Phase 20 D-02 Action 2: deterministic rules-first cleanup.
///
/// Thin orchestrator over the three Phase 20 rule utilities. Composition
/// order is fixed and order-sensitive (locked by RulesCleanupServiceTests):
///
///   1. `FillerWordRemover.strip` — remove conservative ship-list fillers.
///      Runs FIRST so a leading `"ähm, …"` is gone before self-correction
///      examines the comma-prefixed connector window.
///   2. `SelfCorrectionResolver.resolve` — drop reparandum tokens before a
///      comma-prefixed connector. Runs after filler so the backward window
///      sees only content tokens.
///   3. `SwissNumberFormatter.foldCurrencyUnits` — collapse spoken-out
///      `"X Franken Y Rappen"` (and EUR/USD/GBP analogs) to canonical
///      glyph-prefixed decimal form. Runs LAST so it operates on already-
///      cleaned digit sequences.
///   4. Whitespace collapse — `\s+` → single space, then trim.
///
/// Idempotency invariant (D-03): `clean(clean(x)) == clean(x)` for every
/// fixture in `RulesCleanup.fixtures.json`. Each utility is individually
/// idempotent, and whitespace collapse trivially is.
///
/// Pure transform — no `@MainActor`, no `@Published`, no I/O. Thread-safe
/// to call from any context.
public final class RulesCleanupService {

    public init() {}

    /// Run the rules-first cleanup pipeline.
    ///
    /// - Parameters:
    ///   - text: post-ITN, pre-LLM input.
    ///   - language: BCP-47-ish code; first 2 chars used for filler /
    ///     self-correction language gating. Currency-fold is language-
    ///     agnostic by design (the tokens themselves disambiguate).
    /// - Returns: cleaned text.
    public func clean(_ text: String, language: String) -> String {
        var result = FillerWordRemover.strip(text, language: language)
        result = SelfCorrectionResolver.resolve(result, language: language)
        // Currency-fold is gated on `de` (Swiss/German speakers say
        // "Franken Rappen" / "Euro Cent"). The en-mode contract is that
        // German-flavored input passes through untouched — see
        // `RulesCleanupServiceTests.testLanguageGatingEnglishLeavesGermanFlavoredInputUntouched`.
        // The downstream `SwissNumberFormatter.format` (Step 3b in
        // TextProcessingService) still runs language-agnostically per
        // the existing Swiss-toggle gating.
        if language.prefix(2).lowercased() != "en" {
            result = SwissNumberFormatter.foldCurrencyUnits(result)
        }
        // Whitespace collapse — any run of whitespace → single space; trim.
        let collapsed = result
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
        return collapsed.trimmingCharacters(in: .whitespaces)
    }
}
