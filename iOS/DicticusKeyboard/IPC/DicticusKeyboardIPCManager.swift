import Foundation

/// Keyboard extension side of the Darwin IPC bridge.
///
/// Sends commands TO the main app (start/stop/cancel recording) via Darwin notifications,
/// and receives state updates FROM the main app (recordingStarted, transcribingStarted,
/// transcriptionReady, noSpeech) via Darwin notification observers.
///
/// Data (transcription text, recording state) is exchanged via App Group UserDefaults;
/// Darwin notifications are pure signals that carry no payload.
@MainActor
final class DicticusKeyboardIPCManager {

    // MARK: - State Callbacks (set by DicticusKeyboardDictationController)

    var onRecordingStarted: (() -> Void)?
    var onTranscribingStarted: (() -> Void)?
    var onTranscriptionReady: ((String) -> Void)?
    var onNoSpeech: (() -> Void)?

    // MARK: - Commands TO App

    func sendStartCommand() {
        DicticusIPCBridge.setRecordingState(.waitingForApp)
        DicticusIPCBridge.postDarwinNotification(named: DicticusIPCBridge.Notification.startRecording)
    }

    func sendStopCommand() {
        DicticusIPCBridge.setRecordingState(.transcribing)
        DicticusIPCBridge.postDarwinNotification(named: DicticusIPCBridge.Notification.stopRecording)
    }

    func sendCancelCommand() {
        DicticusIPCBridge.clearTransientOperationState()
        DicticusIPCBridge.setRecordingState(.idle)
        DicticusIPCBridge.postDarwinNotification(named: DicticusIPCBridge.Notification.cancelRecording)
    }

    // MARK: - State Queries

    func isSessionWarm() -> Bool {
        DicticusIPCBridge.isSessionWarm()
    }

    func currentRecordingState() -> DicticusIPCBridge.RecordingState {
        DicticusIPCBridge.currentRecordingState()
    }

    func latestTranscription() -> String? {
        DicticusIPCBridge.latestTranscription()
    }

    // MARK: - Stale State Reconciliation

    /// Detects and clears stale IPC state left by crashed or killed app sessions.
    ///
    /// - `waitingForApp` older than 5 seconds is considered abandoned.
    /// - `recording`/`transcribing` without a fresh heartbeat means the app crashed.
    ///
    /// Called on keyboard appear and before each mic tap to ensure a clean starting state.
    func reconcileStaleSharedStateIfNeeded() -> DicticusIPCBridge.RecordingState {
        let state = currentRecordingState()
        switch state {
        case .idle:
            return .idle

        case .waitingForApp:
            // Stale after 5 seconds -- app never responded
            if let age = DicticusIPCBridge.currentRecordingStateAge(), age > 5 {
                DicticusIPCBridge.clearTransientOperationState()
                return .idle
            }
            return .waitingForApp

        case .recording, .transcribing:
            // Only valid if app's heartbeat is fresh
            guard isSessionWarm() else {
                DicticusIPCBridge.clearTransientOperationState()
                return .idle
            }
            return state
        }
    }

    // MARK: - Darwin Notification Registration

    func registerObservers() {
        registerDarwinObserver(named: DicticusIPCBridge.Notification.recordingStarted)
        registerDarwinObserver(named: DicticusIPCBridge.Notification.transcribingStarted)
        registerDarwinObserver(named: DicticusIPCBridge.Notification.transcriptionReady)
        registerDarwinObserver(named: DicticusIPCBridge.Notification.noSpeech)
    }

    func unregisterObservers() {
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        CFNotificationCenterRemoveEveryObserver(center, Unmanaged.passUnretained(self).toOpaque())
    }

    private func registerDarwinObserver(named name: String) {
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        CFNotificationCenterAddObserver(
            center,
            Unmanaged.passUnretained(self).toOpaque(),
            DicticusKeyboardIPCManager.darwinCallback,
            name as CFString,
            nil,
            .deliverImmediately
        )
    }

    // MARK: - Darwin Callback (C bridge)

    /// Static C-function callback for Darwin notification center.
    /// Bridges from the C callback to the instance method via Unmanaged pointer,
    /// dispatching to main queue for thread safety.
    nonisolated private static let darwinCallback: CFNotificationCallback = {
        _, observer, name, _, _ in
        guard let observer, let rawName = name?.rawValue as String? else { return }
        let manager = Unmanaged<DicticusKeyboardIPCManager>.fromOpaque(observer).takeUnretainedValue()
        DispatchQueue.main.async {
            manager.handleNotification(named: rawName)
        }
    }

    private func handleNotification(named name: String) {
        switch name {
        case DicticusIPCBridge.Notification.recordingStarted:
            onRecordingStarted?()

        case DicticusIPCBridge.Notification.transcribingStarted:
            onTranscribingStarted?()

        case DicticusIPCBridge.Notification.transcriptionReady:
            // Read transcription text from shared UserDefaults
            guard let text = latestTranscription(), !text.isEmpty else {
                onNoSpeech?()
                return
            }
            onTranscriptionReady?(text)

        case DicticusIPCBridge.Notification.noSpeech:
            onNoSpeech?()

        default:
            break
        }
    }

    deinit {
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        CFNotificationCenterRemoveEveryObserver(center, Unmanaged.passUnretained(self).toOpaque())
    }
}
