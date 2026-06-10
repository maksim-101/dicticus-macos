import SwiftUI
@preconcurrency import ActivityKit
import UIKit
@preconcurrency import AVFAudio

@MainActor
class DictationViewModel: ObservableObject {
    enum State: Equatable {
        case idle
        case preparingLiveActivity
        case recording
        case transcribing
    }

    @Published var state: State = .idle
    @Published var lastResult: String?
    @Published var error: String?
    @Published var isShortcutLaunch: Bool = false


    // Set by DicticusApp once warmup completes (property injection)
    var transcriptionService: IOSTranscriptionService? {
        didSet {
            if transcriptionService != nil {
                error = nil
            }
            transcriptionService?.onSilenceDetected = { [weak self] in
                Task { @MainActor in
                    await self?.stopDictation()
                }
            }
            // Check for pending intent if service just became available
            if transcriptionService != nil {
                checkPendingIntent()
            }
        }
    }

    // Phase 19 Wave 5: CleanupService injection seam (CLEAN-01 / CLEAN-02).
    // Set by DicticusApp once warmup Step 4 completes (property injection).
    // When non-nil + AppGroup `aiCleanupEnabled` is true, stopDictation routes
    // through TextProcessingService with mode=.aiCleanup. Consumed lazily at
    // stopDictation() time, so no didSet hook is needed.
    var cleanupService: CleanupProvider?

    nonisolated(unsafe) private var currentActivity: Activity<DictationAttributes>?
    nonisolated(unsafe) private var notificationObservers: [NSObjectProtocol] = []
    private var finalizeBackgroundTask: UIBackgroundTaskIdentifier = .invalid

    func startDictation(fromShortcut: Bool = false) async {
        guard state == .idle else { return }
        isShortcutLaunch = fromShortcut

        // STEP 0: Ensure transcription service is available (model loaded)
        guard transcriptionService != nil else {
            self.error = "ASR model not loaded. Download it first."
            return
        }

        // STEP 1: Request microphone permission
        let permissionGranted = await AVAudioApplication.requestRecordPermission()
        guard permissionGranted else {
            self.error = "Microphone access denied. Enable in Settings > Privacy > Microphone."
            return
        }

        // The Live Activity was removed here. It implied dictation kept recording
        // after you leave the app, but with no `audio` background mode iOS suspends
        // the app and recording stops — so the activity (with a frozen 0s ticker) was
        // misleading. Interim behavior is finalize-on-background (see finalizeIfRecording).
        // FUTURE (background-recording phase): re-introduce the Live Activity together
        // with a real AVAudioSession-backed background capture + Stop control
        // (StopDictationIntent is already wired). See 33-HUMAN-UAT.md backlog.

        // SPIKE (36-01 re-test): iOS 18 AudioRecordingIntent fatal-errors if a background
        // audio session is active without a Live Activity. Start the existing (frozen-ticker)
        // Live Activity so the SIGKILL probe can run a clean background session AND the user
        // gets the Dynamic Island Stop control. Plan 02 supersedes this with the
        // ContentState startedAt:Date timer migration — keep this minimal.
        state = .recording
        do {
            try startLiveActivity()
            try transcriptionService?.startRecording()
        } catch {
            await endLiveActivity()
            self.error = error.localizedDescription
            state = .idle
        }
    }

    func stopDictation() async {
        guard state == .recording else { return }
        state = .transcribing

        do {
            guard let result = try await transcriptionService?.stopRecordingAndTranscribe() else {
                await endLiveActivity()
                state = .idle
                return
            }

            // Phase 19 Wave 5 — CLEAN-01 / CLEAN-02.
            // Determine pipeline mode: AI cleanup only if the user toggle is ON
            // AND a CleanupProvider has been injected AND the provider reports
            // loaded. This matches D-13/D-23 gating + graceful degradation
            // (D-26) when Step 4 LLM warmup has not completed yet.
            let appGroupDefaults = UserDefaults(suiteName: "group.com.dicticus") ?? UserDefaults.standard
            let wantsAiCleanup = appGroupDefaults.bool(forKey: "aiCleanupEnabled")
            let llmReady = cleanupService?.isLoaded ?? false
            let mode: DictationMode = (wantsAiCleanup && llmReady) ? .aiCleanup : .plain

            // Route through the shared pipeline:
            //   Dictionary -> ITN -> Swiss ITN -> [LLM cleanup] -> History.
            // TextProcessingService.process() itself saves the TranscriptionEntry
            // (Step 4 of the pipeline) so we MUST NOT call HistoryService here
            // or every dictation would create a duplicate row.
            let processor = TextProcessingService(cleanupService: cleanupService)
            let cleaned = await processor.process(
                text: result.text,
                language: result.language,
                mode: mode,
                confidence: Double(result.confidence)
            )

            UIPasteboard.general.string = cleaned
            lastResult = cleaned
            error = nil

        } catch let transcriptionError as TranscriptionError {
            switch transcriptionError {
            case .tooShort:
                self.error = "Recording too short."
            case .silenceOnly:
                self.error = "No speech detected."
            case .noResult:
                self.error = "Could not understand audio."
            case .unexpectedLanguage:
                self.error = "Unsupported language detected."
            case .modelNotReady:
                self.error = "Model not ready."
            case .busy:
                self.error = "System busy."
            case .notRecording:
                self.error = "Not recording."
            }
        } catch {
            self.error = error.localizedDescription
        }

        await endLiveActivity()
        state = .idle
    }

    /// Interim background behavior (option A). Without an `audio` background mode iOS
    /// suspends the app when it leaves the foreground, so an in-progress recording can't
    /// continue. Rather than leave a zombie recording, finalize what was captured —
    /// stop, transcribe, copy — guarded by a background task so the async transcribe +
    /// optional LLM cleanup completes before suspension.
    /// FUTURE (background-recording phase): replace this with keep-recording.
    func finalizeIfRecording() {
        guard state == .recording else { return }
        finalizeBackgroundTask = UIApplication.shared.beginBackgroundTask(withName: "FinalizeDictation") { [weak self] in
            self?.endFinalizeBackgroundTask()
        }
        Task { @MainActor in
            await stopDictation()
            endFinalizeBackgroundTask()
        }
    }

    private func endFinalizeBackgroundTask() {
        guard finalizeBackgroundTask != .invalid else { return }
        UIApplication.shared.endBackgroundTask(finalizeBackgroundTask)
        finalizeBackgroundTask = .invalid
    }

    // FUTURE (background-recording phase): not currently invoked — the Live Activity was
    // removed from startDictation() because it falsely implied background recording.
    private func startLiveActivity() throws {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        currentActivity = try Activity.request(
            attributes: DictationAttributes(),
            content: ActivityContent(
                state: DictationAttributes.ContentState(isRecording: true, elapsedSeconds: 0),
                staleDate: nil
            ),
            pushType: nil
        )
    }

    private func endLiveActivity() async {
        await currentActivity?.end(
            ActivityContent(
                state: DictationAttributes.ContentState(isRecording: false, elapsedSeconds: 0),
                staleDate: nil
            ),
            dismissalPolicy: .after(.now + 3)
        )
        currentActivity = nil
    }

    func setupNotificationObserver() {
        let startObserver = NotificationCenter.default.addObserver(
            forName: .startDictation,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.startDictation()
            }
        }
        notificationObservers.append(startObserver)

        let stopObserver = NotificationCenter.default.addObserver(
            forName: .stopDictation,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.stopDictation()
            }
        }
        notificationObservers.append(stopObserver)

        checkPendingIntent()
    }

    private func checkPendingIntent() {
        let shared = DicticusIPCBridge.defaults
        if shared?.bool(forKey: "pendingDictation") == true {
            shared?.set(false, forKey: "pendingDictation")
            let shortcut = shared?.bool(forKey: "isShortcutLaunch") ?? false
            shared?.set(false, forKey: "isShortcutLaunch")
            Task {
                try? await Task.sleep(nanoseconds: 500_000_000)
                await self.startDictation(fromShortcut: shortcut)
            }
        }
    }

    deinit {
        for observer in notificationObservers {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}
