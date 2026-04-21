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
class CleanupService: ObservableObject {

    /// Cleanup pipeline state. Observed by DicticusApp for icon state (D-14, D-15).
    enum State: Equatable, Sendable {
        case idle
        case cleaning
    }

    @Published var state: State = .idle

    /// Whether the LLM model is loaded and ready for inference.
    /// Set to true after successful loadModel() call.
    private(set) var isLoaded = false

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

    // MARK: - Configuration

    /// Maximum output tokens for cleanup. Dictation cleanup output is always
    /// shorter than or equal to input length, so 512 tokens is generous.
    private let maxOutputTokens: Int32 = 512

    /// LLM inference timeout in seconds (per D-18).
    /// If exceeded, cleanup returns raw ASR text as fallback.
    private let inferenceTimeoutSeconds: TimeInterval = 5.0

    // MARK: - Initialization

    /// Initialize the llama.cpp backend.
    /// Must be called once before loadModel(). Called during app warmup.
    static func initializeBackend() {
        llama_backend_init()
    }

    /// Load the GGUF model and create the inference context.
    ///
    /// Called once during warmup (ModelWarmupService Step 4).
    /// After this returns successfully, cleanup() can be called.
    ///
    /// - Parameter modelPath: File path to the cached GGUF model
    /// - Throws: CleanupError if model file cannot be loaded or context creation fails
    func loadModel(from modelPath: String) throws {
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
        ctxParams.n_batch = 512      // Batch size for prompt processing
        ctxParams.n_threads = 4      // CPU threads (Metal handles matrix ops)

        guard let ctx = llama_init_from_model(loadedModel, ctxParams) else {
            llama_model_free(loadedModel)
            self.model = nil
            throw CleanupError.contextCreationFailed
        }
        self.context = ctx

        // Sampler chain: conservative settings for text cleanup (AICLEAN-02)
        // llama_sampler_chain_init returns UnsafeMutablePointer<llama_sampler>?
        let samplerChain = llama_sampler_chain_init(llama_sampler_chain_default_params())
        // Temperature 0.2: very low for deterministic corrections
        llama_sampler_chain_add(samplerChain, llama_sampler_init_temp(0.2))
        // Top-K 40: limit vocabulary to top candidates
        llama_sampler_chain_add(samplerChain, llama_sampler_init_top_k(40))
        // Top-P 0.9: nucleus sampling
        llama_sampler_chain_add(samplerChain, llama_sampler_init_top_p(0.9, 1))
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

        let prompt = CleanupPrompt.build(text: text, language: language, dictionaryContext: dictionaryContext)
        log.info("Prompt (\(prompt.count, privacy: .public) chars, lang=\(language, privacy: .public)): \(prompt.prefix(500), privacy: .public)")

        // Run inference in a detached task with timeout (D-18)
        // nonisolated(unsafe) for C pointer access in detached context (Pitfall 7)
        nonisolated(unsafe) let unsafeModel = model
        nonisolated(unsafe) let unsafeContext = context
        nonisolated(unsafe) let unsafeSampler = sampler
        let maxTokens = maxOutputTokens

        do {
            let result = try await withThrowingTaskGroup(of: String.self) { group in
                group.addTask {
                    // Timeout task
                    try await Task.sleep(nanoseconds: UInt64(5.0 * 1_000_000_000))
                    throw CleanupError.timeout
                }

                group.addTask {
                    // Inference task — checks Task.isCancelled between tokens
                    return Self.runInference(
                        prompt: prompt,
                        model: unsafeModel,
                        context: unsafeContext,
                        sampler: unsafeSampler,
                        maxTokens: maxTokens
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

            // Post-process: strip any preamble the model might add (Pitfall 4)
            log.info("LLM raw (\(result.count, privacy: .public) chars): \(result.prefix(500), privacy: .public)")
            let cleaned = Self.stripPreamble(result)
            log.info("After strip (\(cleaned.count, privacy: .public) chars): \(cleaned.prefix(500), privacy: .public)")
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
        maxTokens: Int32
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
        return outputTokens.map { tokenToPiece(token: $0, vocab: vocab) }.joined()
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
    static func stripPreamble(_ text: String) -> String {
        // Step 0: Replace all Unicode whitespace variants with ASCII space.
        var result = text.unicodeScalars.reduce(into: "") { str, scalar in
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

        // Step 1: Normalize whitespace and fix contractions
        while result.contains("  ") {
            result = result.replacingOccurrences(of: "  ", with: " ")
        }
        
        // We strip the space before an apostrophe only when it is preceded
        // and followed by a contraction suffix (e.g., "don ' t" -> "don't", "here ' s" -> "here's").
        // We handle both " 's" and " ' s" variants.
        let contractionRegex = try? NSRegularExpression(pattern: "([a-zA-Z]) ' ?([stdmveSTDMLVR])\\b", options: [])
        let range = NSRange(result.startIndex..<result.endIndex, in: result)
        result = contractionRegex?.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: "$1'$2") ?? result

        // Fix spaces before punctuation (tokenizer artifact: "Hello , world" → "Hello, world")
        for punct in [" .", " ,", " !", " ?", " ;", " :"] {
            result = result.replacingOccurrences(of: punct, with: String(punct.last!))
        }

        // Step 2: Strip known preamble patterns (case-insensitive prefix match)
        let preambles = [
            "Here is the corrected text:",
            "Here is the corrected text",
            "Here's the corrected text:",
            "Here's the corrected text",
            "Here is the polished text:",
            "Here is the polished text",
            "Here's the polished text:",
            "Here's the polished text",
            "Here's a polished version of the text:",
            "Here's a polished version:",
            "Sorry, here's a polished version of the text:",
            "Sorry, here's a polished version:",
            "Sorry, here is the polished text:",
            "Corrected text:",
            "Polished text:",
            "Sure!",
            "Sure,",
            "Sure.",
            "Hier ist der korrigierte Text:",
            "Hier ist der korrigierte Text",
            "Korrigierter Text:",
        ]

        let lowered = result.lowercased()
        for preamble in preambles {
            if lowered.hasPrefix(preamble.lowercased()) {
                result = String(result.dropFirst(preamble.count))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                break
            }
        }

        // Step 3: Strip "Please provide/share..." refusal or "Output:" prefix
        let loweredAfterPreamble = result.lowercased()
        if loweredAfterPreamble.hasPrefix("please provide") || loweredAfterPreamble.hasPrefix("please share") {
            if let dotRange = result.range(of: ".\n", options: .literal) {
                result = String(result[dotRange.upperBound...])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            } else if let dotRange = result.range(of: ". ", options: .literal),
                      result.distance(from: result.startIndex, to: dotRange.lowerBound) < 80 {
                result = String(result[result.index(after: dotRange.lowerBound)...])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                result = ""
            }
        }

        if result.lowercased().hasPrefix("output:") {
            result = String(result.dropFirst("output:".count))
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Step 4: Strip double quotation marks and non-standard quotes (CLEAN-01)
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
