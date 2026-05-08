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
    private func purgeRetiredDefaults() {
        let retired: [String] = [
            "1m", "1 m", "I m", "one m", "One m",
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
            "Zyria": "ZüriA", "Versal": "Vercel", "Acara": "Aqara", "engine X": "NGINX", 
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
            "GSD": "GSD", "gest": "GSD", "GST": "GSD", "cheers": "GSD", "G.S.D.": "GSD", "gsd": "GSD"
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
        
        return result
    }
}
