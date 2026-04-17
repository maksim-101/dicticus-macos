# Phase 4: AI Cleanup - Research

**Researched:** 2026-04-17
**Domain:** Local LLM inference (llama.cpp), text cleanup prompting, Swift/C interop
**Confidence:** HIGH

## Summary

Phase 4 integrates Gemma 3 1B instruction-tuned GGUF via llama.cpp into the existing dictation pipeline. The user presses the AI cleanup hotkey (already registered in Phase 3), speaks, releases, and gets grammar-corrected, punctuation-fixed text pasted at cursor. The core technical challenges are: (1) integrating llama.cpp as an SPM dependency callable from Swift, (2) downloading a ~722 MB GGUF model on first run, (3) constructing language-specific Gemma 3 cleanup prompts, and (4) keeping total ASR + LLM latency under 4 seconds.

The llama.cpp ecosystem provides mature Swift integration via `mattt/llama.swift` (version 2.8832.0), which wraps the official ggml-org XCFramework as a semantically-versioned SPM binary target -- no C++ interop flags or unsafe build settings needed. Metal GPU acceleration is automatic on Apple Silicon, and Gemma 3 1B at Q4_0 quantization requires only ~722 MB on disk and ~1 GB resident memory, well within the budget alongside Parakeet TDT v3.

**Primary recommendation:** Use `mattt/llama.swift` as the SPM dependency (binary XCFramework approach), download the ungated `unsloth/gemma-3-1b-it-GGUF` Q4_0 file on first run via URLSession, and construct single-turn Gemma 3 cleanup prompts with system instructions embedded in the user turn.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Conservative cleanup only -- grammar correction, punctuation, capitalization, and filler word removal. No sentence restructuring, no rephrasing, no content changes.
- **D-02:** Language-specific prompt templates -- use detected language from NLLanguageRecognizer to select German or English cleanup prompt.
- **D-03:** Output must be plain text only -- no markdown, no formatting, no explanations.
- **D-04:** Gemma 3 1B IT (QAT Q4_0 GGUF) as the cleanup model.
- **D-05:** llama.cpp as the inference runtime -- Swift-callable via C API, Metal backend.
- **D-06:** No network calls during inference -- fully local.
- **D-07:** Load LLM at startup alongside ASR models -- extend ModelWarmupService.
- **D-08:** Single warmup flow -- combined progress for ASR and LLM. LLM loading sequential after ASR.
- **D-09:** Download GGUF model on first run -- same pattern as FluidAudio/Parakeet HuggingFace download.
- **D-10:** Cache model in Application Support directory.
- **D-11:** Wire AI cleanup in HotkeyManager.handleKeyUp -- when mode is .aiCleanup, pass ASR result through CleanupService before TextInjector.
- **D-12:** New CleanupService as @MainActor ObservableObject.
- **D-13:** Language auto-selection -- CleanupService reads DicticusTranscriptionResult.language.
- **D-14:** Extend icon state machine with cleanup state.
- **D-15:** Add .cleaning state to distinguish ASR processing from LLM cleanup visually.
- **D-16:** No separate notification for cleanup -- icon state machine provides feedback.
- **D-17:** 4-second total latency target for ASR + LLM on typical utterances.
- **D-18:** Timeout guard on LLM inference -- if cleanup exceeds 5 seconds, paste raw ASR text as fallback.
- **D-19:** LLM failure fallback -- paste raw ASR transcription and post notification.
- **D-20:** Model not loaded fallback -- show "Model loading..." notification.

### Claude's Discretion
- llama.cpp SPM integration approach (C API bridging header vs. Swift wrapper package)
- Specific prompt wording for German and English cleanup templates
- llama.cpp inference parameters (temperature, top-k, max tokens, etc.)
- Exact SF Symbol choice for cleanup state icon
- GGUF model download implementation details (HuggingFace URL, caching logic)
- CleanupService internal architecture (sync vs async inference, threading)
- Whether to extend TranscriptionService.State enum or use a separate state in HotkeyManager

### Deferred Ideas (OUT OF SCOPE)
- Heavy rewrite mode (EMODE-01) -- Phi-3 Mini 3.8B. Deferred to v2.
- Prompt customization (EMODE-02). Deferred to v2.
- Streaming LLM output. Unnecessary for short cleanup outputs.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| AICLEAN-01 | Light cleanup mode via separate hotkey (grammar, punctuation, filler word removal) | CleanupService with Gemma 3 cleanup prompts, wired into HotkeyManager.handleKeyUp for .aiCleanup mode |
| AICLEAN-02 | Cleanup preserves the user's original words and meaning -- only fixes form | Prompt template design with explicit "do not rephrase" instructions; conservative temperature (0.1-0.3) |
| AICLEAN-03 | Cleanup works for both German and English text | Language-specific prompt templates selected via DicticusTranscriptionResult.language ("de"/"en") |
| AICLEAN-04 | LLM runs fully locally with no cloud calls | llama.cpp Metal inference, GGUF model cached in Application Support, no network during inference |
| INFRA-02 | LLM model loads at startup, stays warm | Extend ModelWarmupService.warmup() to initialize llama.cpp context after FluidAudio warmup |
</phase_requirements>

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| llama.swift (mattt) | 2.8832.0 | llama.cpp XCFramework for Swift | Semantically-versioned SPM binary target wrapping official ggml-org llama.cpp XCFramework; no C++ interop flags needed, Metal GPU included, macOS 13+/iOS 16+ [VERIFIED: GitHub API -- tag 2.8832.0 exists, corresponds to upstream b8832] |
| Gemma 3 1B IT Q4_0 GGUF | unsloth/gemma-3-1b-it-GGUF | Cleanup LLM model | 722 MB, ungated, instruction-tuned, 140+ languages including German, Q4_0 quantization [VERIFIED: HuggingFace -- file gemma-3-1b-it-Q4_0.gguf, 722 MB, no gating] |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| URLSession | macOS built-in | GGUF model download | First-run download from HuggingFace CDN |
| FileManager | macOS built-in | Model caching | Store GGUF in Application Support/Dicticus/Models/ |
| NLLanguageRecognizer | macOS built-in | Language detection | Already used by TranscriptionService; consumed by CleanupService for prompt selection |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| mattt/llama.swift | StanfordBDHG/llama.cpp | Stanford fork requires C++ interop flags (.interoperabilityMode(.Cxx)) which must propagate to all dependencies; last release 0.3.3 (May 2024), significantly behind upstream. mattt/llama.swift uses binary XCFramework (no compiler flags needed) and auto-tracks upstream releases |
| mattt/llama.swift | Direct ggml-org/llama.cpp Package.swift | Uses unsafeFlags which prevents semantic versioning via SPM; compilation issues reported in issue #10371 |
| mattt/llama.swift | Build XCFramework manually via build-xcframework.sh | Works but adds build complexity and maintenance burden; mattt/llama.swift automates this |
| unsloth Q4_0 GGUF | Google QAT Q4_0 GGUF | Google QAT version has better quality (54% less perplexity drop) but is **gated** -- requires HuggingFace login and Google license acceptance, making automated first-run download impossible without an auth token. Unsloth Q4_0 is ungated and publicly downloadable |
| Gemma 3 1B | Gemma 3 4B | 4B would be higher quality but ~3x the size (~2.5 GB), slower inference, higher memory pressure alongside Parakeet |

**Installation (project.yml):**
```yaml
packages:
  llama:
    url: https://github.com/mattt/llama.swift.git
    from: 2.8832.0
```

Add to targets.Dicticus.dependencies:
```yaml
  - package: llama
    product: llama
```

**Version verification:**
- llama.swift 2.8832.0 -- verified via GitHub API, published 2026-04-17 [VERIFIED: GitHub tags API]
- Gemma 3 1B IT Q4_0 GGUF -- 722 MB, ungated at unsloth/gemma-3-1b-it-GGUF [VERIFIED: HuggingFace resolve/main]

## Architecture Patterns

### Recommended Project Structure
```
Dicticus/Dicticus/
  Services/
    CleanupService.swift       # NEW: LLM cleanup pipeline
    ModelDownloadService.swift  # NEW: GGUF download + caching
    ModelWarmupService.swift    # EXTEND: Add LLM initialization step
    HotkeyManager.swift        # EXTEND: Wire .aiCleanup pipeline
    TranscriptionService.swift  # UNCHANGED
    TextInjector.swift          # UNCHANGED
    NotificationService.swift   # EXTEND: Add cleanup-specific notifications
  Models/
    TranscriptionResult.swift   # UNCHANGED
    CleanupPrompt.swift         # NEW: Language-specific prompt templates
  DicticusApp.swift             # EXTEND: Wire CleanupService, extend icon state
```

### Pattern 1: CleanupService as @MainActor ObservableObject
**What:** Follows the established TranscriptionService pattern -- @MainActor class with @Published state, injected via .environmentObject() or direct reference.
**When to use:** For all LLM cleanup operations.
**Example:**
```swift
// Source: Established project pattern from TranscriptionService + llama.cpp SwiftUI example
@MainActor
class CleanupService: ObservableObject {
    enum State: Equatable, Sendable {
        case idle
        case cleaning
    }
    
    @Published var state: State = .idle
    
    // llama.cpp context -- initialized during warmup, kept warm
    private var llamaContext: OpaquePointer?  // llama_context*
    private var llamaModel: OpaquePointer?    // llama_model*
    private var llamaSampler: OpaquePointer?  // llama_sampler*
    
    /// Clean up transcribed text using local LLM.
    /// - Parameters:
    ///   - text: Raw ASR transcription
    ///   - language: "de" or "en" from DicticusTranscriptionResult.language
    /// - Returns: Cleaned text, or original text on failure
    func cleanup(text: String, language: String) async -> String {
        guard let context = llamaContext else { return text }
        state = .cleaning
        defer { state = .idle }
        
        let prompt = CleanupPrompt.build(for: text, language: language)
        // ... tokenize, decode, sample, detokenize
        return cleanedText
    }
}
```

### Pattern 2: Gemma 3 Prompt Template (Single-Turn Cleanup)
**What:** Gemma 3 uses `<start_of_turn>user` / `<end_of_turn>` / `<start_of_turn>model` control tokens. No system role exists -- system instructions go inside the user turn.
**When to use:** Every cleanup invocation.
**Example:**
```swift
// Source: https://ai.google.dev/gemma/docs/core/prompt-structure [CITED]
struct CleanupPrompt {
    static func build(for text: String, language: String) -> String {
        let instruction: String
        switch language {
        case "de":
            instruction = """
            Korrigiere den folgenden diktierten Text. Behebe Grammatik-, Zeichensetzungs- und \
            Grossschreibungsfehler. Entferne Fuellwoerter (aehm, halt, also, quasi, sozusagen). \
            Aendere KEINE Woerter und formuliere NICHT um. Gib NUR den korrigierten Text aus, \
            ohne Erklaerungen.
            """
        default: // "en"
            instruction = """
            Fix the following dictated text. Correct grammar, punctuation, and capitalization \
            errors. Remove filler words (um, uh, like, you know, so, basically). Do NOT change \
            any words and do NOT rephrase. Output ONLY the corrected text, no explanations.
            """
        }
        return "<start_of_turn>user\n\(instruction)\n\nText: \(text)<end_of_turn>\n<start_of_turn>model\n"
    }
}
```

### Pattern 3: LLM Warmup Extension in ModelWarmupService
**What:** Extend the existing warmup() method to initialize llama.cpp context after FluidAudio ASR + VAD are ready. Sequential (not parallel) to avoid memory pressure spikes.
**When to use:** App startup.
**Example:**
```swift
// Source: Existing ModelWarmupService pattern + llama.cpp SwiftUI example [CITED]
// Inside ModelWarmupService.warmup(), after Step 3 (VAD init):

// Step 4: Initialize llama.cpp for LLM cleanup
llama_backend_init()
var modelParams = llama_model_default_params()
modelParams.n_gpu_layers = 99  // Offload everything to Metal GPU
let modelPath = ModelDownloadService.modelPath().path
let model = llama_model_load_from_file(modelPath, modelParams)

var ctxParams = llama_context_default_params()
ctxParams.n_ctx = 2048       // Context window (enough for dictation cleanup)
ctxParams.n_batch = 512      // Batch size for prompt processing
ctxParams.n_threads = 4      // CPU threads (Metal handles most work)
let context = llama_new_context_with_model(model, ctxParams)
```

### Pattern 4: Token Generation Loop
**What:** The inference loop: tokenize prompt, decode, sample token by token until EOS or max tokens.
**When to use:** Inside CleanupService.cleanup().
**Example:**
```swift
// Source: llama.cpp SwiftUI example LibLlama.swift [CITED]
// 1. Tokenize the prompt
let tokens = tokenize(text: prompt, addBos: true)

// 2. Create and fill a batch with prompt tokens
var batch = llama_batch_init(Int32(tokens.count), 0, 1)
for (i, token) in tokens.enumerated() {
    llama_batch_add(&batch, token, Int32(i), [0], i == tokens.count - 1)
}
llama_decode(context, batch)

// 3. Sample loop -- generate tokens until EOS or max_tokens
var outputTokens: [llama_token] = []
let maxTokens: Int32 = 512  // Dictation cleanup output is short
while outputTokens.count < maxTokens {
    let newToken = llama_sampler_sample(sampler, context, -1)
    if llama_vocab_is_eog(model, newToken) { break }
    outputTokens.append(newToken)
    // Prepare next batch with single token
    llama_batch_clear(&batch)
    llama_batch_add(&batch, newToken, Int32(tokens.count + outputTokens.count), [0], true)
    llama_decode(context, batch)
}

// 4. Detokenize output
let result = outputTokens.map { tokenToPiece($0) }.joined()
```

### Pattern 5: Model Download with Progress
**What:** Download GGUF from HuggingFace CDN on first run, cache in Application Support.
**When to use:** First launch (before LLM warmup can proceed).
**Example:**
```swift
// Source: Standard URLSession download pattern [ASSUMED]
class ModelDownloadService {
    static let modelURL = URL(string: "https://huggingface.co/unsloth/gemma-3-1b-it-GGUF/resolve/main/gemma-3-1b-it-Q4_0.gguf")!
    
    static func modelPath() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("Dicticus/Models/gemma-3-1b-it-Q4_0.gguf")
    }
    
    static func isModelCached() -> Bool {
        FileManager.default.fileExists(atPath: modelPath().path)
    }
    
    static func download() async throws {
        guard !isModelCached() else { return }
        let dir = modelPath().deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let (tempURL, _) = try await URLSession.shared.download(from: modelURL)
        try FileManager.default.moveItem(at: tempURL, to: modelPath())
    }
}
```

### Anti-Patterns to Avoid
- **Running llama.cpp inference on the main thread:** Token generation is CPU/GPU intensive. Always dispatch to a background thread via Task.detached or similar, following the existing warmup pattern.
- **Creating a new llama_context per cleanup call:** Context creation involves KV cache allocation (~32-64 MB for 2048 context). Create once at warmup, reuse via llama_kv_cache_clear() between calls.
- **Using llama_chat_apply_template from C API:** While available, it requires managing C message structs. For a single-turn cleanup prompt, constructing the prompt string directly in Swift is simpler and more maintainable.
- **Setting temperature too high (>0.5) for cleanup:** High temperature introduces creative variations that would violate AICLEAN-02 (preserve original meaning). Use very low temperature (0.1-0.3) for conservative corrections.
- **Forgetting to set stop tokens:** Gemma 3 uses `<end_of_turn>` as stop token. Without it, the model may generate additional turns or rambling output.
- **Parallel ASR + LLM warmup:** D-08 explicitly requires sequential loading to avoid memory pressure spikes. Parakeet CoreML compilation can peak at 2+ GB; launching llama.cpp model loading simultaneously could cause OOM on 16 GB machines.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| LLM inference runtime | Custom GGUF parser/executor | llama.cpp via mattt/llama.swift | Decades of optimization in quantized inference, Metal GPU kernels, KV cache management |
| GGUF model format parsing | Custom binary parser | llama.cpp's llama_model_load_from_file | GGUF format is complex with version differences, metadata, tensor layouts |
| Token sampling | Greedy argmax | llama.cpp sampler chain (temperature + top-k + top-p) | Proper sampling avoids degenerate repetition while staying conservative |
| Gemma chat template | Hardcoded string concatenation | Defined prompt template struct with language switching | Template tokens must be exact; a struct centralizes this and makes testing easy |
| HuggingFace file download | Custom HTTP client | URLSession.shared.download(from:) | Built-in resume support, proper temp file handling, progress via delegate |

**Key insight:** llama.cpp encapsulates all the hard parts of local LLM inference (quantized matrix operations, Metal GPU dispatch, KV cache management, tokenizer handling). The app's job is only: (1) download the model file, (2) load it at startup, (3) construct prompts, and (4) feed text in / get text out.

## Common Pitfalls

### Pitfall 1: Google QAT GGUF is Gated
**What goes wrong:** The official `google/gemma-3-1b-it-qat-q4_0-gguf` on HuggingFace requires login + Google license acceptance. Automated download in the app fails with HTTP 401/403.
**Why it happens:** Google gates Gemma models behind a license agreement on HuggingFace.
**How to avoid:** Use `unsloth/gemma-3-1b-it-GGUF` (Q4_0, 722 MB) which is ungated and publicly downloadable. The quality difference vs QAT is minor for a 1B model doing light text cleanup. [VERIFIED: HuggingFace -- google repo shows "you have to accept the conditions to access its files"; unsloth repo has no gating]
**Warning signs:** HTTP 401 from HuggingFace during first-run download; users seeing "download failed" on first launch.

### Pitfall 2: llama.cpp C++ Interop Flags Propagation
**What goes wrong:** Some llama.cpp SPM integrations require `.interoperabilityMode(.Cxx)` Swift settings, which must propagate to ALL targets in the dependency tree, including test targets.
**Why it happens:** llama.cpp is C++; Swift/C++ interop is opt-in and must be enabled at every consuming target level.
**How to avoid:** Use `mattt/llama.swift` which provides a precompiled XCFramework binary target -- no C++ interop flags needed in your project at all. The C API is exposed directly to Swift via the framework's module map.
**Warning signs:** Compilation errors mentioning "C++ interop" or "interoperabilityMode" in Xcode build logs.

### Pitfall 3: Memory Pressure with Concurrent Model Loading
**What goes wrong:** Loading Parakeet CoreML (~2.69 GB download, ~1.24 GB compiled) and Gemma GGUF (~722 MB) simultaneously spikes memory usage above available unified memory on 16 GB machines.
**Why it happens:** CoreML compilation is memory-intensive; llama.cpp model loading also allocates KV cache.
**How to avoid:** D-08 requires sequential loading. LLM init happens AFTER ASR + VAD warmup completes. Estimated combined resident memory: ~1.24 GB (Parakeet) + ~66 MB (FluidAudio inference) + ~1 GB (Gemma in memory) + ~32 MB (KV cache 2048) = ~2.4 GB total. Comfortable on 16 GB.
**Warning signs:** App crashes during first-launch warmup on 16 GB machines; Xcode memory gauge spiking above 4 GB.

### Pitfall 4: Gemma Output Contains Preamble/Explanation
**What goes wrong:** Instead of returning just the cleaned text, Gemma outputs "Here is the corrected text:" or similar preamble, violating D-03.
**Why it happens:** Instruction-tuned models tend to be conversational. Without explicit "output ONLY the corrected text" instructions, they add explanations.
**How to avoid:** Prompt template must include explicit "Output ONLY the corrected text, no explanations" instruction. Also set temperature very low (0.1-0.3) to reduce creative deviations. Post-processing: strip any text before the first actual content line if the model adds a preamble.
**Warning signs:** Cleaned text contains phrases like "Here is", "Sure!", "The corrected text is:" prepended to actual output.

### Pitfall 5: KV Cache Not Cleared Between Cleanup Calls
**What goes wrong:** Second cleanup call produces garbled or contextually confused output because the KV cache still contains tokens from the previous cleanup.
**Why it happens:** llama.cpp maintains KV cache state between calls for multi-turn conversation support. For independent cleanup calls, this is wrong.
**How to avoid:** Call `llama_kv_cache_clear(context)` at the start of each cleanup invocation, before tokenizing the new prompt. Also call `llama_sampler_reset(sampler)` to reset sampler state.
**Warning signs:** Second and subsequent cleanup calls produce nonsensical output or reference content from previous transcriptions.

### Pitfall 6: Timeout Not Enforced on LLM Inference
**What goes wrong:** For unusually long transcriptions, the LLM generation loop runs for 10+ seconds, making the app feel frozen.
**Why it happens:** No timeout guard on the token generation loop; long input = many output tokens.
**How to avoid:** D-18 requires a 5-second timeout. Implement via `Task.withTimeout` or a deadline check inside the generation loop. On timeout, return the raw ASR text as fallback (D-19).
**Warning signs:** Status bar icon stays in "cleaning" state for more than 5 seconds after release.

### Pitfall 7: Swift 6 Actor Isolation with C Pointers
**What goes wrong:** Compilation errors when passing llama.cpp C pointer types (OpaquePointer) across actor boundaries, or when calling C functions from @MainActor context.
**Why it happens:** Swift 6 strict concurrency requires Sendable conformance for cross-isolation transfers. OpaquePointer is not Sendable.
**How to avoid:** Keep all llama.cpp C pointer operations within a single isolation domain. Either: (a) wrap in a dedicated actor (like the official example's `actor LlamaContext`), or (b) keep in CleanupService (@MainActor) and dispatch heavy work via Task.detached using raw pointer values. The official example uses an actor pattern.
**Warning signs:** Swift 6 compiler errors about non-Sendable types crossing actor boundaries.

## Code Examples

### Complete Cleanup Pipeline Integration
```swift
// Source: Synthesis of established project patterns + llama.cpp SwiftUI example
// In HotkeyManager.handleKeyUp(mode:), extending the existing Task:

case .aiCleanup:
    Task { [weak self] in
        guard let self else { return }
        do {
            let result = try await service.stopRecordingAndTranscribe()
            // NEW: Pass through CleanupService before injection
            let cleanedText: String
            if let cleanupService = self.cleanupService {
                cleanedText = await cleanupService.cleanup(
                    text: result.text,
                    language: result.language
                )
            } else {
                // Fallback: paste raw ASR text if cleanup service unavailable
                cleanedText = result.text
            }
            await self.textInjector.injectText(cleanedText)
        } catch is CancellationError {
            // Task cancelled -- silent
        } catch let error as TranscriptionError {
            // Same error handling as plain mode
            // ...
        }
    }
```

### Sampler Chain Configuration
```swift
// Source: llama.cpp SwiftUI example + Gemma best practices [CITED: LibLlama.swift]
// Conservative sampling for text cleanup (AICLEAN-02: preserve meaning)
let sampler = llama_sampler_chain_init(llama_sampler_chain_default_params())
// Temperature: very low for deterministic cleanup
llama_sampler_chain_add(sampler, llama_sampler_init_temp(0.2))
// Top-K: limit vocabulary to top candidates
llama_sampler_chain_add(sampler, llama_sampler_init_top_k(40))
// Top-P: nucleus sampling for remaining diversity
llama_sampler_chain_add(sampler, llama_sampler_init_top_p(0.9, 1))
// Distribution sampling (selects from filtered distribution)
llama_sampler_chain_add(sampler, llama_sampler_init_dist(UInt32.random(in: 0...UInt32.max)))
```

### Icon State Machine Extension
```swift
// Source: Existing DicticusApp.iconName pattern [VERIFIED: DicticusApp.swift]
// Extend iconName with cleanup state:
private var iconName: String {
    if !permissionManager.allGranted {
        return "mic.slash"
    }
    if hotkeyManager.isRecording {
        return "mic.fill"
    }
    if let service = transcriptionService, service.state == .transcribing {
        return "waveform.circle"
    }
    // NEW: Cleanup state indicator
    if let cleanup = cleanupService, cleanup.state == .cleaning {
        return "sparkles"  // SF Symbol for AI processing
    }
    return "mic"
}
// Update symbolEffect to pulse during cleaning:
.symbolEffect(.pulse, isActive: warmupService.isWarming 
    || (transcriptionService?.state == .transcribing)
    || (cleanupService?.state == .cleaning))
```

### Inference Parameters Summary
```
// Recommended llama.cpp parameters for dictation cleanup:
n_ctx = 2048        // Context window (input prompt + output tokens)
n_batch = 512       // Tokens processed per decode call (prompt eval)
n_threads = 4       // CPU threads (Metal handles matrix ops)
n_gpu_layers = 99   // Offload all layers to Metal GPU
temperature = 0.2   // Very low for conservative corrections
top_k = 40          // Standard top-K filtering
top_p = 0.9         // Nucleus sampling threshold
max_tokens = 512    // Max output tokens (cleanup is always shorter than input)
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| llama.cpp source compilation in SPM | Precompiled XCFramework via mattt/llama.swift | 2025 | No C++ interop flags needed, faster builds, semantic versioning |
| StanfordBDHG/llama.cpp fork (v0.3.3) | mattt/llama.swift (v2.8832.0) | 2025-2026 | Stanford fork is 2 years behind upstream; mattt auto-tracks releases |
| Manual prompt formatting | llama_chat_apply_template C API | 2024 | Available but manual formatting is simpler for single-turn use cases |
| Gemma 2 | Gemma 3 (1B IT) | 2025 | Gemma 3 has better multilingual support (140+ languages), QAT support |

**Deprecated/outdated:**
- **StanfordBDHG/llama.cpp v0.3.3:** Last release May 2024, significantly behind upstream. Use mattt/llama.swift instead.
- **alexrozanski/llama.swift:** Archived/unmaintained fork of older llama.cpp. Not usable.
- **Ollama / LM Studio integration:** Daemon-based, adds latency and dependency -- rejected per CLAUDE.md stack decisions.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | mattt/llama.swift XCFramework includes Metal GPU support (compiled with Metal enabled) | Standard Stack | If Metal not included, GPU offload fails and inference falls back to CPU-only, likely 3-5x slower. Mitigation: verify at build time by checking `n_gpu_layers` takes effect |
| A2 | Gemma 3 1B at Q4_0 can produce acceptable German grammar corrections | Architecture Patterns | If German cleanup quality is poor, may need to switch to Q4_K_M (806 MB) or 4B model. Mitigation: test with German sentences during development |
| A3 | Temperature 0.2 with top-k 40 produces deterministic-enough cleanup without degenerate output | Code Examples | If too deterministic, may produce repetitive patterns. If too creative, violates AICLEAN-02. Mitigation: tunable parameters, test empirically |
| A4 | 722 MB GGUF + ~1 GB resident memory is accurate for Gemma 3 1B Q4_0 on Metal | Common Pitfalls | If actual resident memory is higher (e.g., 2 GB), may pressure 16 GB machines. Mitigation: measure actual memory in Instruments during testing |
| A5 | unsloth Q4_0 quantization quality is sufficient for light text cleanup (vs Google QAT) | Standard Stack | QAT has 54% less perplexity degradation. For a simple cleanup task, standard Q4_0 should be adequate, but untested. Mitigation: can switch to bartowski QAT reuploads if quality is poor |
| A6 | URLSession.shared.download(from:) can download 722 MB reliably without custom resume logic | Architecture Patterns | Large downloads may fail on poor connections. Mitigation: implement retry with resume data support in a follow-up if needed |

## Open Questions

1. **mattt/llama.swift Metal GPU verification**
   - What we know: The package wraps the official ggml-org XCFramework which is built with Metal support for Apple platforms.
   - What's unclear: Whether the specific XCFramework binary in the SPM package has Metal enabled (vs CPU-only build).
   - Recommendation: Add a verification step in the first implementation task -- check that `n_gpu_layers > 0` is effective by comparing inference speed with/without GPU layers. If Metal is missing, fall back to building from source or using the official build-xcframework.sh script.

2. **Gemma 3 1B German cleanup quality**
   - What we know: Gemma 3 supports 140+ languages and is instruction-tuned. German is included.
   - What's unclear: Whether a 1B model can reliably fix German grammar (cases, compound nouns, comma rules) with just a prompt.
   - Recommendation: Test empirically with 10-15 German dictation samples during CleanupService development. If quality is insufficient, consider upgrading to Q4_K_M quantization or testing with the 4B model.

3. **Exact first-run download time impact**
   - What we know: 722 MB download + 2.69 GB Parakeet download = ~3.4 GB on first launch.
   - What's unclear: Whether downloading both models on first run creates an unacceptable wait.
   - Recommendation: The existing warmup UI already handles long first-run downloads (10-minute timeout for Parakeet). Adding 722 MB is ~27% more download. Sequential downloading means total time increases linearly. Consider showing separate progress indicators per model if warmup takes significantly longer.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Swift 6 | Swift/C interop, concurrency | Yes | 6.3.1 | -- |
| Xcode | Build system | Yes | 26.4.1 | -- |
| xcodegen | Project generation | Yes | 2.45.3 | -- |
| Apple Silicon (Metal) | GPU-accelerated LLM inference | Yes | M4 Pro | CPU fallback (slower) |
| Internet (first run) | GGUF model download | Yes | -- | Bundle model in app (increases app size by 722 MB) |
| HuggingFace CDN | Model file hosting | Yes | -- | Mirror URL or app-bundled model |

**Missing dependencies with no fallback:** None.
**Missing dependencies with fallback:** None -- all required dependencies are available.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | XCTest (built-in, Swift 6) |
| Config file | Dicticus/DicticusTests/ (existing test directory) |
| Quick run command | `xcodebuild test -project Dicticus/Dicticus.xcodeproj -scheme Dicticus -testPlan DicticusTests -only-testing DicticusTests 2>&1 \| tail -20` |
| Full suite command | `xcodebuild test -project Dicticus/Dicticus.xcodeproj -scheme Dicticus 2>&1 \| tail -30` |

### Phase Requirements to Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| AICLEAN-01 | Cleanup mode produces corrected text | integration (requires model) | `xcodebuild test ... -only-testing DicticusTests/CleanupServiceTests/testCleanupProducesOutput` | No -- Wave 0 |
| AICLEAN-02 | Cleanup preserves original meaning (no rephrasing) | unit (prompt validation) | `xcodebuild test ... -only-testing DicticusTests/CleanupPromptTests/testPromptContainsPreservationInstruction` | No -- Wave 0 |
| AICLEAN-03 | German and English prompts differ | unit | `xcodebuild test ... -only-testing DicticusTests/CleanupPromptTests/testGermanPromptDiffersFromEnglish` | No -- Wave 0 |
| AICLEAN-04 | No network calls during inference | unit (architecture verification) | `xcodebuild test ... -only-testing DicticusTests/CleanupServiceTests/testNoNetworkDuringInference` | No -- Wave 0 |
| INFRA-02 | LLM loads at startup after ASR | unit (warmup state machine) | `xcodebuild test ... -only-testing DicticusTests/ModelWarmupServiceTests/testWarmupIncludesLLM` | No -- Wave 0 |

### Sampling Rate
- **Per task commit:** Quick run command (unit tests only, ~10s)
- **Per wave merge:** Full suite (~30s including all tests)
- **Phase gate:** Full suite green before /gsd-verify-work

### Wave 0 Gaps
- [ ] `DicticusTests/CleanupServiceTests.swift` -- covers AICLEAN-01, AICLEAN-04 (state machine tests without model; integration tests with XCTSkipUnless)
- [ ] `DicticusTests/CleanupPromptTests.swift` -- covers AICLEAN-02, AICLEAN-03 (pure unit tests on prompt template strings)
- [ ] `DicticusTests/ModelDownloadServiceTests.swift` -- covers model path computation, cache detection logic (no actual downloads)
- [ ] Extend `DicticusTests/ModelWarmupServiceTests.swift` -- covers INFRA-02 (warmup state machine with LLM step)
- [ ] Extend `DicticusTests/HotkeyManagerTests.swift` -- covers .aiCleanup mode routing

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | No | N/A -- local app, no auth |
| V3 Session Management | No | N/A -- no sessions |
| V4 Access Control | No | N/A -- single user |
| V5 Input Validation | Yes | Prompt injection guard: user-dictated text is placed in a fixed template position, never interpreted as instructions. Output validation: strip any non-text artifacts from LLM output |
| V6 Cryptography | No | N/A -- no encryption |

### Known Threat Patterns for llama.cpp + Gemma

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Prompt injection via dictated text | Tampering | Fixed prompt template with user text in a clearly delimited data position ("Text: ..."); instruction portion is hardcoded, not user-controllable. LLM output is treated as plain text, never executed |
| Malicious GGUF file (supply chain) | Tampering | Download from known HuggingFace repo (unsloth); verify file size on download completion; llama.cpp validates GGUF magic bytes on load |
| LLM output contains harmful content | Information Disclosure | For dictation cleanup, input is the user's own speech -- output is a minor variation. Risk is minimal. No external data enters the pipeline |
| Memory safety in C interop | Elevation of Privilege | All llama.cpp C pointer operations confined to CleanupService actor/class boundary; deinit frees all resources; no raw pointer escapes |

## Sources

### Primary (HIGH confidence)
- [llama.cpp GitHub repository](https://github.com/ggml-org/llama.cpp) -- C API reference, SwiftUI example, Metal support
- [mattt/llama.swift GitHub](https://github.com/mattt/llama.swift) -- SPM binary target wrapping official XCFramework, version 2.8832.0
- [Gemma 3 prompt structure](https://ai.google.dev/gemma/docs/core/prompt-structure) -- official chat template format, control tokens
- [google/gemma-3-1b-it-qat-q4_0-gguf HuggingFace](https://huggingface.co/google/gemma-3-1b-it-qat-q4_0-gguf) -- gated model, license requirements verified
- [unsloth/gemma-3-1b-it-GGUF HuggingFace](https://huggingface.co/unsloth/gemma-3-1b-it-GGUF) -- ungated Q4_0 GGUF, 722 MB, publicly downloadable
- [Templates supported by llama_chat_apply_template](https://github.com/ggml-org/llama.cpp/wiki/Templates-supported-by-llama_chat_apply_template) -- Gemma template confirmation

### Secondary (MEDIUM confidence)
- [llama.cpp SwiftUI example LibLlama.swift](https://github.com/ggml-org/llama.cpp/blob/master/examples/llama.swiftui/llama.cpp.swift/LibLlama.swift) -- Swift/C API usage patterns
- [Gemma 3 QAT blog post](https://developers.googleblog.com/en/gemma-3-quantized-aware-trained-state-of-the-art-ai-to-consumer-gpus/) -- QAT vs standard quantization quality comparison
- [llama.cpp Performance on Apple Silicon M-series](https://github.com/ggml-org/llama.cpp/discussions/4167) -- Metal performance benchmarks
- [How to use llama.cpp in iOS apps](https://zenn.dev/laiso/articles/c4f2c1794f17e3) -- Swift integration guide with C API function reference

### Tertiary (LOW confidence)
- [pgorzelany/swift-llama-cpp](https://github.com/pgorzelany/swift-llama-cpp) -- alternative Swift wrapper, referenced for API patterns only
- [StanfordBDHG/llama.cpp](https://github.com/StanfordBDHG/llama.cpp) -- deprecated fork, documented as not recommended

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- mattt/llama.swift verified via GitHub API, unsloth GGUF verified via HuggingFace
- Architecture: HIGH -- patterns derived from official llama.cpp SwiftUI example and existing project conventions
- Pitfalls: HIGH -- gated model issue verified directly on HuggingFace; memory estimates cross-referenced with multiple sources
- Prompt templates: MEDIUM -- Gemma 3 prompt format verified via official docs, but actual cleanup quality with 1B model is assumed adequate (A2, A5)
- Inference parameters: MEDIUM -- derived from examples and general LLM best practices, not empirically tested for this specific use case (A3)

**Research date:** 2026-04-17
**Valid until:** 2026-05-17 (30 days -- llama.cpp releases frequently but API is stable; model files are immutable)
