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
    ///
    /// Phase 20.06 UAT fix: delegate to `AsrModels.modelsExist(at:version:)` so the
    /// cache check stays in sync with FluidAudio's own storage layout. The previous
    /// implementation hardcoded `parakeet-tdt-0.6b-v3-coreml`, but the SDK's
    /// `Repo.parakeet.folderName` strips the `-coreml` suffix, so the manual path
    /// never matched and `hasModels` stayed false on every fresh launch — Settings
    /// then displayed "ASR Model Missing" while dictation worked because the warmup
    /// cache hit (microsecond) re-set the flag to true.
    func checkHasModels() {
        let cacheDir = AsrModels.defaultCacheDirectory(for: .v3)
        hasModels = AsrModels.modelsExist(at: cacheDir, version: .v3)
    }

    /// Start FluidAudio + Parakeet TDT v3 initialization in a background Task.
    /// Pass `force: true` from explicit user actions (Download / Retry button) so the
    /// download path is not blocked by the no-models guard.
    func warmup(force: Bool = false) {
        // D-D1 (Phase 19.5): Re-check FS on every warmup invocation to avoid
        // relying on stale init-time state after backgrounding / FS mutations.
        // The guard prevents auto-launch sites from silently kicking off a
        // ~2.7 GB download; explicit user actions bypass it via `force`.
        checkHasModels()
        guard hasModels || force else { return }
        guard !isWarming && !isReady else { return }
        isWarming = true
        error = nil
        downloadProgress = 0.0
        downloadStatus = "Step 1/3: Preparing download..."

        let warmupLog = Logger(subsystem: "com.dicticus", category: "warmup")
        let warmupStart = Date()
        warmupLog.info("warmup starting (force=\(force, privacy: .public), hasModels=\(self.hasModels, privacy: .public))")

        // FluidAudio progress callback — fires from a background queue, hop to MainActor
        // for @Published updates. Phase 20.06 hotfix: replaces the previous fake 1%-per-second
        // simulated timer that maxed out at 90% and gave no real signal.
        let progressHandler: DownloadUtils.ProgressHandler = { [weak self] progress in
            Task { @MainActor in
                guard let self else { return }
                let pct = progress.fractionCompleted
                switch progress.phase {
                case .listing:
                    self.downloadStatus = "Step 1/3: Listing model files..."
                case .downloading(let completed, let total):
                    self.downloadStatus = "Step 1/3: Downloading ASR weights (\(completed)/\(total) files, 2.7 GB total)"
                case .compiling(let modelName):
                    self.downloadStatus = "Step 2/3: Compiling \(modelName) for Neural Engine..."
                }
                self.downloadProgress = pct
            }
        }

        warmupTask = Task.detached(priority: .userInitiated) { [weak self] in
            do {
                // Step 1: Download + verify Parakeet TDT v3 CoreML models from HuggingFace.
                warmupLog.info("Step 1: AsrModels.downloadAndLoad starting")
                let models = try await AsrModels.downloadAndLoad(version: .v3, progressHandler: progressHandler)
                let step1Elapsed = Date().timeIntervalSince(warmupStart)
                warmupLog.info("Step 1: AsrModels.downloadAndLoad returned (elapsed=\(step1Elapsed, privacy: .public)s)")

                // Step 2: Create actor-based AsrManager and load models for ANE.
                await MainActor.run { self?.downloadStatus = "Step 2/3: Loading models into Neural Engine..." }
                warmupLog.info("Step 2: AsrManager.loadModels starting")
                let manager = AsrManager(config: .default)
                try await manager.loadModels(models)
                let step2Elapsed = Date().timeIntervalSince(warmupStart)
                warmupLog.info("Step 2: AsrManager.loadModels done (elapsed=\(step2Elapsed, privacy: .public)s)")

                // Step 3: Initialize Silero VAD v6 CoreML model.
                await MainActor.run { self?.downloadStatus = "Step 3/3: Initializing voice activity detector..." }
                warmupLog.info("Step 3: VadManager init starting")
                let vad = try await VadManager(config: VadConfig(
                    defaultThreshold: Float(IOSTranscriptionService.vadProbabilityThreshold)
                ))
                let step3Elapsed = Date().timeIntervalSince(warmupStart)
                warmupLog.info("Step 3: VadManager init done (elapsed=\(step3Elapsed, privacy: .public)s)")

                try Task.checkCancellation()

                await MainActor.run {
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
                warmupLog.info("ASR pipeline ready — UI unblocked")

                // Step 4: LLM warmup (D-12). Conditional on AI Cleanup toggle + RAM gate + GGUF cache.
                // Download is triggered by Settings UI (D-09/D-10), NOT by warmup. If the GGUF
                // is not yet cached, Step 4 skips silently and `llmStatus` remains `.idle`.
                //
                // Critical ordering: the MainActor.run above publishes `isReady = true` BEFORE
                // this block starts, so ASR is usable even if Step 4 fails — plain dictation
                // never blocks on LLM availability (graceful degradation, D-26).
                try Task.checkCancellation()

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
                    warmupLog.info("Step 4: CleanupService.loadModel starting (off-MainActor)")

                    let modelPath = IOSModelDownloadService.modelPath().path
                    // Phase 20.06 hotfix: CleanupService.init and .loadModel are now
                    // nonisolated, so `llama_model_load_from_file` (synchronous ~30s C call)
                    // runs on this detached task instead of blocking MainActor.
                    let cleanup = CleanupService(inferenceTimeoutSeconds: 8.0)  // D-04 iOS timeout
                    try cleanup.loadModel(from: modelPath)
                    let step4Elapsed = Date().timeIntervalSince(warmupStart)
                    warmupLog.info("Step 4: CleanupService.loadModel done (elapsed=\(step4Elapsed, privacy: .public)s)")

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
                warmupLog.error("warmup cancelled")
                await MainActor.run {
                    self?.isWarming = false
                    self?.error = "Model load timed out or was cancelled."
                    self?.watchdogTask?.cancel()
                    self?.watchdogTask = nil
                }
            } catch {
                warmupLog.error("warmup failed: \(error.localizedDescription, privacy: .public)")
                await MainActor.run {
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

    /// Reset error state and retry warmup. Explicit user action — passes
    /// `force: true` so the no-models guard does not block the download path.
    func retry() {
        error = nil
        isReady = false
        warmup(force: true)
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
