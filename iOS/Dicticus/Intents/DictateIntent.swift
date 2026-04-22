import AppIntents
import Foundation

extension Notification.Name {
    static let startDictation = Notification.Name("com.dicticus.startDictation")
}

struct DictateIntent: AudioRecordingIntent {
    static let title: LocalizedStringResource = "Start Dictation"
    static let description = IntentDescription("Begin dictating in Dicticus")

    @available(*, deprecated)
    static let openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        NotificationCenter.default.post(name: .startDictation, object: nil)
        return .result()
    }
}
