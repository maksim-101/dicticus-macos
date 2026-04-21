import Foundation

/// Utility for Inverse Text Normalization (ITN) — converting spelled-out numbers to digits.
struct ITNUtility {

    /// Apply ITN to the given text based on the detected language.
    static func applyITN(to text: String, language: String) -> String {
        if language == "de" {
            return applyGermanITN(to: text)
        } else {
            return applyEnglishITN(to: text)
        }
    }

    // MARK: - German ITN

    /// Custom parser for German compound number words.
    /// Apple's NumberFormatter.spellOut doesn't reliably parse compound German numbers
    /// like "einhundertdreiundzwanzig" or "viertausendfünfhundert".
    private static func applyGermanITN(to text: String) -> String {
        let tokens = text.components(separatedBy: .whitespacesAndNewlines)
        var resultTokens: [String] = []

        for token in tokens {
            let cleanedToken = token.trimmingCharacters(in: .punctuationCharacters)
            let punctuation = String(token.suffix(token.count - cleanedToken.count))

            if let number = parseGermanNumber(cleanedToken.lowercased()) {
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

                let candidates = [subText.lowercased(), subTextAllHyphens.lowercased()] + (subTextMixed.map { [$0.lowercased()] } ?? [])

                var parsed: NSNumber? = nil
                for candidate in candidates {
                    if let n = formatter.number(from: candidate) {
                        parsed = n
                        break
                    }
                }

                if let number = parsed {
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
