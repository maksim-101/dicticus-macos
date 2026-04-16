import SwiftUI
import WhisperKit

/// Manages WhisperKit initialization and CoreML warm-up state.
///
/// Called once at app launch (D-03) to trigger background CoreML model compilation.
/// First-launch compilation can take 2-10+ minutes (Research Pitfall 2).
/// Subsequent launches use cached compilation and are fast.
///
/// Threat T-03-02: Compilation runs on Task.detached(priority: .utility) to avoid
/// blocking the main thread. [weak self] prevents retain cycles on app quit.
@MainActor
class ModelWarmupService: ObservableObject {
    @Published var isWarming = false
    @Published var isReady = false
    @Published var error: String?

    private var whisperKit: WhisperKit?

    /// Reference to the in-flight warmup Task for cancellation support (WR-05).
    private var warmupTask: Task<Void, Never>?

    /// Maximum time (seconds) to wait for model download/compilation before failing.
    /// 10-minute ceiling covers first-launch CoreML compilation on slower hardware.
    private let warmupTimeoutSeconds: UInt64 = 600

    /// Whether the warm-up row should be visible in the dropdown.
    /// True while compiling (isWarming) or when compilation failed (error != nil).
    /// False when ready — row disappears entirely per UI-SPEC.
    var showWarmupRow: Bool {
        isWarming || error != nil
    }

    /// Status text for the dropdown warm-up row.
    /// Returns nil when ready (row is hidden). Returns error string on failure.
    var statusText: String? {
        if isWarming {
            return "Preparing models\u{2026}"  // "Preparing models…" — ellipsis character (UI-SPEC copywriting)
        } else if let error = error {
            return error
        }
        return nil
    }

    /// Start WhisperKit initialization in a background Task.
    ///
    /// Per D-03: called immediately at app launch, not on first hotkey press.
    /// WhisperKit downloads the model from HuggingFace on first launch and compiles
    /// CoreML graphs for the device hardware. This can take 2-10+ minutes on first run.
    /// Subsequent launches use cached compilation and are fast (Research Pitfall 2).
    ///
    /// Guard prevents duplicate calls — safe to call multiple times.
    func warmup() {
        guard !isWarming && !isReady else { return }
        isWarming = true
        error = nil

        warmupTask = Task.detached(priority: .utility) { [weak self] in
            do {
                // WR-05: Race the WhisperKit init against a timeout to prevent indefinite blocking
                // on network failure (first-launch HuggingFace download).
                let pipe = try await withThrowingTaskGroup(of: WhisperKit.self) { group in
                    let timeoutSeconds = await self?.warmupTimeoutSeconds ?? 600

                    // Child 1: Actual WhisperKit initialization
                    group.addTask {
                        // D-08: Pin large-v3-turbo explicitly for predictable quality.
                        // D-09: WhisperKit handles download/caching via HuggingFace Hub automatically.
                        // Model identifier "large-v3-turbo" resolves via glob match to
                        // openai_whisper-large-v3_turbo in the argmaxinc/whisperkit-coreml repo (Pitfall 5).
                        return try await WhisperKit(
                            WhisperKitConfig(
                                model: "large-v3-turbo",  // D-08: Pin model explicitly for predictable quality
                                verbose: false,
                                logLevel: .error          // Reduce console noise in production
                            )
                        )
                    }

                    // Child 2: Timeout watchdog
                    group.addTask {
                        try await Task.sleep(nanoseconds: timeoutSeconds * 1_000_000_000)
                        throw CancellationError()
                    }

                    // First to finish wins; cancel the other
                    guard let result = try await group.next() else {
                        throw CancellationError()
                    }
                    group.cancelAll()
                    return result
                }

                try Task.checkCancellation()

                await MainActor.run {
                    self?.whisperKit = pipe
                    self?.isWarming = false
                    self?.isReady = true
                }
            } catch is CancellationError {
                await MainActor.run {
                    self?.isWarming = false
                    self?.error = "Model load timed out or was cancelled. Restart app."
                }
            } catch {
                await MainActor.run {
                    self?.isWarming = false
                    // Error message matches UI-SPEC copywriting contract exactly
                    self?.error = "Model load failed. Restart app."
                }
            }
        }
    }

    /// Cancel an in-flight warmup task (WR-05).
    /// After cancellation, the guard in warmup() passes again (isWarming == false, isReady == false),
    /// so calling warmup() again will retry.
    func cancelWarmup() {
        warmupTask?.cancel()
        warmupTask = nil
    }

    /// Expose the initialized WhisperKit instance for Phase 2 ASR pipeline.
    /// Returns nil until warm-up completes. Phase 2 will consume this instance
    /// directly to avoid redundant initialization.
    var whisperKitInstance: WhisperKit? {
        whisperKit
    }
}
