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

    /// Phase 27 D-09: per-replacement trace entry emitted by `applyWithTrace`.
    /// Field names mirror the JSONL schema (`dictionary_replacements`) exactly so
    /// the recorder can encode the array with no name mapping.
    public struct Replacement: Codable, Sendable {
        public let key: String
        public let from: String
        public let to: String
    }

    /// Phase 27 D-09: blocked-fuzzy trace entry. Emitted when a candidate would
    /// have hit under the pre-guard distance rule (distance <= 2) but the new
    /// Levenshtein ratio cap (D-03, RESEARCH §6.1 Option 1: 0.25) blocks it.
    /// Field names mirror the JSONL schema (`dictionary_blocked`).
    /// `to` is included per D-06 amendment 2026-05-26 (RESEARCH §6.6) for
    /// single-file diagnosability of JSONL logs.
    public struct BlockedMatch: Codable, Sendable {
        public let key: String
        public let from: String
        public let to: String
        public let ratio: Double
    }

    /// Phase 27 D-03 (open-decision Option 1 per RESEARCH §6.1): Levenshtein
    /// ratio cap above which a fuzzy candidate is rejected. 0.25 keeps the
    /// existing Tailscele->Tailscale fuzzy hit (ratio 0.222) while blocking
    /// remind->Gemini (0.333) and applies->AppLite (0.286).
    private static let fuzzyRatioCap: Double = 0.25

    /// The active dictionary of [Original: Metadata] pairs.
    @Published private(set) var dictionary: [String: DictionaryMetadata] = [:]

    /// Whether matching should be case-sensitive.
    @Published var isCaseSensitive: Bool = false {
        didSet {
            UserDefaults(suiteName: "group.com.dicticus")!.set(isCaseSensitive, forKey: Self.caseSensitiveKey)
        }
    }

    /// Phase 27 D-01a / D-02 / D-04: bundled common-word allowlist. Tokens
    /// matching an entry (lowercased) short-circuit the fuzzy pass entirely.
    /// Loaded once at init from `Shared/Resources/allowlist-{en,de}.txt`.
    private let commonWords: Set<String>

    /// Test-only accessor for the loaded allowlist. Used by
    /// `DictionaryServiceHallucinationGuardTests.testAllowlistLoadedFromBundle`.
    internal var commonWordsForTests: Set<String> { commonWords }

    /// Shared instance for use in TextProcessingService and DictionaryView.
    static let shared = DictionaryService()

    private init() {
        self.isCaseSensitive = UserDefaults(suiteName: "group.com.dicticus")!.bool(forKey: Self.caseSensitiveKey)
        self.commonWords = Self.loadCommonWords()
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

    /// Phase 27 D-02 / D-05: load the bundled common-word allowlist into a
    /// single `Set<String>` (union of EN + DE top-N corpora). Returns an empty
    /// Set on any failure (RESEARCH §6.3 Assumption A2 defensive fallback) so
    /// init never crashes — the ratio cap (Guard B) still provides defense.
    ///
    /// Phase 27 WR-03: every entry is normalized to NFC
    /// (`.precomposedStringWithCanonicalMapping`). Swift `String` hashing /
    /// equality is byte-identical at the underlying storage level, so
    /// graphemically-equal NFD vs NFC forms hash differently. ASR pipelines
    /// occasionally emit decomposed German diacritics (`ü` = `u` + U+0308)
    /// while the bundled `.txt` corpora ship precomposed forms (`ü` = U+00FC).
    /// Without normalization the allowlist veto silently misses on exactly the
    /// German tokens the guard is designed to protect. Lookup site must NFC
    /// the token symmetrically — see fuzzyReplaceTokenWithTrace().
    private static func loadCommonWords() -> Set<String> {
        var words: Set<String> = []
        for resourceName in ["allowlist-en", "allowlist-de"] {
            guard let url = Bundle.main.url(forResource: resourceName, withExtension: "txt") else {
                print("[DictionaryService] allowlist load failed: \(resourceName).txt not found in bundle")
                continue
            }
            do {
                let content = try String(contentsOf: url, encoding: .utf8)
                for line in content.split(separator: "\n", omittingEmptySubsequences: true) {
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                        .lowercased()
                        .precomposedStringWithCanonicalMapping
                    if !trimmed.isEmpty {
                        words.insert(trimmed)
                    }
                }
            } catch {
                print("[DictionaryService] allowlist load failed: \(resourceName).txt — \(error.localizedDescription)")
            }
        }
        return words
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

    /// Phase 27 WR-04: lifted from `private` → internal so the WR-04
    /// regression test can invoke the merge loop directly and assert
    /// the D-12 invariant (existing user customizations are never
    /// overwritten on re-merge). Not exposed publicly — `@testable
    /// import Dicticus` provides access; production callers continue
    /// to go through the singleton's private init only.
    internal func prepopulateWithDefaults() {
        let defaults: [String: String] = [
            "true nest": "TrueNAS", "true Nest": "TrueNAS", "TrueNest": "TrueNAS",
            "truenest": "TrueNAS", "True Nest": "TrueNAS",
            "clods.md": "Claude.MD", "DOC-G": "Dockge", "cloth desktop": "Claude Desktop",
            "medviki": "MedWiki", "matviki": "MedWiki", "add guard": "adguard", "trueness": "TrueNAS",
            "claw desktop": "Claude Desktop", "Cloud Desktop": "Claude Desktop",
            "cloud.md": "Claude.MD", "clot.md": "Claude.MD", "clod.md": "Claude.MD",
            "Swiss \"": "Swissquote", "Swiss quote": "Swissquote", "Swiss code": "Swissquote",
            "this quote": "Swissquote", "This quote": "Swissquote", "dot cloud": ".claude",
            "Zyria": "ZüriA", "Acara": "Aqara", "engine X": "NGINX", "X code": "Xcode", "x code": "Xcode",
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
            // Phase 27 K7: brand misses from log-analysis 2026-05-26 §K7.
            // Each entry cites the live-capture JSONL timestamp it closes.
            "clawed code": "Claude Code",                  // 2026-05-23T05:24:32.417Z
            "Accara": "Aqara",                             // 2026-05-24T17:50:00.606Z (×2)
            "accara": "Aqara",
            "Andre Karpaty": "Andrej Karpathy",            // 2026-05-25T04:14:30.688Z
            "Swiss folio": "Swissfolio",                   // log-analysis §K7
            "swiss folio": "Swissfolio",
            // Phase 27 carried backlog — exact-match only under the new fuzzy guard.
            "germinize": "Gemini",                         // ratio 0.44 BLOCKS fuzzy; only exact-match fires
            "crown shop": "cron job",
            // Phase 29 DICT-ZED-01: Spike-001-validated. Period-anchored to avoid
            // "the set of …" / compound "X set" false positives. Recovers Zed IDE
            // misheard as "set" when clause-final. Mid-sentence Zed is missed (safe failure).
            "the set.": "Zed.",
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

    /// Phase 27 D-08: `apply(to:)` is a thin wrapper over `applyWithTrace(to:)`.
    /// Single source of truth — production and recorder share one code path.
    func apply(to text: String) -> String {
        return applyWithTrace(to: text).text
    }

    /// Phase 27 D-08: canonical traced dictionary application. Returns the
    /// processed text plus per-replacement and per-blocked-fuzzy-candidate
    /// trace arrays. Both arrays are empty when nothing happened (D-07 default-
    /// empty contract for downstream JSONL stability).
    public func applyWithTrace(to text: String) -> (text: String, replacements: [Replacement], blocked: [BlockedMatch]) {
        var result = text
        var replacements: [Replacement] = []
        var blocked: [BlockedMatch] = []

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
                let nsResult = result as NSString
                let fullRange = NSRange(location: 0, length: nsResult.length)
                let matches = regex.matches(in: result, options: [], range: fullRange)
                if !matches.isEmpty {
                    // Capture matched substrings (in original positions) before
                    // mutating `result` so trace.from carries the actual text.
                    for m in matches {
                        let matched = nsResult.substring(with: m.range)
                        replacements.append(Replacement(key: original, from: matched, to: metadata.replacement))
                    }
                    result = regex.stringByReplacingMatches(in: result, options: [], range: fullRange, withTemplate: metadata.replacement)
                }
            } catch {
                // Fallback: best-effort replacement; cannot reliably emit trace entries here.
                result = result.replacingOccurrences(of: original, with: metadata.replacement, options: isCaseSensitive ? [] : [.caseInsensitive])
            }
        }

        // Phase 25.1-03: fuzzy second pass after exact-match completes.
        let fuzzy = applyFuzzyPassWithTrace(result)
        result = fuzzy.text
        replacements.append(contentsOf: fuzzy.replacements)
        blocked.append(contentsOf: fuzzy.blocked)

        return (result, replacements, blocked)
    }

    /// Phase 25.1-03 — paper §2.2 fuzzy-match second pass.
    ///
    /// Runs after the exact-match lookaround regex pass in `applyWithTrace(to:)`.
    /// For each token of length ≥ 6 in `text`, checks dictionary keys of length
    /// ≥ 6 (single-token only) where `abs(token.count - key.count) <= 2`.
    ///
    /// Phase 27 D-01 defense-in-depth: each candidate must pass BOTH (a) the
    /// common-word allowlist veto (D-01a) and (b) the Levenshtein ratio cap
    /// (D-01b, D-03) before a replacement fires.
    ///
    /// Length-prefilter ≥ 6 is mandatory: distance-2 matches against short tokens
    /// (e.g. `the`/`she`) catastrophically false-positive. Multi-word keys are
    /// skipped — the exact-match regex pass handles those.
    private func applyFuzzyPassWithTrace(_ text: String) -> (text: String, replacements: [Replacement], blocked: [BlockedMatch]) {
        // Phase 27 WR-01: sort candidates lexicographically to make
        // fuzzy-match outcomes deterministic across launches. Dictionary key
        // iteration order is unspecified in Swift, so a token with two distinct
        // keys within distance ≤ 2 (one passing the ratio cap, one blocked)
        // could otherwise produce different outputs across runs depending on
        // which key the hash table happened to surface first. Lexicographic
        // sort is the simplest stable order; no quality signal is encoded.
        let candidateKeys = dictionary.keys
            .filter { $0.count >= 6 && !$0.contains(" ") }
            .sorted()
        if candidateKeys.isEmpty { return (text, [], []) }

        var replacements: [Replacement] = []
        var blocked: [BlockedMatch] = []

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
                    let r = fuzzyReplaceTokenWithTrace(current, candidates: candidateKeys)
                    result.append(r.0)
                    if let rep = r.1 { replacements.append(rep) }
                    if let blk = r.2 { blocked.append(blk) }
                    current = ""
                }
                result.append(ch)
            }
        }
        if !current.isEmpty {
            let r = fuzzyReplaceTokenWithTrace(current, candidates: candidateKeys)
            result.append(r.0)
            if let rep = r.1 { replacements.append(rep) }
            if let blk = r.2 { blocked.append(blk) }
        }
        return (result, replacements, blocked)
    }

    /// Phase 27 D-01 fuzzy-pass guard. Returns the (possibly replaced) token
    /// plus an optional `Replacement` (when a candidate fires) or an optional
    /// `BlockedMatch` (when a candidate would have hit pre-guard but is now
    /// rejected by either Guard A or Guard B). At most one of the optionals is
    /// non-nil per call.
    private func fuzzyReplaceTokenWithTrace(_ token: String, candidates: [String]) -> (String, Replacement?, BlockedMatch?) {
        guard token.count >= 6 else { return (token, nil, nil) }
        // Phase 27 WR-03: NFC-normalize before allowlist lookup. The allowlist
        // is loaded NFC (loadCommonWords), and ASR may emit NFD-decomposed
        // German diacritics. Without symmetric normalization the Set<String>
        // contains check would silently miss on ä/ö/ü/ß tokens — exactly the
        // inputs Guard A is built to protect.
        let lowered = token.lowercased().precomposedStringWithCanonicalMapping

        // Guard A (D-01a, D-04): allowlist veto. Common English/German words
        // never become fuzzy candidates regardless of distance.
        if commonWords.contains(lowered) {
            return (token, nil, nil)
        }

        for key in candidates {
            guard abs(token.count - key.count) <= 2 else { continue }
            let keyLowered = key.lowercased()
            // Skip identity — already handled by exact-match pass.
            if lowered == keyLowered { return (token, nil, nil) }

            let ratio = LevenshteinDistance.normalizedDistance(lowered, keyLowered)
            if ratio <= Self.fuzzyRatioCap {
                // Guard B passes — fire the replacement.
                let to = dictionary[key]?.replacement ?? token
                // Skip trace emission when the replacement produces no visible
                // change (the exact-match pass already produced the final form).
                if to == token {
                    return (token, nil, nil)
                }
                return (to, Replacement(key: key, from: token, to: to), nil)
            } else if LevenshteinDistance.distance(lowered, keyLowered) <= 2 {
                // Would have hit pre-guard; record as blocked for telemetry.
                let to = dictionary[key]?.replacement ?? token
                return (token, nil, BlockedMatch(key: key, from: token, to: to, ratio: ratio))
            }
        }
        return (token, nil, nil)
    }
}
