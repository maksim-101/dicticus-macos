import Foundation

/// Main app side of the Darwin notification IPC bridge.
///
/// Responsibilities:
/// 1. Listens for keyboard extension commands via Darwin notifications (start/stop/cancel recording)
/// 2. Publishes state updates back to keyboard via Darwin notifications + UserDefaults
/// 3. Runs a 1Hz heartbeat so keyboard can detect warm sessions via `DicticusIPCBridge.isSessionWarm()`
///
/// This file is compiled into the Dicticus main app target ONLY (not the keyboard extension).
/// The keyboard extension uses `DicticusKeyboardIPCManager` (to be created in a later plan).
@MainActor
final class DicticusHostBridge: ObservableObject {

    // MARK: - Callbacks (wired by DicticusApp to DictationViewModel)

    var onStartRecordingCommand: (() -> Void)?
    var onStopRecordingCommand: (() -> Void)?
    var onCancelRecordingCommand: (() -> Void)?

    private var heartbeatTimer: Timer?

    // MARK: - Lifecycle

    func registerObservers() {
        registerDarwinObserver(named: DicticusIPCBridge.Notification.startRecording)
        registerDarwinObserver(named: DicticusIPCBridge.Notification.stopRecording)
        registerDarwinObserver(named: DicticusIPCBridge.Notification.cancelRecording)
        DicticusIPCBridge.touchHeartbeat()
        startHeartbeatTimer()
    }

    func unregisterObservers() {
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        CFNotificationCenterRemoveEveryObserver(center, Unmanaged.passUnretained(self).toOpaque())
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
    }

    // MARK: - Publish State TO Keyboard

    func publishRecordingStarted() {
        DicticusIPCBridge.setRecordingState(.recording)
        DicticusIPCBridge.postDarwinNotification(named: DicticusIPCBridge.Notification.recordingStarted)
        DicticusIPCBridge.touchHeartbeat()
    }

    func publishTranscribing() {
        DicticusIPCBridge.setRecordingState(.transcribing)
        DicticusIPCBridge.postDarwinNotification(named: DicticusIPCBridge.Notification.transcribingStarted)
    }

    func publishTranscriptionReady(_ text: String) {
        DicticusIPCBridge.setTranscription(text)          // Write text FIRST
        DicticusIPCBridge.setRecordingState(.idle)
        DicticusIPCBridge.postDarwinNotification(named: DicticusIPCBridge.Notification.transcriptionReady)  // THEN signal
    }

    func publishNoSpeech() {
        DicticusIPCBridge.clearTransientOperationState()
        DicticusIPCBridge.setRecordingState(.idle)
        DicticusIPCBridge.postDarwinNotification(named: DicticusIPCBridge.Notification.noSpeech)
    }

    // MARK: - Heartbeat

    private func startHeartbeatTimer() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                _ = self  // prevent premature deallocation
                DicticusIPCBridge.touchHeartbeat()
            }
        }
    }

    // MARK: - Darwin Notification Observer

    private func registerDarwinObserver(named name: String) {
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        CFNotificationCenterAddObserver(
            center,
            Unmanaged.passUnretained(self).toOpaque(),
            DicticusHostBridge.darwinCallback,
            name as CFString,
            nil,
            .deliverImmediately
        )
    }

    /// Static C function callback required by CFNotificationCenter.
    /// Bridges Darwin notification to instance method on main queue.
    nonisolated private static let darwinCallback: CFNotificationCallback = {
        _, observer, name, _, _ in
        guard let observer, let rawName = name?.rawValue as String? else { return }
        let bridge = Unmanaged<DicticusHostBridge>.fromOpaque(observer).takeUnretainedValue()
        DispatchQueue.main.async {
            bridge.handleNotification(named: rawName)
        }
    }

    private func handleNotification(named name: String) {
        switch name {
        case DicticusIPCBridge.Notification.startRecording:
            onStartRecordingCommand?()
        case DicticusIPCBridge.Notification.stopRecording:
            onStopRecordingCommand?()
        case DicticusIPCBridge.Notification.cancelRecording:
            onCancelRecordingCommand?()
        default:
            break
        }
    }

    deinit {
        heartbeatTimer?.invalidate()
    }
}
