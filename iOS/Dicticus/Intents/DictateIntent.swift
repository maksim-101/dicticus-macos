import AppIntents
import Foundation
import os

extension Notification.Name {
    static let startDictation = Notification.Name("com.dicticus.startDictation")
}

struct DictateIntent: AudioRecordingIntent {
    static let title: LocalizedStringResource = "Start Dictation"
    static let description = IntentDescription("Begin dictating in Dicticus")

    @available(*, deprecated)
    static let openAppWhenRun: Bool = true

    // SPIKE: subsystem log for D-04 intent-invoke → mic-start latency (plan 36-01)
    private static let spikeLog = OSLog(subsystem: "com.dicticus.spike", category: "intent")

    @MainActor
    func perform() async throws -> some IntentResult {
        // SPIKE: entry timestamp so Console.app can measure intent-invoke → startRecording() delta
        os_log("DictateIntent.perform() entry — t=%{public}.3f", log: Self.spikeLog, type: .info, Date().timeIntervalSinceReferenceDate)
        DicticusIPCBridge.defaults?.set(true, forKey: "pendingDictation")
        DicticusIPCBridge.defaults?.set(true, forKey: "isShortcutLaunch")
        NotificationCenter.default.post(name: .startDictation, object: nil)
        return .result()
    }
}
