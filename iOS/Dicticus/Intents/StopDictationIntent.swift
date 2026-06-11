import AppIntents
import Foundation
#if DEBUG
import os
private let diagLog = Logger(subsystem: "com.dicticus.diag", category: "StopDictationIntent")
#endif

extension Notification.Name {
    static let stopDictation = Notification.Name("com.dicticus.stopDictation")
}

struct StopDictationIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Stop Dictation"
    static let description = IntentDescription("Stop current dictation in Dicticus")

    @MainActor
    func perform() async throws -> some IntentResult {
        #if DEBUG
        let proc = ProcessInfo.processInfo.processName
        let bundle = Bundle.main.bundleIdentifier ?? "unknown"
        diagLog.debug("[StopDictationIntent.perform] process=\(proc, privacy: .public) bundle=\(bundle, privacy: .public)")
        #endif
        NotificationCenter.default.post(name: .stopDictation, object: nil)
        return .result()
    }
}
