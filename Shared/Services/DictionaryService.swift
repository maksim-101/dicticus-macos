import Foundation
import Combine

/// Metadata for a dictionary entry.
struct DictionaryMetadata: Codable, Equatable {
    let replacement: String
    let createdAt: Date
}

/// Manages a custom dictionary of find-replace pairs for dictation correction.
@MainActor
class DictionaryService: ObservableObject {

    static let dictionaryKey = "customDictionaryMetadata"
    static let caseSensitiveKey = "dictionaryCaseSensitive"

    /// The active dictionary of [Original: Metadata] pairs.
    @Published private(set) var dictionary: [String: DictionaryMetadata] = [:]
    
    /// Whether matching should be case-sensitive.
    @Published var isCaseSensitive: Bool = false {
        didSet {
            UserDefaults(suiteName: "group.com.dicticus")!.set(isCaseSensitive, forKey: Self.caseSensitiveKey)
        }
    }

    /// Shared instance for use in TextProcessingService and DictionaryView.
    static let shared = DictionaryService()

    private init() {
        self.isCaseSensitive = UserDefaults(suiteName: "group.com.dicticus")!.bool(forKey: Self.caseSensitiveKey)
        load()

        // Migrate old data if it exists and new data is empty
        if dictionary.isEmpty {
            migrateOldFormat()
        }

        // Drop entries we previously shipped as defaults but have since
        // retired as harmful. Runs once per launch on the persisted set —
        // cheap, idempotent, and required for users who already have the
        // bad keys cached in UserDefaults.
        purgeRetiredDefaults()

        // Always merge defaults — adds new entries on updates, preserves existing user entries
        prepopulateWithDefaults()
    }

    /// Keys we previously shipped in `prepopulateWithDefaults()` but
    /// have since identified as net-harmful (false-positive matches
    /// against legitimate dictation). Removed on every launch from the
    /// persisted dictionary so existing installs converge to the new
    /// behavior without requiring a manual reset.
    ///
    /// 2026-05-06: dropped the "I'm" cluster — `"one m"` matched
    /// inside "one meeting" when ASR introduced any punctuation/space
    /// between tokens, producing "I'm meeting" hallucinations.
    ///
    /// 2026-05-22: dropped "Versal" — Levenshtein distance 2 from
    /// "versus", causing every spoken "versus" to be replaced with
    /// "Vercel". Replaced by exact-match "vercel" key (distance 3
    /// from "versus", outside fuzzy threshold). Phase 26 P2.
    private func purgeRetiredDefaults() {
        let retired: [String] = [
            "1m", "1 m", "I m", "one m", "One m",
            "Versal",
        ]
        var changed = false
        for key in retired {
            if dictionary.removeValue(forKey: key) != nil {
                changed = true
            }
        }
        if changed {
            save()
        }
    }

    private func migrateOldFormat() {
        let oldKey = "customDictionary"
        if let oldStored = UserDefaults.standard.dictionary(forKey: oldKey) as? [String: String] {
            for (original, replacement) in oldStored {
                dictionary[original] = DictionaryMetadata(replacement: replacement, createdAt: Date())
            }
            save()
            // Clean up old key
            UserDefaults.standard.removeObject(forKey: oldKey)
        }
    }

    private func prepopulateWithDefaults() {
        let defaults: [String: String] = [
            "true nest": "TrueNAS", "true Nest": "TrueNAS", "TrueNest": "TrueNAS", 
            "truenest": "TrueNAS", "True Nest": "TrueNAS",
            "clods.md": "Claude.MD", "DOC-G": "Dockge", "cloth desktop": "Claude Desktop", 
            "medviki": "MedWiki", "matviki": "MedWiki", "add guard": "adguard", "trueness": "TrueNAS", 
            "claw desktop": "Claude Desktop", "Cloud Desktop": "Claude Desktop", 
            "cloud.md": "Claude.MD", "clot.md": "Claude.MD", "clod.md": "Claude.MD", 
            "Swiss \"": "Swissquote", "Swiss quote": "Swissquote", "Swiss code": "Swissquote", 
            "this quote": "Swissquote", "This quote": "Swissquote", "dot cloud": ".claude",
            "Zyria": "ZüriA", "Acara": "Aqara", "engine X": "NGINX",
            "docg": "Dockge", "true NAS": "TrueNAS", "tail scale": "Tailscale", 
            "Telscale": "Tailscale", "light llm": "LiteLLM", "LightLLM": "LiteLLM", 
            "doc G": "Dockge", "Clot": "Claude", ".clot": ".claude", "clot code": "Claude Code", 
            ".cloud": ".claude", "Cloud Code": "Claude Code",
            // 2026-05-06: removed brittle "1m"/"1 m"/"I m"/"one m"/"One m" → "I'm"
            // mappings. They false-fired on legitimate phrases like "one meeting"
            // ("one m" matched on "one meeting" when ASR injected punctuation
            // between tokens) and Gemma already capitalizes "i" → "I" without
            // dictionary forcing. See purgeRetiredDefaults() for in-place cleanup.
            "Selguard": "Cellguard", "selguard": "Cellguard", "Mac Vesper": "MacWhisper", "Kai-Agenten": "KI-Agenten", "Ki-Argenten": "KI-Agenten", "KI-Agenten": "KI-Agenten", "AI-Agenten": "AI-Agenten", "Dektik-Tools": "Dicticus", "Sigby": "Zigbee", "Sig B": "Zigbee", "sig b": "Zigbee", "Sigbee": "Zigbee", "sigbee": "Zigbee", "Zigbee": "Zigbee", "AI Cleanup": "AI Cleanup", "AI-Cleanup": "AI Cleanup",
            "GSD": "GSD", "gest": "GSD", "GST": "GSD", "cheers": "GSD", "G.S.D.": "GSD", "gsd": "GSD",
            // Phase 25-03 Lever 1 (matrix.md §5, 2026-05-16): brand/anchor
            // mishearings from V15 capture-window. H9 (rules+dict) collapses
            // brand 35→2 and anchor 28→0 without any LLM cost. Each entry
            // cites the V15 fixture timestamp it closes.
            "Chemini": "Gemini", "Cheminai": "Gemini", "chemini": "Gemini", "cheminai": "Gemini",
            "Jemini": "Gemini",
            "MPM": "NPM",
            "engine eggs": "NGINX",
            "Doghand": "Dokku", "Dog Hand": "Dokku", "doghand": "Dokku", "dog hand": "Dokku",
            "DogChee": "Dockge", "Dog Chee": "Dockge", "dogchee": "Dockge", "dog chee": "Dockge",
            "C Oli": "CLI", "c oli": "CLI",
            "true Nas": "TrueNAS",
            // Phase 25.1-03 — paper §2.2 lexical priming. Closes 25-03 Class B defects
            // (own-brand mishearings the LLM correctly leaves alone per §4.2 lexical
            // fidelity). Each entry cites the JSONL timestamp it closes.
            "Chema 4 2EB": "Gemma 4 E2B",                 // 2026-05-17 06:02:10
            "chema 4 2eb": "Gemma 4 E2B",
            "Chema": "Gemma",                              // partial fallback for "Chema 7B" / "Chema 12B" variants
            "chema": "Gemma",
            "Dicticos": "Dicticus",                        // 25-03 Class B exemplar (Dicticus own-brand)
            "dicticos": "Dicticus",
            "Olama": "Ollama",                             // 25-03 Class B exemplar
            "olama": "Ollama",
            "Tailskill": "Tailscale",                      // 2026-05-17 05:30:23 (existing `tail scale` entry doesn't catch this — single-token mishearing)
            "tailskill": "Tailscale",
            "hopath": "homeopath",                         // 25-03 Class B exemplar (medical-context dictation)
        ]

        
        for (original, replacement) in defaults {
            if dictionary[original] == nil {
                dictionary[original] = DictionaryMetadata(replacement: replacement, createdAt: Date())
            }
        }
        save()
    }

    func load() {
        if let data = UserDefaults(suiteName: "group.com.dicticus")!.data(forKey: Self.dictionaryKey),
           let stored = try? JSONDecoder().decode([String: DictionaryMetadata].self, from: data) {
            dictionary = stored
        }
    }

    func save() {
        if let data = try? JSONEncoder().encode(dictionary) {
            UserDefaults(suiteName: "group.com.dicticus")!.set(data, forKey: Self.dictionaryKey)
        }
    }

    func setReplacement(for original: String, with replacement: String) {
        let trimmedOriginal = original.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedOriginal.isEmpty else { return }
        
        dictionary[trimmedOriginal] = DictionaryMetadata(
            replacement: replacement.trimmingCharacters(in: .whitespacesAndNewlines),
            createdAt: Date()
        )
        save()
    }

    func removeReplacement(for original: String) {
        dictionary.removeValue(forKey: original)
        save()
    }

    func removeAll() {
        dictionary.removeAll()
        save()
    }

    func apply(to text: String) -> String {
        var result = text
        let sortedKeys = dictionary.keys.sorted { $0.count > $1.count }

        for original in sortedKeys {
            guard let metadata = dictionary[original] else { continue }

            // \b only works between \w (alphanumeric) and \W (non-alphanumeric).
            // It fails for "Swiss \" because " matches \W.
            // We use lookarounds to simulate word boundaries for any string.
            let escaped = NSRegularExpression.escapedPattern(for: original)

            // Pattern: Ensure match is not preceded or followed by an alphanumeric character
            // unless the original string itself starts/ends with one.
            let pattern = "(?<![a-zA-Z0-9])\(escaped)(?![a-zA-Z0-9])"

            let options: NSRegularExpression.Options = isCaseSensitive ? [] : [.caseInsensitive]

            do {
                let regex = try NSRegularExpression(pattern: pattern, options: options)
                let range = NSRange(result.startIndex..<result.endIndex, in: result)
                result = regex.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: metadata.replacement)
            } catch {
                result = result.replacingOccurrences(of: original, with: metadata.replacement, options: isCaseSensitive ? [] : [.caseInsensitive])
            }
        }

        // Phase 25.1-03: fuzzy second pass after exact-match completes.
        result = applyFuzzyPass(result)
        return result
    }

    /// Phase 25.1-03 — paper §2.2 fuzzy-match second pass.
    ///
    /// Runs after the exact-match lookaround regex pass in `apply(to:)`. For each
    /// token of length ≥ 6 in `text`, checks dictionary keys of length ≥ 6
    /// (single-token only) where `abs(token.count - key.count) <= 2`. If
    /// `LevenshteinDistance.distance(token.lowercased(), key.lowercased()) <= 2`,
    /// the token is replaced with the dictionary value.
    ///
    /// Length-prefilter ≥ 6 is mandatory: distance-2 matches against short tokens
    /// (e.g. `the`/`she`) catastrophically false-positive. Multi-word keys are
    /// skipped — the exact-match regex pass handles those.
    ///
    /// Closes 25-03 substring-matching failures (Tailskill ↔ Tailscale was missed
    /// by the exact-match path because the keys are distinct single tokens). Per
    /// CONTEXT.md Parakeet implication §4: this is the ONLY pre-LLM brand-
    /// recognition lever (Parakeet TDT v3 has no `initial_prompt` equivalent).
    private func applyFuzzyPass(_ text: String) -> String {
        let candidateKeys = dictionary.keys
            .filter { $0.count >= 6 && !$0.contains(" ") }
        if candidateKeys.isEmpty { return text }

        // Walk character by character, collecting word tokens and preserving
        // all non-word characters (punctuation, whitespace) in their original
        // positions. Split on whitespace; preserve trailing punctuation per token.
        var result = ""
        var current = ""
        let isWordChar: (Character) -> Bool = { $0.isLetter || $0.isNumber }
        for ch in text {
            if isWordChar(ch) {
                current.append(ch)
            } else {
                if !current.isEmpty {
                    result.append(fuzzyReplaceToken(current, candidates: candidateKeys))
                    current = ""
                }
                result.append(ch)
            }
        }
        if !current.isEmpty {
            result.append(fuzzyReplaceToken(current, candidates: candidateKeys))
        }
        return result
    }

    private func fuzzyReplaceToken(_ token: String, candidates: [String]) -> String {
        guard token.count >= 6 else { return token }
        let lowered = token.lowercased()
        for key in candidates {
            guard abs(token.count - key.count) <= 2 else { continue }
            let keyLowered = key.lowercased()
            // Skip identity — already handled by exact-match pass.
            if lowered == keyLowered { return token }
            if LevenshteinDistance.distance(lowered, keyLowered) <= 2 {
                return dictionary[key]?.replacement ?? token
            }
        }
        return token
    }
}
