# Phase 19: AI Cleanup iOS — Research

**Researched:** 2026-04-24
**Domain:** On-device LLM (llama.cpp + Gemma 4 E2B) integration into existing iOS dictation pipeline
**Confidence:** HIGH overall — core path is a direct port of a proven, shipping macOS implementation.

## Summary

Phase 19 ports the macOS AI cleanup pipeline to iOS. The macOS implementation (`macOS/Dicticus/Services/CleanupService.swift`, ~460 LOC, shipped 2026-04-17) is battle-tested and already uses the same `LlamaSwift` SPM package that declares `iOS(.v16)` support out of the box — so the Swift/C pointer bindings, sampler chain, tokenizer helpers, preamble stripper, and deinit hygiene are copy-ready. CONTEXT.md locks 29 decisions including model, runtime, paths, timeouts, and UX; the research scope reduces to verifying iOS-specific runtime behaviors.

The five things that materially differ from macOS and need planner attention: (1) **memory pressure** — Parakeet (~2.7 GB) + Gemma 4 E2B Q4_K_M (~3.1 GB) resident simultaneously on a 6 GB iPhone 14 puts us within single-digit-hundred-MB of the ~4.5 GB ceiling with the `increased-memory-limit` entitlement; (2) **URLSession progress delegate** — the macOS downloader uses the fire-and-forget `URLSession.shared.download(from:)` which provides no intermediate progress callbacks or resume semantics, so iOS needs a `URLSessionDownloadDelegate` rewrite; (3) **iCloud backup exclusion** — Application Support is included in iCloud Backup by default; a ~3 GB GGUF there without `isExcludedFromBackup = true` will bloat user backups and has been a reliable App Review rejection reason for large cacheable blobs; (4) **performance** — iPhone 14/15 Metal decode for a ~3 GB Q4 model sits around 15–25 tok/s per community benchmarks, so the 8 s timeout (D-04) comfortably covers 100–200 output tokens but has zero headroom for 400+ token outputs; (5) **Swift 6 / iOS 18 strict concurrency** — the macOS service uses `nonisolated(unsafe)` for C pointers, which is the correct and only pattern; iOS behavior is identical here.

**Primary recommendation:** Extract `CleanupService` into `Shared/Services/CleanupService.swift` — the code is pointer-manipulation and sampler-chain logic with zero macOS-specific dependencies. Keep only the `IOSModelDownloadService` (new) and the warmup wiring iOS-local. Mirror everything else from macOS literally. Extend `ITNUtility` for Swiss ß→ss. Add the two Settings toggles with inline download UI. Reverse the "no Step 4 on iOS" comment in `IOSModelWarmupService` and add a conditional Step 4.

## User Constraints (from CONTEXT.md)

### Locked Decisions

**Model, runtime, memory:**
- D-01: Gemma 4 E2B IT Q4_K_M from `unsloth/gemma-4-E2B-it-GGUF` (~3.1 GB, ungated)
- D-02: `mattt/llama.swift` SPM package, Metal backend, `n_gpu_layers = 99`
- D-03: RAM gate — disable if `ProcessInfo.processInfo.physicalMemory < 5 GB` (iPhone 12/13 out)
- D-04: 8 s inference timeout (vs 5 s macOS)
- D-05: `temp=0.2`, `top_k=40`, `top_p=0.9`, random seed, `n_ctx=2048`, batch 512, 4 CPU threads, max 512 output tokens
- D-06: KV cache cleared between calls via `llama_memory_clear(llama_get_memory(ctx), false)`
- D-07: `com.apple.developer.kernel.increased-memory-limit` entitlement already present (Phase 13)

**Activation & download:**
- D-08: "AI Cleanup" Settings toggle, default OFF
- D-09: No onboarding bundling — LLM download triggered on first toggle flip
- D-10: Inline Settings download UI — sheet with size warning, progress bar, pause/resume
- D-11: Path `Application Support/Dicticus/Models/gemma-4-E2B-it-Q4_K_M.gguf`
- D-12: Extend `IOSModelWarmupService` with conditional Step 4 on launch
- D-13: Block dictation result delivery until cleanup completes
- D-14: Main-app pipeline only — no keyboard extension

**Swiss German:**
- D-15: Independent "Swiss German spelling" toggle, default OFF
- D-16: ß→ss deterministic regex in `Shared/Utilities/ITNUtility.swift`
- D-17: Handle ẞ→SS (case-aware)
- D-18: When both toggles ON, append Swiss prompt line to `CleanupPrompt.build()`
- D-19: Post-LLM safety-net ß→ss regex
- D-20: No deterministic thousands-separator regex — LLM-only via D-18
- D-21: Vocabulary translations via Custom Dictionary — no built-in list

**Pipeline & integration:**
- D-22: Reuse `Shared/Models/CleanupPrompt.swift` (extend `build()` only)
- D-23: Reuse `Shared/Protocols/CleanupProvider.swift` (no changes)
- D-24: Dictionary context passed via `cleanup(text:, language:, dictionaryContext:)`
- D-25: Language auto-detected from `DicticusTranscriptionResult.language`
- D-26: Any failure → return raw ASR text
- D-27: Reuse `CleanupPrompt.sanitizeControlTokens`
- D-28: `isInferring` guard rejects concurrent calls
- D-29: `llama_backend_init()` called once at app launch

### Claude's Discretion

- Extract `CleanupService.swift` to `Shared/Services/` vs keep two copies
- Exact Settings UI (toggle order, copy, sheet vs inline expander)
- Error/explainer copy (device-unsupported, download-failed, timeout)
- Optional "Reset AI Cleanup" button to delete GGUF
- Show/hide LLM warmup progress in existing `IOSModelWarmupService.downloadProgress` UI

### Deferred Ideas (OUT OF SCOPE)

- Phi-3 Mini rewrite mode
- Per-dictation raw/cleaned choice
- Streaming / per-word replace UI
- Background URLSession for LLM download
- Adaptive timeout
- Deterministic Swiss thousands separator
- Built-in Swiss vocab list
- Mixed-language cleanup fixes
- Device allowlist gating

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| CLEAN-01 | User can enable AI cleanup for grammar/punctuation correction on iOS | Settings toggle + llama.swift package + Metal backend all verified viable on iOS 17+; extraction path to `Shared/` confirmed since CleanupProvider protocol already exists |
| CLEAN-02 | AI cleanup runs fully locally via llama.cpp Metal on iPhone | `mattt/llama.swift` Package.swift declares `.iOS(.v16)` with XCFramework binary target; Metal backend ships as part of the XCFramework; no network calls during inference (same as macOS) |

## Domain Overview: On-Device LLM on iPhone in 2026

The state of on-device LLM on iPhone in Q1 2026 is well past proof-of-concept. Multiple shipping iOS apps run 1B–4B parameter Q4 GGUF models via llama.cpp Metal: **PocketPal AI** (App Store, ships Gemma 4, Phi, Qwen, Bonsai via llama.rn bindings), **LLMFarm** (open-source, SwiftUI + llama.cpp directly), and **LocalLLMClient** (Swift package with both llama.cpp and MLX backends). Community benchmarks consistently place iPhone 14/15 (A16, 6 GB RAM) at ~15–25 tok/s for ~2–3 B parameter Q4_K_M models; iPhone 15 Pro / 16 (A17 Pro / A18, 8 GB) at ~20–30+ tok/s. Our Gemma 4 E2B at Q4_K_M is at the larger end of this range (~3.1 GB on disk).

**Why Gemma 4 E2B at Q4_K_M is near the ceiling, not comfortably below it:** the model file is 3.1 GB; resident RSS at inference is higher (KV cache + activations + allocator overhead add ~15–25% for a 2048-token context). Combined with 2.7 GB for Parakeet + the app itself + system reservations, a 6 GB iPhone 14 user enabling AI cleanup is in the 4.5–5.0 GB total-process zone. The `increased-memory-limit` entitlement raises the per-app ceiling on 6 GB devices from ~3 GB default to ~4.5 GB in Apple's own observed limits — which means **iPhone 14 with both models resident is within a few hundred MB of Jetsam**. iOS 18 added `vm-compressor-space-shortage` as a new jetsam reason, which fires when compressed-memory growth (not just physical memory use) overwhelms the VM system. This is the specific pressure mode LLM+ASR workloads create. The 5 GB RAM gate (D-03) excludes iPhone 12/13, but iPhone 14 at 6 GB is the marginal case the planner must treat as the stress target for tests.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|--------------|----------------|-----------|
| LLM inference (tokenize, decode, sample) | iOS app process (Metal GPU via llama.cpp XCFramework) | — | No IPC, no extension — all in main app (D-14) |
| Model file download | iOS app (foreground URLSession with delegate) | — | Foreground-only per D-10; background URLSession deferred |
| Device eligibility check | iOS app launch | — | Runtime `ProcessInfo.processInfo.physicalMemory` read (D-03); no Info.plist declaration possible |
| Swiss ß→ss transform | `Shared/Utilities/ITNUtility.swift` | — | ITN layer is the right home (D-16); runs on both plain and AI-cleanup paths |
| Prompt assembly (incl. Swiss extension) | `Shared/Models/CleanupPrompt.swift` | — | Already cross-platform; Swiss prompt line is a conditional extension (D-18) |
| Pipeline orchestration | `Shared/Services/TextProcessingService.swift` | — | Unchanged — already accepts `CleanupProvider?` (D-23) |
| Settings toggles & download UI | `iOS/Dicticus/Settings/SettingsView.swift` | — | iOS Settings idioms only; macOS copy is reference for explainer text |
| Warmup orchestration | `iOS/Dicticus/Services/IOSModelWarmupService.swift` | — | Extend existing 3-step with conditional Step 4 (D-12) |
| Cleanup service implementation | Recommended: `Shared/Services/CleanupService.swift` (extracted) | Alternative: `iOS/Dicticus/Services/IOSCleanupService.swift` (mirror) | Code is platform-agnostic; extraction preferred (see Q9 below) |

## Standard Stack

### Core (all confirmed via codebase / Package.swift)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `mattt/llama.swift` | from 2.8832.0 (macOS has it); latest tag 2.8913.0+ | llama.cpp bindings via XCFramework | Already in macOS `project.yml`; Package.swift declares `.iOS(.v16)` — same package works on iOS target with zero changes [VERIFIED: fetched Package.swift] |
| Gemma 4 E2B IT Q4_K_M GGUF | `unsloth/gemma-4-E2B-it-GGUF` | LLM model | Already shipping on macOS (same URL, same model); ungated (no HF auth) |
| FluidAudio | 0.13.6+ | Parakeet ASR (already in iOS target) | Unchanged |
| GRDB | 7.0+ | History (already in iOS target) | Unchanged |

### Installation

Add to `iOS/project.yml`:

```yaml
packages:
  # ... existing ...
  llama:
    url: https://github.com/mattt/llama.swift.git
    from: 2.8832.0   # match macOS version pin

targets:
  Dicticus:
    settings:
      base:
        # Existing settings ...
        OTHER_LDFLAGS: "-framework llama"
    dependencies:
      # ... existing ...
      - package: llama
        product: LlamaSwift
```

Then `xcodegen generate` to regenerate the Xcode project.

### Version verification

The macOS target uses `from: 2.8832.0`. As of research date the latest tag is 2.8913.0+. **Recommendation: pin iOS to the same version string as macOS** to guarantee parity — binary-target XCFrameworks are tied to specific llama.cpp release builds, and sampler-chain / memory API behavior should be identical across both targets. Do not let iOS float to a newer version independently.

## Architecture Patterns

### System Architecture Diagram

```
User (iPhone)
    |
    | 1. Siri Shortcut / Action Button / in-app mic
    v
DictationViewModel (@MainActor, iOS)
    |
    | 2. Captures audio via AVAudioSession
    v
IOSTranscriptionService (Parakeet TDT v3 via FluidAudio + Silero VAD)
    |
    | 3. Returns DicticusTranscriptionResult(text, language, confidence)
    v
TextProcessingService (@MainActor, Shared)
    |
    |  Pipeline (unchanged by this phase):
    |   Step 1. DictionaryService.apply() → dictionary replacements
    |   Step 2. ITNUtility.applyITN()     → number words → digits
    |           ITNUtility.applySwissITN() → ß→ss when Swiss toggle ON (NEW, D-16)
    |   Step 3. if mode == .aiCleanup && cleanupService != nil:
    |             CleanupProvider.cleanup() → LLM polish (BLOCKS until done, D-13)
    |               Swiss extension injected into prompt (D-18)
    |             post-LLM ß→ss safety-net regex (NEW, D-19)
    |   Step 4. HistoryService.save(entry)
    v
DictationViewModel publishes cleaned text → UI → clipboard

Cleanup service internals (runs inside Step 3):
    loadModel() [done once at warmup, not per call]
      -> llama_model_load_from_file
      -> llama_init_from_model (n_ctx=2048, n_batch=512, n_threads=4)
      -> llama_sampler_chain (temp→top_k→top_p→dist)
    cleanup()
      -> guard !isInferring (D-28)
      -> build prompt via CleanupPrompt.build() (with Swiss line if D-18)
      -> TaskGroup { timeout(8s) || inference }
           inference:
             llama_memory_clear(llama_get_memory(ctx), false)  # D-06
             llama_sampler_reset(sampler)
             tokenize → decode prompt batch → sample loop (checks Task.isCancelled)
             detokenize
      -> stripPreamble() (Pitfall 4)
      -> apply Swiss safety-net regex if Swiss ON (D-19)
      -> return (or raw text on any error — D-26)

Download flow (triggered by first toggle flip):
    SettingsView toggle → ON
      -> show confirmation sheet ("~3 GB, Wi-Fi recommended")
      -> user taps Download
      -> IOSModelDownloadService.start() with URLSessionDownloadDelegate
      -> delegate callbacks update @Published progress, bytesPerSec
      -> on completion: move to Application Support/Dicticus/Models/
      -> set isExcludedFromBackup = true on the GGUF (NEW)
      -> IOSModelWarmupService.warmup() triggers Step 4 (load into Metal)
      -> toggle flips from "pending" to "on"
```

### Recommended Project Structure

```
Shared/
├── Models/
│   ├── CleanupPrompt.swift       # D-22 extended (Swiss prompt line)
│   ├── DictationMode.swift       # unchanged
│   └── TranscriptionResult.swift # unchanged
├── Protocols/
│   └── CleanupProvider.swift     # D-23 unchanged
├── Services/
│   ├── CleanupService.swift      # NEW — extracted from macOS (see Q9)
│   ├── TextProcessingService.swift # D-23 unchanged
│   ├── DictionaryService.swift   # unchanged
│   └── HistoryService.swift      # unchanged
└── Utilities/
    └── ITNUtility.swift          # D-16 extended (applySwissITN)

iOS/Dicticus/
├── Services/
│   ├── IOSModelDownloadService.swift   # NEW — URLSessionDownloadDelegate
│   ├── IOSModelWarmupService.swift     # D-12 extended with Step 4
│   └── IOSTranscriptionService.swift   # unchanged
├── Settings/
│   └── SettingsView.swift              # add 2 toggles + download UI
└── DictationViewModel.swift            # inject CleanupService when toggle ON
```

### Pattern 1: `@MainActor` service + `nonisolated(unsafe)` C pointers

The macOS `CleanupService` is the canonical pattern. Do not deviate:
```swift
@MainActor
class CleanupService: ObservableObject, CleanupProvider {
    // C pointers must be nonisolated(unsafe) so Swift 6 `deinit` (which is
    // nonisolated by default) can free them.
    private nonisolated(unsafe) var model: OpaquePointer?
    private nonisolated(unsafe) var context: OpaquePointer?
    private nonisolated(unsafe) var sampler: UnsafeMutablePointer<llama_sampler>?

    // Inference runs in a detached task with timeout. Capture pointers
    // into nonisolated(unsafe) locals before crossing into the task.
    func cleanup(...) async -> String {
        nonisolated(unsafe) let unsafeModel = model
        nonisolated(unsafe) let unsafeContext = context
        nonisolated(unsafe) let unsafeSampler = sampler
        // ... TaskGroup with timeout + inference
    }

    deinit {
        if let sampler { llama_sampler_free(sampler) }
        if let context { llama_free(context) }
        if let model { llama_model_free(model) }
    }
}
```
This works identically on iOS 18 / Swift 6. **Source: `macOS/Dicticus/Services/CleanupService.swift` lines 44–52 and 161–164, already shipping.**

### Pattern 2: URLSession foreground download with progress + pause/resume

iOS needs this, macOS doesn't have it. Minimal sketch:
```swift
@MainActor
final class IOSModelDownloadService: NSObject, ObservableObject, URLSessionDownloadDelegate {
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
            task = session.downloadTask(with: ModelDownloadService.modelURL)
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

    // URLSessionDownloadDelegate
    nonisolated func urlSession(_ session: URLSession,
                                downloadTask: URLSessionDownloadTask,
                                didWriteData bytesWritten: Int64,
                                totalBytesWritten: Int64,
                                totalBytesExpectedToWrite: Int64) {
        Task { @MainActor in
            self.progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        }
    }

    nonisolated func urlSession(_ session: URLSession,
                                downloadTask: URLSessionDownloadTask,
                                didFinishDownloadingTo location: URL) {
        let target = ModelDownloadService.modelPath()
        // FileManager copy off-main, then mark isExcludedFromBackup on target
        // ...
    }
}
```
Key points:
- **`waitsForConnectivity = true`** on the session config — auto-retries when Wi-Fi drops (important for a 3 GB download).
- **`cancel(byProducingResumeData:)`** returns resume data; re-creating with `downloadTask(withResumeData:)` continues from last checkpoint.
- **Delegate methods are non-isolated** — use `Task { @MainActor in … }` to update `@Published` state.
- **Move-then-exclude-backup** in the `didFinishDownloadingTo` handler before calling the completion path.

**Source: Apple's `URLSessionDownloadDelegate` documentation + Swift Forums thread on `downloadTask(withResumeData:)` behavior.**

### Pattern 3: Warmup Step 4 — conditional LLM load on launch

`IOSModelWarmupService` currently has an explicit `// NOTE: No Step 4 (LLM) on iOS v2.0 — locked decision` at line 91. This comment is to be **removed in this phase**. Add a gated Step 4:
```swift
// After Step 3 (VAD) completes:
let cleanupEnabled = UserDefaults.standard.bool(forKey: "aiCleanupEnabled")
if cleanupEnabled && IOSModelDownloadService.isModelCached() {
    await MainActor.run { self?.downloadStatus = "Step 4/4: Loading AI cleanup model..." }
    CleanupService.initializeBackend()   // once, safe to call again
    let service = CleanupService()
    try service.loadModel(from: ModelDownloadService.modelPath().path)
    await MainActor.run {
        self?.cleanupService = service
    }
}
```
The `cleanupService` instance then gets passed to `TextProcessingService` via dependency injection in `DictationViewModel`. If Step 4 fails (OOM, bad GGUF), fall back to `.cleaned = nil` and the pipeline degrades to plain ITN output per D-26.

### Anti-Patterns to Avoid

- **Don't call `llama_backend_init()` per-cleanup.** It is a global init; call once at app launch in `DicticusApp.init()` or from `IOSModelWarmupService` before Step 4. Same as macOS (D-29).
- **Don't call `llama_backend_free()` from `deinit`.** The macOS `CleanupService.deinit` explicitly does not — this is a global resource. Port this comment/behavior exactly.
- **Don't store pointers on any isolation other than `nonisolated(unsafe)`.** Swift 6 will refuse to compile `deinit` access to `@MainActor` stored C pointers.
- **Don't background the download.** D-10 locks foreground-only; `URLSessionConfiguration.background(...)` is deferred.
- **Don't skip `isExcludedFromBackup`.** 3 GB in iCloud Backup is both a UX insult and an App Review flag.
- **Don't assume the model directory exists.** `FileManager.default.createDirectory(withIntermediateDirectories: true)` before writing, same as macOS.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| llama.cpp C bindings for iOS | Custom `module.modulemap` + bridging header + headerless framework wrangling | `mattt/llama.swift` SPM with `LlamaSwift` product | XCFramework, semver, Metal backend included, iOS 16+ declared. Same package already shipping in macOS target. |
| GGUF download with progress/resume | Raw `URLSession.shared.data(from:)` loop | `URLSessionDownloadTask` + `URLSessionDownloadDelegate` | Delegate gives you mid-download byte counts for free; `cancel(byProducingResumeData:)` handles pause; `waitsForConnectivity` handles Wi-Fi drops. |
| Device RAM gate | Parsing `uname -m` and mapping hardware identifiers to iPhone generation | `ProcessInfo.processInfo.physicalMemory` | Direct, no table to maintain, handles future devices transparently. |
| GGUF validation / SHA256 | Custom checksum loop | Deferred — same tech-debt item as macOS (accepted limitation) | Listed in v1.0 milestone tech debt. Don't relitigate in this phase. |
| Swiss ß→ss rules | Full libICU transliteration | A 3-line regex in `ITNUtility` | Two Unicode characters (U+00DF → "ss", U+1E9E → "SS"), one regex. |
| Prompt construction | New Swiss-specific prompt | Extend `CleanupPrompt.build()` with one conditional line (D-18) | Prompt structure is proven; only add orthography instruction. |
| Pipeline orchestration | New iOS-specific pipeline | `Shared/Services/TextProcessingService.swift` (already injects `CleanupProvider?`) | Zero changes needed. |

## Key Technical Decisions (Answers to Research Questions)

### Q1. llama.swift SPM package on iOS

**Answer: It's a drop-in. No gotchas.** `Package.swift` declares `.iOS(.v16)` and the product is an XCFramework binary target downloaded from the llama.cpp GitHub release. The same package string that works for macOS works for iOS. Add to `iOS/project.yml` `packages:` and `targets.Dicticus.dependencies:` with `product: LlamaSwift`, and set `OTHER_LDFLAGS: "-framework llama"` the same way `macOS/project.yml` does.

**Potential issues to watch for:**
- The binary target is an XCFramework that bundles iOS-device, iOS-simulator (arm64 + x86_64), and macOS slices. Recent Xcode 16.3 / 17 validation has been strict about arm64-simulator-only slices — if that lands on us, the project.yml workaround is to use `CODE_SIGNING_ALLOWED: NO` for simulator configurations or drop the simulator slice. Not expected to hit, but mentioning for the planner.
- `ENABLE_HARDENED_RUNTIME` / `allow-unsigned-executable-memory` present on macOS target is **not needed on iOS** — iOS code signing model is different and the XCFramework is already signed. Do not propagate these entitlements.
- The `CleanupService.swift` import is `import LlamaSwift` (not `import llama`) — note the already-used import name from the macOS service.

[VERIFIED: Package.swift fetched 2026-04-24, `from: 2.8832.0` already shipping in `macOS/project.yml`]

### Q2. Metal performance on iPhone for Gemma 4 E2B Q4_K_M

**Answer: 15–25 tok/s on iPhone 14/15, 20–30+ tok/s on iPhone 15 Pro/16. The 8 s timeout (D-04) is realistic for typical dictation outputs (100–200 tokens) but has no headroom for long outputs.**

- Community benchmarks (multiple independent sources, 2025–2026) place iPhone 14/15 (A16, 6 GB) at ~15–25 tok/s for 2–3 B Q4_K_M models via llama.cpp Metal. Gemma 4 E2B at ~2.5 B effective params is at the larger end — expect the lower half of that range, so **budget 15–20 tok/s on iPhone 14**.
- Dictation outputs are typically ≤ input length. If user dictates ~30 s of speech (~100 input tokens → ~100–150 output tokens after cleanup), worst case is 150 / 15 = **10 s on iPhone 14** — already past the 8 s timeout. The existing `maxOutputTokens = 512` is a hard safety cap, but dictation output is rarely > 200 tokens.
- **No known iOS-specific Metal backend bugs in recent llama.cpp releases** (b8832+). Metal backend on iOS is first-class in the llama.cpp project since 2024.
- **First-inference cold-cache cost**: the first `llama_decode` call on a freshly loaded model incurs Metal shader compilation and KV-cache allocation — typically 1–2 s longer than steady-state. This is why the D-12 warmup Step 4 matters: it amortizes cold-cache cost into the warmup window, not the first cleanup call.

**Planner recommendation:** keep 8 s timeout as locked (D-04); do not adaptively raise it (deferred). Include a test case that exercises a long output (e.g., a 250-token dictation) and verifies timeout fallback path fires cleanly.

[CITED: dev.to "Run LLMs Locally on iPhone 2026", awesomeagents.ai Home GPU LLM Leaderboard; CONFIDENCE: MEDIUM — community benchmarks, not Apple-authoritative]

### Q3. URLSession progress delegate for ~3 GB download

**Answer: Use `URLSessionDownloadTask` + `URLSessionDownloadDelegate`, not the convenience async `URLSession.shared.download(from:)`.** The macOS `ModelDownloadService` uses the convenience API which gives zero progress callbacks — for iOS we need the delegate-based path. Pattern documented above (Pattern 2). Key APIs:

- `urlSession(_:downloadTask:didWriteData:totalBytesWritten:totalBytesExpectedToWrite:)` — called on every chunk; compute `progress = totalBytesWritten / totalBytesExpectedToWrite`.
- `cancel(byProducingResumeData:)` + `downloadTask(withResumeData:)` — clean pause/resume. Persist resume data in memory only (don't write to disk) — 3 GB is too large to want stale resume data.
- `URLSessionConfiguration.default.waitsForConnectivity = true` — handles Wi-Fi drops without user action.
- `urlSession(_:task:didCompleteWithError:)` — final callback; distinguish cancellation (user paused) from real error (retry prompt).

**Extract to `Shared/`?** The macOS `ModelDownloadService` is convenience-API-based and intentionally simple. Extracting the *new* delegate-based iOS version to `Shared/Services/IOSModelDownloadService.swift` and later migrating macOS to it is a refactor out of scope. **Recommendation: put the new delegate-based service in `iOS/Dicticus/Services/IOSModelDownloadService.swift`** and keep macOS as-is. `ModelDownloadService` on macOS stays; iOS gets a parallel implementation. The two services can share a constants file (URL, path, filename) via the `Shared/` helpers — that's the only duplication that matters.

[CITED: developer.apple.com NSURLSessionDownloadDelegate docs, Swift Forums downloadTask timeout thread; CONFIDENCE: HIGH]

### Q4. iOS memory pressure with 2.7 GB Parakeet + 3 GB Gemma resident

**Answer: Marginal but workable on iPhone 14 (6 GB) with the entitlement. iPhone 15 Pro / 16+ (8 GB) has comfortable headroom. Keep D-12 warmup-at-launch as locked, but ADD a memory-pressure fallback.**

Budget breakdown on iPhone 14 (6 GB total RAM):
- System + OS background services: ~1.0–1.5 GB
- Default app memory ceiling: ~3 GB
- With `increased-memory-limit` entitlement: ~4.5 GB [CITED: community observations, Apple forums — CONFIDENCE: MEDIUM]
- Parakeet TDT v3 CoreML resident: ~2.7 GB (measured in Phase 13)
- Gemma 4 E2B Q4_K_M resident: ~3.1 GB file + ~15–25% overhead = ~3.5–3.9 GB
- Both resident simultaneously: **~6.2–6.6 GB process size** — over the 4.5 GB entitled ceiling

**This means iPhone 14 cannot hold both models in full precision at the same time.** However, real-world measurements of llama.cpp Metal with `n_gpu_layers=99` show that after `llama_model_load_from_file`, much of the weight data is mapped (not copied) as Metal resources, and the *process RSS* hovers below the file size. PocketPal and LLMFarm ship Gemma 3/4 models on 6 GB iPhones in production, so the ceiling-margin is real but survivable.

**Recommendation to the planner:** lock in three mitigations on top of D-03's 5 GB gate:

1. **Mark GGUF `isExcludedFromBackup`** (covered in Q6) — unrelated to jetsam but required for quality bar.
2. **Add `DidReceiveMemoryWarning` handler** in `IOSCleanupService` (or app delegate) — on warning, free the LLM: `llama_sampler_free`, `llama_free`, `llama_model_free`, set `isLoaded = false`. The next dictation request returns raw text (D-26) instead of attempting cleanup. Restore on next cold app launch. This is PocketPal's "auto offload" pattern.
3. **Consider deferring D-12 Step 4 warmup on iPhone 14 specifically.** Alternative: warmup LLM on first *active* cleanup call, not at launch. This narrows the peak-pressure window to when the user is already actively dictating (and has consented to pay the latency). Downside: adds 5–15 s to first cleanup after cold launch. The planner should evaluate whether warming eagerly (D-12) is worth the jetsam risk during background → foreground transitions for iPhone 14 users.

**Do not override D-12 without user confirmation.** But surface #3 as a risk in the plan.

[ASSUMED: exact RSS numbers for Parakeet + Gemma co-resident on iPhone 14 — the ~4.5 GB ceiling is community-observed not Apple-documented; the mitigation patterns are from PocketPal/LLMFarm prior art, not from our own measurements]

### Q5. llama.cpp pointer hygiene across Swift 6 strict concurrency on iOS 18

**Answer: Identical to macOS. `nonisolated(unsafe)` everywhere a C pointer lives. Already solved.**

The macOS `CleanupService` (lines 46–52, 161–164) uses `nonisolated(unsafe)` for the model, context, and sampler pointers *and* for the locals captured into the detached inference task. This is the only pattern that compiles under Swift 6 strict concurrency because:
1. `deinit` is nonisolated by default — can't access `@MainActor` properties.
2. C pointers are not `Sendable`, so detached tasks can't capture `@MainActor`-isolated storage.

**No iOS-specific issue.** iOS 18 and macOS 15 share the Swift 6 compiler. Copy the pattern byte-for-byte. The `CleanupService` file is already a Swift 6 reference implementation; extracting it to `Shared/` (recommended in Q9) would get both platforms this correct pattern for free.

[VERIFIED: `macOS/Dicticus/Services/CleanupService.swift` lines 44–52, 161–164, shipping in v1.1.1]

### Q6. Application Support directory on iOS + iCloud backup exclusion

**Answer: Mark the GGUF `isExcludedFromBackup = true` immediately after move-to-final-path.**

- Application Support on iOS is backed up to iCloud by default.
- 3 GB of GGUF data in iCloud Backup is unacceptable: slow backups, user iCloud quota burn, potential App Review rejection under "don't store re-downloadable data in backed-up locations".
- Apple documents `isExcludedFromBackup` specifically for this case: cache-like / redownloadable data in Application Support should be excluded.

Implementation (in `IOSModelDownloadService.didFinishDownloadingTo`):
```swift
var targetURL = ModelDownloadService.modelPath()
try FileManager.default.moveItem(at: location, to: targetURL)
var values = URLResourceValues()
values.isExcludedFromBackup = true
try targetURL.setResourceValues(values)
```
Also apply the same flag to the parent `Dicticus/Models/` directory (set once, covers future files).

**Planner testing note:** include a verification step that reads `URLResourceValues(forKeys: [.isExcludedFromBackupKey])` and asserts `true` after download completes. This is a one-line unit test that prevents the regression.

[CITED: developer.apple.com `URLResourceKey/isExcludedFromBackupKey`, blog.eidinger.info; CONFIDENCE: HIGH]

### Q7. Validation Architecture (MANDATORY — see dedicated section below)

Full treatment in `## Validation Architecture` section.

### Q8. Similar projects / prior art

**Confirmed production iOS apps shipping llama.cpp + Gemma via Metal:**

| Project | Stack | Notes |
|---------|-------|-------|
| PocketPal AI | React Native + llama.rn bindings to llama.cpp | Ships Gemma 4 IT, Phi, Qwen, Bonsai on iPhone via App Store. Has "auto offload on backgrounding" pattern (model unload on background, reload on foreground). HF Hub integration for model browsing. |
| LLMFarm (guinmoon) | SwiftUI + llama.cpp direct integration | Open source. Direct Swift ↔ C pointer pattern (pre-dates llama.swift SPM). Reference for sampler chain construction. |
| LocalLLMClient (tattn) | Swift package, llama.cpp + MLX backends | Abstraction layer — less directly applicable since we don't need MLX. |
| SpeziLLM | XCFramework llama.cpp via SPM binary target | Same strategy as `mattt/llama.swift`; no unique learnings. |

**Patterns worth stealing:**
- PocketPal's **background auto-offload** — if app goes to background, free LLM to reclaim 3 GB; re-warm on foreground. Addresses Q4 memory pressure. **Recommendation: add as follow-up after ship**; not in Phase 19 scope per D-12 ("warmup at launch when toggle ON") but surface as a planner note.
- LLMFarm's **sampler chain configuration pattern** — essentially identical to our macOS `CleanupService.loadModel()`. Confirms our approach is standard.

**No iOS-specific Gemma 4 gotchas found** in public issue trackers for these projects beyond the memory-pressure observations already covered.

[CITED: github.com/a-ghorbani/pocketpal-ai, github.com/guinmoon/LLMFarm; CONFIDENCE: MEDIUM — based on README/docs, not code audit]

### Q9. Extract `CleanupService.swift` to `Shared/` vs duplicate?

**Strong recommendation: EXTRACT to `Shared/Services/CleanupService.swift`.**

Rationale:
- The current macOS `CleanupService.swift` has **zero macOS-specific imports**: `SwiftUI`, `LlamaSwift`, `os.log`. All available on iOS.
- Every line of logic (backend init, model load, sampler chain, tokenize/detokenize helpers, batched decode loop, timeout TaskGroup, preamble stripper, `deinit` cleanup) is platform-agnostic Swift.
- The only differences between platforms are:
  - **Timeout constant** (5 s macOS, 8 s iOS) — make it an `init` parameter with platform-default constants.
  - **`CleanupPrompt.build()` extension** (Swiss line) — already in `Shared/`, no per-platform code.
- The class already conforms to `CleanupProvider` (Shared protocol) and is consumed by `TextProcessingService` (Shared).
- **Risk of extraction is small**: macOS phase 4 is shipped and tested; moving the file to `Shared/Services/` and updating `macOS/project.yml` `sources:` keeps the same target inclusion. The iOS target already includes `../Shared` per `iOS/project.yml` line 23.

**Minimal extraction delta:**
1. Move `macOS/Dicticus/Services/CleanupService.swift` → `Shared/Services/CleanupService.swift`.
2. Parameterize `inferenceTimeoutSeconds` in `init(timeoutSeconds: TimeInterval = 5.0)`; iOS instantiator passes `8.0`.
3. Nothing else changes in the file.

**If the planner prefers lower blast radius**, the alternative is to copy the file to `iOS/Dicticus/Services/IOSCleanupService.swift` verbatim with only the timeout constant changed. Both options are acceptable per CONTEXT.md's "Claude's Discretion." Extract is preferred for the DRY win and for future Swiss prompt / sampler tuning to apply to both platforms without divergence.

[VERIFIED: read full `CleanupService.swift`, confirmed zero platform-specific code]

## Runtime State Inventory

(Phase 19 is not a rename/refactor phase, but the `IOSModelWarmupService` comment flip warrants mention.)

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | None — no user-visible data being renamed | None |
| Live service config | None | None |
| OS-registered state | None | None |
| Secrets/env vars | None — HuggingFace URL is public, no auth | None |
| Build artifacts | `iOS/project.yml` must be regenerated (add `llama` package + `LlamaSwift` product + `OTHER_LDFLAGS`) | Run `xcodegen generate` after edit; commit the regenerated `.xcodeproj` per existing convention |
| Code comments | `IOSModelWarmupService.swift` line 91 `// NOTE: No Step 4 (LLM) on iOS v2.0 — locked decision` | Remove in this phase |
| UserDefaults keys | NEW: `aiCleanupEnabled: Bool`, `swissGermanSpelling: Bool` | Define with `@AppStorage` in SettingsView; match macOS key naming if macOS uses similar keys |

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| `xcodegen` | Regenerating `iOS/Dicticus.xcodeproj` after `project.yml` changes | Assumed ✓ (used in all prior phases) | Any 2.x | Manual `.xcodeproj` edit (strongly discouraged) |
| Xcode 16+ | Swift 6 strict concurrency + iOS 18 SDK | ✓ per `iOS/project.yml` | 16.0+ | — |
| Physical iPhone 14+ or 6 GB+ simulator | Realistic memory-pressure + Metal performance testing | ✓ (developer device assumed per prior phases) | A16+ | Simulator tests only validate correctness, not jetsam behavior |
| Internet (Wi-Fi) | Downloading 3.1 GB GGUF during first toggle-flip | ✓ at dev time | — | Pre-download GGUF and sideload to Application Support for testing |
| HuggingFace CDN (`huggingface.co/unsloth/...`) | GGUF source | Available | — | Mirror to project-owned CDN (deferred tech debt item, shared with macOS) |

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | XCTest (iOS default via xcodegen `bundle.unit-test` target) |
| Config file | `iOS/project.yml` — `DicticusTests` target |
| Quick run command | `xcodebuild test -project iOS/Dicticus.xcodeproj -scheme Dicticus -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:DicticusTests/CleanupServiceTests` |
| Full suite command | `xcodebuild test -project iOS/Dicticus.xcodeproj -scheme Dicticus -destination 'platform=iOS Simulator,name=iPhone 15'` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|--------------|
| CLEAN-01 | Settings toggle enables AI cleanup path | unit (SettingsView @AppStorage binding) | `xcodebuild test ... -only-testing:DicticusTests/SettingsToggleTests` | ❌ Wave 0 |
| CLEAN-01 | TextProcessingService routes to cleanup when mode = .aiCleanup && service loaded | unit (inject mock CleanupProvider, assert call) | `xcodebuild test ... -only-testing:DicticusTests/TextProcessingServiceTests/testCleanupPath` | ❌ Wave 0 |
| CLEAN-01 | RAM gating hides toggle on <5 GB device | unit (inject ProcessInfo mock) | `xcodebuild test ... -only-testing:DicticusTests/DeviceEligibilityTests` | ❌ Wave 0 |
| CLEAN-02 | CleanupService loads GGUF, returns non-empty cleaned text (real model) | integration (requires GGUF in test fixture or skipped in CI) | `xcodebuild test ... -only-testing:DicticusTests/CleanupServiceTests/testRealModelInference` | ❌ Wave 0 (guard with `skipIfNoModel`) |
| CLEAN-02 | Cleanup returns raw text on timeout | unit (mock slow inference) | `xcodebuild test ... -only-testing:DicticusTests/CleanupServiceTests/testTimeoutFallback` | ❌ Wave 0 |
| CLEAN-02 | Cleanup returns raw text on concurrent call | unit | `xcodebuild test ... -only-testing:DicticusTests/CleanupServiceTests/testConcurrentCallGuard` | ❌ Wave 0 |
| D-16 | ß → ss deterministic | unit | `xcodebuild test ... -only-testing:DicticusTests/ITNUtilityTests/testSwissGermanEszett` | ❌ Wave 0 |
| D-17 | ẞ → SS (capital) | unit | `xcodebuild test ... -only-testing:DicticusTests/ITNUtilityTests/testSwissGermanCapitalEszett` | ❌ Wave 0 |
| D-19 | Post-LLM safety-net regex applied only when Swiss toggle ON | unit | `xcodebuild test ... -only-testing:DicticusTests/CleanupServiceTests/testSwissSafetyNetGating` | ❌ Wave 0 |
| D-06 | KV cache cleared between back-to-back calls (no context bleed) | integration | `xcodebuild test ... -only-testing:DicticusTests/CleanupServiceTests/testBackToBackCallsIndependent` | ❌ Wave 0 |
| D-27 | Control tokens in ASR output are sanitized before prompt build | unit (reused from macOS) | `xcodebuild test ... -only-testing:DicticusTests/CleanupPromptTests/testSanitizeControlTokens` | — existing macOS test covers `Shared/` code; confirm iOS target includes it |
| D-10 | Download delegate reports progress between 0 and 1 over at least 3 chunks | unit (mock `URLProtocol`) | `xcodebuild test ... -only-testing:DicticusTests/IOSModelDownloadServiceTests/testProgressCallbacks` | ❌ Wave 0 |
| D-10 | Pause produces resume data; resume restarts from checkpoint | unit (mock `URLProtocol` with Range header assertion) | `xcodebuild test ... -only-testing:DicticusTests/IOSModelDownloadServiceTests/testPauseResume` | ❌ Wave 0 |
| Q6 | GGUF marked isExcludedFromBackup after download | unit (invoke download, query resource value) | `xcodebuild test ... -only-testing:DicticusTests/IOSModelDownloadServiceTests/testBackupExclusion` | ❌ Wave 0 |

### Sampling Rate

- **Per task commit:** `CleanupServiceTests` + `ITNUtilityTests` + `IOSModelDownloadServiceTests` (unit-only, <30 s)
- **Per wave merge:** Full `DicticusTests` suite on iPhone 15 simulator (<2 min)
- **Phase gate (`/gsd-verify-work`):** Full suite green + manual smoke on physical iPhone 14 or 15 with real Gemma 4 E2B GGUF:
  - Toggle flip triggers download UI
  - Download completes, GGUF lands at expected path, backup flag set
  - Warmup Step 4 runs and `isLoaded = true`
  - Dictate "hallo velt das ist ein test" (German) → cleanup fixes to "Hallo Welt, das ist ein Test."
  - Swiss toggle ON → dictate word containing "ß" → output has "ss"
  - Force timeout by dictating very long text → verify raw text delivered
  - Memory profile: peak RSS during active cleanup < 4.5 GB on iPhone 14

### Wave 0 Gaps

- [ ] `iOS/DicticusTests/CleanupServiceTests.swift` — covers CLEAN-02, D-04, D-06, D-28
- [ ] `iOS/DicticusTests/SettingsToggleTests.swift` — covers CLEAN-01, D-08, D-15
- [ ] `iOS/DicticusTests/DeviceEligibilityTests.swift` — covers D-03
- [ ] `iOS/DicticusTests/ITNUtilityTests.swift` — covers D-16, D-17 (may already exist for German ITN; extend)
- [ ] `iOS/DicticusTests/IOSModelDownloadServiceTests.swift` — covers D-10, Q6 (backup exclusion)
- [ ] `iOS/DicticusTests/TextProcessingServiceTests.swift` — covers D-13 (block until cleanup completes), D-23 (injection pattern)
- [ ] Test fixture strategy for real-model integration tests: document a `DICTICUS_TEST_MODEL_PATH` env var; skip with clear message when absent so CI passes without the 3 GB file
- [ ] Mock `URLProtocol` helper for download tests — generic enough to share between this phase and any future download work

### Test Fixtures Needed

- **Swiss ß corpus** — a `SwissGerman.fixtures.json` in `DicticusTests/Fixtures/` with input/expected pairs covering: pure ASCII ("weiss"), single ß ("weiß"), multiple ß in one word, capital ẞ, mixed case, ß adjacent to punctuation, ß at word boundary.
- **Canary prompts** — a small corpus of known-good inputs and hand-verified cleanup outputs (3–5 German, 3–5 English). Used for the real-model integration tests; acceptable to have fuzzy equality (LLM output drifts between seeds).
- **Control-token injection attempts** — strings containing `<start_of_turn>`, `<end_of_turn>`, `<bos>`, `<eos>` as user dictation. Assert sanitizer removes them.
- **Preamble variants** — the fixed list from `CleanupService.stripPreamble` (macOS line 383–405) — reuse verbatim; extend only if new Swiss-specific preambles observed during UAT.

## Risks & Pitfalls

### Pitfall 1: Memory pressure → Jetsam on iPhone 14

**What goes wrong:** Parakeet + Gemma co-resident exceeds the `increased-memory-limit` entitled ceiling (~4.5 GB); iOS kills the app, user sees it disappear mid-dictation.
**Why it happens:** File size lies — a 3.1 GB GGUF has ~3.5–3.9 GB RSS under llama.cpp Metal after decoder state + KV cache + activations. Add Parakeet's 2.7 GB and you're over budget on 6 GB devices.
**How to avoid:**
- Lock the 5 GB `ProcessInfo.physicalMemory` gate (D-03).
- Add `didReceiveMemoryWarning` → free LLM resources path.
- Ensure the D-29 `llama_backend_init()` is called once and only once.
- Run memory profiling in Xcode Instruments on a physical iPhone 14 during active cleanup.
**Warning signs:** `vm-compressor-space-shortage` in device logs; app termination with reason "Jetsam"; crash reports missing user-visible error.

### Pitfall 2: 3 GB in iCloud Backup without `isExcludedFromBackup`

**What goes wrong:** User's iCloud Backup balloons by 3 GB; slow backups; Apple App Review flags it.
**Why it happens:** `FileManager.default.moveItem` to Application Support doesn't set `isExcludedFromBackup`; default is false.
**How to avoid:** Set `isExcludedFromBackup = true` on the GGUF file (and its parent directory) immediately after move. Unit test asserts the flag is set.

### Pitfall 3: Context bleed between back-to-back cleanup calls (Pitfall 5 from macOS phase 4)

**What goes wrong:** Second cleanup call returns text influenced by the first call's prompt/output.
**Why it happens:** KV cache is persistent across decode invocations unless explicitly cleared.
**How to avoid:** Call `llama_memory_clear(llama_get_memory(ctx), false)` at start of every inference (D-06). Already in macOS `CleanupService.runInference` — port verbatim.
**Warning signs:** Cleanup output contains snippets from a prior dictation; test via back-to-back distinct-content dictations.

### Pitfall 4: Preamble leakage ("Here's the polished text: ...")

**What goes wrong:** Gemma sometimes prepends conversational preamble despite "Output ONLY" instruction. User sees "Here is the corrected text: Hallo Welt" in their clipboard.
**Why it happens:** Model pretrained behavior; instruction-following is imperfect.
**How to avoid:** Port `stripPreamble()` from macOS verbatim. The preamble list (macOS lines 383–405) is proven; extend only if Swiss-specific preambles emerge during UAT.
**Swiss note:** existing preambles like "Hier ist der korrigierte Text:" work for Swiss too (no ß in that phrase). No new preamble entries expected.

### Pitfall 5: Control-token injection via ASR output

**What goes wrong:** User says "start of turn" (or ASR produces similar); Gemma sees raw `<start_of_turn>` in input and treats subsequent text as a new conversation turn.
**Why it happens:** Chat template tokens are just strings in the prompt; no escape layer.
**How to avoid:** `CleanupPrompt.sanitizeControlTokens` strips all 4 chat-template tokens (D-27). Already in Shared code. Must run *before* prompt assembly; existing `build()` does this.

### Pitfall 6: Null-byte bug in detokenizer output

**What goes wrong:** Output string has invisible U+0000 characters rendered as double spaces.
**Why it happens:** `String(decoding: buffer, as: UTF8.self)` over a 256-byte buffer includes trailing `\0` bytes.
**How to avoid:** macOS `tokenToPiece` uses `buffer.prefix(Int(nChars)).map { UInt8(bitPattern: $0) }` to slice exactly. Port verbatim. Existing — don't re-derive.

### Pitfall 7: Swift 6 `deinit` + `@MainActor` + C pointer interaction

**What goes wrong:** Compiler error "deinit cannot access property isolated to main actor".
**Why it happens:** `deinit` is nonisolated; `@MainActor` properties are isolated.
**How to avoid:** Mark every C pointer `private nonisolated(unsafe) var`. Already in macOS service; don't change the pattern on iOS.

### Pitfall 8: Warmup Step 4 on Step 1 model-download first-run

**What goes wrong:** User flips AI cleanup toggle → warmup retriggers → Parakeet download runs twice / in parallel with LLM download.
**Why it happens:** `IOSModelWarmupService.warmup()` guards against `isWarming`, but the service is designed for a one-shot lifecycle.
**How to avoid:** Make Step 4 an independent method: `warmupCleanup()` called separately after download completes, not a re-entry into `warmup()`. Or: gate Step 4 behind `isReady == true` and a separate `cleanupIsReady` flag.

### Pitfall 9: Timeout cancellation must be cooperative

**What goes wrong:** 8 s timeout fires; inference task keeps running in the background; C pointers mutated concurrently with next cleanup call; undefined behavior.
**Why it happens:** `group.cancelAll()` sets the flag but the inference loop must check it.
**How to avoid:** `runInference` checks `Task.isCancelled` between every token (macOS line 273). Do not remove or skip this check.

### Pitfall 10: `aiCleanupEnabled` toggle flips during download

**What goes wrong:** User flips toggle ON → download starts → user flips toggle OFF → download continues in background → 3 GB wasted.
**Why it happens:** No download cancellation on toggle OFF.
**How to avoid:** Toggle OFF while `state == .downloading` calls `task.cancel()` and clears any partial resume data. UI should reflect "cancelled" state.

## Similar Projects / Prior Art

| Project | Link | What to Learn |
|---------|------|---------------|
| PocketPal AI (a-ghorbani) | https://github.com/a-ghorbani/pocketpal-ai | Auto-offload on background; HuggingFace integration; real-time tok/s UI (deferred for us) |
| LLMFarm (guinmoon) | https://github.com/guinmoon/LLMFarm | Swift + llama.cpp direct bindings; mature sampler chain patterns |
| LocalLLMClient (tattn) | dev.to/tattn/localllmclient | Swift package abstraction over llama.cpp and MLX (useful for future MLX migration, not now) |
| SpeziLLM | Cited in search results | Another XCFramework-via-SPM consumer; confirms our approach |

**Our macOS Phase 4 implementation** (shipped 2026-04-17) is itself prior art — the most relevant and directly-applicable reference.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `llama_kv_cache_clear` | `llama_memory_clear(llama_get_memory(ctx), false)` | llama.cpp ~2024-Q4 | Already handled in macOS Phase 4 RESEARCH Pitfall 5; port verbatim |
| Vocab via `llama_model_*` | Vocab via `llama_vocab*` from `llama_model_get_vocab` | llama.cpp b3500+ | Already in macOS service; no action |
| `URLSession.shared.download(from:)` convenience | `URLSessionDownloadTask` + delegate for progress | Apple stable API | iOS-only new work; macOS keeps convenience API |
| Gemma 3 1B | Gemma 4 E2B Q4_K_M | CLAUDE.md v1.1 update | Already in macOS; iOS uses same |

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | iPhone 14 `increased-memory-limit` ceiling is ~4.5 GB | Q4, Pitfall 1 | Memory budget miscalculated; may need to skip Step 4 warmup or fall back to on-demand load |
| A2 | Gemma 4 E2B Q4_K_M decode at 15–25 tok/s on iPhone 14 Metal | Q2, Pitfall in timeout tuning | If actual is <10 tok/s, 8 s timeout is too tight for ~150-token outputs |
| A3 | RSS overhead on a 3.1 GB GGUF is 15–25% | Q4 | If higher (e.g., 50%), co-residency on iPhone 14 fails outright — must defer D-12 warmup |
| A4 | iOS 18 XCFramework slice of `mattt/llama.swift` builds clean in Xcode 16+ with no workarounds | Q1 | If validation errors, extra project.yml gymnastics needed |
| A5 | `com.apple.developer.kernel.increased-memory-limit` on iPhone 14 raises ceiling (not just supported device flag) | Q4 | If entitlement is no-op on 6 GB devices for some iOS versions, peak memory comes down hard against 3 GB default |

**Assumptions A1–A3 should be validated empirically during Wave 0 by running the existing macOS `CleanupService` in a barebones iOS harness on an iPhone 14 simulator and a real device. Those measurements are the single most de-risking action in this phase.**

## Open Questions

1. **Should warmup Step 4 be eager or lazy on iPhone 14 specifically?**
   - What we know: D-12 locks eager-at-launch. Q4 memory analysis shows iPhone 14 is within a few hundred MB of the entitled ceiling with both models resident.
   - What's unclear: actual co-residency RSS on a real iPhone 14 with real workload.
   - Recommendation: measure during Wave 0 before committing. If co-residency fails, escalate to user to revisit D-12 (not planner's call to override a locked decision).

2. **Does CLEAN-01 require the toggle to disable cleanup without deleting the 3 GB GGUF, or does OFF also delete?**
   - What we know: CONTEXT.md D-08 says toggle default OFF; "Reset AI Cleanup" affordance is listed as Claude's discretion.
   - What's unclear: user's expectation when they toggle OFF after having downloaded.
   - Recommendation: default = keep GGUF on disk; provide optional "Reset AI Cleanup" action (discretionary per CONTEXT.md) that deletes the GGUF and sets toggle OFF.

3. **Should the Swiss safety-net regex (D-19) apply only when AI cleanup is ON, or also to plain-mode German?**
   - What we know: D-16 applies ß→ss in ITN layer when Swiss toggle is ON (plain dictation too). D-19 is specifically "post-LLM".
   - What's unclear: whether D-16 is sufficient to cover plain-mode without the D-19 safety net — they're idempotent, so running D-19 even without LLM is harmless.
   - Recommendation: keep D-16 and D-19 as distinct call sites per CONTEXT.md; D-19 runs only in the AI-cleanup branch. This is what CONTEXT.md literally says.

## Code Examples

### Swiss ß→ss regex (ITNUtility extension)

```swift
extension ITNUtility {
    /// Convert German ß → ss and ẞ → SS. Case-aware via Unicode (U+00DF, U+1E9E).
    /// Applied when Swiss German Spelling toggle is ON (D-16, D-17).
    static func applySwissOrthography(to text: String) -> String {
        return text
            .replacingOccurrences(of: "ß", with: "ss")
            .replacingOccurrences(of: "ẞ", with: "SS")
    }
}
```
Simple string replace is sufficient — no regex needed for these two codepoints. Keep the function signature symmetric with `applyITN(to:language:)`.

### CleanupPrompt Swiss extension (D-18)

```swift
// In CleanupPrompt.build(...):
static func build(text: String,
                  language: String? = nil,
                  dictionaryContext: [String: String]? = nil,
                  swissGerman: Bool = false) -> String {   // NEW param
    // ... existing body up to INPUT line ...

    if swissGerman, language == "de" {
        prompt += "SWISS GERMAN RULES: Use Swiss orthography (never use 'ß', always 'ss'). "
        prompt += "Use Swiss thousands separator with apostrophe (e.g. 1'250, not 1.250).\n"
    }

    prompt += "INPUT: \(sanitizedText)<end_of_turn>\n"
    // ...
}
```

### Integration in CleanupService

```swift
// In cleanup():
let swissGerman = UserDefaults.standard.bool(forKey: "swissGermanSpelling")
let prompt = CleanupPrompt.build(
    text: text,
    language: language,
    dictionaryContext: dictionaryContext,
    swissGerman: swissGerman
)

// ... inference ...

var cleaned = Self.stripPreamble(result)
if swissGerman {
    cleaned = ITNUtility.applySwissOrthography(to: cleaned)  // D-19 safety net
}
return cleaned.isEmpty ? text : cleaned
```

### RAM gate

```swift
enum DeviceCapability {
    static var canRunAICleanup: Bool {
        let bytes = ProcessInfo.processInfo.physicalMemory
        let gb = Double(bytes) / 1_073_741_824.0  // 1024^3
        return gb >= 5.0
    }
}

// In SettingsView:
if DeviceCapability.canRunAICleanup {
    Toggle("AI Cleanup", isOn: $aiCleanupEnabled)
} else {
    VStack(alignment: .leading) {
        Toggle("AI Cleanup", isOn: .constant(false))
            .disabled(true)
        Text("Requires iPhone 14 or newer")
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}
```

## Sources

### Primary (HIGH confidence)
- `mattt/llama.swift` Package.swift (fetched raw): iOS 16+, XCFramework binary, `LlamaSwift` product — https://github.com/mattt/llama.swift
- `macOS/Dicticus/Services/CleanupService.swift` (read in full) — our own shipping Phase 4 implementation
- `macOS/project.yml` (read) — verified `llama` package declaration, `OTHER_LDFLAGS: "-framework llama"`
- `iOS/project.yml` (read) — verified `increased-memory-limit` entitlement present, `Shared/` already included
- `Shared/Models/CleanupPrompt.swift`, `Shared/Protocols/CleanupProvider.swift`, `Shared/Services/TextProcessingService.swift`, `Shared/Utilities/ITNUtility.swift` (all read) — verified reuse surface
- Apple Documentation: `isExcludedFromBackup` — https://developer.apple.com/documentation/foundation/urlresourcevalues/isexcludedfrombackup
- Apple Documentation: `URLSessionDownloadDelegate` — https://developer.apple.com/documentation/foundation/nsurlsessiondownloaddelegate/1409408-urlsession

### Secondary (MEDIUM confidence)
- PocketPal AI (README + App Store listing): confirms Gemma 4 on iOS via llama.cpp shipping — https://github.com/a-ghorbani/pocketpal-ai
- LLMFarm: open-source iOS llama.cpp app — https://github.com/guinmoon/LLMFarm
- Apple Developer Forums thread 777370 on memory limits and VM compression — https://developer.apple.com/forums/thread/777370
- dev.to: Run LLMs Locally on iPhone 2026 (tok/s benchmarks) — https://dev.to/alichherawalla/how-to-run-llms-locally-on-your-iphone-in-2026-completely-offline-no-subscription-4b3a
- Apple Developer Documentation: `com.apple.developer.kernel.increased-memory-limit` entitlement — https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.kernel.increased-memory-limit
- Swift Forums: URLSession downloadTask timeout + resume data behavior — https://forums.swift.org/t/urlsession-downloadtask-cannot-configure-timeout-and-also-cannot-downlaod-with-resume-data/55654

### Tertiary (LOW confidence — to validate empirically)
- Community reports of iPhone 14 `increased-memory-limit` ceiling ≈ 4.5 GB (multiple forum posts, no single authoritative source)
- Community reports of Gemma 4 E2B Q4_K_M tok/s on iPhone 14 (~15–20 tok/s, extrapolated from Gemma 3 / Phi-3 benchmarks)
- ~15–25% RSS overhead over GGUF file size under llama.cpp Metal on iOS

## Metadata

**Confidence breakdown:**
- Standard stack (llama.swift on iOS): HIGH — Package.swift verified, macOS already ships same package
- Architecture (service extraction, pipeline seams): HIGH — direct port of shipping macOS code
- Swift 6 concurrency patterns: HIGH — proven in macOS service
- Memory ceiling on iPhone 14 with entitlement: MEDIUM — community-reported, not Apple-documented; must validate on device
- Decode tok/s on iPhone 14 for Gemma 4 E2B: MEDIUM — benchmark extrapolation; measure in Wave 0
- URLSession delegate pattern: HIGH — documented Apple API
- iCloud backup exclusion: HIGH — documented Apple API

**Research date:** 2026-04-24
**Valid until:** 2026-05-24 (30 days — llama.cpp releases weekly; `mattt/llama.swift` tracks upstream)

---

## Project Constraints (from CLAUDE.md)

- **Privacy:** No audio or text leaves the device. GGUF download is from HuggingFace CDN (content delivery only, no telemetry) — confirmed compliant.
- **Performance:** "Near-instant after releasing the hotkey (< 2–3 seconds)" — with 8 s cleanup timeout, cleanup mode violates the 2–3 s plain-mode target. This is accepted per D-13 (block until cleanup completes) — cleanup is an opt-in trade-off.
- **Swift 6 / iOS 18:** iOS target is set to iOS 17.0 minimum in `iOS/project.yml`. llama.swift requires iOS 16+ so we're comfortably above the floor. Swift 6 strict concurrency handled via `nonisolated(unsafe)` pattern.
- **GSD workflow:** All changes in this phase go through `/gsd-execute-phase`; no direct edits.
- **xcodegen:** Project regeneration on every `project.yml` edit.
- **Branching:** Feature branch, no direct main commits — existing convention.
