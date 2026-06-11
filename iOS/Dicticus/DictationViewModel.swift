import SwiftUI
@preconcurrency import ActivityKit
import UIKit
@preconcurrency import AVFAudio
import UserNotifications

@MainActor
class DictationViewModel: ObservableObject {
    enum State: Equatable {
        case idle
        case preparingLiveActivity
        case recording
        case transcribing
    }

    @Published var state: State = .idle {
        didSet {
            // Publish isRecording flag to App Group defaults so DictateIntent
            // can toggle-to-stop without opening the app a second time (D-01a).
            let isRecording = state == .recording
            DicticusIPCBridge.defaults?.set(isRecording, forKey: DicticusIPCBridge.Key.isRecording)
        }
    }
    @Published var lastResult: String?
    @Published var error: String?
    @Published var isShortcutLaunch: Bool = false

    // Soft-cap intervals — injectable so unit tests can use tiny values (D-03).
    var capFinalizeSeconds: Double = 300  // 5:00 — auto-finalize
    var capWarningSeconds: Double = 270   // 4:30 — pre-cap warning


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

    // MARK: - Test seams (36-04)

    /// Test seam for backgrounded-state detection. Defaults to the real UIKit check.
    /// Injected in unit tests to avoid depending on real app lifecycle (UIApplication
    /// is not available in the test host without a running UIApplication).
    var isBackgroundedProvider: () -> Bool = {
        UIApplication.shared.applicationState != .active
    }

    /// Test seam for clipboard writes. Defaults to UIPasteboard.general.
    /// Injected in unit tests to assert "no clipboard write" without touching the real pasteboard.
    var clipboardWriter: (String) -> Void = { text in
        UIPasteboard.general.string = text
    }

    /// Test seam for notification posting. Defaults to the real UNUserNotificationCenter.
    /// Injected in unit tests to capture title/body without OS notification infrastructure.
    var notificationPoster: (_ title: String, _ body: String) async -> Void = { title, body in
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: "transcriptReady-\(UUID().uuidString)",
            content: content,
            trigger: nil  // deliver immediately
        )
        try? await UNUserNotificationCenter.current().add(request)
    }

    nonisolated(unsafe) private var currentActivity: Activity<DictationAttributes>?
    nonisolated(unsafe) private var notificationObservers: [NSObjectProtocol] = []
    private var finalizeBackgroundTask: UIBackgroundTaskIdentifier = .invalid
    private var capWarningTask: Task<Void, Never>?
    private var capFinalizeTask: Task<Void, Never>?

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

        // iOS 18 AudioRecordingIntent requires an active Live Activity when a background
        // audio session is active (confirmed by spike run 1 fatal crash without one).
        // The Live Activity uses startedAt:Date + Text(timerInterval:) for a widget-autonomous
        // elapsed timer that ticks without app-driven activity.update() calls.
        state = .recording
        do {
            // Persist start time so a freshly-launched process can detect a stale cap
            // and finalize-on-relaunch if the recording exceeded the cap while backgrounded (ADDENDUM B).
            DicticusIPCBridge.defaults?.set(Date().timeIntervalSince1970,
                                            forKey: DicticusIPCBridge.Key.recordingStartedAt)
            try startLiveActivity()
            try transcriptionService?.startRecording()
            startCapTimers()
            await requestNotificationAuthorizationIfNeeded()
        } catch {
            await endLiveActivity()
            self.error = error.localizedDescription
            state = .idle
        }
    }

    func stopDictation() async {
        guard state == .recording else { return }
        cancelCapTimers()
        state = .transcribing

        // Determine whether we are backgrounded BEFORE any async work.
        // isBackgroundedProvider is injectable for unit tests (avoids UIApplication dependency).
        let isBackgrounded = isBackgroundedProvider()

        do {
            guard let result = try await transcriptionService?.stopRecordingAndTranscribe() else {
                await endLiveActivity()
                // Clear stale recordingStartedAt since recording ended
                DicticusIPCBridge.defaults?.removeObject(forKey: DicticusIPCBridge.Key.recordingStartedAt)
                state = .idle
                return
            }

            if isBackgrounded {
                // BACKGROUND PATH (SPIKE constraints 1+2 / IOSBG-02):
                // - NEVER run GPU/Metal (LLM cleanup) — kIOGPUCommandBufferCallbackErrorBackgroundExecutionNotPermitted
                // - NEVER write UIPasteboard — iOS hard-blocks backgrounded clipboard writes
                // Force .plain so TextProcessingService runs only Dictionary→ITN (CPU, allowed).
                // The entry is saved by TextProcessingService.process() itself.
                let processor = TextProcessingService(cleanupService: nil)
                _ = await processor.process(
                    text: result.text,
                    language: result.language,
                    mode: .plain,
                    confidence: Double(result.confidence)
                )

                // Tag the most-recent persisted entry as pending so foreground delivery can find it.
                // TextProcessingService.process() calls HistoryService.save() internally and then
                // HistoryService.load() — the new entry is now at .entries.first (createdAt DESC).
                // We query the most-recent UUID here because process() doesn't surface the UUID.
                // This is a deliberate trade-off to avoid invasive changes to process() signature.
                if let uuid = HistoryService.shared.entries.first?.uuid {
                    DicticusIPCBridge.defaults?.set(uuid.uuidString,
                                                    forKey: DicticusIPCBridge.Key.pendingTranscriptUUID)
                }

                // Post away-stop notification (D-02a) — only on background path.
                // Body contains NO transcript text (T-36-08 / security).
                await notificationPoster("Dictation ready",
                                         "Recording stopped — your transcript is waiting. Tap to open Dicticus.")

            } else {
                // FOREGROUND PATH — unchanged from 36-02:
                // Toggle-respecting mode, TextProcessingService.process() (saves entry), clipboard write.
                let wantsAiCleanup = (UserDefaults(suiteName: "group.com.dicticus") ?? .standard).bool(forKey: "aiCleanupEnabled")
                let llmReady = cleanupService?.isLoaded ?? false
                let mode: DictationMode = Self.selectMode(wantsAiCleanup: wantsAiCleanup, llmReady: llmReady)

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

                clipboardWriter(cleaned)
                lastResult = cleaned
                // Do NOT tag pendingTranscriptUUID — foreground delivery is inline.
            }
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
        DicticusIPCBridge.defaults?.removeObject(forKey: DicticusIPCBridge.Key.recordingStartedAt)
        state = .idle
    }

    /// Finalize a recording that was stopped from a background context (e.g. StopDictationIntent
    /// invoked from the Live Activity). Wraps stopDictation() in a background task so the
    /// async transcribe tail completes before iOS suspends the process.
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

    /// Testable seam for cleanup mode selection (D-13 / D-23 gating).
    static func selectMode(wantsAiCleanup: Bool, llmReady: Bool) -> DictationMode {
        return (wantsAiCleanup && llmReady) ? .aiCleanup : .plain
    }

    // MARK: - Soft-cap timers (D-03)

    func startCapTimers() {
        cancelCapTimers()
        capWarningTask = Task { @MainActor [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: .seconds(capWarningSeconds))
            guard !Task.isCancelled else { return }
            // Warning is best-effort foreground-only: activity.update() is blocked in
            // background audio mode (RESEARCH Pitfall 4). The auto-finalize at 5:00
            // is the load-bearing bound; the warning fires if the app is in foreground.
            if UIApplication.shared.applicationState == .active {
                self.error = "Recording will auto-stop soon (5-minute limit)."
            }
        }
        capFinalizeTask = Task { @MainActor [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: .seconds(capFinalizeSeconds))
            guard !Task.isCancelled else { return }
            await self.stopDictation()
        }
    }

    private func cancelCapTimers() {
        capWarningTask?.cancel()
        capWarningTask = nil
        capFinalizeTask?.cancel()
        capFinalizeTask = nil
    }

    private func startLiveActivity() throws {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        // ADDENDUM A: Reconcile orphaned Live Activities before requesting a new one.
        // Without this, a mid-recording termination leaves a permanent phantom "Recording…"
        // banner — the orphan's Stop button can't dismiss it because the new process has
        // no reference in `currentActivity`. Each new startLiveActivity() would stack
        // another duplicate, making lock-screen unrecoverable.
        reconcileOrphanedActivities()

        let startedAt = Date.now
        // staleDate backstop: if the app dies mid-recording the system auto-marks the
        // activity stale after cap + generous slack (ADDENDUM A — system-side safety net).
        let staleDate = startedAt.addingTimeInterval(capFinalizeSeconds + 60)
        currentActivity = try Activity.request(
            attributes: DictationAttributes(),
            content: ActivityContent(
                state: DictationAttributes.ContentState(isRecording: true, startedAt: startedAt),
                staleDate: staleDate
            ),
            pushType: nil
        )
    }

    private func endLiveActivity() async {
        await currentActivity?.end(
            ActivityContent(
                state: DictationAttributes.ContentState(isRecording: false, startedAt: Date.now),
                staleDate: nil
            ),
            dismissalPolicy: .after(.now + 3)
        )
        currentActivity = nil
    }

    /// Reconcile orphaned Live Activities (ADDENDUM A).
    /// Called on launch (from DicticusApp) and before each new recording to prevent
    /// phantom "Recording…" banners from a previous process that terminated mid-recording.
    func reconcileOrphanedActivities() {
        for activity in Activity<DictationAttributes>.activities {
            // An activity is orphaned if it's not backed by this process's currentActivity.
            // Any activity other than currentActivity is either a stale orphan or a
            // ghost from a prior process — end it immediately.
            if activity.id != currentActivity?.id {
                Task {
                    await activity.end(
                        ActivityContent(
                            state: DictationAttributes.ContentState(isRecording: false, startedAt: Date.now),
                            staleDate: nil
                        ),
                        dismissalPolicy: .immediate
                    )
                }
            }
        }
    }

    // MARK: - Foreground deferred delivery (D-02 / D-02b / D-05)

    /// Deliver the most-recent pending transcript (persisted while backgrounded) on foreground.
    /// Called from DicticusApp when scenePhase transitions to .active.
    ///
    /// Design: TextProcessingService.process() would create a DUPLICATE History row if called here.
    /// Instead, we run cleanup directly on the already-persisted entry's text and update the
    /// clipboard + lastResult without touching HistoryService — no duplicate, no data loss.
    func deliverPendingTranscriptsIfNeeded() async {
        guard let uuidString = DicticusIPCBridge.defaults?.string(forKey: DicticusIPCBridge.Key.pendingTranscriptUUID),
              !uuidString.isEmpty,
              let uuid = UUID(uuidString: uuidString) else {
            return  // No pending — common foreground-stop case delivered inline.
        }

        // Fetch the matching History entry (most-recent pending from the background stop).
        // D-05: only the most-recent is auto-delivered; others remain queryable in History.
        guard let entry = HistoryService.shared.entries.first(where: { $0.uuid == uuid }) else {
            // Entry not found (shouldn't happen) — clear the stale tag and return.
            DicticusIPCBridge.defaults?.removeObject(forKey: DicticusIPCBridge.Key.pendingTranscriptUUID)
            return
        }

        // Show processing state while cleanup runs (D-02b).
        state = .transcribing

        // Run cleanup respecting the toggle. Because the background entry was persisted as
        // plain text, we call cleanup directly rather than process() to avoid a duplicate row.
        let wantsAiCleanup = (UserDefaults(suiteName: "group.com.dicticus") ?? .standard).bool(forKey: "aiCleanupEnabled")
        let llmReady = cleanupService?.isLoaded ?? false

        let delivered: String
        if wantsAiCleanup && llmReady, let cs = cleanupService {
            // Run AI cleanup on the plain entry text (Dictionary+ITN was already applied backgrounded).
            delivered = await cs.cleanup(
                text: entry.text,
                language: entry.language,
                dictionaryContext: nil
            )
        } else {
            delivered = entry.text
        }

        // Write to clipboard and show ready to paste.
        clipboardWriter(delivered)
        lastResult = delivered
        error = nil

        // Clear the pending tag — delivery is complete.
        DicticusIPCBridge.defaults?.removeObject(forKey: DicticusIPCBridge.Key.pendingTranscriptUUID)

        state = .idle
    }

    // MARK: - Notification (D-02a)

    /// Post an away-stop "transcript ready" notification.
    /// Called only on the background path of stopDictation() — NOT when stopping from inside the app.
    /// Body contains NO transcript text (T-36-08 — information disclosure mitigation).
    /// This default implementation delegates to the `notificationPoster` seam so unit tests
    /// can capture title/body without OS notification infrastructure.
    private func postTranscriptReadyNotification() async {
        await notificationPoster(
            "Dictation ready",
            "Recording stopped — your transcript is waiting. Tap to open Dicticus."
        )
    }

    /// Request notification authorization just-in-time with .provisional (silent, no blocking dialog).
    /// Called from startDictation() so authorization is sought without blocking the capture/persist/deliver path.
    /// A denied/undetermined permission MUST NOT prevent persistence or foreground delivery.
    private func requestNotificationAuthorizationIfNeeded() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else { return }
        // .provisional delivers silently to Notification Center; no alert dialog shown to user.
        try? await center.requestAuthorization(options: [.alert, .sound, .provisional])
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
