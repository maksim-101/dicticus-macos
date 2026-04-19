import Foundation

/// Utility for Inverse Text Normalization (ITN) — converting spelled-out numbers to digits.
///
/// Per TEXT-01: Cardinal numbers in dictated speech appear as digits (e.g. "twenty three" -> "23").
/// Supported languages: English ("en"), German ("de").
/// Uses NumberFormatter with .spellOut style for rule-based conversion.
struct ITNUtility {

    /// Apply ITN to the given text based on the detected language.
    ///
    /// - Parameters:
    ///   - text: The transcribed text.
    ///   - language: "de" or "en".
    /// - Returns: Text with spelled-out numbers replaced by digits.
    static func applyITN(to text: String, language: String) -> String {
        let locale = language == "de" ? Locale(identifier: "de_DE") : Locale(identifier: "en_US")
        let formatter = NumberFormatter()
        formatter.numberStyle = .spellOut
        formatter.locale = locale

        if language == "de" {
            return applyGermanITN(to: text, formatter: formatter)
        } else {
            return applyEnglishITN(to: text, formatter: formatter)
        }
    }

    /// German ITN implementation.
    /// German cardinal numbers up to 999,999 are typically written as a single word
    /// (e.g., "einhundertdreiundzwanzig").
    private static func applyGermanITN(to text: String, formatter: NumberFormatter) -> String {
        // Split by whitespace and punctuation, but preserve separators for reassembly
        let tokens = text.components(separatedBy: .whitespacesAndNewlines)
        var resultTokens: [String] = []

        for token in tokens {
            // Remove trailing punctuation for parsing
            let cleanedToken = token.trimmingCharacters(in: .punctuationCharacters)
            let punctuation = String(token.suffix(token.count - cleanedToken.count))

            // Try to parse the word as a number
            if let number = formatter.number(from: cleanedToken.lowercased()) {
                resultTokens.append("\(number)\(punctuation)")
            } else {
                resultTokens.append(token)
            }
        }

        return resultTokens.joined(separator: " ")
    }

    /// English ITN implementation.
    /// English numbers use multiple words (e.g., "one hundred twenty-three").
    /// Uses a sliding window to find the longest sequence of words that form a valid number.
    private static func applyEnglishITN(to text: String, formatter: NumberFormatter) -> String {
        let words = text.components(separatedBy: .whitespacesAndNewlines)
        var result: [String] = []
        var i = 0

        while i < words.count {
            var foundNumber = false
            // Try sliding window from largest (max 6 words) to smallest (1 word)
            for length in (1...6).reversed() {
                guard i + length <= words.count else { continue }
                
                let subSequence = words[i..<i+length]
                // Join with spaces or hyphens for parsing
                let subText = subSequence.joined(separator: " ")
                let subTextWithHyphen = subSequence.joined(separator: "-")

                if let number = formatter.number(from: subText.lowercased()) ?? formatter.number(from: subTextWithHyphen.lowercased()) {
                    // Check if it's a real number (NumberFormatter can be over-eager with "one")
                    // We check if the parsed number's string representation in spell-out matches
                    // closely enough or if it's a multi-word number.
                    let backToText = formatter.string(from: number) ?? ""
                    
                    // "one" -> 1 is simple. But we don't want to catch every "a" or similar artifacts.
                    // If it's a single word and not a number word, skip.
                    if length == 1 {
                        let isCommonNumber = ["zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten", "eleven", "twelve", "twenty", "thirty", "forty", "fifty", "sixty", "seventy", "eighty", "ninety", "hundred", "thousand", "million", "billion"].contains(subText.lowercased())
                        if !isCommonNumber { continue }
                    }

                    result.append("\(number)")
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
