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

    // Set by DicticusApp once warmup completes (property injection)
    var transcriptionService: IOSTranscriptionService?

    nonisolated(unsafe) private var currentActivity: Activity<DictationAttributes>?
    private var notificationObserver: NSObjectProtocol?

    func startDictation() async {
        guard state == .idle else { return }

        // STEP 0: Request microphone permission
        let permissionGranted = await AVAudioApplication.requestRecordPermission()
        guard permissionGranted else {
            self.error = "Microphone access denied. Enable in Settings > Privacy > Microphone."
            return
        }

        state = .preparingLiveActivity

        // STEP 1: Live Activity MUST start before AVAudioSession
        do {
            try startLiveActivity()
        } catch {
            // Non-fatal: Live Activities may be disabled by user — still attempt recording
        }

        // STEP 2: Activate AVAudioSession + start recording (inside IOSTranscriptionService)
        state = .recording
        do {
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
            if let result = try await transcriptionService?.stopRecordingAndTranscribe() {
                UIPasteboard.general.string = result.text
                lastResult = result.text
                error = nil // Clear any previous error on success
                
                // Save to History
                let entry = TranscriptionEntry(
                    text: result.text,
                    rawText: result.text, // iOS v2.0 doesn't distinguish raw vs processed in this pipeline yet
                    language: result.language,
                    mode: DictationMode.plain.rawValue,
                    confidence: Double(result.confidence)
                )
                HistoryService.shared.save(entry)
            }
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
        notificationObserver = NotificationCenter.default.addObserver(
            forName: .startDictation,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.startDictation()
            }
        }
    }

    deinit {
        // Since deinit is called on an unknown thread, we use NotificationCenter.default.removeObserver directly
        // However, notificationObserver is an NSObjectProtocol which is thread-safe to remove.
        // But the deinit might not be on @MainActor.
        // Actually, non-isolated deinit is fine for this.
    }
}
