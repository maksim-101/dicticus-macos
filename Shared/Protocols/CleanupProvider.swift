import Foundation

@MainActor
public protocol CleanupProvider: Sendable {
    var isLoaded: Bool { get }
    func cleanup(text: String, language: String, dictionaryContext: [String: String]?) async -> String
}
