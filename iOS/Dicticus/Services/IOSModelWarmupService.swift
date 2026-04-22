import SwiftUI
import FluidAudio
import os.log

/// Manages FluidAudio initialization and Parakeet TDT v3 CoreML warm-up state for iOS.
///
/// iOS v2.0 focuses on plain dictation; AI cleanup (LLM) is excluded to reduce memory pressure
/// and binary footprint on mobile hardware (D- تصمیم taken in STATE.md).
@MainActor
class IOSModelWarmupService: ObservableObject {
    @Published var isWarming = false
    @Published var isReady = false
    @Published var hasModels = false
    @Published var error: String?

    private var asrManager: AsrManager?
    private var vadManager: VadManager?

    /// Reference to the in-flight warmup Task for cancellation support.
    private var warmupTask: Task<Void, Never>?

    /// Reference to the timeout watchdog Task.
    private var watchdogTask: Task<Void, Never>?

    /// Maximum time (seconds) to wait for model download/compilation before failing.
    private let warmupTimeoutSeconds: UInt64 = 600

    init() {
        checkHasModels()
    }

    /// Check if models are already downloaded.
    func checkHasModels() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        guard let base = appSupport else {
            hasModels = false
            return
        }
        let fluidAudioModels = base.appendingPathComponent("FluidAudio/Models")
        // If the directory exists and is not empty, we assume models are present
        let contents = try? FileManager.default.contentsOfDirectory(atPath: fluidAudioModels.path)
        hasModels = contents?.isEmpty == false
    }

    /// Start FluidAudio + Parakeet TDT v3 initialization in a background Task.
    func warmup() {
        guard !isWarming && !isReady else { return }
        isWarming = true
        error = nil

        warmupTask = Task.detached(priority: .utility) { [weak self] in
            do {
                // Step 1: Download + load Parakeet TDT v3 CoreML models from HuggingFace.
                let models = try await AsrModels.downloadAndLoad(version: .v3)

                // Step 2: Create actor-based AsrManager and load models into it.
                let manager = AsrManager(config: .default)
                try await manager.loadModels(models)

                // Step 3: Initialize Silero VAD v6 CoreML model.
                let vad = try await VadManager(config: VadConfig(
                    defaultThreshold: Float(IOSTranscriptionService.vadProbabilityThreshold)
                ))

                try Task.checkCancellation()

                await MainActor.run {
                    self?.asrManager = manager
                    self?.vadManager = vad
                    self?.isWarming = false
                    self?.isReady = true
                    self?.watchdogTask?.cancel()
                    self?.watchdogTask = nil
                }
                
                // NOTE: No Step 4 (LLM) on iOS v2.0 — locked decision
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

        watchdogTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: (self?.warmupTimeoutSeconds ?? 600) * 1_000_000_000)
            guard let self else { return }
            if self.isWarming {
                self.cancelWarmup()
            }
        }
    }

    /// Cancel an in-flight warmup task.
    func cancelWarmup() {
        warmupTask?.cancel()
        warmupTask = nil
        isWarming = false
    }

    /// Expose the initialized AsrManager for IOSTranscriptionService.
    var asrManagerInstance: AsrManager? {
        asrManager
    }

    /// Expose the initialized VadManager for IOSTranscriptionService.
    var vadManagerInstance: VadManager? {
        vadManager
    }
}
