import Foundation

/// Utility for Inverse Text Normalization (ITN) — converting spelled-out numbers to digits.
struct ITNUtility {

    /// Apply ITN to the given text based on the detected language.
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

    private static func applyGermanITN(to text: String, formatter: NumberFormatter) -> String {
        let tokens = text.components(separatedBy: .whitespacesAndNewlines)
        var resultTokens: [String] = []

        for token in tokens {
            let cleanedToken = token.trimmingCharacters(in: .punctuationCharacters)
            let punctuation = String(token.suffix(token.count - cleanedToken.count))

            // Apple's NumberFormatter for German is extremely brittle with ASR text.
            // We use it as a first pass, then fallback to individual checks.
            if let number = formatter.number(from: cleanedToken.lowercased()) {
                if cleanedToken.count == 1 && !CharacterSet.decimalDigits.isSuperset(of: CharacterSet(charactersIn: cleanedToken)) && cleanedToken.lowercased() != "eins" {
                    resultTokens.append(token)
                    continue
                }
                resultTokens.append("\(number)\(punctuation)")
                continue
            }
            
            resultTokens.append(token)
        }

        return resultTokens.joined(separator: " ")
    }

    private static func applyEnglishITN(to text: String, formatter: NumberFormatter) -> String {
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
                
                // Normalization: NumberFormatter.number(from:) expects "twenty-three" with a hyphen.
                // ASR gives "twenty three". We try both.
                let subText = cleanedSubSequence.joined(separator: " ")
                let subTextWithHyphen = cleanedSubSequence.joined(separator: "-")

                if let number = formatter.number(from: subText.lowercased()) ?? formatter.number(from: subTextWithHyphen.lowercased()) {
                    
                    let allAreNumberWords = cleanedSubSequence.allSatisfy { word in
                        let w = word.lowercased()
                        return numberWords.contains(w) || w.contains("-")
                    }
                    
                    if allAreNumberWords {
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

                        result.append("\(number)\(lastPunctuation)")
                        i += length
                        foundNumber = true
                        break
                    }
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
