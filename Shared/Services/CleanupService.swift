import SwiftUI
import LlamaSwift
import os.log

/// Local LLM cleanup service using Gemma 4 E2B via llama.cpp.
///
/// Per D-12: @MainActor ObservableObject following established service pattern.
/// Per D-05: llama.cpp Metal backend for Apple Silicon GPU acceleration.
/// Per D-06: No network calls during inference — fully local (AICLEAN-04).
/// Per D-17: 4-second total latency target (ASR ~1s + LLM ~3s).
/// Per D-18: 5-second timeout on LLM inference — fallback to raw text.
/// Per D-19: On any failure, return raw ASR text (never lose dictation).
///
/// Lifecycle: initialized during warmup (Plan 03), kept warm, cleanup() called per invocation.
/// KV cache cleared between calls to prevent context bleed (Pitfall 5 from RESEARCH.md).
/// Memory is cleared via llama_memory_clear(llama_get_memory(ctx), false) which is the
/// current llama.cpp API replacing the deprecated llama_kv_cache_clear.
///
/// Swift/C type mapping for llama.cpp:
///   - llama_model* → OpaquePointer (forward-declared struct)
///   - llama_context* → OpaquePointer (forward-declared struct)
///   - llama_sampler* → UnsafeMutablePointer<llama_sampler> (fully defined struct)
///   - llama_vocab* → OpaquePointer (forward-declared struct)
///   - llama_memory_t → OpaquePointer (typedef of llama_memory_i*, forward-declared)
@MainActor
class CleanupService: ObservableObject, CleanupProvider {

    /// Cleanup pipeline state. Observed by DicticusApp for icon state (D-14, D-15).
    enum State: Equatable, Sendable {
        case idle
        case cleaning
    }

    @Published var state: State = .idle

    /// Whether the LLM model is loaded and ready for inference.
    /// Set to true after successful loadModel() call.
    /// nonisolated(unsafe): loadModel runs off-MainActor (see Phase 20.06 fix —
    /// llama_model_load_from_file is a synchronous ~30s C call that previously
    /// blocked the UI when invoked via MainActor.run). Reads from cleanup()
    /// (MainActor) happen long after warmup completes — race window is benign.
    nonisolated(unsafe) private(set) var isLoaded = false

    // MARK: - llama.cpp resources (kept warm between calls)

    /// llama_model pointer — loaded once during warmup, freed in deinit.
    /// llama_model is forward-declared only in llama.h → OpaquePointer in Swift.
    /// nonisolated(unsafe): deinit is nonisolated in Swift 6, so non-Sendable C pointer
    /// properties must be marked nonisolated(unsafe) to be accessible from deinit.
    private nonisolated(unsafe) var model: OpaquePointer?
    /// llama_context pointer — created once during warmup, freed in deinit.
    /// llama_context is forward-declared only in llama.h → OpaquePointer in Swift.
    private nonisolated(unsafe) var context: OpaquePointer?
    /// Sampler chain — created once, reset between calls.
    /// llama_sampler is a fully-defined struct in llama.h → UnsafeMutablePointer<llama_sampler> in Swift.
    private nonisolated(unsafe) var sampler: UnsafeMutablePointer<llama_sampler>?

    #if DEBUG_RECORDER
    /// Filename of the loaded GGUF model — captured during loadModel for the
    /// debug recorder. Lives only in DEBUG_RECORDER builds.
    private nonisolated(unsafe) var loadedModelName: String = "unknown"

    /// Trace from the most recent cleanup() invocation. TextProcessingService
    /// reads this immediately after awaiting cleanup() to assemble the JSONL
    /// record. Single-writer/single-reader — no lock needed.
    public nonisolated(unsafe) var lastDebugTrace: CleanupServiceTrace?
    #endif

    // MARK: - Configuration

    /// Maximum output tokens for cleanup. Dictation cleanup output is always
    /// shorter than or equal to input length, so 512 tokens is generous.
    /// Configurable per-platform via init (default matches macOS/iOS behavior).
    private let maxOutputTokens: Int32

    /// LLM inference timeout in seconds (per D-04 iOS, D-18 macOS).
    /// If exceeded, cleanup returns raw ASR text as fallback.
    /// Platform defaults diverge: iOS uses 8.0 s (Neural Engine is slower),
    /// macOS passes 5.0 s explicitly at call-site to preserve v1.x behavior.
    private let inferenceTimeoutSeconds: TimeInterval

    // MARK: - Initialization

    /// Platform-agnostic initializer. iOS uses the default 8 s timeout (D-04);
    /// macOS passes `inferenceTimeoutSeconds: 5.0` explicitly to preserve the
    /// tighter pre-extraction behavior.
    ///
    /// - Parameters:
    ///   - inferenceTimeoutSeconds: Per-call inference timeout before falling
    ///     back to raw ASR text. Default 8.0 (D-04, iOS-tuned).
    ///   - maxOutputTokens: Upper bound on generated tokens. Default 512 —
    ///     dictation outputs are always ≤ input length so 512 is generous.
    /// nonisolated so the warmup pipeline can construct the service from a
    /// background `Task.detached`, avoiding a MainActor hop just to allocate
    /// a couple of stored properties.
    nonisolated init(inferenceTimeoutSeconds: TimeInterval = 8.0, maxOutputTokens: Int32 = 512) {
        self.inferenceTimeoutSeconds = inferenceTimeoutSeconds
        self.maxOutputTokens = maxOutputTokens
    }

    /// Initialize the llama.cpp backend.
    /// Must be called once before loadModel(). Called during app warmup.
    /// nonisolated so the warmup pipeline can call it from a `Task.detached`
    /// without bouncing through MainActor.
    nonisolated static func initializeBackend() {
        llama_backend_init()
    }

    /// Load the GGUF model and create the inference context.
    ///
    /// Called once during warmup (ModelWarmupService Step 4).
    /// After this returns successfully, cleanup() can be called.
    ///
    /// - Parameter modelPath: File path to the cached GGUF model
    /// - Throws: CleanupError if model file cannot be loaded or context creation fails
    ///
    /// nonisolated: `llama_model_load_from_file` is a synchronous C call that
    /// takes ~30s on iOS for a 3 GB GGUF. Calling it on MainActor freezes the
    /// UI (Phase 20.06 hotfix — black-screen reproduce). All mutated state is
    /// either `nonisolated(unsafe)` (model/context/sampler/isLoaded) or `let`
    /// (config), so it's safe to run from a detached background task.
    nonisolated func loadModel(from modelPath: String) throws {
        // Model parameters: offload all layers to Metal GPU (D-05)
        var modelParams = llama_model_default_params()
        modelParams.n_gpu_layers = 99  // All layers on Metal GPU

        guard let loadedModel = llama_model_load_from_file(modelPath, modelParams) else {
            throw CleanupError.modelLoadFailed
        }
        self.model = loadedModel

        // Context parameters for dictation cleanup
        var ctxParams = llama_context_default_params()
        ctxParams.n_ctx = 2048       // Context window (prompt + output)
        // n_batch must accommodate the full prompt — runInference submits the
        // entire prompt as one llama_decode call (no chunking). Plan 20.08-05's
        // German variant (g15) prompt + a 250-token utterance crosses 512 tokens
        // and triggers GGML_ABORT inside llama_context::decode. Match n_batch to
        // n_ctx so any prompt fitting the context window decodes in one batch.
        ctxParams.n_batch = 2048     // Batch size for prompt processing
        ctxParams.n_threads = 4      // CPU threads (Metal handles matrix ops)

        guard let ctx = llama_init_from_model(loadedModel, ctxParams) else {
            llama_model_free(loadedModel)
            self.model = nil
            throw CleanupError.contextCreationFailed
        }
        self.context = ctx

        #if DEBUG_RECORDER
        self.loadedModelName = (modelPath as NSString).lastPathComponent
        #endif

        // Sampler chain: conservative settings for text cleanup (AICLEAN-02).
        // Phase 20.08: chain order matches llama-server's conventional order
        // (top_k → top_p → temp → dist). Earlier macOS code applied temp first,
        // which peaks the distribution before filtering and can collapse into
        // degenerate token loops on long inputs (observed on F4 in spike). The
        // /tmp/spike-harness path uses the conventional order and produces
        // clean output on identical params; aligning macOS removes the
        // divergence and unblocks long-sentence cleanup.
        let samplerChain = llama_sampler_chain_init(llama_sampler_chain_default_params())
        // Top-K 40: limit vocabulary to top candidates
        llama_sampler_chain_add(samplerChain, llama_sampler_init_top_k(40))
        // Top-P 0.9: nucleus sampling
        llama_sampler_chain_add(samplerChain, llama_sampler_init_top_p(0.9, 1))
        // Phase 20 D-01: temperature reduced from 0.2 → 0.1 to reduce hallucination rate.
        // Levenshtein gate (CleanupService.gateLLMOutput, plan 20.02) is the fail-safe.
        llama_sampler_chain_add(samplerChain, llama_sampler_init_temp(0.1))
        // Distribution sampling with random seed
        llama_sampler_chain_add(samplerChain, llama_sampler_init_dist(UInt32.random(in: 0...UInt32.max)))
        self.sampler = samplerChain

        isLoaded = true
    }

    // MARK: - Cleanup

    /// Whether inference is currently running. Guards against concurrent cleanup calls
    /// that would race on the shared llama.cpp C pointers (model, context, sampler).
    private var isInferring = false

    /// Clean up transcribed text using the local LLM.
    ///
    /// Per D-01: Conservative cleanup — grammar, punctuation, capitalization, filler removal.
    /// Per D-13: Language auto-selected from DicticusTranscriptionResult.language.
    /// Per D-18: 5-second timeout — returns raw text on timeout.
    /// Per D-19: On any failure, returns original text (never lose dictation).
    ///
    /// - Parameters:
    ///   - text: The text to clean up
    ///   - language: Detected language code
    ///   - dictionaryContext: Optional dictionary entries to guide the LLM
    /// - Returns: Cleaned text, or original text on failure/timeout
    func cleanup(text: String, language: String, dictionaryContext: [String: String]? = nil) async -> String {
        let log = Logger(subsystem: "com.dicticus", category: "cleanup")

        guard isLoaded, let model = model, let context = context, let sampler = sampler else {
            log.warning("cleanup: model not loaded, returning raw text")
            return text  // D-19: Fallback to raw text
        }

        // Reject concurrent calls — C pointers are not thread-safe
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

        // WR-03 fix (Phase 19.5): Snapshot the Swiss-toggle decision exactly
        // ONCE at the top of cleanup() and pass that same value to both the
        // prompt builder and the post-LLM Swiss formatting pass. Without this
        // snapshot, a user toggling the setting during the 0.5-8 s inference
        // window could cause prompt/post-pass disagreement (prompt instructs
        // Swiss output but post-pass skips formatting, or vice versa).
        let swissDefaults = UserDefaults(suiteName: "group.com.dicticus") ?? UserDefaults.standard
        let useSwissGerman = swissDefaults.bool(forKey: "useSwissGerman")

        let prompt = CleanupPrompt.build(
            text: text,
            language: language,
            dictionaryContext: dictionaryContext,
            useSwissGerman: useSwissGerman
        )
        log.info("Prompt (\(prompt.count, privacy: .public) chars, lang=\(language, privacy: .public)): \(prompt.prefix(500), privacy: .public)")

        // Run inference in a detached task with timeout (D-04 iOS / D-18 macOS)
        // nonisolated(unsafe) for C pointer access in detached context (Pitfall 7)
        nonisolated(unsafe) let unsafeModel = model
        nonisolated(unsafe) let unsafeContext = context
        nonisolated(unsafe) let unsafeSampler = sampler
        let maxTokens = maxOutputTokens
        // Capture timeout locally for Sendable safety inside the task group closure.
        let timeout = self.inferenceTimeoutSeconds

        #if DEBUG_RECORDER
        let llmStart = Date()
        // Reset before each call so a thrown/timed-out path leaves no stale trace.
        self.lastDebugTrace = nil
        #endif

        do {
            let result = try await withThrowingTaskGroup(of: String.self) { group in
                group.addTask {
                    // Timeout task — honors the parameterized inferenceTimeoutSeconds
                    try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                    throw CleanupError.timeout
                }

                group.addTask {
                    // Inference task — checks Task.isCancelled between tokens
                    return Self.runInference(
                        prompt: prompt,
                        model: unsafeModel,
                        context: unsafeContext,
                        sampler: unsafeSampler,
                        maxTokens: maxTokens,
                        stopSequences: [
                            "In:", "Original:", "ORIGINAL:",
                            "Please provide", "Based on", "Glossary:", "Examples:"
                        ]
                    )
                }

                // Return whichever finishes first
                guard let firstResult = try await group.next() else {
                    log.warning("cleanup: task group returned nil")
                    return text
                }
                group.cancelAll()
                return firstResult
            }

            #if DEBUG_RECORDER
            let llmMs = Date().timeIntervalSince(llmStart) * 1000.0
            self.lastDebugTrace = CleanupServiceTrace(
                prompt: prompt,
                llmRaw: result,
                llmMs: llmMs,
                modelName: self.loadedModelName,
                samplerTemp: 0.1,
                samplerTopK: 40,
                samplerTopP: 0.9,
                samplerMaxTokens: Int(self.maxOutputTokens)
            )
            #endif

            // Post-process: strip any preamble the model might add (Pitfall 4)
            log.info("LLM raw (\(result.count, privacy: .public) chars): \(result.prefix(500), privacy: .public)")
            var cleaned = Self.stripPreamble(result)
            log.info("After strip (\(cleaned.count, privacy: .public) chars): \(cleaned.prefix(500), privacy: .public)")

            // D-B1c (Phase 19.5): Currency anti-flip post-LLM revert. Fires on
            // language == "de" regardless of Swiss toggle (per D-B2). Reverts any
            // model-substituted currency labels (e.g., EUR ← CHF) using positional
            // best-match against the input. Numeric values stay as the model wrote
            // them — only the currency LABEL is corrected. Graceful-degradation:
            // utility returns its `output` argument unchanged on any unexpected shape.
            if language == "de" {
                cleaned = CurrencyAntiFlip.revertCurrencyFlip(input: text, output: cleaned)
            }

            // D-19: Post-LLM Swiss ß→ss safety-net — catch any ß the LLM slipped in
            // despite the D-18 prompt instruction. WR-03 fix (Phase 19.5):
            // gated on the SAME `useSwissGerman` snapshot taken at the top of
            // cleanup(); a mid-inference toggle change cannot desync prompt
            // intent and post-pass formatting.
            //
            // Phase 19.5 follow-up: SwissNumberFormatter no longer runs here —
            // it moved to TextProcessingService Step 3b so it also fires for
            // plain dictation and for LLM timeout/failure paths (which return
            // the raw input text from this catch block).
            if useSwissGerman {
                cleaned = ITNUtility.applySwissITN(to: cleaned)
            }

            // Phase 28 Plan 03 — VARIANT-A-WINNER (per harness results/contraction_matrix_winner.md):
            // No post-LLM contraction gate. The V19D K2-contraction few-shot (Plan 28-01) alone
            // satisfied D-14 acceptance criteria. The harness runner remains in-tree
            // (.planning/debug/harness/run_contraction_matrix.py) for future re-runs.

            return cleaned.isEmpty ? text : cleaned

        } catch {
            log.error("cleanup error: \(error.localizedDescription, privacy: .public)")
            // D-19: Any failure -> return raw text
            return text
        }
    }

    // MARK: - Inference (nonisolated for detached task execution)

    /// Run the llama.cpp inference loop.
    ///
    /// This is a pure function operating on C pointers — no actor isolation needed.
    /// Called from a detached task inside cleanup().
    ///
    /// Steps:
    ///   1. Clear KV cache (Pitfall 5: prevent context bleed between calls)
    ///      Uses llama_memory_clear(llama_get_memory(ctx), false) — current API
    ///      replacing the removed llama_kv_cache_clear from older llama.cpp versions.
    ///   2. Reset sampler state
    ///   3. Tokenize prompt (via llama_vocab* from llama_model_get_vocab)
    ///   4. Decode prompt tokens (batch processing)
    ///   5. Sample output tokens until EOS or max_tokens
    ///   6. Detokenize output
    private nonisolated static func runInference(
        prompt: String,
        model: OpaquePointer,
        context: OpaquePointer,
        sampler: UnsafeMutablePointer<llama_sampler>,
        maxTokens: Int32,
        stopSequences: [String] = []
    ) -> String {
        // Step 1: Clear KV cache between calls (Pitfall 5)
        // llama_kv_cache_clear was removed; use llama_memory_clear instead.
        // llama_get_memory returns llama_memory_t (typedef for llama_memory_i*).
        // llama_memory_i is forward-declared only → OpaquePointer in Swift.
        let memory = llama_get_memory(context)
        llama_memory_clear(memory, false)

        // Step 2: Reset sampler state
        llama_sampler_reset(sampler)

        // Step 3: Tokenize prompt
        // vocab functions take llama_vocab* obtained from llama_model_get_vocab.
        // llama_vocab is forward-declared only → OpaquePointer in Swift.
        let vocab = llama_model_get_vocab(model)
        let promptTokens = tokenize(text: prompt, vocab: vocab, addSpecial: true, parseSpecial: true)
        guard !promptTokens.isEmpty else { return "" }

        // Step 4: Decode prompt tokens in a batch
        var batch = llama_batch_init(Int32(promptTokens.count), 0, 1)
        defer { llama_batch_free(batch) }

        batch.n_tokens = Int32(promptTokens.count)
        for (i, token) in promptTokens.enumerated() {
            batch.token[i] = token
            batch.pos[i] = Int32(i)
            batch.n_seq_id[i] = 1
            batch.seq_id[i]![0] = 0
            // Only compute logits for the last token in the prompt batch
            batch.logits[i] = (i == promptTokens.count - 1) ? 1 : 0
        }

        guard llama_decode(context, batch) == 0 else { return "" }

        // Step 5: Sample output tokens
        // Reuse a single batch for token-by-token generation (avoids alloc/free per token)
        var outputTokens: [llama_token] = []
        var currentPos = Int32(promptTokens.count)
        var nextBatch = llama_batch_init(1, 0, 1)
        defer { llama_batch_free(nextBatch) }

        while outputTokens.count < maxTokens {
            // Check for cooperative cancellation (timeout task fired)
            if Task.isCancelled { break }

            let newToken = llama_sampler_sample(sampler, context, -1)

            // Check for end of generation using vocab-based EOG check
            if llama_vocab_is_eog(vocab, newToken) { break }

            outputTokens.append(newToken)
            
            // Check for stop sequences in the current output
            if !stopSequences.isEmpty {
                let currentText = outputTokens.map { tokenToPiece(token: $0, vocab: vocab) }.joined()
                var shouldStop = false
                for stop in stopSequences {
                    if currentText.contains(stop) {
                        shouldStop = true
                        break
                    }
                }
                if shouldStop { break }
            }

            // Prepare next batch with single token (reuse allocated batch)
            nextBatch.n_tokens = 1
            nextBatch.token[0] = newToken
            nextBatch.pos[0] = currentPos
            nextBatch.n_seq_id[0] = 1
            nextBatch.seq_id[0]![0] = 0
            nextBatch.logits[0] = 1

            guard llama_decode(context, nextBatch) == 0 else { break }
            currentPos += 1
        }

        // Step 6: Detokenize output
        var finalResult = outputTokens.map { tokenToPiece(token: $0, vocab: vocab) }.joined()
        
        // Final cleanup of stop sequences
        for stop in stopSequences {
            if let range = finalResult.range(of: stop) {
                finalResult = String(finalResult[..<range.lowerBound])
            }
        }
        
        return finalResult
    }

    // MARK: - Tokenization helpers

    /// Convert text to llama tokens.
    ///
    /// Uses llama_vocab* (not llama_model*) as required by the current llama.cpp API.
    /// llama_vocab is forward-declared only → OpaquePointer in Swift.
    private nonisolated static func tokenize(
        text: String,
        vocab: OpaquePointer?,
        addSpecial: Bool,
        parseSpecial: Bool
    ) -> [llama_token] {
        guard let vocab else { return [] }
        let utf8Count = text.utf8.count
        let upperBound = Int32(utf8Count) + 128  // Extra space for special tokens
        var tokens = [llama_token](repeating: 0, count: Int(upperBound))
        let nTokens = llama_tokenize(
            vocab,
            text,
            Int32(utf8Count),
            &tokens,
            upperBound,
            addSpecial,
            parseSpecial
        )
        guard nTokens >= 0 else { return [] }
        return Array(tokens.prefix(Int(nTokens)))
    }

    /// Convert a single token to its string representation.
    ///
    /// Uses llama_vocab* (not llama_model*) as required by the current llama.cpp API.
    /// llama_vocab is forward-declared only → OpaquePointer in Swift.
    private nonisolated static func tokenToPiece(token: llama_token, vocab: OpaquePointer?) -> String {
        guard let vocab else { return "" }
        var buffer = [CChar](repeating: 0, count: 256)
        let nChars = llama_token_to_piece(vocab, token, &buffer, 256, 0, false)
        guard nChars > 0 else { return "" }
        // Convert exactly nChars bytes to a Swift String — do NOT append a null
        // terminator. String(decoding:as:) includes ALL bytes, so an appended \0
        // becomes a Unicode NULL (U+0000) embedded in the string, causing invisible
        // gaps that render as double spaces.
        return String(decoding: buffer.prefix(Int(nChars)).map { UInt8(bitPattern: $0) }, as: UTF8.self)
    }

    // MARK: - Post-processing

    /// Strip common LLM preamble patterns from output (Pitfall 4 from RESEARCH.md).
    ///
    /// Gemma 3 1B may prepend conversational text despite explicit "output ONLY"
    /// instructions. This strips known patterns and normalizes whitespace from
    /// token-by-token detokenization (leading spaces per token → double spaces).
    ///
    /// Phase 25.1-02: envelope extraction runs first (paper §6.2 Class D mitigation).
    static func stripPreamble(_ text: String) -> String {
        // Phase 25.1-02 — paper §6.2 XML envelope extraction (Class D mitigation).
        // When both <corrected_text> and </corrected_text> tags are present, extract
        // contents and apply <unk> stripping. Falls back to the original input when
        // either tag is missing (quantized models drop the closing tag on long outputs
        // — paper §6.2 documented risk). Existing pipeline then normalizes `working`.
        let working = extractEnvelopeOrFallback(text)

        // Step 0: Replace all Unicode whitespace variants with ASCII space.
        var result = working.unicodeScalars.reduce(into: "") { str, scalar in
            if scalar.value == 0 {
                return
            } else if scalar.properties.isWhitespace && scalar != "\n" {
                str.append(" ")
            } else if scalar == "\u{2581}" {
                str.append(" ")
            } else {
                str.append(Character(scalar))
            }
        }
        result = result.trimmingCharacters(in: .whitespacesAndNewlines)

        // Step 0.5: Strip leaked Gemma chat-template fragments and 'response' markers.
        if let chatTemplateRegex = try? NSRegularExpression(
            pattern: #"</?(?:start_of_turn|end_of_turn)>(?:\s*(?:model|user))?|<bos>|<eos>|<\|endoftext\|>|_?response>|<response>|OUTPUT:|KORRIGIERT:"#,
            options: [.caseInsensitive]
        ) {
            let r = NSRange(result.startIndex..<result.endIndex, in: result)
            result = chatTemplateRegex.stringByReplacingMatches(
                in: result, options: [], range: r, withTemplate: ""
            )
            result = result.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Step 1: Normalize whitespace and fix contractions
        while result.contains("  ") {
            result = result.replacingOccurrences(of: "  ", with: " ")
        }
        
        // Fix contractions artifact (tokenizer artifacts like "don ' t")
        let contractionRegex = try? NSRegularExpression(pattern: "([a-zA-Z]) ' ?([stdmveSTDMLVR])\\b", options: [])
        let range = NSRange(result.startIndex..<result.endIndex, in: result)
        result = contractionRegex?.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: "$1'$2") ?? result

        // Fix spaces before punctuation (tokenizer artifact: "Hello , world" → "Hello, world")
        for punct in [" .", " ,", " !", " ?", " ;", " :"] {
            result = result.replacingOccurrences(of: punct, with: String(punct.last!))
        }

        // Step 2: Strip surrounding double quotation marks and non-standard quotes (CLEAN-01)
        let doubleQuotes = CharacterSet(charactersIn: "\"“”„«»")
        result = result.components(separatedBy: doubleQuotes).joined()

        // Strip surrounding single quotes if they wrap the whole result
        if (result.hasPrefix("'") && result.hasSuffix("'")) ||
           (result.hasPrefix("‘") && result.hasSuffix("’")) {
            result = String(result.dropFirst().dropLast())
        }

        result = result.trimmingCharacters(in: .whitespacesAndNewlines)
        
        while result.contains("  ") {
            result = result.replacingOccurrences(of: "  ", with: " ")
        }

        return result
    }

    /// Phase 25.1-02 — extract content from the `<corrected_text>...</corrected_text>`
    /// envelope AND strip `<unk>` ASR-leak sentinels. Pure function.
    ///
    /// Handles four shapes of model output:
    ///   1. Full envelope:  `<corrected_text>X</corrected_text>`  → `X`
    ///   2. Opening only:   `<corrected_text>X`                    → `X`  (model truncated)
    ///   3. Closing only:   `X</corrected_text>`                   → `X`
    ///      (V18C/V19C pattern — opening tag pre-filled in the prompt as a
    ///      completion anchor at `CleanupPrompt.swift:202`, so the model
    ///      only emits content + closing tag)
    ///   4. No envelope:    `X`                                    → `X`  (passthrough)
    ///
    /// `<unk>` ASR sentinels are stripped in all four cases.
    ///
    /// Note: case (3) was treated as a fallback in 25.1-02's original implementation
    /// (closing tag passed through verbatim, deferred to Plan 06's NLD/Jaccard
    /// safety net). Plan 25.1-04 (V18C, 2026-05-18) and Plan 25.1-05 (V19C) made
    /// pre-fill the *normal* output shape, so this is now the dominant path —
    /// stripping the closing tag is required, not optional.
    private static func extractEnvelopeOrFallback(_ text: String) -> String {
        let openTag = "<corrected_text>"
        let closeTag = "</corrected_text>"
        var inner: String

        if let openRange = text.range(of: openTag) {
            let contentStart = openRange.upperBound
            if let closeRange = text.range(of: closeTag, range: contentStart..<text.endIndex) {
                inner = String(text[contentStart..<closeRange.lowerBound])    // Case 1
            } else {
                inner = String(text[contentStart..<text.endIndex])             // Case 2
            }
        } else if let closeRange = text.range(of: closeTag) {
            inner = String(text[text.startIndex..<closeRange.lowerBound])      // Case 3
        } else {
            inner = text                                                       // Case 4
        }

        // Class D mitigation: strip <unk> ASR sentinels (case-sensitive — only the
        // lowercase ASR-emitted form, NOT any user-typed <UNK> or similar).
        inner = inner.replacingOccurrences(of: "<unk>", with: "")
        return inner.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Resource deallocation

    deinit {
        if let sampler { llama_sampler_free(sampler) }
        if let context { llama_free(context) }
        if let model { llama_model_free(model) }
        // Note: llama_backend_free() is NOT called here — it's a global resource
        // that should only be freed at app termination, not when a service is deallocated.
    }
}

// MARK: - Errors

/// Errors specific to the LLM cleanup pipeline.
enum CleanupError: Error, Sendable {
    /// GGUF model file could not be loaded by llama.cpp
    case modelLoadFailed
    /// llama_context could not be created from the loaded model
    case contextCreationFailed
    /// LLM inference exceeded the 5-second timeout (D-18)
    case timeout
}

// MARK: - Phase 20 Levenshtein verification gate (D-01)

extension CleanupService {

    /// Single tunable knob — surfaces in CONTEXT.md as the UAT calibration target.
    /// Increase to be MORE permissive of LLM edits (the gate accepts more);
    /// decrease to reject MORE aggressively. Downstream code MUST reference this
    /// constant by name and never magic-number 0.30 inline.
    public static let levenshteinGateThreshold: Double = 0.45

    /// Pure helper. Returns `llmOutput` if it is plausibly a light edit of
    /// `rulesCleaned`; otherwise returns `rulesCleaned` (LLM is rejected as
    /// hallucination / over-rewrite).
    ///
    /// Distance is computed over normalized forms (lowercased, whitespace-collapsed,
    /// soft punctuation `, . ! ? : ; '` stripped) so reorderings like
    /// `"15 CHF"` vs `"CHF 15"` and casing/punctuation-only edits do not
    /// register as wholesale rewrites.
    ///
    /// Currency symbols are NOT stripped — the rules pass already canonicalized
    /// currency, and a missing symbol is a real semantic loss the gate should
    /// catch (defense-in-depth alongside `CurrencyAntiFlip.revertCurrencyFlip`).
    ///
    /// - Parameters:
    ///   - rulesCleaned: deterministic Swift-side cleanup output (rules pass).
    ///   - llmOutput: post-stripPreamble LLM output.
    ///   - threshold: normalized-distance ceiling. Defaults to
    ///     `levenshteinGateThreshold` (0.45) — pass an explicit value only for
    ///     calibration / testing.
    /// - Returns: `llmOutput` when normalizedDistance ≤ threshold, else
    ///   `rulesCleaned`.
    public static func gateLLMOutput(rulesCleaned: String,
                                     llmOutput: String,
                                     threshold: Double = levenshteinGateThreshold) -> String {
        let lhs = normalizeForGate(rulesCleaned)
        let rhs = normalizeForGate(llmOutput)
        let dist = LevenshteinDistance.normalizedDistance(lhs, rhs)
        return dist > threshold ? rulesCleaned : llmOutput
    }

    /// Lowercase + soft-punctuation strip + whitespace-collapse. Keeps
    /// currency symbols, digits, and letters intact.
    private static func normalizeForGate(_ s: String) -> String {
        let lowered = s.lowercased()
        // Collapse whitespace runs to single space, strip soft punctuation.
        let stripped = lowered
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: "?", with: "")
            .replacingOccurrences(of: "!", with: "")
            .replacingOccurrences(of: ":", with: "")
            .replacingOccurrences(of: ";", with: "")
            .replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: "\u{2019}", with: "")  // typographic apostrophe
        return stripped.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }
}

// MARK: - Phase 20.08 Dialect-suppression gate (D-06..D-08)

extension CleanupService {

    /// Phase 20.08 D-06..D-08. Pre-Levenshtein dialect-suppression gate.
    /// Returns `llmOutput` if it introduces zero unsolicited Swiss dialect
    /// forms relative to `rulesCleaned`; otherwise returns `rulesCleaned`
    /// (LLM rejected as Swiss-ifier).
    ///
    /// "Unsolicited" = present in the LLM output AND in `SwissDialectForms.tokens`
    /// AND NOT present in the rules-cleaned baseline.
    ///
    /// Threshold = strict >= 1 (D-07). Aligned to the threat model: this user
    /// does not dictate Swiss German, so any unsolicited dialect form is
    /// rejected. The "speaker actually said it" exception is honoured by the
    /// `!baseline.contains(tok)` clause.
    ///
    /// Graceful degradation contract: empty inputs, zero matches, and any
    /// other unexpected shape return `llmOutput` unchanged (no demotion).
    /// Mirrors the CurrencyAntiFlip safety contract.
    ///
    /// - Parameters:
    ///   - rulesCleaned: deterministic Swift-side cleanup output (rules pass).
    ///   - llmOutput: post-stripPreamble LLM output.
    /// - Returns: `llmOutput` when delta == 0; else `rulesCleaned`.
    public static func gateLLMDialect(rulesCleaned: String,
                                      llmOutput: String) -> String {
        let baseline = Set(tokenizeForDialectGate(rulesCleaned))
        let candidate = tokenizeForDialectGate(llmOutput)
        let dialectSet = Set(SwissDialectForms.tokens)
        for tok in candidate where dialectSet.contains(tok) && !baseline.contains(tok) {
            #if DEBUG
            os_log("gateLLMDialect: demoted on token '%{public}@'", log: .default, type: .info, tok)
            #endif
            return rulesCleaned
        }
        return llmOutput
    }

    /// Word-level tokenization tuned for dialect-form detection.
    /// Differs from `normalizeForGate` (which collapses to a single string for
    /// distance comparison): this returns an array of lowercased word tokens
    /// suitable for set membership.
    ///
    /// Edge cases (per RESEARCH.md §3 table):
    /// - Case mismatch -> lowercased before split
    /// - Trailing punctuation -> stripped via separators charset
    /// - Apostrophes inside word (s'het, d'Mueter) -> preserved as single token
    /// - Hyphenated words -> split on hyphen (per SwissHelvetisms convention)
    ///
    /// Internal (not private) so tests can verify tokenization edge cases.
    static func tokenizeForDialectGate(_ s: String) -> [String] {
        let lowered = s.lowercased()
        let separators = CharacterSet.whitespacesAndNewlines
            .union(CharacterSet(charactersIn: ".,!?;:\"„“”«»()[]{}—–-"))
        return lowered.unicodeScalars
            .split { separators.contains($0) }
            .map { String(String.UnicodeScalarView($0)) }
            .filter { !$0.isEmpty }
    }
}

// MARK: - Phase 20.08 Spike harness helpers (DEBUG-only, D-02/D-03)

#if DEBUG
extension CleanupService {

    /// DEBUG-only helper for the Phase 20.08 prompt-spike harness.
    ///
    /// Bypasses `CleanupPrompt.build(...)` and feeds an arbitrary pre-built
    /// prompt string directly to the same inference loop used by `cleanup(...)`.
    /// Mirrors the production isInferring guard, state transition, and
    /// task-group timeout structure from cleanup() lines 178-242 — the only
    /// difference is the prompt source (caller-supplied vs CleanupPrompt.build).
    ///
    /// Returns the post-stripPreamble LLM output, or empty string on
    /// model-not-loaded / concurrent-call / timeout / inference failure.
    ///
    /// CONCURRENCY: callers MUST invoke this sequentially. The shared
    /// `isInferring` guard (CleanupService.swift line 155, 178-181) rejects
    /// concurrent calls. The spike harness UI loops
    /// `for input in inputs { for variant in variants { let out = await ... } }`.
    func cleanupWithExplicitPrompt(_ prompt: String, timeoutSeconds: TimeInterval? = nil) async -> String {
        let log = Logger(subsystem: "com.dicticus", category: "cleanup-spike")

        guard isLoaded, let model = model, let context = context, let sampler = sampler else {
            log.warning("cleanupWithExplicitPrompt: model not loaded")
            return ""
        }

        guard !isInferring else {
            log.warning("cleanupWithExplicitPrompt: inference already in progress")
            return ""
        }

        isInferring = true
        state = .cleaning
        defer {
            state = .idle
            isInferring = false
        }

        // Mirror cleanup() lines 207-242 verbatim: capture nonisolated(unsafe)
        // C-pointer aliases, then run a throwing task group with a sleep-throw
        // timeout task + the static inference task. Return whichever finishes
        // first; cancel the loser.
        nonisolated(unsafe) let unsafeModel = model
        nonisolated(unsafe) let unsafeContext = context
        nonisolated(unsafe) let unsafeSampler = sampler
        let maxTokens = maxOutputTokens
        let timeout = timeoutSeconds ?? self.inferenceTimeoutSeconds

        do {
            let result = try await withThrowingTaskGroup(of: String.self) { group in
                group.addTask {
                    try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
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
                    return ""
                }
                group.cancelAll()
                return firstResult
            }

            log.info("Spike LLM raw (\(result.count, privacy: .public) chars)")
            return Self.cleanSpikeOutput(result)
        } catch {
            log.error("cleanupWithExplicitPrompt error: \(error.localizedDescription, privacy: .public)")
            return ""
        }
    }

    /// Spike-specific post-processor.
    ///
    /// Gemma 4 E2B at temp 0.1 sometimes (a) emits markdown-blockquote `>` line
    /// prefixes and (b) keeps generating past `<end_of_turn>` when that token
    /// is not flagged EOG by `llama_vocab_is_eog`, producing duplicate
    /// paragraphs. Production cleanup() doesn't hit this because its prompt
    /// shape and post-strip pipeline differ. For spike comparison we want a
    /// single clean answer per cell: truncate at the first chat-template
    /// marker or blank-line break, then strip leading `>` per line.
    private nonisolated static func cleanSpikeOutput(_ raw: String) -> String {
        var out = raw
        // Include closing-tag variants (e.g. `</start_of_turn>`) — Gemma 4 E2B
        // occasionally emits these as stray tokens; substring matching on
        // `<start_of_turn>` does not catch them due to the leading `/`.
        for marker in [
            "</start_of_turn>", "</end_of_turn>",
            "<end_of_turn>", "<start_of_turn>",
            "<eos>", "<|endoftext|>",
        ] {
            if let r = out.range(of: marker) { out = String(out[..<r.lowerBound]) }
        }
        if let r = out.range(of: "\n\n") { out = String(out[..<r.lowerBound]) }
        // Strip stray output-template prefixes Gemma 4 E2B emits when primed
        // by a structural-looking prompt trailer. Observed Wave A artifacts:
        // "_response>", "<response>", "OUTPUT:". Match case-insensitively at
        // the start of the trimmed output only.
        let trimmedLeading = out.drop(while: { $0.isWhitespace })
        for prefix in ["_response>", "<response>", "OUTPUT:", "Output:", "output:"] {
            if trimmedLeading.lowercased().hasPrefix(prefix.lowercased()) {
                if let r = out.range(of: prefix, options: .caseInsensitive) {
                    out = String(out[r.upperBound...])
                }
                break
            }
        }
        // Phase 20.08: BPE-fragmented chat-template leak. When Gemma emits
        // `<end_of_turn>` mid-decode, the leading `<...of_` portion is sometimes
        // truncated by upstream marker stripping (line 794-800) while the
        // SentencePiece-rendered tail `▁turn>` / `_turn>` / `turn>` survives at
        // the start. Catch any dangling chat-template tail at the leading edge.
        if let regex = try? NSRegularExpression(
            pattern: #"^\s*[_▁<]?(?:(?:start|end)_of_)?turn>\s*"#,
            options: [.caseInsensitive]
        ) {
            let nsOut = out as NSString
            let range = NSRange(location: 0, length: nsOut.length)
            out = regex.stringByReplacingMatches(in: out, options: [], range: range, withTemplate: "")
        }
        out = out
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { line -> String in
                var s = String(line)
                // Strip leading quote-marker, whitespace, and stray
                // punctuation (":" / "," / ";") that Gemma sometimes emits
                // as a structural opener before the actual cleaned text.
                while let first = s.first,
                      first == ">" || first == " " || first == "\t" ||
                      first == ":" || first == "," || first == ";" {
                    s.removeFirst()
                }
                return s
            }
            .joined(separator: "\n")
        return out.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// DEBUG-only sampler-seed override for spike reproducibility (D-03).
    ///
    /// Tears down the current sampler chain (`llama_sampler_free`) and
    /// rebuilds it VERBATIM from CleanupService.loadModel lines 136-146
    /// with `seed` substituted for the random `UInt32.random(in: ...)` in
    /// `llama_sampler_init_dist`. All other chain nodes (temperature 0.1,
    /// top-K 40, top-P 0.9) are reconstructed identically so spike output
    /// matches production sampler behavior except for determinism.
    ///
    /// Pass `nil` (or call again with a fresh random seed) to restore
    /// non-deterministic sampling. Production code never calls this — the
    /// `#if DEBUG` wrap guarantees the symbol does not exist in Release.
    ///
    /// PRECONDITION: `loadModel()` has completed (isLoaded == true). Calling
    /// this before warmup is a no-op (logged warning).
    func setSamplerSeed(_ seed: UInt32?) {
        let log = Logger(subsystem: "com.dicticus", category: "cleanup-spike")

        guard isLoaded else {
            log.warning("setSamplerSeed: called before loadModel completed — no-op")
            return
        }

        guard !isInferring else {
            log.warning("setSamplerSeed: inference in progress — refusing to mutate sampler")
            return
        }

        // Tear down the existing sampler chain (allocated in loadModel via
        // llama_sampler_chain_init). llama_sampler_free walks the chain and
        // releases all child samplers added with llama_sampler_chain_add.
        if let oldSampler = sampler {
            llama_sampler_free(oldSampler)
            sampler = nil
        }

        // Rebuild the chain to match loadModel — Phase 20.08 conventional
        // order (top_k → top_p → temp → dist). Must stay in lockstep with
        // loadModel's chain or seeded reproducibility breaks.
        let resolvedSeed: UInt32 = seed ?? UInt32.random(in: 0...UInt32.max)
        let samplerChain = llama_sampler_chain_init(llama_sampler_chain_default_params())
        llama_sampler_chain_add(samplerChain, llama_sampler_init_top_k(40))
        llama_sampler_chain_add(samplerChain, llama_sampler_init_top_p(0.9, 1))
        llama_sampler_chain_add(samplerChain, llama_sampler_init_temp(0.1))
        llama_sampler_chain_add(samplerChain, llama_sampler_init_dist(resolvedSeed))
        sampler = samplerChain

        log.info("setSamplerSeed: rebuilt sampler chain with seed \(resolvedSeed, privacy: .public)")
    }
}
#endif
