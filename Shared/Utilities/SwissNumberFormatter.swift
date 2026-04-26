import Foundation

/// D-C1 / D-C2 / D-C3: Post-LLM number-formatting pass for Swiss output.
///
/// Replaces the Phase 19 D-20 LLM-only thousands-separator approach with a
/// deterministic post-pass:
///   - ASCII straight apostrophe `'` (U+0027) thousands separator, NOT
///     U+2019 right-single-quote that `NumberFormatter` for `de_CH`
///     emits by default. Per D-C1.
///   - Period decimal separator on every numeric token (currency and
///     non-currency alike) when Swiss toggle is ON. Per D-C2.
///
/// Single call site: `Shared/Services/CleanupService.cleanup(...)` —
/// runs after the existing D-19 `applySwissITN` safety-net, gated on the
/// same `useSwissGerman` AppGroup toggle.
///
/// Graceful-degradation contract (D-26): tokens that don't parse as
/// numbers are emitted unchanged. The function never throws and never
/// drops surrounding whitespace or punctuation.
///
/// Parser-strategy lock (B3 fix, Phase 19.5 revision):
///   The naive approach of "try parseSwiss first, fall back to parseGerman"
///   silently corrupts German-thousands inputs: `"1.250"` parses as `1.25`
///   under en_US_POSIX (period read as decimal), short-circuiting the
///   correct German-thousands interpretation. We pre-classify by
///   punctuation pattern: tokens containing `'` or U+2019 go to parseSwiss
///   directly; other tokens go to parseGerman first, then fall back to
///   parseSwiss as a safety net for already-Swiss-formatted input.
///
/// Currency-glyph handling (W7 fix, Phase 19.5 revision):
///   Tokens prefixed by a currency glyph (€, $, £) without a separating
///   space — e.g., `"€6,70"` — must reformat the numeric core while
///   preserving the glyph. We strip a leading currency glyph before
///   reformatting and re-attach it to the result.
public struct SwissNumberFormatter {

    /// Reformat every numeric token in `text` to ASCII-apostrophe-thousands
    /// + period-decimal. Non-numeric tokens are emitted unchanged.
    public static func format(_ text: String) -> String {
        // Tokenize by whitespace and re-join — preserves spacing, matches
        // the established pattern in ITNUtility.applyEnglishITN.
        let tokens = text.split(separator: " ", omittingEmptySubsequences: false)
        let reformed = tokens.map(reformatToken)
        return reformed.joined(separator: " ")
    }

    // MARK: - Internals

    /// Set of leading currency glyphs we strip-and-reattach (W7).
    private static let leadingGlyphs: Set<Character> = ["€", "$", "£"]

    /// Reformat a single token. Strips a single trailing punctuation
    /// character (`.`, `,`, `;`, `:`, `?`, `!`) before parsing and
    /// re-attaches it to the output. Also strips a single leading currency
    /// glyph (€, $, £) per W7 and re-attaches it. Returns the input
    /// verbatim on any parse failure.
    private static func reformatToken(_ raw: Substring) -> String {
        let token = String(raw)
        guard !token.isEmpty else { return token }

        // W7: detach a leading currency glyph (€, $, £) so it doesn't
        // poison parsing. Whitespace-prefixed currencies (`"€ 6,70"`)
        // already split on the space and don't hit this path.
        let leadingGlyph: String
        let afterGlyph: String
        if let first = token.first, leadingGlyphs.contains(first), token.count > 1 {
            leadingGlyph = String(first)
            afterGlyph = String(token.dropFirst())
        } else {
            leadingGlyph = ""
            afterGlyph = token
        }

        // Detach a trailing punctuation tail so it doesn't poison parsing.
        let tail: Character?
        let core: String
        if let last = afterGlyph.last, ".,;:?!".contains(last), afterGlyph.count > 1 {
            tail = last
            core = String(afterGlyph.dropLast())
        } else {
            tail = nil
            core = afterGlyph
        }

        // B3 (Phase 19.5 revision): pre-classify by punctuation pattern,
        // do NOT speculatively parseSwiss first.
        //
        // Rule:
        //   - Token contains `'` or U+2019 → it's already Swiss-formatted.
        //     parseSwiss only.
        //   - Otherwise → parseGerman first (covers German-thousands `1.250`
        //     correctly as 1250). If parseGerman fails (e.g., input has
        //     no separator at all, like `"5.70"` which is valid Swiss
        //     decimal), fall back to parseSwiss.
        let containsApostrophe = core.contains("'") || core.contains("\u{2019}")
        let parsed: Decimal?
        if containsApostrophe {
            parsed = parseSwiss(core)
        } else {
            parsed = parseGerman(core) ?? parseSwiss(core)
        }

        guard let value = parsed else {
            // Not a number — emit verbatim (with original glyph + tail).
            return token
        }
        let body = emitSwiss(value, originalSampleForFractionDigits: core)
        return leadingGlyph + body + (tail.map(String.init) ?? "")
    }

    private static func parseSwiss(_ s: String) -> Decimal? {
        // Swiss: apostrophe thousands (ASCII or U+2019), period decimal.
        let stripped = s
            .replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: "\u{2019}", with: "")
        return Decimal(string: stripped, locale: Locale(identifier: "en_US_POSIX"))
    }

    private static func parseGerman(_ s: String) -> Decimal? {
        // German: period thousands, comma decimal. WR-02 fix (Phase 19.5):
        // `Decimal(string:locale:)` does not strictly validate German
        // thousands-separator positions and its tolerance has changed across
        // iOS/macOS versions (some accept "5.70" as 570, others return nil).
        // We pre-classify before delegating so the Foundation call sees only
        // input that we have proven matches German conventions:
        //   - If a comma is present, treat it as a German decimal and pass
        //     through (de_DE has comma=decimal, period=thousands).
        //   - If no comma is present, accept only inputs whose period
        //     positions form a strict 3-digit grouping pattern from the
        //     right; otherwise return nil so the caller falls back to
        //     parseSwiss (e.g., "5.70" → nil → parseSwiss → 5.70).
        // This locks the testSwissPeriodDecimalRoundtrip / B3 invariants
        // independent of Foundation version drift.
        if s.contains(",") {
            return Decimal(string: s, locale: Locale(identifier: "de_DE"))
        }
        guard isStrictGermanThousands(s) else { return nil }
        return Decimal(string: s, locale: Locale(identifier: "de_DE"))
    }

    /// Validate that `s` either contains no `.` (a pure integer) or has
    /// `.` separators sitting at strict 3-digit-from-right positions
    /// (German thousands grouping). Used to gate `parseGerman` for
    /// non-comma inputs so ambiguous strings like `"5.70"` correctly fall
    /// through to `parseSwiss` instead of being misread as `570`.
    /// Sign and any leading `+`/`-` are tolerated. Non-digit characters
    /// other than `.` cause rejection.
    private static func isStrictGermanThousands(_ s: String) -> Bool {
        // Strip an optional leading sign for inspection.
        var body = Substring(s)
        if let first = body.first, first == "-" || first == "+" {
            body = body.dropFirst()
        }
        guard !body.isEmpty else { return false }
        // Reject anything that isn't digit-or-period.
        for ch in body where !(ch.isNumber || ch == ".") { return false }
        // Pure integer (no period) — accept.
        if !body.contains(".") { return true }
        // Period segments: every segment after the first must be exactly 3
        // digits long; the first segment must be 1-3 digits long. Empty
        // segments (leading/trailing/double dots) are rejected.
        let segments = body.split(separator: ".", omittingEmptySubsequences: false)
        guard segments.count >= 2 else { return false }
        let first = segments.first!
        guard (1...3).contains(first.count) else { return false }
        for seg in segments.dropFirst() {
            guard seg.count == 3 else { return false }
        }
        return true
    }

    /// Emit a Decimal with ASCII apostrophe thousands and period decimal,
    /// preserving the fraction-digit count of `sample` so 5.70 stays 5.70.
    private static func emitSwiss(_ value: Decimal, originalSampleForFractionDigits sample: String) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "de_CH")
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = true
        formatter.groupingSeparator = "'"        // explicit ASCII apostrophe — D-C1
        formatter.decimalSeparator = "."         // explicit period — D-C2
        // Preserve the input's fraction digits when possible.
        let fractionDigits = fractionDigitCount(of: sample)
        formatter.minimumFractionDigits = fractionDigits
        formatter.maximumFractionDigits = max(fractionDigits, 4)
        let result = formatter.string(from: value as NSDecimalNumber) ?? sample
        // Belt-and-suspenders: ensure no U+2019 leaks even if a future iOS
        // changes the formatter's grouping behavior.
        return result.replacingOccurrences(of: "\u{2019}", with: "'")
    }

    /// Determine fraction-digit count from the original sample string.
    /// For inputs like `"5.70"` (Swiss decimal) or `"5,70"` (German decimal),
    /// returns 2. For thousands-only inputs like `"1.250"` (German thousands)
    /// returns 0 — but only when the digits-after-separator length is exactly
    /// 3 AND there's no other separator suggesting a true decimal.
    private static func fractionDigitCount(of sample: String) -> Int {
        // If the sample contains BOTH `.` and `,`, the LAST one wins as
        // decimal. Otherwise: a single `,` is decimal; a single `.` is
        // decimal UNLESS it's followed by exactly 3 digits and no other
        // separator (then it's German thousands → 0 fraction digits).
        let lastDot = sample.lastIndex(of: ".")
        let lastComma = sample.lastIndex(of: ",")

        if let d = lastDot, let c = lastComma {
            // Both present — the latter is the decimal separator.
            let decimalIdx = d > c ? d : c
            return sample.distance(from: sample.index(after: decimalIdx), to: sample.endIndex)
        } else if let c = lastComma {
            // Comma only — German decimal.
            return sample.distance(from: sample.index(after: c), to: sample.endIndex)
        } else if let d = lastDot {
            let after = sample.distance(from: sample.index(after: d), to: sample.endIndex)
            // German thousands heuristic: exactly 3 digits after the dot,
            // no other separator → it's thousands (0 fraction digits).
            if after == 3 { return 0 }
            return after
        }
        return 0
    }
}
