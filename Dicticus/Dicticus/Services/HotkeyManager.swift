import SwiftUI
import KeyboardShortcuts
import Combine

/// Dictation mode — determines which pipeline processes the transcription.
/// Per D-12: Both registered in Phase 3. Per D-13: AI cleanup is a no-op stub.
enum DictationMode: String, Sendable, CaseIterable {
    case plain
    case aiCleanup  // Wired to LLM pipeline in Phase 4
}

/// Push-to-talk state machine coordinating hotkey events, TranscriptionService, and TextInjector.
///
/// Per D-01: Hold hotkey starts recording, release triggers transcription and paste.
/// Per D-03: Key repeat suppressed via isKeyDown flag.
/// Per D-12/D-13: AI cleanup hotkey registered but silently ignored.
/// Per D-18: Recording continues across app switches — text pastes into frontmost app on release.
/// Per D-19: Reject second hotkey while transcribing.
@MainActor
class HotkeyManager: ObservableObject {

    enum PipelineState {
        case idle
        case recording
        case transcribing
        case cleaning
    }

    /// Overall pipeline state combining recording, transcribing, and cleaning.
    @Published var pipelineState: PipelineState = .idle

    /// True while actively recording (keyDown received, keyUp not yet received).
    /// Kept for internal logic, but UI observes pipelineState.
    @Published var isRecording = false

    /// Tracks whether the last notification was a specific type, for testability.
    /// Not used in production UI — exists to verify notification posting in tests.
    @Published var lastPostedNotification: DicticusNotification?

    /// Last successful transcription text for display in menu bar dropdown (D-21).
    /// Returns nil when no transcription has occurred in this session.
    var lastTranscriptionText: String? {
        transcriptionService?.lastResult?.text
    }

    /// D-03: Suppress key repeat — ignore keyDown when already down.
    private var isKeyDown = false

    /// Weak reference to TranscriptionService — set via setup().
    private weak var transcriptionService: TranscriptionService?

    /// Reference to ModelWarmupService to check isReady before recording.
    private weak var warmupService: ModelWarmupService?

    /// Reference to TextProcessingService for dictionary, ITN, and AI cleanup pipeline.
    /// Set via setup() after warmup completes.
    var textProcessingService: TextProcessingService?

    /// Reference to CleanupService for AI cleanup mode (D-11).
    /// Set via setup() after warmup completes, or later when LLM finishes loading.
    /// Weak to avoid retain cycle.
    weak var cleanupService: CleanupService? {
        didSet { bindState() }
    }

    private var cancellables = Set<AnyCancellable>()

    /// TextInjector for clipboard-based text injection.
    /// Isolated to @MainActor via HotkeyManager's own isolation.
    private let textInjector = TextInjector()

    /// Reference to ModifierHotkeyListener — set via setupModifierListener().
    /// Retains the listener for the app lifetime; closures route events to push-to-talk state machine.
    private var modifierListener: ModifierHotkeyListener?

    /// Configure the manager with required service references and start listening for hotkey events.
    ///
    /// Must be called after TranscriptionService is created (after warmup completes).
    /// Safe to call multiple times — KeyboardShortcuts.events(for:) creates new async streams.
    func setup(
        transcriptionService: TranscriptionService,
        warmupService: ModelWarmupService,
        textProcessingService: TextProcessingService
    ) {
        self.transcriptionService = transcriptionService
        self.warmupService = warmupService
        self.textProcessingService = textProcessingService
        self.cleanupService = warmupService.cleanupServiceInstance

        bindState()

        // D-12: Register plain dictation hotkey with full push-to-talk.
        // Task inherits @MainActor isolation from the enclosing @MainActor class.
        Task { [weak self] in
            for await event in KeyboardShortcuts.events(for: .plainDictation) {
                guard let self else { return }
                switch event {
                case .keyDown:
                    self.handleKeyDown(mode: .plain)
                case .keyUp:
                    self.handleKeyUp(mode: .plain)
                }
            }
        }

        // D-11: AI cleanup hotkey — full ASR + LLM cleanup + paste pipeline
        Task { [weak self] in
            for await event in KeyboardShortcuts.events(for: .aiCleanup) {
                guard let self else { return }
                switch event {
                case .keyDown:
                    self.handleKeyDown(mode: .aiCleanup)
                case .keyUp:
                    self.handleKeyUp(mode: .aiCleanup)
                }
            }
        }

        // Request notification permission on setup
        NotificationService.shared.setup()
    }

    /// Wire ModifierHotkeyListener into the push-to-talk state machine and start the CGEventTap.
    ///
    /// Called after ASR warmup completes (same point as setup()) so modifier hotkeys only
    /// activate when the app is ready to record. The listener's CGEventTap events are routed
    /// directly into handleKeyDown/handleKeyUp — identical pipeline to KeyboardShortcuts combos.
    ///
    /// Per D-08: modifier listener runs in parallel with KeyboardShortcuts (not replacing it).
    func setupModifierListener(_ listener: ModifierHotkeyListener) {
        self.modifierListener = listener
        listener.onComboActivated = { [weak self] mode in
            self?.handleKeyDown(mode: mode)
        }
        listener.onComboReleased = { [weak self] mode in
            self?.handleKeyUp(mode: mode)
        }
        listener.start()
    }

    private func bindState() {
        cancellables.removeAll()
        guard let ts = transcriptionService else { return }
        
        let tsPub = ts.$state
        let csPub = cleanupService?.$state.eraseToAnyPublisher() ?? Just(.idle).eraseToAnyPublisher()
        
        Publishers.CombineLatest3($isRecording, tsPub, csPub)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isRec, tsState, csState in
                if isRec || tsState == .recording { self?.pipelineState = .recording }
                else if tsState == .transcribing { self?.pipelineState = .transcribing }
                else if csState == .cleaning { self?.pipelineState = .cleaning }
                else { self?.pipelineState = .idle }
            }
            .store(in: &cancellables)
    }

    /// Handle hotkey key-down event — start recording if conditions met.
    ///
    /// Per D-03: Suppresses key repeat via isKeyDown guard.
    /// Per D-17: Shows notification if models not ready.
    /// Per D-19: Shows notification if already transcribing.
    func handleKeyDown(mode: DictationMode) {
        // D-03: Suppress key repeat
        guard !isKeyDown else { return }
        isKeyDown = true

        // D-17: Model not ready check
        guard let warmupService, warmupService.isReady else {
            let notification = DicticusNotification.modelLoading
            lastPostedNotification = notification
            NotificationService.shared.post(notification)
            isKeyDown = false  // Reset so next press can try again
            return
        }

        // D-20: Check LLM readiness for AI cleanup mode
        if mode == .aiCleanup {
            guard let cleanupService, cleanupService.isLoaded else {
                let notification = DicticusNotification.llmLoading
                lastPostedNotification = notification
                NotificationService.shared.post(notification)
                isKeyDown = false
                return
            }
        }

        guard let service = transcriptionService else {
            isKeyDown = false
            return
        }

        // D-19: Reject while transcribing
        guard service.state == .idle else {
            let notification = DicticusNotification.busy
            lastPostedNotification = notification
            NotificationService.shared.post(notification)
            isKeyDown = false  // Reset so next press can try again
            return
        }

        do {
            try service.startRecording()
            isRecording = true
        } catch {
            let notification = DicticusNotification.recordingFailed(error)
            lastPostedNotification = notification
            NotificationService.shared.post(notification)
            isKeyDown = false
        }
    }

    /// Handle hotkey key-up event — stop recording, transcribe, and inject text.
    ///
    /// Per D-01: Release triggers transcription and paste.
    /// Per D-02: Short presses (<0.3s) silently discarded (TranscriptionError.tooShort).
    /// Per D-16: Silence-only recordings silently discarded.
    func handleKeyUp(mode: DictationMode) {
        guard isKeyDown else { return }
        isKeyDown = false

        guard let service = transcriptionService,
              service.state == .recording else {
            isRecording = false
            return
        }

        isRecording = false

        // Task inherits @MainActor isolation from the enclosing @MainActor class,
        // so self.textInjector access is safe without crossing isolation boundaries.
        Task { [weak self] in
            guard let self else { return }
            do {
                let result = try await service.stopRecordingAndTranscribe()

                // Delegate processing to TextProcessingService (TEXT-03)
                // Flow: Dictionary -> ITN -> [LLM Cleanup]
                let finalOutput = await self.textProcessingService?.process(
                    text: result.text,
                    language: result.language,
                    mode: mode,
                    confidence: Double(result.confidence)
                ) ?? result.text

                // D-06: Inject final processed text into the active app
                await self.textInjector.injectText(finalOutput)

            } catch is CancellationError {
                // Task cancelled — silent
            } catch let error as TranscriptionError {
                switch error {
                case .tooShort:
                    break  // D-02: Silent discard
                case .silenceOnly:
                    break  // D-16: No notification for silence
                case .unexpectedLanguage:
                    // Non-Latin script detected — notify user (not silent, user needs to know
                    // why text was not injected)
                    let notification = DicticusNotification.unexpectedLanguage
                    self.lastPostedNotification = notification
                    NotificationService.shared.post(notification)
                default:
                    let notification = DicticusNotification.transcriptionFailed(error)
                    self.lastPostedNotification = notification
                    NotificationService.shared.post(notification)
                }
            } catch {
                let notification = DicticusNotification.transcriptionFailed(error)
                self.lastPostedNotification = notification
                NotificationService.shared.post(notification)
            }
        }
    }
}
