import Foundation

/// Phase 36.1 Plan 05: Post-LLM number-form revert.
///
/// After the LLM runs, the deterministic layer owns number forms: any digit↔word
/// change the LLM introduced vs. the ITN baseline reverts to the baseline form.
/// Two count-budgeted passes over space-tokens cover both directions:
///   - LLM re-spelled a baseline digit → revert to digit
///   - LLM promoted a spelled number-word that ITN left spelled → revert to word
///
/// Count-budget design prevents over-rewriting legitimate duplicates:
/// "three things, all three" — each occurrence tracked individually (Pitfall 4).
///
/// EN and DE maps cover cardinals and ordinals. The `@MainActor` annotation present
/// in the spike (Numbers006.swift) is removed — this is a pure transform; the
/// `@MainActor` call site (TextProcessingService) handles isolation.
public enum NumberRevert {

    public static let enWords: [String: String] = [
        "zero": "0", "one": "1", "two": "2", "three": "3", "four": "4",
        "five": "5", "six": "6", "seven": "7", "eight": "8", "nine": "9",
        "ten": "10", "eleven": "11", "twelve": "12", "thirteen": "13",
        "fourteen": "14", "fifteen": "15", "sixteen": "16", "seventeen": "17",
        "eighteen": "18", "nineteen": "19", "twenty": "20", "thirty": "30",
        "forty": "40", "fifty": "50", "sixty": "60", "seventy": "70",
        "eighty": "80", "ninety": "90",
        "first": "1st", "second": "2nd", "third": "3rd", "fourth": "4th",
        "fifth": "5th", "sixth": "6th", "seventh": "7th", "eighth": "8th",
        "ninth": "9th", "tenth": "10th", "twentieth": "20th"
    ]
    public static let deWords: [String: String] = [
        "null": "0", "eins": "1", "zwei": "2", "drei": "3", "vier": "4",
        "fünf": "5", "sechs": "6", "sieben": "7", "acht": "8", "neun": "9",
        "zehn": "10", "elf": "11", "zwölf": "12", "zwanzig": "20",
        "dreissig": "30", "vierzig": "40", "fünfzig": "50", "sechzig": "60",
        "siebzig": "70", "achtzig": "80", "neunzig": "90",
        "erste": "1.", "ersten": "1.", "zweite": "2.", "zweiten": "2.",
        "dritte": "3.", "dritten": "3.", "vierte": "4.", "vierten": "4.",
        "fünfte": "5.", "fünften": "5.", "sechste": "6.", "sechsten": "6.",
        "siebte": "7.", "siebten": "7.", "achte": "8.", "achten": "8.",
        "neunte": "9.", "neunten": "9.", "zehnte": "10.", "zehnten": "10."
    ]

    public struct Change {
        public let from: String
        public let to: String
    }

    /// Reverts LLM-introduced number-form changes. The baseline (rules-cleaned
    /// text) is authoritative: ITN already promoted everything the policy wants
    /// as digits, so a spelled number-word remaining in the baseline is meant
    /// to stay spelled — and a digit in the baseline is meant to stay a digit.
    public static func apply(
        baseline: String,
        output: String,
        language: String
    ) -> (text: String, changes: [Change]) {
        let map = language == "de" ? deWords : enWords
        // Build inverse from both bare digit form AND ordinal form (e.g. "4." → "vierten")
        // so ordinal tokens like "4." are found via either lookup key.
        let inverse: [String: [String]] = Dictionary(grouping: map.keys, by: { map[$0]! })

        func tokens(_ s: String) -> [String] {
            s.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        }
        // Strip surrounding sentence punctuation only — NOT trailing ordinal period.
        // A token like "4." is an ordinal marker in DE: strip leading/trailing
        // "normal" punct but preserve the internal "digit." ordinal form.
        func strip(_ t: String) -> String {
            t.trimmingCharacters(in: CharacterSet(charactersIn: ",!?;:()\"„\u{201C}\u{201D}\u{AB}\u{BB}"))
        }

        let baseTokens = tokens(baseline).map { strip($0).lowercased() }
        var baseWordCounts: [String: Int] = [:]   // spelled number-words in baseline
        var baseDigitCounts: [String: Int] = [:]  // pure-digit tokens in baseline
        for t in baseTokens {
            if map[t] != nil { baseWordCounts[t, default: 0] += 1 }
            if t.allSatisfy({ $0.isNumber }) && !t.isEmpty { baseDigitCounts[t, default: 0] += 1 }
        }

        // Also track ordinal digit-forms (like "4.") that appear in the inverse map.
        // These are in the output when the LLM promotes a German ordinal word to digit+period.
        var baseOrdinalCounts: [String: Int] = [:]  // "4.", "1.", etc. in baseline
        for t in baseTokens {
            if inverse[t] != nil && t.last == "." { baseOrdinalCounts[t, default: 0] += 1 }
        }

        var outWordBudget = baseWordCounts   // how many spelled words still unaccounted
        var outDigitBudget = baseDigitCounts // how many digits still unaccounted
        var outOrdinalBudget = baseOrdinalCounts
        var changes: [Change] = []

        // First pass: tokens already in output consume the relevant budget.
        for t in tokens(output) {
            let core = strip(t).lowercased()
            if core.allSatisfy({ $0.isNumber }) && !core.isEmpty, outDigitBudget[core, default: 0] > 0 {
                outDigitBudget[core]! -= 1
            }
            if map[core] != nil, outWordBudget[core, default: 0] > 0 {
                outWordBudget[core]! -= 1
            }
            if inverse[core] != nil && core.last == ".", outOrdinalBudget[core, default: 0] > 0 {
                outOrdinalBudget[core]! -= 1
            }
        }

        // Second pass: rewrite offending tokens.
        var result: [String] = []
        for t in tokens(output) {
            let core = strip(t)
            let lower = core.lowercased()

            // Case A: LLM introduced an ordinal digit-form (e.g. "4.") not in baseline
            // → revert to the spelled ordinal word if unconsumed.
            if !core.isEmpty, core.last == ".",
               inverse[lower] != nil,
               baseOrdinalCounts[lower, default: 0] == 0 {
                if let words = inverse[lower] {
                    if let w = words.first(where: { outWordBudget[$0, default: 0] > 0 }) {
                        outWordBudget[w]! -= 1
                        let replacement = t.replacingOccurrences(of: core, with: matchCase(of: w, to: core))
                        changes.append(Change(from: t, to: replacement))
                        result.append(replacement)
                        continue
                    }
                }
            }

            // Case B: LLM introduced a bare digit not in baseline → revert to the spelled
            // word if a spelled word of the same value is unconsumed.
            if !core.isEmpty, core.allSatisfy({ $0.isNumber }),
               baseDigitCounts[lower, default: 0] == 0 {
                if let words = inverse[lower] {
                    if let w = words.first(where: { outWordBudget[$0, default: 0] > 0 }) {
                        outWordBudget[w]! -= 1
                        // restore original casing if it began the sentence
                        let replacement = t.replacingOccurrences(of: core, with: matchCase(of: w, to: core))
                        changes.append(Change(from: t, to: replacement))
                        result.append(replacement)
                        continue
                    }
                }
            }

            // Case C: LLM re-spelled a digit → revert to the digit if that digit is
            // missing from the output but present in baseline.
            if let digit = map[lower], baseWordCounts[lower, default: 0] == 0,
               outDigitBudget[digit, default: 0] > 0 {
                outDigitBudget[digit]! -= 1
                let replacement = t.replacingOccurrences(of: core, with: digit)
                changes.append(Change(from: t, to: replacement))
                result.append(replacement)
                continue
            }

            result.append(t)
        }
        return (text: result.joined(separator: " "), changes: changes)
    }

    public static func matchCase(of word: String, to original: String) -> String {
        if let f = original.first, f.isUppercase || f.isNumber == false && original == original.uppercased() {
            // digits have no case; only uppercase the word if the digit token
            // can't tell us — use lowercase unless the slot is sentence-start,
            // which we can't see here. Default lowercase; sentence-start digits
            // are rare.
            return word
        }
        return word
    }
}
