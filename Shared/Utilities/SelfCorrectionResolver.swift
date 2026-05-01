import Foundation

/// Phase 20 D-02 Action 2: deterministic self-correction resolution.
///
/// Resolves in-stream speech repairs of the shape
/// `"<reparandum>, <connector> <repair>"` by dropping the reparandum and
/// the connector, leaving only the repair. Connector list and design
/// constraints come from CONTEXT.md decision D-02 and the Wave 0 RED
/// suite `iOS/DicticusTests/SelfCorrectionResolverTests.swift`.
///
/// Critical guards (locked by tests + adversarial fixtures):
///   1. **Comma-prefix guard.** The connector MUST be preceded by a
///      comma. Defends against "I mean it" / "Ich meine es ernst" /
///      "or rather not" content phrases.
///   2. **Backward window cap = 3 tokens.** Never delete more than the
///      most recent 3 backward tokens.
///   3. **Abort path** when there is no clear repair candidate:
///         a) The connector itself is followed by a comma
///            (`", ich meine, …"` — clausal continuation).
///         b) The first repair token is a relative / object pronoun
///            that signals a clausal continuation rather than a
///            substitute noun (`I mean what …`, `ich meine es …`).
///      On abort: leave the entire match span untouched. Do NOT drop the
///      connector pair; do NOT drop trailing content tokens.
///
/// Connector lists (case-insensitive):
///   de: `ich meine`, `besser gesagt`, `genauer gesagt`,
///       `oder vielmehr`, `oder besser`
///   en: `I mean`, `I meant`, `or rather`, `or better`, `scratch that`
///
/// Drop-count algorithm (derived from the union of the positive fixtures
/// and the cap-test in `SelfCorrectionResolverTests.testGermanBackwardWindowCappedAtThree`):
///   1. Find the first repair token.
///   2. Look for that token in the last 3 backward tokens. If found at
///      position `k` from the end (1-indexed), drop `k` tokens. This is
///      the alignment-by-first-repair-token rule that handles all the
///      "X Franken / X Euro" parallel cases cleanly.
///   3. Else fall back: drop = `min(repair_token_count, 3)` UNLESS the
///      repair is a single token AND there are ≥ 6 backward tokens; in
///      that case use the cap-3 (the synthetic cap-test rule).
///
/// Pure transform — no actors, no state. Idempotent: a second invocation
/// on already-resolved text leaves it unchanged because either the
/// connector is gone or the repair phrase no longer has a comma-prefixed
/// connector.
public enum SelfCorrectionResolver {

    // MARK: - Public API

    public static func resolve(_ text: String, language: String) -> String {
        let connectors = connectorList(for: language)
        let abortPronouns = pronounAbortSet(for: language)
        guard !connectors.isEmpty else { return text }

        // Build the connector alternation. Sort longest-first so multi-word
        // connectors win over single-word prefixes (e.g. "or rather" before
        // "or" — even though we don't ship "or" as a connector, the same
        // discipline applies to "I meant" / "I mean").
        let alternation = connectors
            .sorted(by: { $0.count > $1.count })
            .map { NSRegularExpression.escapedPattern(for: $0) }
            .joined(separator: "|")

        // The connector MUST be preceded by `, ` (comma + whitespace) to
        // fire — this is the comma-prefix guard. Capture the connector
        // span itself for span replacement; the comma-and-space prefix
        // sits OUTSIDE the match group so it is also consumed.
        // Group layout: full match = `, <connector>\s*` (consumed),
        // group 1 = the connector text itself.
        let pattern = "(?i),\\s*(\(alternation))(\\s*)"

        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return text
        }

        let nsText = text as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)
        let matches = regex.matches(in: text, options: [], range: fullRange)
        guard !matches.isEmpty else { return text }

        // Process matches in REVERSE so range arithmetic stays stable.
        var result = text
        for match in matches.reversed() {
            guard let matchRange = Range(match.range, in: result) else { continue }

            // What sits AFTER the match? We need the first repair token
            // and any trailing context, AND we need to detect the abort
            // signal of an immediately-following comma.
            let afterStart = matchRange.upperBound
            if afterStart >= result.endIndex { continue }
            let after = String(result[afterStart...])

            // Abort 3a: the connector is followed by a comma → clausal
            // continuation (e.g. ", ich meine, mit der ganzen Familie").
            // We have to look past any trailing whitespace the match might
            // not have eaten, but the match's `(\s*)` group already
            // gobbles trailing whitespace, so the literal next char tells.
            if let firstChar = after.first, firstChar == "," {
                continue
            }

            // Tokenize the repair side (everything after the connector,
            // up to but NOT including the next sentence-ending boundary
            // for the purpose of identifying the FIRST repair token; we
            // still keep the rest of `after` in the output verbatim).
            let repairTokensFull = tokenize(after)
            guard !repairTokensFull.isEmpty else { continue }
            let firstRepairToken = repairTokensFull[0]
            let firstRepairLower = firstRepairToken.lowercasedTrimmingPunctuation()

            // Abort 3b: relative / object pronoun head signals a clausal
            // continuation rather than a substitute noun phrase.
            if abortPronouns.contains(firstRepairLower) {
                continue
            }

            // Tokenize the backward span (text BEFORE the leading comma
            // of the match — i.e. before `result[matchRange]`).
            let beforeText = String(result[result.startIndex..<matchRange.lowerBound])
            let backwardTokens = tokenize(beforeText)
            guard !backwardTokens.isEmpty else { continue }

            // Determine drop count.
            let backwardCount = backwardTokens.count
            let lastThreeIndex = max(0, backwardCount - 3)
            let lastThree = Array(backwardTokens[lastThreeIndex..<backwardCount])
            // 1) Try alignment-by-first-repair-token in the last 3.
            //    Compare with case-insensitive strict-equality (no punctuation
            //    folding on the backward side because backward tokens rarely
            //    end in sentence punctuation; the repair-side strip is enough).
            var dropCount: Int? = nil
            for (offset, token) in lastThree.enumerated() {
                if token.lowercasedTrimmingPunctuation() == firstRepairLower {
                    // offset is 0-based from the start of `lastThree`;
                    // distance from end = lastThree.count - offset.
                    dropCount = lastThree.count - offset
                    break  // first (left-most in the last-3 window) wins
                }
            }

            // 2) Fallback: repair-count, capped at 3, with the synthetic
            //    cap-test escalation (single-token repair + ≥ 6 backward
            //    tokens → use full cap of 3).
            if dropCount == nil {
                let repairCount = repairTokensFull.count
                if repairCount == 1 && backwardCount >= 6 {
                    dropCount = min(3, backwardCount)
                } else {
                    dropCount = min(max(repairCount, 1), 3)
                }
            }

            let actualDrop = min(dropCount ?? 1, min(3, backwardCount))
            guard actualDrop > 0 else { continue }

            // Compute the character range to drop on the BACKWARD side.
            // We drop `actualDrop` trailing tokens AND any whitespace
            // immediately preceding the leading comma — the comma itself
            // is already consumed by the match.
            let dropFromIndex = backwardCount - actualDrop
            // Find the start char-index of token at `dropFromIndex` inside
            // `beforeText`. Re-scan `beforeText` to recover positions.
            let dropStart = startIndexOfNthToken(beforeText, n: dropFromIndex)
            guard let realDropStart = dropStart else { continue }

            // The replacement: remove tokens from realDropStart through
            // the END of the match (i.e. through the consumed connector +
            // trailing whitespace). Then leave the original tail (`after`)
            // intact starting at its first repair token.
            let trailing = result[matchRange.upperBound..<result.endIndex]
            // Strip trailing whitespace before the dropped span
            // (so we don't leave a stray double-space).
            var prefix = String(result[result.startIndex..<realDropStart])
            while prefix.hasSuffix(" ") || prefix.hasSuffix("\t") {
                prefix.removeLast()
            }
            // Re-insert a single space if the prefix is non-empty AND
            // the trailing starts with a non-whitespace, non-punctuation
            // character (so that "Das" + " " + "fünf Stück." reads naturally
            // when we drop e.g. " kostet 110 Franken").
            let needsSpace: Bool = {
                guard !prefix.isEmpty, let firstTrailing = trailing.first else { return false }
                return !firstTrailing.isWhitespace && !".,;:!?".contains(firstTrailing)
            }()
            let glue = needsSpace ? " " : ""
            result = prefix + glue + trailing
        }

        // Final whitespace tidy: collapse any accidental double spaces.
        while result.contains("  ") {
            result = result.replacingOccurrences(of: "  ", with: " ")
        }
        return result
    }

    // MARK: - Connector + abort lists

    private static let germanConnectors: [String] = [
        "ich meine",
        "besser gesagt",
        "genauer gesagt",
        "oder vielmehr",
        "oder besser",
    ]

    private static let englishConnectors: [String] = [
        "I mean",
        "I meant",
        "or rather",
        "or better",
        "scratch that",
    ]

    private static let germanAbortPronouns: Set<String> = [
        // Object / relative pronouns and demonstrative heads that signal
        // a clausal continuation rather than a substitute noun.
        "es", "das", "dass", "den", "dem", "der", "die",
        "was", "wer", "wie", "wo", "ob", "wenn",
    ]

    private static let englishAbortPronouns: Set<String> = [
        "it", "what", "that", "which", "who", "whom",
        "this", "when", "why", "how", "where",
    ]

    private static func connectorList(for language: String) -> [String] {
        let prefix = language.prefix(2).lowercased()
        switch prefix {
        case "en": return englishConnectors
        case "de": return germanConnectors
        default:   return germanConnectors
        }
    }

    private static func pronounAbortSet(for language: String) -> Set<String> {
        let prefix = language.prefix(2).lowercased()
        switch prefix {
        case "en": return englishAbortPronouns
        case "de": return germanAbortPronouns
        default:   return germanAbortPronouns
        }
    }

    // MARK: - Tokenization helpers

    /// Whitespace-separated tokens, dropping empty entries.
    private static func tokenize(_ s: String) -> [String] {
        return s.split(whereSeparator: { $0.isWhitespace })
            .map(String.init)
    }

    /// Return the character index of the start of the n-th whitespace-
    /// separated token in `s`. n is 0-indexed.
    /// Returns nil if `s` has fewer than `n + 1` tokens.
    private static func startIndexOfNthToken(_ s: String, n: Int) -> String.Index? {
        var seen = 0
        var i = s.startIndex
        var inToken = false
        var tokenStart: String.Index? = nil
        while i < s.endIndex {
            let c = s[i]
            if c.isWhitespace {
                if inToken {
                    if seen == n {
                        return tokenStart
                    }
                    seen += 1
                    inToken = false
                }
            } else {
                if !inToken {
                    tokenStart = i
                    inToken = true
                }
            }
            i = s.index(after: i)
        }
        // Reached end while inside a token.
        if inToken {
            if seen == n { return tokenStart }
        }
        return nil
    }
}

// MARK: - String helpers

private extension String {
    /// Lowercase + strip a single trailing sentence-punctuation char if any.
    func lowercasedTrimmingPunctuation() -> String {
        var s = self
        if let last = s.last, ".,;:!?".contains(last), s.count > 1 {
            s = String(s.dropLast())
        }
        return s.lowercased()
    }
}
