import Foundation

/// Utility for Inverse Text Normalization (ITN) — converting spelled-out numbers to digits.
struct ITNUtility {

    /// Apply ITN to the given text based on the detected language.
    static func applyITN(to text: String, language: String) -> String {
        let normalized: String
        if language == "de" {
            normalized = applyGermanITN(to: text)
        } else {
            normalized = applyEnglishITN(to: text)
        }
        let rangeFixed = applyRangeHomophoneFix(to: normalized, language: language)
        // Phase 28 D-03 (Plan 28-02): single-digit identifier-adjacent promotion.
        // Runs BEFORE applyNumericStructuralWords so "model three point one"
        // chains: → "model 3 point one" → "model 3.1".
        let singleDigit = applySingleDigitIdentifier(to: rangeFixed, language: language)
        return applyNumericStructuralWords(to: singleDigit, language: language)
    }

    /// Numeric structural word post-pass (P3).
    ///
    /// Converts verbal connectors ("point", "dash", "Punkt", "Komma", "zero") to
    /// their symbolic equivalents when they appear in numeric contexts — i.e. when
    /// adjacent to digit tokens on both sides. Guards prevent false positives for
    /// words like "the point is clear" where no adjacent digit exists (T-26-01).
    ///
    /// Transform order matters for "25 point 1 dash zero 6":
    ///   1. point/Punkt:  `\d+ point \d` → `\d+.\d`
    ///   2. Komma:        `\d+ Komma \d` → `\d+,\d`  (German only)
    ///   3. zero-prefix:  `\d+ dash zero \d` → `\d+-0\d`  (so "1-zero 6" → "1-06")
    ///   4. dash:         `\d+ dash \d`  → `\d+-\d`
    ///
    /// Single-digit English words ("one"…"nine") are resolved to their digit forms
    /// when they appear as the right operand of a structural connector, enabling
    /// "twenty five point one dash zero six" → "25.1-06" end-to-end.
    static func applyNumericStructuralWords(to text: String, language: String) -> String {
        var result = text

        // Single-digit English words used as right operands in structural patterns.
        let enDigitWords = "(?:zero|one|two|three|four|five|six|seven|eight|nine|\\d+)"
        // Lookup for converting word to digit string.
        let enWordMap: [String: String] = [
            "zero": "0", "one": "1", "two": "2", "three": "3", "four": "4",
            "five": "5", "six": "6", "seven": "7", "eight": "8", "nine": "9",
        ]
        func resolveEn(_ s: String) -> String { enWordMap[s.lowercased()] ?? s }

        // Step 1: point/Punkt between digit and digit-or-word → decimal dot.
        // Runs first so "25 point one" → "25.1" before any dash pass.
        // English: (\d+) point (\d+|word)
        result = replaceStructural(
            result,
            pattern: "(\\d+)\\s+(?i:point)\\s+(\(enDigitWords))"
        ) { g in "\(g[1]).\(resolveEn(g[2]))" }

        // German: (\d+) Punkt (\d+)
        if language == "de" {
            result = replaceStructural(
                result,
                pattern: "(\\d+)\\s+Punkt\\s+(\\d+)"
            ) { g in "\(g[1]).\(g[2])" }

            // Step 2: Komma between digits → German decimal comma
            result = replaceStructural(
                result,
                pattern: "(\\d+)\\s+Komma\\s+(\\d+)"
            ) { g in "\(g[1]),\(g[2])" }
        }

        // Step 3: zero-prefix after digit-dash/hyphen context.
        // "1 dash zero 6" → "1-06"; "25.1 dash zero six" → "25.1-06"
        // Runs before plain dash so "dash zero X" is captured as a unit.
        result = replaceStructural(
            result,
            pattern: "(\\d+)\\s+(?i:dash|hyphen)\\s+(?i:zero)\\s+(\(enDigitWords))"
        ) { g in "\(g[1])-0\(resolveEn(g[2]))" }

        // Step 4: dash/hyphen between digits → "-" (remaining cases not handled by step 3)
        result = replaceStructural(
            result,
            pattern: "(\\d+)\\s+(?i:dash|hyphen)\\s+(\\d+)"
        ) { g in "\(g[1])-\(g[2])" }

        return result
    }

    /// Apply a regex pattern to `text`, replacing each match using the `replacement`
    /// closure. The closure receives an array of captured group strings (index 0 =
    /// full match, 1… = capture groups). Matches are processed in reverse order so
    /// string indices remain valid across replacements.
    private static func replaceStructural(
        _ text: String,
        pattern: String,
        replacement: ([String]) -> String
    ) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return text
        }
        var result = text
        let nsText = result as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)
        let matches = regex.matches(in: result, options: [], range: fullRange)
        guard !matches.isEmpty else { return result }
        for match in matches.reversed() {
            guard let matchRange = Range(match.range, in: result) else { continue }
            var groups: [String] = []
            for i in 0..<match.numberOfRanges {
                if let r = Range(match.range(at: i), in: result) {
                    groups.append(String(result[r]))
                } else {
                    groups.append("")
                }
            }
            result.replaceSubrange(matchRange, with: replacement(groups))
        }
        return result
    }

    /// Range homophone post-pass.
    ///
    /// Catches the "X to Y" → "X two Y" / "X 0 Y" → digit-merged ASR
    /// failure mode reported in v2.2 UAT (e.g. "Claude Code should
    /// verify phases 102, four." for intended "phases 1 to 4"). The
    /// range marker "to" is acoustically near-identical to "two" /
    /// "oh"; downstream ITN/ASR can collapse the trio into a single
    /// large number plus a stranded final digit/word.
    ///
    /// Detection requires a range-implying noun head (phases, chapters,
    /// steps, items, sections, parts, levels, stages — DE: Phasen,
    /// Kapitel, Schritte, Abschnitte, Teile) so the rewrite never fires
    /// on legitimate sequences (lists of phone numbers, ID arrays, etc.).
    ///
    /// Two patterns are rewritten:
    ///   1. `<noun> N M K` (three 1-digit numbers, space-separated)
    ///      → `<noun> N to K` (first-to-last; the middle digit is the
    ///      range marker "to" misheard as a digit).
    ///   2. `<noun> N0M(,)? <K>` where N0M is a 3-digit number whose
    ///      middle digit is 0 (the "to" → "oh" path) and the following
    ///      token is a digit or small number-word
    ///      → `<noun> N to K` (first digit of N0M, dropping the M, paired
    ///      with the trailing token).
    ///
    /// Conservative by design: when the pattern doesn't match the
    /// noun-head guard, the input passes through untouched. Idempotent.
    static func applyRangeHomophoneFix(to text: String, language: String) -> String {
        let isGerman = language.prefix(2).lowercased() == "de"
        let nouns: [String]
        let connector: String
        if isGerman {
            nouns = ["phasen", "kapitel", "schritte", "abschnitte", "teile", "stufen"]
            connector = "bis"
        } else {
            nouns = ["phases", "chapters", "steps", "items", "sections", "parts", "levels", "stages"]
            connector = "to"
        }
        let nounAlt = nouns.joined(separator: "|")

        var result = text

        // Pattern 1: <noun> N M K  (three 1-digit numbers, space-separated)
        //   "phases 1 2 4" → "phases 1 to 4"
        let p1 = "(?i)\\b(\(nounAlt))\\s+(\\d)\\s+\\d\\s+(\\d)\\b"
        result = rewriteRange(result, pattern: p1, headIdx: 1, firstIdx: 2, lastIdx: 3, lastIsWord: false, connector: connector)

        // Pattern 2: <noun> N0M  ,? <small number or word>
        //   "phases 102, four" → "phases 1 to 4"
        //   "phases 102 four"  → "phases 1 to 4"
        //   "phases 102 4"     → "phases 1 to 4"
        let numberWord = "(\\d|two|three|four|five|six|seven|eight|nine|zwei|drei|vier|fünf|sechs|sieben|acht|neun)"
        let p2 = "(?i)\\b(\(nounAlt))\\s+(\\d)0\\d\\s*,?\\s+\(numberWord)\\b"
        result = rewriteRange(result, pattern: p2, headIdx: 1, firstIdx: 2, lastIdx: 3, lastIsWord: true, connector: connector)

        return result
    }

    /// Apply a regex rewrite that maps the matched span to
    /// `<head> <first> <connector> <last>`. When `lastIsWord` is true,
    /// the `lastIdx` capture is converted via `numberWordToDigit`;
    /// otherwise it is treated as a literal digit.
    private static func rewriteRange(
        _ text: String,
        pattern: String,
        headIdx: Int,
        firstIdx: Int,
        lastIdx: Int,
        lastIsWord: Bool,
        connector: String
    ) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return text
        }
        let nsText = text as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)
        let matches = regex.matches(in: text, options: [], range: fullRange)
        guard !matches.isEmpty else { return text }

        var result = text
        for match in matches.reversed() {
            guard
                let matchRange = Range(match.range, in: result),
                let head = Range(match.range(at: headIdx), in: result),
                let first = Range(match.range(at: firstIdx), in: result),
                let last = Range(match.range(at: lastIdx), in: result)
            else { continue }
            let headText = String(result[head])
            let firstDigit = String(result[first])
            let lastToken = String(result[last])
            let lastDigit = lastIsWord
                ? (numberWordToDigit(lastToken) ?? lastToken)
                : lastToken
            result.replaceSubrange(matchRange, with: "\(headText) \(firstDigit) \(connector) \(lastDigit)")
        }
        return result
    }

    /// Convert a small number word (en/de) to its digit form. Returns
    /// nil for unrecognized inputs and for words outside the 2..9 range
    /// so the caller can keep the original token.
    private static func numberWordToDigit(_ word: String) -> String? {
        let lower = word.lowercased()
        // Pure digit passes through.
        if Int(lower) != nil { return lower }
        let map: [String: String] = [
            "two": "2", "three": "3", "four": "4", "five": "5",
            "six": "6", "seven": "7", "eight": "8", "nine": "9",
            "zwei": "2", "drei": "3", "vier": "4", "fünf": "5",
            "sechs": "6", "sieben": "7", "acht": "8", "neun": "9",
        ]
        return map[lower]
    }

    /// D-16 / D-17: Deterministic Swiss German orthography transform.
    ///
    /// Converts `ß` → `ss` and `ẞ` (U+1E9E, capital Eszett) → `SS`, preserving
    /// the surrounding case. Runs whenever the Swiss German toggle is ON,
    /// independent of AI cleanup state. Sub-millisecond cost — cheap enough
    /// to run on every transcription when enabled.
    ///
    /// Called from two sites:
    ///   1. `TextProcessingService.process(...)` — applies to plain dictation AND
    ///      the pre-LLM input (Swiss users benefit without enabling AI cleanup).
    ///   2. `CleanupService.cleanup(...)` — post-LLM safety-net (D-19) to catch
    ///      any `ß` the LLM slipped in despite the D-18 prompt instruction.
    ///
    /// - Parameter text: Any Swiss German text (or mixed-case input).
    /// - Returns: Text with all Eszett characters transliterated to ss/SS.
    static func applySwissITN(to text: String) -> String {
        return text
            .replacingOccurrences(of: "ß", with: "ss")
            .replacingOccurrences(of: "\u{1E9E}", with: "SS")
    }

    // MARK: - German ITN

    /// Custom parser for German compound number words.
    /// Apple's NumberFormatter.spellOut doesn't reliably parse compound German numbers
    /// like "einhundertdreiundzwanzig" or "viertausendfünfhundert".
    /// Minimum value for standalone number conversion.
    /// Numbers below this are left as words (style guide: spell out one through nine).
    private static let minDigitThreshold = 10

    private static func applyGermanITN(to text: String) -> String {
        let tokens = text.components(separatedBy: .whitespacesAndNewlines)
        var resultTokens: [String] = []

        for token in tokens {
            let cleanedToken = token.trimmingCharacters(in: .punctuationCharacters)
            let punctuation = String(token.suffix(token.count - cleanedToken.count))

            if let number = parseGermanNumber(cleanedToken.lowercased()),
               number >= minDigitThreshold {
                resultTokens.append("\(number)\(punctuation)")
            } else {
                resultTokens.append(token)
            }
        }

        return resultTokens.joined(separator: " ")
    }

    /// Parse a single German compound number word into its numeric value.
    /// Handles patterns like: viertausendfünfhundertdreiundzwanzig (4523)
    private static func parseGermanNumber(_ word: String) -> Int? {
        // Single-word unit lookup (also catches simple cases)
        if let simple = germanUnits[word] {
            return simple
        }

        var remaining = word
        var total = 0
        var hasMatch = false

        // Extract thousands: [prefix]tausend[rest]
        if let tausendRange = remaining.range(of: "tausend") {
            let prefix = String(remaining[remaining.startIndex..<tausendRange.lowerBound])
            remaining = String(remaining[tausendRange.upperBound...])

            let multiplier: Int
            if prefix.isEmpty || prefix == "ein" {
                multiplier = 1
            } else if let n = germanUnits[prefix] {
                multiplier = n
            } else {
                return nil
            }
            total += multiplier * 1000
            hasMatch = true
        }

        // Extract hundreds: [prefix]hundert[rest]
        if let hundertRange = remaining.range(of: "hundert") {
            let prefix = String(remaining[remaining.startIndex..<hundertRange.lowerBound])
            remaining = String(remaining[hundertRange.upperBound...])

            let multiplier: Int
            if prefix.isEmpty || prefix == "ein" {
                multiplier = 1
            } else if let n = germanUnits[prefix] {
                multiplier = n
            } else {
                return nil
            }
            total += multiplier * 100
            hasMatch = true
        }

        // Remaining should be a two-digit number or empty
        if !remaining.isEmpty {
            if let n = parseGermanTwoDigit(remaining) {
                total += n
                hasMatch = true
            } else {
                return nil
            }
        }

        return hasMatch ? total : nil
    }

    /// Parse German two-digit numbers, including "und" compounds (e.g. "dreiundzwanzig" → 23)
    private static func parseGermanTwoDigit(_ word: String) -> Int? {
        // Direct lookup for units and teens
        if let n = germanUnits[word] { return n }
        if let n = germanTeens[word] { return n }
        if let n = germanTens[word] { return n }

        // Compound: [unit]und[tens] (e.g. "dreiundzwanzig")
        if let undRange = word.range(of: "und") {
            let unitPart = String(word[word.startIndex..<undRange.lowerBound])
            let tensPart = String(word[undRange.upperBound...])
            if let u = germanUnits[unitPart], let t = germanTens[tensPart] {
                return t + u
            }
        }

        return nil
    }

    private static let germanUnits: [String: Int] = [
        "null": 0, "eins": 1, "ein": 1, "zwei": 2, "drei": 3,
        "vier": 4, "fünf": 5, "sechs": 6, "sieben": 7, "acht": 8, "neun": 9
    ]

    private static let germanTeens: [String: Int] = [
        "zehn": 10, "elf": 11, "zwölf": 12, "dreizehn": 13, "vierzehn": 14,
        "fünfzehn": 15, "sechzehn": 16, "siebzehn": 17, "achtzehn": 18, "neunzehn": 19
    ]

    private static let germanTens: [String: Int] = [
        "zwanzig": 20, "dreißig": 30, "vierzig": 40, "fünfzig": 50,
        "sechzig": 60, "siebzig": 70, "achtzig": 80, "neunzig": 90
    ]

    // MARK: - English ITN

    // MARK: - Phase 28 D-03: Single-digit identifier-adjacent promotion

    /// Dispatches single-digit identifier promotion by language.
    /// Called from `applyITN` between `applyRangeHomophoneFix` and `applyNumericStructuralWords`.
    static func applySingleDigitIdentifier(to text: String, language: String) -> String {
        if language == "de" {
            return applyGermanSingleDigitIdentifier(to: text)
        }
        return applyEnglishSingleDigitIdentifier(to: text)
    }

    /// Promotes single-digit number-words to digits when identifier-adjacent (EN).
    ///
    /// Pattern A — capitalized stem prefix (Phase 28 CR-01 fix):
    ///   Stem shapes: [A-Z](?![a-z]) (E, M — 1-char ALLCAPS not followed by lowercase)
    ///                | [A-Z]{2,5} (GSD, NRSNA)
    ///                | [a-z][A-Z][a-zA-Z]{0,3} (iOS, iPad, eBook)
    ///   Excludes ALL Title-Case prose words (No, At, Be, Go, Cat, One, The).
    ///   The 1-char ALLCAPS branch uses a negative lookahead so common prose
    ///   bigrams like "No one", "At one", "Go five" are NOT mangled to
    ///   "No1", "At1", "Go5" (CR-01).
    ///
    /// Pattern B — version-class word prefix (case-insensitive, fixed alternation).
    static func applyEnglishSingleDigitIdentifier(to text: String) -> String {
        var result = text

        let digitWords = "(?i:one|two|three|four|five|six|seven|eight|nine)"
        let wordMap: [String: String] = [
            "one": "1", "two": "2", "three": "3", "four": "4", "five": "5",
            "six": "6", "seven": "7", "eight": "8", "nine": "9",
        ]
        func resolve(_ s: String) -> String { wordMap[s.lowercased()] ?? s }

        // Pattern A — Phase 28 CR-01 fix: 1-char ALLCAPS guarded by negative
        // lookahead so 2-char Title-Case prose stems (No, At, In, Be, Go, etc.)
        // do NOT match and produce "No1 knows" / "At1 point" / "Go5 steps".
        let stemPattern = "(?:[A-Z](?![a-z])|[A-Z]{2,5}|[a-z][A-Z][a-zA-Z]{0,3})"
        let patternA = "\\b(\(stemPattern))\\s+(\(digitWords))\\b"
        result = replaceStructural(result, pattern: patternA) { g in
            "\(g[1])\(resolve(g[2]))"
        }

        // Pattern B — version-class word prefix (case-insensitive).
        let versionClass = "(?i:version|model|item|option|chapter|step|phase|task|level|stage|track|round|tier|grade)"
        let patternB = "\\b(\(versionClass))\\s+(\(digitWords))\\b"
        result = replaceStructural(result, pattern: patternB) { g in
            "\(g[1]) \(resolve(g[2]))"
        }

        return result
    }

    /// DE inflected forms in identifier position.
    /// Scoped to single-digit identifier promotion — NOT added to `germanUnits`
    /// (which would break `parseGermanNumber` compound parsing like `einundzwanzig`).
    private static let germanIdentifierUnits: [String: String] = [
        "eins": "1", "ein": "1", "eine": "1", "einen": "1", "einer": "1",
        "einem": "1", "eines": "1",
        "zwei": "2", "drei": "3", "vier": "4", "fünf": "5", "sechs": "6",
        "sieben": "7", "acht": "8", "neun": "9", "zehn": "10", "elf": "11", "zwölf": "12",
    ]

    /// Promotes single-digit number-words to digits when identifier-adjacent (DE).
    /// Handles inflected forms (eins/ein/eine/einen/einer/einem/eines) via `germanIdentifierUnits`.
    static func applyGermanSingleDigitIdentifier(to text: String) -> String {
        var result = text

        let digitWords = "(?i:eins|ein|eine|einen|einer|einem|eines|zwei|drei|vier|fünf|sechs|sieben|acht|neun|zehn|elf|zwölf)"
        func resolve(_ s: String) -> String { germanIdentifierUnits[s.lowercased()] ?? s }

        // Pattern A — Phase 28 CR-01 fix: 1-char ALLCAPS guarded by negative
        // lookahead (extended for German diacritics) so 2-char Title-Case prose
        // stems (Da, So, Wo, Er, Am, etc.) do NOT mangle bigrams like "Da eins".
        let stemPattern = "(?:[A-Z](?![a-zäöüß])|[A-Z]{2,5}|[a-zäöü][A-Z][a-zA-ZäöüÄÖÜß]{0,3})"
        let patternA = "\\b(\(stemPattern))\\s+(\(digitWords))\\b"
        result = replaceStructural(result, pattern: patternA) { g in
            "\(g[1])\(resolve(g[2]))"
        }

        // Pattern B — DE version-class words (case-insensitive).
        let versionClass = "(?i:version|modell|item|option|kapitel|schritt|phase|aufgabe|stufe|ebene|runde|rang|klasse)"
        let patternB = "\\b(\(versionClass))\\s+(\(digitWords))\\b"
        result = replaceStructural(result, pattern: patternB) { g in
            "\(g[1]) \(resolve(g[2]))"
        }

        return result
    }

    private static func applyEnglishITN(to text: String) -> String {
        let locale = Locale(identifier: "en_US")
        let formatter = NumberFormatter()
        formatter.numberStyle = .spellOut
        formatter.locale = locale

        let words = text.components(separatedBy: .whitespacesAndNewlines)
        var result: [String] = []
        var i = 0

        let numberWords = Set(["zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten", "eleven", "twelve", "thirteen", "fourteen", "fifteen", "sixteen", "seventeen", "eighteen", "nineteen", "twenty", "thirty", "forty", "fifty", "sixty", "seventy", "eighty", "ninety", "hundred", "thousand", "million", "billion", "and"])

        while i < words.count {
            var foundNumber = false

            for length in (1...8).reversed() {
                guard i + length <= words.count else { continue }

                let subSequence = words[i..<i+length]
                let cleanedSubSequence = subSequence.map { $0.trimmingCharacters(in: .punctuationCharacters) }
                let lastPunctuation = String(subSequence.last!.suffix(subSequence.last!.count - cleanedSubSequence.last!.count))

                let allAreNumberWords = cleanedSubSequence.allSatisfy { word in
                    let w = word.lowercased()
                    return numberWords.contains(w) || w.contains("-")
                }
                guard allAreNumberWords else { continue }

                // Logic to prevent over-merging distinct numbers (e.g., "5 26")
                if length == 2 {
                    let first = cleanedSubSequence[0].lowercased()
                    let second = cleanedSubSequence[1].lowercased()
                    let units = ["zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine"]
                    let tens = ["twenty", "thirty", "forty", "fifty", "sixty", "seventy", "eighty", "ninety"]
                    if units.contains(first) && tens.contains(second) {
                        continue
                    }
                    // "zero X" where X is a single digit: "zero" serves as a structural
                    // zero-prefix (e.g. "dash zero six" → "-06"). Don't let ITN merge
                    // the pair — the structural word post-pass handles it.
                    if first == "zero" && units.contains(second) {
                        continue
                    }
                }

                // Try multiple formats — NumberFormatter expects "twenty-three" (hyphenated)
                // but ASR outputs "twenty three" (space-separated).
                let subText = cleanedSubSequence.joined(separator: " ")
                let subTextAllHyphens = cleanedSubSequence.joined(separator: "-")

                // Mixed format: spaces between groups, hyphen between tens-units
                // e.g. "one hundred twenty-three" for ["one", "hundred", "twenty", "three"]
                var subTextMixed: String? = nil
                if cleanedSubSequence.count >= 3 {
                    let prefix = cleanedSubSequence[0..<cleanedSubSequence.count-2].joined(separator: " ")
                    let lastTwo = cleanedSubSequence[cleanedSubSequence.count-2..<cleanedSubSequence.count].joined(separator: "-")
                    subTextMixed = "\(prefix) \(lastTwo)"
                }

                // Try hyphenated form first: NSNumberFormatter correctly parses "twenty-five"→25
                // but parses "twenty five" (space) as 2005 (concatenating 20+05). By trying
                // the hyphenated form first, the correct parse is found before the broken one.
                let candidates = [subTextAllHyphens.lowercased(), subText.lowercased()] + (subTextMixed.map { [$0.lowercased()] } ?? [])

                var parsed: NSNumber? = nil
                for candidate in candidates {
                    if let n = formatter.number(from: candidate) {
                        parsed = n
                        break
                    }
                }

                if let number = parsed {
                    // Skip small standalone numbers (style: spell out one through nine)
                    if number.intValue < minDigitThreshold && length == 1 {
                        break
                    }
                    result.append("\(number)\(lastPunctuation)")
                    i += length
                    foundNumber = true
                    break
                }
            }

            if !foundNumber {
                result.append(words[i])
                i += 1
            }
        }

        return result.joined(separator: " ")
    }
}
