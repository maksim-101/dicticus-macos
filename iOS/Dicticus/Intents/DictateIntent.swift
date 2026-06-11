import AppIntents
import Foundation
#if DEBUG
import os
private let diagLog = Logger(subsystem: "com.dicticus.diag", category: "DictateIntent")
#endif

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
        // Action-Button toggle-to-stop (D-01a): if already recording, this
        // press stops; otherwise it starts. The isRecording flag is written by
        // DictationViewModel on every state change via App Group defaults.
        // Note: the stop branch still brings the app forward (AudioRecordingIntent
        // openAppWhenRun:true) — the lock-screen Live Activity Stop is the true
        // no-reopen stop surface.
        let isRecording = DicticusIPCBridge.defaults?.bool(forKey: "isRecording") ?? false
        #if DEBUG
        let proc = ProcessInfo.processInfo.processName
        let bundle = Bundle.main.bundleIdentifier ?? "unknown"
        diagLog.debug("[DictateIntent.perform] process=\(proc, privacy: .public) bundle=\(bundle, privacy: .public) isRecording=\(isRecording, privacy: .public) → branch=\(isRecording ? "stop" : "start", privacy: .public)")
        #endif
        if isRecording {
            NotificationCenter.default.post(name: .stopDictation, object: nil)
        } else {
            DicticusIPCBridge.defaults?.set(true, forKey: "pendingDictation")
            DicticusIPCBridge.defaults?.set(true, forKey: "isShortcutLaunch")
            NotificationCenter.default.post(name: .startDictation, object: nil)
        }
        return .result()
    }
}
