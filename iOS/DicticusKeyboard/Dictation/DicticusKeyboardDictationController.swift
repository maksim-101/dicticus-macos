import Foundation
import os.log

private let logger = Logger(subsystem: "com.dicticus.ios.keyboard", category: "dictation")

/// State machine for keyboard dictation, following KeyVox's `KeyboardDictationController` pattern.
///
/// Manages the lifecycle of a dictation session triggered from the keyboard extension:
/// - Detects warm sessions (app alive with fresh heartbeat) vs cold starts (app not running)
/// - Warm start: sends Darwin notification directly to app
/// - Cold start: opens app via URL scheme, app launches and starts recording
/// - Grace period (0.5s): if warm-start notification is not acknowledged, falls back to URL launch
/// - Waiting timeout (5s): resets to idle if app never responds
///
/// The `state` property is `@Published` so SwiftUI views can observe changes.
@MainActor
final class DicticusKeyboardDictationController: ObservableObject {

    enum State: Equatable {
        case idle
        case waitingForApp
        case recording
        case transcribing
    }

    @Published private(set) var state: State = .idle

    let ipcManager = DicticusKeyboardIPCManager()

    /// Set by KeyboardViewController -- used for cold start URL opening via responder chain.
    var openURL: ((URL) -> Void)?

    /// Set by KeyboardViewController -- called when transcription text is ready for insertion
    /// via `textDocumentProxy.insertText()`.
    var onTranscriptionReady: ((String) -> Void)?

    private let startRecordingURL = URL(string: "dicticus://record/start")!
    private let waitingTimeoutDuration: TimeInterval = 5
    private let warmSessionGracePeriod: TimeInterval = 0.5

    private var waitingForAppTimeoutAction: DispatchWorkItem?
    private var gracePeriodAction: DispatchWorkItem?

    // MARK: - Lifecycle

    func setup() {
        ipcManager.onRecordingStarted = { [weak self] in
            guard let self else { return }
            self.cancelGracePeriod()
            self.cancelWaitingTimeout()
            self.state = .recording
            logger.info("State -> recording (app confirmed)")
        }

        ipcManager.onTranscribingStarted = { [weak self] in
            self?.state = .transcribing
            logger.info("State -> transcribing")
        }

        ipcManager.onTranscriptionReady = { [weak self] text in
            guard let self else { return }
            self.onTranscriptionReady?(text)
            self.state = .idle
            logger.info("Transcription received: \(text.prefix(50))")
        }

        ipcManager.onNoSpeech = { [weak self] in
            self?.state = .idle
            logger.info("No speech detected -- reset to idle")
        }

        ipcManager.registerObservers()

        // Reconcile stale state on keyboard appear (crash recovery)
        let reconciled = ipcManager.reconcileStaleSharedStateIfNeeded()
        if reconciled != .idle {
            logger.info("Reconciled stale state: \(String(describing: reconciled))")
        }
    }

    // MARK: - User Actions

    func handleMicTap() {
        // Reconcile stale state before acting
        _ = ipcManager.reconcileStaleSharedStateIfNeeded()

        switch state {
        case .idle:
            state = .waitingForApp
            scheduleWaitingTimeout()

            if ipcManager.isSessionWarm() {
                // App is alive -- send command directly via Darwin notification
                ipcManager.sendStartCommand()
                scheduleWarmSessionGracePeriod()
                logger.info("Warm start -- sent Darwin startRecording")
            } else {
                // App not running -- launch it via URL scheme
                openURL?(startRecordingURL)
                logger.info("Cold start -- opening app via URL scheme")
            }

        case .recording:
            state = .transcribing
            ipcManager.sendStopCommand()
            logger.info("Stop recording -- sent Darwin stopRecording")

        case .waitingForApp, .transcribing:
            // Ignore taps during transitions
            break
        }
    }

    func handleCancelTap() {
        cancelWaitingTimeout()
        cancelGracePeriod()
        ipcManager.sendCancelCommand()
        state = .idle
        logger.info("Cancelled -- reset to idle")
    }

    func teardown() {
        cancelWaitingTimeout()
        cancelGracePeriod()
        ipcManager.unregisterObservers()
    }

    // MARK: - Timeouts

    /// Resets to idle if the app doesn't start recording within 5 seconds.
    private func scheduleWaitingTimeout() {
        cancelWaitingTimeout()
        let item = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                guard let self, self.state == .waitingForApp else { return }
                self.state = .idle
                logger.info("Waiting timeout -- reset to idle")
            }
        }
        waitingForAppTimeoutAction = item
        DispatchQueue.main.asyncAfter(deadline: .now() + waitingTimeoutDuration, execute: item)
    }

    private func cancelWaitingTimeout() {
        waitingForAppTimeoutAction?.cancel()
        waitingForAppTimeoutAction = nil
    }

    /// On warm start, if app doesn't confirm recordingStarted within 0.5s, falls back to URL launch.
    private func scheduleWarmSessionGracePeriod() {
        cancelGracePeriod()
        let item = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                guard let self, self.state == .waitingForApp else { return }
                // App didn't respond in time -- fall back to URL launch
                guard self.ipcManager.currentRecordingState() != .recording else { return }
                self.openURL?(self.startRecordingURL)
                logger.info("Grace period expired -- falling back to URL launch")
            }
        }
        gracePeriodAction = item
        DispatchQueue.main.asyncAfter(deadline: .now() + warmSessionGracePeriod, execute: item)
    }

    private func cancelGracePeriod() {
        gracePeriodAction?.cancel()
        gracePeriodAction = nil
    }
}
