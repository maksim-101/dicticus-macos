import SwiftUI
import FluidAudio

/// Manages FluidAudio initialization and Parakeet TDT v3 CoreML warm-up state.
///
/// Called once at app launch to trigger background CoreML model compilation and download.
/// First-launch download is ~2.69 GB (Parakeet CoreML package) plus ~1.8 MB (Silero VAD).
/// CoreML encoder compilation takes ~3.4 s on first run; subsequent launches use cached
/// compilation and are fast (~162 ms warm load).
///
/// Threat T-02.1-03: Compilation runs on Task.detached(priority: .utility) to avoid
/// blocking the main thread. [weak self] prevents retain cycles on app quit.
/// Threat T-02.1-02: Audio samples are never persisted; only held in memory during
/// a single recording session.
@MainActor
class ModelWarmupService: ObservableObject {
    @Published var isWarming = false
    @Published var isReady = false
    @Published var error: String?

    private var asrManager: AsrManager?
    private var vadManager: VadManager?

    /// Reference to the in-flight warmup Task for cancellation support.
    private var warmupTask: Task<Void, Never>?

    /// Reference to the timeout watchdog Task — cancelled when warmup succeeds
    /// to avoid a 600-second sleeping Task lingering after fast warm loads (~162 ms).
    private var watchdogTask: Task<Void, Never>?

    /// Maximum time (seconds) to wait for model download/compilation before failing.
    /// 10-minute ceiling covers first-launch ~2.69 GB Parakeet CoreML download on slower hardware
    /// and initial CoreML compilation.
    private let warmupTimeoutSeconds: UInt64 = 600

    /// Whether the warm-up row should be visible in the dropdown.
    /// True while loading (isWarming) or when loading failed (error != nil).
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

    /// Start FluidAudio + Parakeet TDT v3 initialization in a background Task.
    ///
    /// Per D-08: called immediately at app launch, not on first hotkey press.
    /// Downloads and compiles Parakeet TDT v3 CoreML models from HuggingFace on first launch
    /// via AsrModels.downloadAndLoad(). Also initializes Silero VAD via VadManager.
    /// Subsequent launches use cached CoreML compilation and are fast.
    ///
    /// Guard prevents duplicate calls — safe to call multiple times.
    func warmup() {
        guard !isWarming && !isReady else { return }
        isWarming = true
        error = nil

        warmupTask = Task.detached(priority: .utility) { [weak self] in
            do {
                // Step 1: Download + load Parakeet TDT v3 CoreML models from HuggingFace.
                // First run downloads ~2.69 GB; subsequent runs use cached CoreML package.
                // AsrModels.downloadAndLoad handles caching, progress, and CoreML compilation.
                let models = try await AsrModels.downloadAndLoad(version: .v3)

                // Step 2: Create actor-based AsrManager and load models into it.
                // CoreML encoder compilation takes ~3.4 s on first run, ~162 ms on warm loads.
                // AsrManager is an actor — all subsequent calls require await.
                let manager = AsrManager(config: .default)
                try await manager.loadModels(models)

                // Step 3: Initialize Silero VAD v6 CoreML model (~1.8 MB).
                // VadManager provides frame-based voice activity detection to filter silence.
                // Initialized alongside ASR models to ensure VAD is ready for first transcription.
                let vad = try await VadManager(config: VadConfig(defaultThreshold: 0.75))

                try Task.checkCancellation()

                await MainActor.run {
                    self?.asrManager = manager
                    self?.vadManager = vad
                    self?.isWarming = false
                    self?.isReady = true
                    self?.watchdogTask?.cancel()
                    self?.watchdogTask = nil
                }
            } catch is CancellationError {
                await MainActor.run {
                    self?.isWarming = false
                    self?.error = "Model load timed out or was cancelled. Restart app."
                    self?.watchdogTask?.cancel()
                    self?.watchdogTask = nil
                }
            } catch {
                await MainActor.run {
                    self?.isWarming = false
                    self?.error = "Model load failed. Restart app."
                    self?.watchdogTask?.cancel()
                    self?.watchdogTask = nil
                }
            }
        }

        // Timeout watchdog — cancels warmupTask if download/compilation hangs (e.g. network
        // failure during first-launch HuggingFace download). Runs separately to avoid Swift 6
        // Sendable issues with FluidAudio actors in task groups.
        // Stored in watchdogTask so it can be cancelled when warmup succeeds (avoids a
        // 600-second sleeping Task lingering after fast warm loads).
        watchdogTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: (self?.warmupTimeoutSeconds ?? 600) * 1_000_000_000)
            guard let self else { return }
            if self.isWarming {
                self.cancelWarmup()
            }
        }
    }

    /// Cancel an in-flight warmup task.
    /// Immediately resets isWarming to false for responsive UI feedback.
    /// The guard in warmup() then passes again (isWarming == false, isReady == false),
    /// so calling warmup() again will retry. The task's CancellationError handler
    /// becomes a no-op since isWarming is already false.
    func cancelWarmup() {
        warmupTask?.cancel()
        warmupTask = nil
        isWarming = false
    }

    /// Expose the initialized AsrManager for TranscriptionService.
    /// Returns nil until warm-up completes. TranscriptionService consumes this instance
    /// directly to avoid redundant initialization.
    var asrManagerInstance: AsrManager? {
        asrManager
    }

    /// Expose the initialized VadManager for TranscriptionService.
    /// Returns nil until warm-up completes. VadManager provides Silero VAD v6 for
    /// voice activity detection during transcription.
    var vadManagerInstance: VadManager? {
        vadManager
    }
}
