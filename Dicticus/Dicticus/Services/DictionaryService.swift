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
            UserDefaults.standard.set(isCaseSensitive, forKey: Self.caseSensitiveKey)
        }
    }

    /// Shared instance for use in TextProcessingService and DictionaryView.
    static let shared = DictionaryService()

    private init() {
        self.isCaseSensitive = UserDefaults.standard.bool(forKey: Self.caseSensitiveKey)
        load()
        
        // Migrate old data if it exists and new data is empty
        if dictionary.isEmpty {
            migrateOldFormat()
        }
        
        // If still empty, prepopulate defaults
        if dictionary.isEmpty {
            prepopulateWithDefaults()
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
            ".cloud": ".claude", "Cloud Code": "Claude Code", "1m": "I'm", "1 m": "I'm",
            "I m": "I'm", "one m": "I'm", "One m": "I'm"
        ]

        
        for (original, replacement) in defaults {
            if dictionary[original] == nil {
                dictionary[original] = DictionaryMetadata(replacement: replacement, createdAt: Date())
            }
        }
        save()
    }

    func load() {
        if let data = UserDefaults.standard.data(forKey: Self.dictionaryKey),
           let stored = try? JSONDecoder().decode([String: DictionaryMetadata].self, from: data) {
            dictionary = stored
        }
    }

    func save() {
        if let data = try? JSONEncoder().encode(dictionary) {
            UserDefaults.standard.set(data, forKey: Self.dictionaryKey)
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
