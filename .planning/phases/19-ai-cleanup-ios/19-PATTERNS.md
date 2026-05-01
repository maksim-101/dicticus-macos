# Phase 19: AI Cleanup iOS — Pattern Map

**Mapped:** 2026-04-24
**Files analyzed:** 9 (4 new, 5 modified)
**Analogs found:** 9 / 9 (all have strong same-repo analogs — iOS port of shipped macOS pipeline)

---

## File Classification

| New/Modified File | NEW/MOD | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|---------|------|-----------|----------------|---------------|
| `Shared/Services/CleanupService.swift` | NEW (extracted) | service | request-response (LLM inference) | `macOS/Dicticus/Services/CleanupService.swift` | exact — direct lift + small constant changes |
| `iOS/Dicticus/Services/IOSModelDownloadService.swift` | NEW | service | streaming / file-I/O (URLSession delegate) | `macOS/Dicticus/Services/ModelDownloadService.swift` + RESEARCH.md Pattern 2 sketch | role-match — macOS has no progress delegate; iOS adds `URLSessionDownloadDelegate` |
| `iOS/Dicticus/Services/IOSModelWarmupService.swift` | MOD | service | orchestration (launch lifecycle) | `macOS/Dicticus/Services/ModelWarmupService.swift` Step 4 block | exact — copy Step 4 wrapper verbatim |
| `iOS/Dicticus/Settings/SettingsView.swift` | MOD | view | user-settings binding | existing toggles in same file (lines 16–26), + `macOS/Dicticus/Views/AiCleanupInfoView.swift` explainer copy | exact for toggles; role-match for download UI (inline progress, new pattern) |
| `iOS/Dicticus/DictationViewModel.swift` | MOD | view-model | request-response orchestration | existing property-injection pattern already in file (`transcriptionService` didSet, lines 22–37) | exact — add parallel `cleanupService` injection seam + pipeline routing |
| `iOS/project.yml` | MOD | config | build-tool declarative | `macOS/project.yml` lines 21–23 (package), 74 (OTHER_LDFLAGS), 82–83 (dep) | exact — mirror line-for-line |
| `Shared/Models/CleanupPrompt.swift` | MOD | model | pure transform (string builder) | itself — add Swiss branch inside existing `build()` (lines 22–45) | exact — extend-in-place |
| `Shared/Utilities/ITNUtility.swift` | MOD | utility | pure transform (regex) | itself — extend the `applyITN` entry point with new `applySwissITN` | role-match — only existing file of its kind |
| `Shared/Services/CleanupService.swift` → `TextProcessingService.swift` wiring | no change | — | — | `Shared/Services/TextProcessingService.swift` line 13 (already accepts `CleanupProvider?`) | already in place |

---

## Pattern Assignments

### 1. `Shared/Services/CleanupService.swift` (NEW — extracted, service, request-response)

**Analog:** `macOS/Dicticus/Services/CleanupService.swift` (476 lines, shipped 2026-04-17).

**Recommended action (D-ctx: Claude's discretion):** Move the entire file into `Shared/Services/` verbatim. The code has zero macOS-only imports (`SwiftUI`, `LlamaSwift`, `os.log` — all cross-platform). Only iOS-specific constants differ (`inferenceTimeoutSeconds: 8.0` per D-04 vs `5.0` on macOS). Make the timeout a parameter on `init` so both targets share one file.

**Imports pattern** (lines 1–3):
```swift
import SwiftUI
import LlamaSwift
import os.log
```

**@MainActor ObservableObject + CleanupProvider pattern** (lines 25–38):
```swift
@MainActor
class CleanupService: ObservableObject, CleanupProvider {
    enum State: Equatable, Sendable {
        case idle
        case cleaning
    }
    @Published var state: State = .idle

    /// Whether the LLM model is loaded and ready for inference.
    private(set) var isLoaded = false
```

**nonisolated(unsafe) C pointer pattern** (lines 42–52):
```swift
/// llama_model pointer — loaded once during warmup, freed in deinit.
/// nonisolated(unsafe): deinit is nonisolated in Swift 6, so non-Sendable C pointer
/// properties must be marked nonisolated(unsafe) to be accessible from deinit.
private nonisolated(unsafe) var model: OpaquePointer?
private nonisolated(unsafe) var context: OpaquePointer?
private nonisolated(unsafe) var sampler: UnsafeMutablePointer<llama_sampler>?
```

**Backend init + model load + sampler chain** (lines 68–116) — copy verbatim:
```swift
static func initializeBackend() {
    llama_backend_init()
}

func loadModel(from modelPath: String) throws {
    var modelParams = llama_model_default_params()
    modelParams.n_gpu_layers = 99  // All layers on Metal GPU

    guard let loadedModel = llama_model_load_from_file(modelPath, modelParams) else {
        throw CleanupError.modelLoadFailed
    }
    self.model = loadedModel

    var ctxParams = llama_context_default_params()
    ctxParams.n_ctx = 2048
    ctxParams.n_batch = 512
    ctxParams.n_threads = 4

    guard let ctx = llama_init_from_model(loadedModel, ctxParams) else {
        llama_model_free(loadedModel)
        self.model = nil
        throw CleanupError.contextCreationFailed
    }
    self.context = ctx

    let samplerChain = llama_sampler_chain_init(llama_sampler_chain_default_params())
    llama_sampler_chain_add(samplerChain, llama_sampler_init_temp(0.2))
    llama_sampler_chain_add(samplerChain, llama_sampler_init_top_k(40))
    llama_sampler_chain_add(samplerChain, llama_sampler_init_top_p(0.9, 1))
    llama_sampler_chain_add(samplerChain, llama_sampler_init_dist(UInt32.random(in: 0...UInt32.max)))
    self.sampler = samplerChain

    isLoaded = true
}
```

**Concurrent-call guard + isInferring pattern** (lines 122, 136–155) — copy verbatim for D-28:
```swift
private var isInferring = false

func cleanup(text: String, language: String, dictionaryContext: [String: String]? = nil) async -> String {
    let log = Logger(subsystem: "com.dicticus", category: "cleanup")

    guard isLoaded, let model = model, let context = context, let sampler = sampler else {
        log.warning("cleanup: model not loaded, returning raw text")
        return text
    }
    guard !isInferring else {
        log.warning("cleanup: inference already in progress, returning raw text")
        return text
    }

    isInferring = true
    state = .cleaning
    defer {
        state = .idle
        isInferring = false
    }
```

**Timeout via TaskGroup** (lines 162–193) — iOS change: `5.0` → `8.0` per D-04:
```swift
nonisolated(unsafe) let unsafeModel = model
nonisolated(unsafe) let unsafeContext = context
nonisolated(unsafe) let unsafeSampler = sampler
let maxTokens = maxOutputTokens

do {
    let result = try await withThrowingTaskGroup(of: String.self) { group in
        group.addTask {
            // iOS: 8.0 * 1_000_000_000 per D-04
            try await Task.sleep(nanoseconds: UInt64(8.0 * 1_000_000_000))
            throw CleanupError.timeout
        }
        group.addTask {
            return Self.runInference(
                prompt: prompt,
                model: unsafeModel,
                context: unsafeContext,
                sampler: unsafeSampler,
                maxTokens: maxTokens
            )
        }
        guard let firstResult = try await group.next() else {
            return text
        }
        group.cancelAll()
        return firstResult
    }
    let cleaned = Self.stripPreamble(result)
    return cleaned.isEmpty ? text : cleaned
} catch {
    return text  // D-26: any failure → raw text
}
```

**KV cache hygiene + batched decode** (lines 224–296) — copy verbatim. Key lines for D-06:
```swift
// Step 1: Clear KV cache between calls (Pitfall 5)
let memory = llama_get_memory(context)
llama_memory_clear(memory, false)

// Step 2: Reset sampler state
llama_sampler_reset(sampler)

// Step 3: Tokenize prompt
let vocab = llama_model_get_vocab(model)
let promptTokens = tokenize(text: prompt, vocab: vocab, addSpecial: true, parseSpecial: true)
guard !promptTokens.isEmpty else { return "" }

// Step 4: Decode prompt tokens in a batch
var batch = llama_batch_init(Int32(promptTokens.count), 0, 1)
defer { llama_batch_free(batch) }
// ... fill batch, llama_decode(context, batch) ...

// Step 5: Token-by-token sampling loop with cooperative cancellation
while outputTokens.count < maxTokens {
    if Task.isCancelled { break }
    let newToken = llama_sampler_sample(sampler, context, -1)
    if llama_vocab_is_eog(vocab, newToken) { break }
    outputTokens.append(newToken)
    // ... fill nextBatch, llama_decode, currentPos += 1 ...
}
```

**stripPreamble pattern** (lines 350–453) — copy verbatim. Already contains both English ("Here's the polished text:") and German ("Hier ist der korrigierte Text:") preamble strippers. Note for D-18: no additional Swiss variants needed since the existing German preamble contains no ß.

**deinit pattern** (lines 457–463) — copy verbatim:
```swift
deinit {
    if let sampler { llama_sampler_free(sampler) }
    if let context { llama_free(context) }
    if let model { llama_model_free(model) }
    // llama_backend_free() is NOT called — global resource, app-lifetime only.
}
```

**Post-LLM Swiss safety-net regex (D-19)** — NEW code to add after `stripPreamble(result)`, gated on Swiss toggle:
```swift
var cleaned = Self.stripPreamble(result)
if UserDefaults.standard.bool(forKey: "useSwissGerman") {
    cleaned = ITNUtility.applySwissITN(to: cleaned)
}
return cleaned.isEmpty ? text : cleaned
```

---

### 2. `iOS/Dicticus/Services/IOSModelDownloadService.swift` (NEW, service, streaming/file-I/O)

**Primary analog:** `macOS/Dicticus/Services/ModelDownloadService.swift` — for the model URL, file name, path constants, and `isModelCached()` helper.
**Secondary analog:** `RESEARCH.md` Pattern 2 sketch (lines 267–300) — for `URLSessionDownloadDelegate` progress + pause/resume (macOS doesn't have this).

**Static constants — copy verbatim from macOS `ModelDownloadService`** (lines 14–34):
```swift
static let modelURL = URL(string: "https://huggingface.co/unsloth/gemma-4-E2B-it-GGUF/resolve/main/gemma-4-E2B-it-Q4_K_M.gguf")!
static let modelFileName = "gemma-4-E2B-it-Q4_K_M.gguf"

static func modelPath() -> URL {
    let appSupport = FileManager.default.urls(
        for: .applicationSupportDirectory,
        in: .userDomainMask
    ).first!
    return appSupport
        .appendingPathComponent("Dicticus")
        .appendingPathComponent("Models")
        .appendingPathComponent(modelFileName)
}

static func isModelCached() -> Bool {
    FileManager.default.fileExists(atPath: modelPath().path)
}
```

**URLSessionDownloadDelegate class shell (new — from RESEARCH.md Pattern 2, lines 267–300):**
```swift
@MainActor
final class IOSModelDownloadService: NSObject, ObservableObject, URLSessionDownloadDelegate {
    enum DownloadState: Equatable { case idle, downloading, paused, completed, failed(String) }
    @Published var state: DownloadState = .idle
    @Published var progress: Double = 0
    @Published var bytesPerSec: Double = 0

    private var session: URLSession!
    private var task: URLSessionDownloadTask?
    private var resumeData: Data?

    override init() {
        super.init()
        let cfg = URLSessionConfiguration.default
        cfg.waitsForConnectivity = true
        self.session = URLSession(configuration: cfg, delegate: self, delegateQueue: .main)
    }

    func start() {
        if let resumeData {
            task = session.downloadTask(withResumeData: resumeData)
        } else {
            task = session.downloadTask(with: Self.modelURL)
        }
        task?.resume()
        state = .downloading
    }

    func pause() {
        task?.cancel(byProducingResumeData: { [weak self] data in
            Task { @MainActor in
                self?.resumeData = data
                self?.state = .paused
            }
        })
    }

    // URLSessionDownloadDelegate callbacks (write progress → @Published; on finish move to modelPath())
}
```

**iCloud-backup exclusion pattern — NEW (from RESEARCH.md — App Review requirement):** After moving to `modelPath()`, apply:
```swift
var url = Self.modelPath()
var values = URLResourceValues()
values.isExcludedFromBackup = true
try url.setResourceValues(values)
```
This is NOT in the macOS file (macOS Application Support is not iCloud-backed by default); it must be added for iOS.

---

### 3. `iOS/Dicticus/Services/IOSModelWarmupService.swift` (MODIFY, service, orchestration)

**Analog A (current Steps 1–3 pattern):** `iOS/Dicticus/Services/IOSModelWarmupService.swift` itself (lines 60–89). Keep the outer `Task.detached(priority: .utility) { [weak self] in` shell, `MainActor.run` state publishes, and watchdog task unchanged.

**Analog B (Step 4 block to add):** `macOS/Dicticus/Services/ModelWarmupService.swift` lines 129–169. This is the exact pattern to port — wrapped in `do { ... } catch is CancellationError { ... } catch { ... }` with `warmupLog.info/error` calls.

**Current iOS Step 3 tail (line 76–91) — remove the misleading comment, add Step 4 below it:**
```swift
try Task.checkCancellation()

// ASR ready — publish immediately so plain dictation works even if LLM fails.
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

// NOTE: No Step 4 (LLM) on iOS v2.0 — locked decision   ← DELETE THIS COMMENT
```

**Step 4 to add (port from `macOS/Dicticus/Services/ModelWarmupService.swift` lines 129–169):**
```swift
// Step 4: Download + initialize LLM for AI cleanup (D-12).
// Gated on AI Cleanup toggle — skip entirely when OFF.
// Also gated on device RAM (D-03).
let warmupLog = Logger(subsystem: "com.dicticus", category: "warmup")
let aiCleanupEnabled = UserDefaults.standard.bool(forKey: "aiCleanupEnabled")
let hasEnoughRam = ProcessInfo.processInfo.physicalMemory >= 5 * 1024 * 1024 * 1024  // D-03

guard aiCleanupEnabled && hasEnoughRam else { return }

do {
    let needsDownload = !IOSModelDownloadService.isModelCached()
    warmupLog.info("LLM Step 4: cached=\(!needsDownload)")
    if needsDownload {
        await MainActor.run { self?.llmStatus = .downloading }
        try await IOSModelDownloadService.downloadIfNeeded()  // or via the delegate-based start()
    }

    await MainActor.run { self?.llmStatus = .loading }
    let modelPath = IOSModelDownloadService.modelPath().path
    let cleanup = try await MainActor.run { () throws -> CleanupService in
        CleanupService.initializeBackend()
        let service = CleanupService()
        try service.loadModel(from: modelPath)
        return service
    }
    await MainActor.run {
        self?.cleanupService = cleanup
        self?.isLlmReady = true
        self?.llmStatus = .ready
    }
} catch is CancellationError {
    throw CancellationError()
} catch {
    warmupLog.error("LLM warmup failed: \(error.localizedDescription)")
    await MainActor.run { self?.llmStatus = .failed("AI cleanup unavailable") }
}
```

**Matching property additions (from macOS lines 51–53):**
```swift
@Published var isLlmReady = false
@Published var llmStatus: LlmStatus = .idle
private var cleanupService: CleanupService?

var cleanupServiceInstance: CleanupService? { cleanupService }
```

**`LlmStatus` enum — copy verbatim from `macOS/Dicticus/Services/ModelWarmupService.swift` lines 21–41** (already in Shared-appropriate shape, no macOS deps):
```swift
enum LlmStatus: Equatable {
    case idle, downloading, loading, ready, failed(String)

    var label: String {
        switch self {
        case .idle:                return "Waiting"
        case .downloading:         return "Downloading model\u{2026}"
        case .loading:             return "Loading model\u{2026}"
        case .ready:               return "Ready"
        case .failed(let reason):  return reason
        }
    }
    var isActive: Bool { self == .downloading || self == .loading }
}
```

---

### 4. `iOS/Dicticus/Settings/SettingsView.swift` (MODIFY, view, user-settings binding)

**Analog (in-file toggle idiom — lines 20–26):**
```swift
Toggle(isOn: appGroupBinding("useCustomDictionary", default: true)) {
    Label("Apply Replacements", systemImage: "character.cursor.ibeam")
}

Toggle(isOn: appGroupBinding("useITN", default: true)) {
    Label("Numbers to Digits", systemImage: "number")
}
```

**`appGroupBinding` helper already in file — reuse for both new toggles (lines 131–141):**
```swift
private static let appGroupDefaults = UserDefaults(suiteName: "group.com.dicticus")!

private func appGroupBinding(_ key: String, default defaultValue: Bool) -> Binding<Bool> {
    Binding(
        get: {
            let defaults = Self.appGroupDefaults
            return defaults.object(forKey: key) == nil ? defaultValue : defaults.bool(forKey: key)
        },
        set: { Self.appGroupDefaults.set($0, forKey: key) }
    )
}
```

**Two new toggles to add (both default `false` per D-08, D-15):**
```swift
Toggle(isOn: appGroupBinding("aiCleanupEnabled", default: false)) {
    Label("AI Cleanup", systemImage: "sparkles")
}

Toggle(isOn: appGroupBinding("useSwissGerman", default: false)) {
    Label("Swiss German Spelling", systemImage: "character.bubble")
}
```

**Model-info sheet idiom (lines 90–119) — reuse pattern for Gemma info sheet.** Current pattern uses `.sheet(isPresented:)` + `LabeledContent` rows + `.presentationDetents([.medium])`. Apply the same shape for an "LLM Model Info" sheet (Gemma 4 E2B, ~3.1 GB, llama.cpp Metal, etc.).

**Explainer copy source:** `macOS/Dicticus/Views/AiCleanupInfoView.swift` lines 25, 106 — reuse literal strings ("Gemma 4 E2B (Q4_K_M)", and the "fully on-device — no audio is sent to any server" tone).

**Inline download UI (new pattern):** No existing in-file analog. Use a `DisclosureGroup` or inline `VStack` appearing when the toggle is ON but `!IOSModelDownloadService.isModelCached()`. Show `ProgressView(value: downloadService.progress)`, size warning text, Download/Pause/Resume button. Follows iOS Settings idioms; closest shape in this file is the Action Button `DisclosureGroup` (lines 35–46).

---

### 5. `iOS/Dicticus/DictationViewModel.swift` (MODIFY, view-model, request-response orchestration)

**Analog (in-file property-injection seam — lines 22–37):**
```swift
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
        if transcriptionService != nil {
            checkPendingIntent()
        }
    }
}
```

**New parallel injection seam to add:**
```swift
var cleanupService: CleanupProvider? {
    didSet {
        // no lifecycle hooks needed — consumed only at transcribe time
    }
}
```

**Pipeline integration — `stopDictation()` currently calls `transcriptionService?.stopRecordingAndTranscribe()` and writes raw `result.text` directly (line 85, 93).** The iOS pipeline must route through `TextProcessingService` when `aiCleanupEnabled == true`. Use the pattern already present in `Shared/Services/TextProcessingService.swift`:

```swift
// macOS already wires TextProcessingService; iOS needs the same seam.
if let result = try await transcriptionService?.stopRecordingAndTranscribe() {
    let mode: DictationMode = UserDefaults.standard.bool(forKey: "aiCleanupEnabled") ? .aiCleanup : .plain
    let processor = TextProcessingService(cleanupService: cleanupService, dictionaryService: DictionaryService.shared)
    let cleaned = await processor.process(
        text: result.text,
        language: result.language,
        mode: mode,
        confidence: Double(result.confidence)
    )
    UIPasteboard.general.string = cleaned
    lastResult = cleaned
    // History entry stores both raw and cleaned per existing TranscriptionEntry shape.
}
```

Existing `DictationMode.plain` string on line 93 must become `mode.rawValue` matching the selected mode.

---

### 6. `iOS/project.yml` (MODIFY, config, build-tool declarative)

**Analog: `macOS/project.yml`.** Mirror three blocks literally.

**Add to `packages:` (lines 21–23 in macOS):**
```yaml
packages:
  # ... existing FluidAudio, GRDB ...
  llama:
    url: https://github.com/mattt/llama.swift.git
    from: 2.8832.0   # pin identical to macOS for binary parity
```

**Add to target `Dicticus` settings (line 74 in macOS):**
```yaml
settings:
  # existing settings ...
  OTHER_LDFLAGS: "-framework llama"
```
Note: current iOS `project.yml` line 35 is a flat `settings:` block — the `OTHER_LDFLAGS` key goes at the same level as `PRODUCT_BUNDLE_IDENTIFIER`.

**Add to target `Dicticus` dependencies (lines 82–83 in macOS):**
```yaml
dependencies:
  # ... existing GRDB, FluidAudio, DicticusWidget ...
  - package: llama
    product: LlamaSwift
```

**Then run:** `xcodegen generate` from `iOS/`.

---

### 7. `Shared/Models/CleanupPrompt.swift` (MODIFY, model, pure transform)

**Analog (in-file `build()` — lines 22–45):**
```swift
static func build(text: String, language: String? = nil, dictionaryContext: [String: String]? = nil) -> String {
    let instruction = userInstruction()
    var prompt = "<start_of_turn>user\n"
    prompt += "INSTRUCTION: \(instruction)\n"

    if let dict = dictionaryContext, !dict.isEmpty {
        prompt += "DICTIONARY:\n"
        for (original, replacement) in dict.sorted(by: { $0.key < $1.key }) {
            prompt += "- \(original) -> \(replacement)\n"
        }
    }

    if let lang = language {
        prompt += "LANGUAGE: \(lang == "de" ? "German" : "English")\n"
    }

    let sanitizedText = sanitizeControlTokens(text)
    prompt += "INPUT: \(sanitizedText)<end_of_turn>\n"
    prompt += "<start_of_turn>model\n"
    prompt += "OUTPUT:"
    return prompt
}
```

**New Swiss branch to append (gated on settings read) — insert after the `LANGUAGE:` block, before the `INPUT:` block, per D-18:**
```swift
if UserDefaults.standard.bool(forKey: "useSwissGerman") && (language == "de") {
    prompt += "STYLE: Use Swiss German orthography (never use ß, always ss). "
    prompt += "Use Swiss thousands separator style (e.g. 1'250, not 1.250).\n"
}
```

---

### 8. `Shared/Utilities/ITNUtility.swift` (MODIFY, utility, pure transform)

**Analog (in-file entry-point pattern — lines 6–13):**
```swift
static func applyITN(to text: String, language: String) -> String {
    if language == "de" {
        return applyGermanITN(to: text)
    } else {
        return applyEnglishITN(to: text)
    }
}
```

**New function to add (D-16 / D-17):**
```swift
/// Convert ß → ss (and ẞ → SS) for Swiss German spelling.
/// Deterministic, Unicode-aware, case-preserving regex pass. Sub-millisecond.
/// Called whenever the Swiss German toggle is ON, independent of AI cleanup.
static func applySwissITN(to text: String) -> String {
    return text
        .replacingOccurrences(of: "ß", with: "ss")
        .replacingOccurrences(of: "\u{1E9E}", with: "SS")  // U+1E9E = capital Eszett ẞ
}
```

**Call-site integration — planner should also update `Shared/Services/TextProcessingService.swift` Step 2 to call `applySwissITN` after `applyITN` when the Swiss toggle is ON (D-16).**

---

## Shared Patterns

### Service lifecycle — `@MainActor ObservableObject` with `@Published` state
**Source:** `macOS/Dicticus/Services/CleanupService.swift` lines 25–34; `iOS/Dicticus/Services/IOSModelWarmupService.swift` lines 9–17.
**Apply to:** `Shared/Services/CleanupService.swift` (new), `iOS/Dicticus/Services/IOSModelDownloadService.swift` (new).
```swift
@MainActor
class SomeService: ObservableObject {
    @Published var state: State = .idle
    private(set) var isLoaded = false
}
```

### `nonisolated(unsafe)` for C pointers crossed into detached tasks / deinit
**Source:** `macOS/Dicticus/Services/CleanupService.swift` lines 44–52, 162–164.
**Apply to:** `Shared/Services/CleanupService.swift` exclusively. Both at property level (for `deinit` access) and as local re-bindings before entering a detached `group.addTask { ... }`.

### Graceful degradation — any cleanup failure returns raw text
**Source:** `macOS/Dicticus/Services/CleanupService.swift` lines 140–148, 201–205.
**Apply to:** All cleanup call sites. Never throw out of `cleanup(...)`; swallow and return the input `text`. This is the contract `TextProcessingService` relies on.

### Warmup orchestration — `Task.detached(priority: .utility) { [weak self] }` + `MainActor.run`
**Source:** `iOS/Dicticus/Services/IOSModelWarmupService.swift` lines 60–89.
**Apply to:** the new Step 4 addition inside the same file.
```swift
warmupTask = Task.detached(priority: .utility) { [weak self] in
    do {
        // ... await long work on background ...
        await MainActor.run {
            self?.state = .ready
        }
    } catch { /* ... */ }
}
```

### `@AppStorage` / App Group bindings for settings toggles
**Source:** `iOS/Dicticus/Settings/SettingsView.swift` lines 131–141 (App Group helper); `macOS/Dicticus/Views/AiCleanupInfoView.swift` line 98 (`@AppStorage` for prompt customization).
**Apply to:** Both new iOS toggles. Use the existing `appGroupBinding(_:default:)` helper — consistent with `useCustomDictionary` / `useITN` / `useAutoStop`. Keys: `"aiCleanupEnabled"` (default false), `"useSwissGerman"` (default false).

### Dictionary / prompt / injection seam (already built — do NOT change)
**Source:** `Shared/Services/TextProcessingService.swift` line 13 (`cleanupService: CleanupProvider?`), line 37 (mode-gated routing), line 45 (`cleanup(text:language:dictionaryContext:)` call).
**Apply to:** iOS just needs to construct a `TextProcessingService` with the new iOS cleanup service injected. Zero protocol or signature changes.

### URL path convention — `Application Support/Dicticus/Models/`
**Source:** `macOS/Dicticus/Services/ModelDownloadService.swift` lines 25–34.
**Apply to:** `iOS/Dicticus/Services/IOSModelDownloadService.swift` (same literal path — per D-11).

---

## No Analog Found

| File / concern | Reason | Planner guidance |
|----------------|--------|------------------|
| `URLSessionDownloadDelegate` progress + pause/resume in `IOSModelDownloadService` | macOS downloader uses `URLSession.shared.download(from:)` which has no intermediate progress callback | Use RESEARCH.md Pattern 2 sketch (lines 267–300) as the primary reference. No same-repo analog of this pattern exists. |
| Inline Settings download UI (progress bar + size warning + pause/resume controls) | No existing inline-progress pattern in `SettingsView.swift` | Closest shape: `DisclosureGroup` at lines 35–46 (Action Button). Build a new VStack-with-ProgressView pattern; keep iOS-idiomatic. |
| Device RAM gating (`ProcessInfo.physicalMemory`) and explainer UI | No runtime device-capability gate exists anywhere in the codebase | Planner to draft fresh. Recommended: a `static var isAiCleanupSupported: Bool` computed in `IOSModelWarmupService` and consumed by `SettingsView` to render an explainer banner instead of the toggle on `<5 GB` devices (D-03). |
| `isExcludedFromBackup = true` on GGUF | macOS does not need this; not in existing codebase | Add in `IOSModelDownloadService` right after moving the download to `modelPath()`. Snippet in Pattern Assignment §2. |

---

## Metadata

**Analog search scope:**
- `macOS/Dicticus/Services/` — full scan (11 files)
- `iOS/Dicticus/` — full scan (Settings, Services, DictationViewModel)
- `Shared/` — all four subdirectories
- `macOS/Dicticus/Views/AiCleanupInfoView.swift` — explainer copy
- Both `project.yml` files

**Files scanned:** 14 source files directly read.
**Pattern extraction date:** 2026-04-24.
**Phase directory:** `/Users/mowehr/code/dicticus/.planning/phases/19-ai-cleanup-ios/`.
