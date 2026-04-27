import Foundation
import NaturalLanguage

// Phase 20 D-01: verb changed Rewrite → "Lightly edit" and the LLM is no longer
// asked to remove fillers or convert spelled numbers — those tasks moved to the
// deterministic Swift rules pass (RulesCleanupService, plan 20-03). The LLM is
// now reined in to grammar / punctuation / capitalization fixes only, with the
// Levenshtein gate (CleanupService.gateLLMOutput) as a structural fail-safe.

/// Prompt builder for AI text cleanup via Gemma 4 E2B.
struct CleanupPrompt {

    static let customInstructionKey = "cleanupInstruction"

    static let defaultInstruction = """
    Lightly edit the following transcribed text. Fix obvious grammar, punctuation, and capitalization. \
    Do not paraphrase, summarize, or add information. \
    Apply the dictionary replacements if any. Output ONLY the polished text. \
    If the input is already correct, output it unchanged.
    """

    static func userInstruction() -> String {
        let custom = UserDefaults.standard.string(forKey: customInstructionKey) ?? ""
        return custom.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? defaultInstruction
            : custom
    }

    /// Build the cleanup prompt.
    ///
    /// - Parameters:
    ///   - text: the raw transcribed text to be polished.
    ///   - language: detected language code (`"de"` / `"en"`).
    ///   - dictionaryContext: user-defined replacement pairs.
    ///   - useSwissGerman: explicit Swiss-toggle snapshot. When `nil` (legacy
    ///     callers), the AppGroup `useSwissGerman` key is read once. WR-03 fix
    ///     (Phase 19.5): `CleanupService.cleanup` now snapshots this toggle at
    ///     the top of the call and passes the same value to both this builder
    ///     and the post-LLM Swiss formatting pass, so a mid-inference toggle
    ///     change cannot cause prompt/post-pass disagreement.
    static func build(
        text: String,
        language: String? = nil,
        dictionaryContext: [String: String]? = nil,
        useSwissGerman: Bool? = nil
    ) -> String {
        let instruction = userInstruction()

        var prompt = "<start_of_turn>user\n"
        prompt += "INSTRUCTION: \(instruction)\n"

        if let dict = dictionaryContext, !dict.isEmpty {
            prompt += "DICTIONARY:\n"
            for (original, replacement) in dict.sorted(by: { $0.key < $1.key }) {
                prompt += "- \(original) -> \(replacement)\n"
            }
        }

        if let lang = language {
            prompt += "LANGUAGE: \(lang == "de" ? "German" : "English")\n"
        }

        // D-18: Swiss German orthography prompt extension (scoped to German only).
        // Gated on BOTH the Swiss-toggle decision AND language == "de".
        // Standard-German dictation stays untouched even if the Swiss toggle is ON.
        // WR-03 fix: prefer the explicit `useSwissGerman` argument when provided
        // (CleanupService snapshots it once); fall back to reading the AppGroup
        // for legacy callers / direct unit tests.
        let swissEnabled: Bool = useSwissGerman ?? {
            let suite = UserDefaults(suiteName: "group.com.dicticus") ?? UserDefaults.standard
            return suite.bool(forKey: "useSwissGerman")
        }()
        if swissEnabled && language == "de" {
            prompt += "STYLE: Use Swiss German orthography (never use ß, always ss). "
            prompt += "Use Swiss thousands separator style (e.g. 1'250, not 1.250).\n"
            // Phase 20.06 F-20-UAT-01: HELVETISMS block reworked preservation-first.
            // Phase 19.5 D-D2 wording ("Prefer these Swiss German words when applicable")
            // caused Gemma 4 E2B to translate High German → Swiss German dialect
            // (auf→uf, ausgeflogen→usgfloge, gekostet→choschtet, …) on UAT 2026-04-27.
            // The block now leads with explicit preservation, restricts allowed
            // normalizations, enumerates a NEGATIVE trap list, and keeps the positive
            // word list as a vocabulary anchor only for words the speaker actually used.
            prompt += "HELVETISMS: Preserve the speaker's dialect register exactly. "
            prompt += "Only change ß→ss and decimal-comma→period. "
            prompt += "Do NOT replace High German words with Swiss German equivalents. "
            prompt += "Specifically: do NOT apply any of these substitutions — "
            prompt += "auf→uf, ausgeflogen→usgfloge, gekostet→choschtet, einkaufen→iikaufe, "
            prompt += "natürlich→natürli, Dingen→Sache, gegessen→gässe, später→speter, "
            prompt += "beiden→beidne, Seite→Siite, etwas→öppis, Kleines→chliins, "
            prompt += "gekauft→chauft. "
            prompt += "If — and only if — the speaker actually used a Swiss word, keep it as-is "
            prompt += "(reference list: \(SwissHelvetisms.words.joined(separator: ", "))).\n"
        }

        // D-B1b (Phase 19.5): Currency anti-flip prompt anchor. Fires on ANY
        // de-language input that contains a currency token, regardless of the
        // Swiss toggle (per D-B2 — Gemma's EUR bias is a German-language issue,
        // not a Swiss-only one).
        // W8 lock: detect on raw `text`. sanitizeControlTokens only strips
        // Gemma turn tokens (never present in user dictation), so detection
        // on raw text is equivalent and avoids reordering existing code.
        if language == "de" {
            let detectedCurrencies = CurrencyAntiFlip.detectCurrencies(in: text)
            if !detectedCurrencies.isEmpty {
                let labels = detectedCurrencies.map(\.text).joined(separator: ", ")
                prompt += "STRICT: Keep currency exactly as written ("
                prompt += labels
                prompt += "). Do NOT translate, convert, or substitute one currency for another.\n"
                // Phase 20.06 F-20-UAT-02: speaker-explicit anchor against the
                // wrong-direction Franken→Euro flip the LLM exhibited on UAT.
                prompt += "Explicit currency words from the speaker are authoritative — never substitute Franken with Euro or vice versa.\n"
            }
        }

        let sanitizedText = sanitizeControlTokens(text)
        prompt += "INPUT: \(sanitizedText)<end_of_turn>\n"
        prompt += "<start_of_turn>model\n"
        prompt += "OUTPUT:"
        
        return prompt
    }

    static func sanitizeControlTokens(_ text: String) -> String {
        var result = text
        for token in ["<start_of_turn>", "<end_of_turn>", "<bos>", "<eos>"] {
            result = result.replacingOccurrences(of: token, with: "")
        }
        return result
    }

    static func containsMixedLanguages(_ text: String) -> Bool {
        let recognizer = NLLanguageRecognizer()
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard sentences.count > 1 else { return false }

        var languages = Set<String>()
        for sentence in sentences {
            recognizer.processString(sentence)
            if let lang = recognizer.dominantLanguage?.rawValue {
                languages.insert(lang)
            }
            if languages.count >= 2 { return true }
        }

        return false
    }
}
