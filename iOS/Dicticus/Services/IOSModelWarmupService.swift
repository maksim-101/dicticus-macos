import SwiftUI
import FluidAudio
import os.log

/// Manages FluidAudio initialization and Parakeet TDT v3 CoreML warm-up state for iOS.
///
/// iOS v2.0 focuses on plain dictation; AI cleanup (LLM) is excluded to reduce memory pressure
/// and binary footprint on mobile hardware (D- تصمیم taken in STATE.md).
@MainActor
class IOSModelWarmupService: ObservableObject {

    // MARK: - LLM warmup status (D-12)

    /// LLM warmup lifecycle state, observed by Settings UI (Wave 4).
    ///
    /// iOS omits `.downloading` because the GGUF download is driven by
    /// Settings UI (D-09/D-10), not by warmup. If the GGUF is absent when
    /// Step 4 runs, Step 4 simply remains `.idle` and defers to the
    /// user-initiated download flow.
    public enum LlmStatus: Equatable {
        case idle
        case loading
        case ready
        case failed(String)

        public var label: String {
            switch self {
            case .idle:                return "Waiting"
            case .loading:             return "Loading model\u{2026}"
            case .ready:               return "Ready"
            case .failed(let reason):  return reason
            }
        }

        public var isActive: Bool { self == .loading }
    }

    // MARK: - Device eligibility (D-03)

    /// Per D-03: AI cleanup requires ≥5 GB RAM to safely coexist with the
    /// ~2.7 GB Parakeet ASR model. iPhone 12/13 (4 GB A14) are below this
    /// threshold; iPhone 14+ (6 GB) meet it.
    /// `nonisolated` so SettingsView (and any other call site, including
    /// non-main contexts) can read it without actor hops.
    public nonisolated static let requiredPhysicalMemoryBytes: UInt64 = 5 * 1024 * 1024 * 1024

    /// Whether the current device meets the RAM requirement for AI cleanup.
    /// Read at launch by `SettingsView` to decide between showing the AI
    /// Cleanup toggle or a device-unsupported explainer.
    public nonisolated static var isAiCleanupSupported: Bool {
        ProcessInfo.processInfo.physicalMemory >= requiredPhysicalMemoryBytes
    }

    @Published var isWarming = false
    @Published var isReady = false
    @Published var hasModels = false
    @Published var downloadProgress: Double = 0.0
    @Published var downloadStatus: String = ""
    @Published var error: String?

    // MARK: - LLM state (Wave 3, D-12)

    /// Whether the LLM (Gemma 4 E2B) is loaded and ready for inference.
    /// Consumed by `DictationViewModel` (Wave 4) to decide whether to route
    /// transcripts through `TextProcessingService` for AI cleanup.
    @Published public private(set) var isLlmReady: Bool = false

    /// Current LLM warmup lifecycle state — observed by Settings UI (Wave 4).
    @Published public private(set) var llmStatus: LlmStatus = .idle

    private var asrManager: AsrManager?
    private var vadManager: VadManager?

    /// llama.cpp-backed cleanup service instance — populated by Step 4 on success.
    /// Exposed via `cleanupServiceInstance` for `DictationViewModel` injection.
    private var cleanupService: CleanupService?

    /// Expose the initialized CleanupService for DictationViewModel (Wave 4).
    /// Returns nil until Step 4 (LLM warmup) completes successfully.
    public var cleanupServiceInstance: CleanupService? {
        cleanupService
    }

    /// File-scoped static token that triggers `CleanupService.initializeBackend()`
    /// exactly once per app lifetime (D-29). Referenced from `init(...)` so the
    /// backend is initialized on first `IOSModelWarmupService` creation without
    /// requiring an app-delegate hook. Swift guarantees once-only evaluation of
    /// static let initializers (thread-safe, lazy).
    private static let backendInitToken: Void = {
        CleanupService.initializeBackend()
    }()

    /// Reference to the in-flight warmup Task for cancellation support.
    private var warmupTask: Task<Void, Never>?

    /// Reference to the timeout watchdog Task.
    private var watchdogTask: Task<Void, Never>?

    /// Maximum time (seconds) to wait for model download/compilation before failing.
    private let warmupTimeoutSeconds: UInt64 = 600

    init() {
        // Fire the once-only static backend init (D-29). `_ =` ensures the
        // compiler doesn't elide the reference; Swift evaluates `backendInitToken`
        // on first touch and caches the result for subsequent instances.
        _ = IOSModelWarmupService.backendInitToken
        checkHasModels()
    }

    /// Check if models are already downloaded.
    func checkHasModels() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        guard let base = appSupport else {
            hasModels = false
            return
        }
        // FluidAudio stores models in Application Support / FluidAudio / Models / <repo-name>
        let modelDir = base.appendingPathComponent("FluidAudio/Models/parakeet-tdt-0.6b-v3-coreml")
        let preprocessor = modelDir.appendingPathComponent("Preprocessor.mlmodelc")
        
        let exists = FileManager.default.fileExists(atPath: preprocessor.path)
        print("Checking model at: \(preprocessor.path) - Exists: \(exists)")
        hasModels = exists
    }

    /// Start FluidAudio + Parakeet TDT v3 initialization in a background Task.
    func warmup() {
        guard !isWarming && !isReady else { return }
        isWarming = true
        error = nil
        downloadProgress = 0.0
        downloadStatus = "Step 1/3: Initializing models..."

        let progressTimer = startProgressTimer()

        warmupTask = Task.detached(priority: .utility) { [weak self] in
            do {
                // Step 1: Download + load Parakeet TDT v3 CoreML models from HuggingFace.
                await MainActor.run { self?.downloadStatus = "Step 2/3: Downloading ASR Weights (2.7GB)..." }
                let models = try await AsrModels.downloadAndLoad(version: .v3)

                // Step 2: Create actor-based AsrManager and load models into it.
                await MainActor.run { self?.downloadStatus = "Step 3/3: Compiling for Neural Engine..." }
                let manager = AsrManager(config: .default)
                try await manager.loadModels(models)

                // Step 3: Initialize Silero VAD v6 CoreML model.
                let vad = try await VadManager(config: VadConfig(
                    defaultThreshold: Float(IOSTranscriptionService.vadProbabilityThreshold)
                ))

                try Task.checkCancellation()

                await MainActor.run {
                    progressTimer.cancel()
                    self?.downloadProgress = 1.0
                    self?.downloadStatus = "Ready"
                    self?.asrManager = manager
                    self?.vadManager = vad
                    self?.isWarming = false
                    self?.isReady = true
                    self?.hasModels = true
                    self?.watchdogTask?.cancel()
                    self?.watchdogTask = nil
                }

                // Step 4: LLM warmup (D-12). Conditional on AI Cleanup toggle + RAM gate + GGUF cache.
                // Download is triggered by Settings UI (D-09/D-10), NOT by warmup. If the GGUF
                // is not yet cached, Step 4 skips silently and `llmStatus` remains `.idle`.
                //
                // Critical ordering: Step 3's MainActor.run above publishes `isReady = true`
                // BEFORE this block starts, so ASR is usable even if Step 4 fails — plain
                // dictation never blocks on LLM availability (graceful degradation, D-26).
                try Task.checkCancellation()

                let warmupLog = Logger(subsystem: "com.dicticus", category: "warmup")

                // Read AppGroup-scoped toggle (matches SettingsView.appGroupBinding suite).
                let appGroupDefaults = UserDefaults(suiteName: "group.com.dicticus") ?? UserDefaults.standard
                let aiCleanupEnabled = appGroupDefaults.bool(forKey: "aiCleanupEnabled")
                let hasEnoughRam = IOSModelWarmupService.isAiCleanupSupported  // D-03
                let isCached = IOSModelDownloadService.isModelCached()

                guard aiCleanupEnabled, hasEnoughRam, isCached else {
                    warmupLog.info("Step 4 skipped — aiCleanupEnabled=\(aiCleanupEnabled, privacy: .public), hasEnoughRam=\(hasEnoughRam, privacy: .public), isCached=\(isCached, privacy: .public)")
                    return  // Leaves llmStatus = .idle, isLlmReady = false — safe default
                }

                do {
                    await MainActor.run { self?.llmStatus = .loading }

                    let modelPath = IOSModelDownloadService.modelPath().path
                    // CleanupService is @MainActor; construct + load on the main actor.
                    // `MainActor.run` is the actor-hop primitive; its throwing overload
                    // lets us propagate loadModel errors without a second hop.
                    let cleanup: CleanupService = try await MainActor.run { () throws -> CleanupService in
                        let service = CleanupService(inferenceTimeoutSeconds: 8.0)  // D-04 iOS timeout
                        try service.loadModel(from: modelPath)
                        return service
                    }

                    await MainActor.run {
                        self?.cleanupService = cleanup
                        self?.isLlmReady = true
                        self?.llmStatus = .ready
                    }
                    warmupLog.info("Step 4 complete — LLM loaded and ready")
                } catch is CancellationError {
                    throw CancellationError()
                } catch {
                    warmupLog.error("Step 4 failed: \(error.localizedDescription, privacy: .public)")
                    await MainActor.run {
                        self?.llmStatus = .failed("AI cleanup unavailable")
                        self?.isLlmReady = false
                    }
                    // Do NOT re-throw — ASR already published readiness; plain dictation still works.
                }
            } catch is CancellationError {
                await MainActor.run {
                    progressTimer.cancel()
                    self?.isWarming = false
                    self?.error = "Model load timed out or was cancelled."
                    self?.watchdogTask?.cancel()
                    self?.watchdogTask = nil
                }
            } catch {
                await MainActor.run {
                    progressTimer.cancel()
                    self?.isWarming = false
                    self?.error = "Model load failed: \(error.localizedDescription)"
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

    /// Reset error state and retry warmup.
    func retry() {
        error = nil
        isReady = false
        warmup()
    }

    /// Expose the initialized AsrManager for IOSTranscriptionService.
    var asrManagerInstance: AsrManager? {
        asrManager
    }

    /// Expose the initialized VadManager for IOSTranscriptionService.
    var vadManagerInstance: VadManager? {
        vadManager
    }

    private func startProgressTimer() -> Task<Void, Never> {
        Task {
            // Simulated progress: 0 to 0.9 over 90 seconds
            for i in 1...90 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if Task.isCancelled { return }
                await MainActor.run {
                    self.downloadProgress = Double(i) * 0.01
                }
            }
        }
    }
}
