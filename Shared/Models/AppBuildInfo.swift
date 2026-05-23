import Foundation

enum AppBuildInfo {
    static var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
    }

    static var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
    }

    static var gitCommit: String? {
        Bundle.main.infoDictionary?["GitCommit"] as? String
    }

    static var buildDate: String? {
        Bundle.main.infoDictionary?["BuildDate"] as? String
    }

    static var displayVersion: String {
        var s = "Dicticus v\(version) (build \(build))"
        if let hash = gitCommit {
            s += " · \(hash)"
        }
        return s
    }

    static let recentChanges: [String] = [
        "Fixed: \"twenty five\" now correctly converts to 25",
        "New: \"X dash/hyphen Y\" converts to X-Y",
        "New: \"X point Y\" converts to X.Y",
        "Fixed: German \"doch\"/\"oder\" no longer falsely removed",
        "Fixed: \"versus\" no longer replaced with \"Vercel\"",
    ]
}
