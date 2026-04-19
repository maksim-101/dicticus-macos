import Foundation
import Combine

/// Manages a custom dictionary of find-replace pairs for dictation correction.
///
/// Per TEXT-02: User-defined replacements that correct recurring ASR errors.
/// Per User Feedback: Pre-populated with MacWhisper dictionary entries.
/// Per User Settings: Case-insensitive by default, matching only separate words.
///
/// Pairs are persisted in UserDefaults as a [String: String] dictionary.
@MainActor
class DictionaryService: ObservableObject {

    static let dictionaryKey = "customDictionary"

    /// The active dictionary of [Original: Replacement] pairs.
    @Published private(set) var dictionary: [String: String] = [:]

    /// Shared instance for use in TextProcessingService and DictionaryView.
    static let shared = DictionaryService()

    private init() {
        load()
        if dictionary.isEmpty {
            prepopulateWithDefaults()
        }
    }

    /// Pre-populate the dictionary with the user's provided MacWhisper entries.
    private func prepopulateWithDefaults() {
        let defaults: [String: String] = [
            "true nest": "TrueNAS", "clods.md": "Claude.MD", "DOC-G": "Dockge",
            "cloth desktop": "Claude Desktop", "medviki": "MedWiki", "matviki": "MedWiki",
            "add guard": "adguard", "trueness": "TrueNAS", "claw desktop": "Claude Desktop",
            "Cloud Desktop": "Claude Desktop", "cloud.md": "Claude.MD", "clot.md": "Claude.MD",
            "clod.md": "Claude.MD", "Swiss \"": "Swissquote", "dot cloud": ".claude",
            "Zyria": "ZüriA", "Versal": "Vercel", "Acara": "Aqara", "engine X": "NGINX",
            "docg": "Dockge", "true NAS": "TrueNAS", "tail scale": "Tailscale",
            "Telscale": "Tailscale", "light llm": "LiteLLM", "LightLLM": "LiteLLM",
            "doc G": "Dockge", "Clot": "Claude", ".clot": ".claude", "clot code": "Claude Code",
            ".cloud": ".claude", "Cloud Code": "Claude Code"
        ]
        dictionary = defaults
        save()
    }

    /// Load the dictionary from UserDefaults.
    func load() {
        if let stored = UserDefaults.standard.dictionary(forKey: Self.dictionaryKey) as? [String: String] {
            dictionary = stored
        }
    }

    /// Save the current dictionary to UserDefaults.
    func save() {
        UserDefaults.standard.set(dictionary, forKey: Self.dictionaryKey)
    }

    /// Add or update a replacement pair.
    func setReplacement(for original: String, with replacement: String) {
        let trimmedOriginal = original.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedOriginal.isEmpty else { return }
        dictionary[trimmedOriginal] = replacement.trimmingCharacters(in: .whitespacesAndNewlines)
        save()
    }

    /// Remove a replacement pair.
    func removeReplacement(for original: String) {
        dictionary.removeValue(forKey: original)
        save()
    }

    /// Remove all replacements.
    func removeAll() {
        dictionary.removeAll()
        save()
    }

    /// Apply dictionary replacements to the given text.
    ///
    /// Logic:
    /// 1. Case-insensitive matching (per MacWhisper screenshot).
    /// 2. Only replaces separate words using regex word boundaries (per MacWhisper screenshot).
    ///
    /// - Parameter text: The raw transcribed text.
    /// - Returns: The text with all dictionary replacements applied.
    func apply(to text: String) -> String {
        var result = text
        
        // Sort keys by length (descending) to prevent partial replacements 
        // (e.g., "cloth desktop" should be replaced before "cloth").
        let sortedKeys = dictionary.keys.sorted { $0.count > $1.count }
        
        for original in sortedKeys {
            guard let replacement = dictionary[original] else { continue }
            
            // Use regex for word-boundary matching and case-insensitivity.
            // NSRegularExpression handles the regex logic.
            // \b matches word boundaries. We escape the search string to handle punctuation.
            let pattern = "\\b\(NSRegularExpression.escapedPattern(for: original))\\b"
            
            do {
                let regex = try NSRegularExpression(pattern: pattern, options: .caseInsensitive)
                let range = NSRange(result.startIndex..<result.endIndex, in: result)
                result = regex.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: replacement)
            } catch {
                // Fallback to simple replacement if regex fails for some reason
                result = result.replacingOccurrences(of: original, with: replacement, options: [.caseInsensitive])
            }
        }
        
        return result
    }
}
