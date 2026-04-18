---
phase: 04-ai-cleanup
reviewed: 2026-04-18T14:32:00Z
depth: standard
files_reviewed: 14
files_reviewed_list:
  - Dicticus/Dicticus/Models/CleanupPrompt.swift
  - Dicticus/Dicticus/Services/CleanupService.swift
  - Dicticus/Dicticus/Services/ModelDownloadService.swift
  - Dicticus/Dicticus/Services/HotkeyManager.swift
  - Dicticus/Dicticus/Services/ModelWarmupService.swift
  - Dicticus/Dicticus/Services/NotificationService.swift
  - Dicticus/Dicticus/DicticusApp.swift
  - Dicticus/DicticusTests/CleanupPromptTests.swift
  - Dicticus/DicticusTests/CleanupServiceTests.swift
  - Dicticus/DicticusTests/ModelDownloadServiceTests.swift
  - Dicticus/DicticusTests/HotkeyManagerTests.swift
  - Dicticus/DicticusTests/ModelWarmupServiceTests.swift
  - Dicticus/DicticusTests/NotificationServiceTests.swift
  - Dicticus/project.yml
findings:
  critical: 2
  warning: 5
  info: 3
  total: 10
status: issues_found
---

# Phase 4: Code Review Report

**Reviewed:** 2026-04-18T14:32:00Z
**Depth:** standard
**Files Reviewed:** 14
**Status:** issues_found

## Summary

Phase 4 integrates Gemma 3 1B via llama.cpp for AI text cleanup. The implementation is well-structured, follows established service patterns (@MainActor ObservableObject), and correctly implements the D-01 through D-20 design decisions. The fallback-to-raw-text safety net (D-19) is properly wired throughout.

Two critical issues were found: (1) a data race on llama.cpp C pointers where the inference task runs concurrently with the timeout task, both accessing the same sampler/context with no synchronization, and (2) a prompt injection surface where ASR transcription text containing Gemma control tokens could manipulate LLM behavior. Five warnings address concurrency safety, resource cleanup, missing integrity validation, and an incomplete test file. Three informational items note minor improvements.

## Critical Issues

### CR-01: Data Race on llama.cpp C Pointers in Task Group

**File:** `Dicticus/Dicticus/Services/CleanupService.swift:148-172`
**Issue:** The `cleanup()` method launches two concurrent tasks in a `ThrowingTaskGroup`: one for inference (which reads/writes to `context`, `sampler`) and one for timeout. When the timeout fires first, `group.cancelAll()` is called while `runInference()` may still be executing inside the inference task. The inference loop (lines 244-265) calls `llama_decode`, `llama_sampler_sample`, etc. on C pointers that are not thread-safe. Swift task cancellation is cooperative -- `cancelAll()` sets a flag but does not stop execution. The inference loop has no `Task.checkCancellation()` calls, so it continues running after cancellation until it naturally finishes. Meanwhile, the `cleanup()` function returns and the caller may trigger another `cleanup()` call or the object may deinit, freeing the C pointers while the first inference is still running.

More specifically: after the timeout task throws, `group.next()` returns (or throws), and `cleanup()` returns the raw text. A subsequent `cleanup()` call would then call `llama_memory_clear` and `llama_sampler_reset` on the same pointers while the previous inference loop is still calling `llama_decode` and `llama_sampler_sample`.

**Fix:** Add cooperative cancellation checks inside the inference loop, and add a mutex or serial dispatch mechanism to prevent concurrent inference calls:

```swift
// Inside the while loop in runInference(), add cancellation check:
while outputTokens.count < maxTokens {
    // Check for cancellation to exit promptly on timeout
    guard !Task.isCancelled else { break }

    let newToken = llama_sampler_sample(sampler, context, -1)
    // ... rest of loop
}
```

Additionally, add a `private var isInferring = false` guard in `cleanup()` to reject concurrent calls:

```swift
guard !isInferring else { return text }
isInferring = true
defer { isInferring = false }
```

### CR-02: Prompt Injection via ASR Transcription Text

**File:** `Dicticus/Dicticus/Models/CleanupPrompt.swift:54`
**Issue:** The `build()` method interpolates raw ASR text directly into the Gemma prompt template using string interpolation: `\(text)`. If the ASR engine transcribes speech that happens to contain Gemma control tokens (e.g., a user dictating about LLMs and saying "end of turn" which Parakeet transcribes as `<end_of_turn>`), the control tokens would be interpreted by the tokenizer as actual format tokens, breaking the prompt structure. While Parakeet is unlikely to output literal angle-bracket tokens in normal transcription, this is a defense-in-depth concern -- the `parseSpecial: true` flag in `CleanupService.tokenize()` (line 221) means special tokens in the user text *will* be parsed as control tokens.

**Fix:** Either (a) sanitize control tokens from the user text before interpolation, or (b) pass `parseSpecial: false` when tokenizing user-supplied content (which requires splitting tokenization into instruction + user text):

```swift
// Option (a) - sanitize in CleanupPrompt.build():
static func build(for text: String, language: String) -> String {
    let instruction: String
    switch language {
    case "de": instruction = germanInstruction
    default: instruction = englishInstruction
    }
    // Strip Gemma control tokens from user text
    let sanitized = text
        .replacingOccurrences(of: "<start_of_turn>", with: "")
        .replacingOccurrences(of: "<end_of_turn>", with: "")
        .replacingOccurrences(of: "<eos>", with: "")
    return "<start_of_turn>user\n\(instruction)\n\nText: \(sanitized)<end_of_turn>\n<start_of_turn>model\n"
}
```

## Warnings

### WR-01: Missing Integrity Check on Downloaded GGUF Model

**File:** `Dicticus/Dicticus/Services/ModelDownloadService.swift:56-57`
**Issue:** The `downloadIfNeeded()` method downloads a ~722 MB GGUF file from HuggingFace and moves it to the cache directory without any integrity validation (no SHA256 checksum, no file size check). A corrupted download (network interruption, partial write) would be cached permanently and cause `llama_model_load_from_file` to fail on every subsequent launch. The user would need to manually delete the cached file to recover. While the CONTEXT.md notes that "llama.cpp validates GGUF magic bytes on load" (T-04-09), a corrupted file that passes magic byte validation but has truncated weights would produce garbage output silently.

**Fix:** Add a file size check after download as a minimal integrity gate. Optionally add a SHA256 checksum:

```swift
static let expectedModelSize: UInt64 = 757_000_000  // ~722 MB, with margin

static func downloadIfNeeded() async throws {
    guard !isModelCached() else { return }

    let dir = modelPath().deletingLastPathComponent()
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

    let (tempURL, _) = try await URLSession.shared.download(from: modelURL)

    // Validate file size before caching
    let attrs = try FileManager.default.attributesOfItem(atPath: tempURL.path)
    let fileSize = attrs[.size] as? UInt64 ?? 0
    guard fileSize > 100_000_000 else {  // At least 100 MB
        try? FileManager.default.removeItem(at: tempURL)
        throw URLError(.cannotDecodeContentData)
    }

    try FileManager.default.moveItem(at: tempURL, to: modelPath())
}
```

### WR-02: Batch Allocation Inside Token-by-Token Loop Without Reuse

**File:** `Dicticus/Dicticus/Services/CleanupService.swift:253-254`
**Issue:** Inside the token sampling loop (lines 244-265), a new `llama_batch` is allocated via `llama_batch_init(1, 0, 1)` and freed via `defer { llama_batch_free(nextBatch) }` on every single iteration. For the maximum 512 output tokens, this means 512 malloc/free cycles. While not a correctness bug, the `defer` inside a loop body means `llama_batch_free` is called at each loop iteration end (which is correct), but allocating and freeing a batch struct per token is wasteful when the batch could be allocated once before the loop and reused.

More importantly, if `llama_batch_init` returns a zero-initialized struct on allocation failure, subsequent pointer dereferences (`nextBatch.token[0]`, `nextBatch.seq_id[0]![0]`) would crash with a null pointer dereference.

**Fix:** Allocate the single-token batch once before the loop and reuse it:

```swift
var nextBatch = llama_batch_init(1, 0, 1)
defer { llama_batch_free(nextBatch) }

while outputTokens.count < maxTokens {
    let newToken = llama_sampler_sample(sampler, context, -1)
    if llama_vocab_is_eog(vocab, newToken) { break }
    outputTokens.append(newToken)

    nextBatch.n_tokens = 1
    nextBatch.token[0] = newToken
    nextBatch.pos[0] = currentPos
    nextBatch.n_seq_id[0] = 1
    nextBatch.seq_id[0]![0] = 0
    nextBatch.logits[0] = 1

    guard llama_decode(context, nextBatch) == 0 else { break }
    currentPos += 1
}
```

### WR-03: ModelWarmupService Watchdog Uses Self Before Detach

**File:** `Dicticus/Dicticus/Services/ModelWarmupService.swift:140`
**Issue:** The watchdog task closure captures `[weak self]` but then immediately accesses `self?.warmupTimeoutSeconds` to compute the sleep duration. If `self` is deallocated before the `Task.sleep` call evaluates, `self?.warmupTimeoutSeconds` returns `nil`, and the nil-coalescing operator falls back to `600`. This is functionally correct but the intent is fragile -- the timeout value should be captured before the task is created to avoid any ambiguity:

```swift
try? await Task.sleep(nanoseconds: (self?.warmupTimeoutSeconds ?? 600) * 1_000_000_000)
```

If `self` is nil at this point, the watchdog sleeps for 600 seconds doing nothing (since `guard let self` on line 141 will exit). This is a wasted 600-second sleeping Task in a degenerate case.

**Fix:** Capture the timeout value eagerly:

```swift
let timeout = warmupTimeoutSeconds
watchdogTask = Task { [weak self] in
    try? await Task.sleep(nanoseconds: timeout * 1_000_000_000)
    guard let self else { return }
    if self.isWarming {
        self.cancelWarmup()
    }
}
```

### WR-04: tokenToPiece Silently Drops Tokens Longer Than 256 Bytes

**File:** `Dicticus/Dicticus/Services/CleanupService.swift:306-307`
**Issue:** The `tokenToPiece` method uses a fixed 256-byte buffer. If `llama_token_to_piece` returns a value where `nChars > 256`, the buffer would be too small, but the current code guards with `guard nChars > 0` which would pass. However, the llama.cpp API returns a negative value when the buffer is too small (the magnitude indicates the required size). The guard `guard nChars > 0` correctly handles this by returning empty string, but the token is silently dropped from the output, potentially corrupting the cleaned text. While 256 bytes is generous for a single token (typically 1-4 bytes), multi-byte Unicode sequences from German text (umlauts, etc.) combined with certain tokenizer behaviors could theoretically exceed this.

**Fix:** Handle the "buffer too small" case by retrying with a larger buffer:

```swift
private nonisolated static func tokenToPiece(token: llama_token, vocab: OpaquePointer?) -> String {
    guard let vocab else { return "" }
    var buffer = [CChar](repeating: 0, count: 256)
    var nChars = llama_token_to_piece(vocab, token, &buffer, 256, 0, false)
    if nChars < 0 {
        // Buffer too small -- retry with required size
        let requiredSize = Int(-nChars)
        buffer = [CChar](repeating: 0, count: requiredSize)
        nChars = llama_token_to_piece(vocab, token, &buffer, Int32(requiredSize), 0, false)
    }
    guard nChars > 0 else { return "" }
    var nullTerminated = Array(buffer.prefix(Int(nChars)))
    nullTerminated.append(0)
    return String(decoding: nullTerminated.map { UInt8(bitPattern: $0) }, as: UTF8.self)
}
```

### WR-05: NotificationServiceTests Missing Coverage for New Phase 4 Cases

**File:** `Dicticus/DicticusTests/NotificationServiceTests.swift:31-38`
**Issue:** The `testAllNotificationsHaveDicticusTitle` test checks only 4 notification cases (busy, modelLoading, transcriptionFailed, recordingFailed) but does not include the 3 cases added in Phase 4: `.unexpectedLanguage`, `.cleanupFailed`, and `.llmLoading`. These are defined in `NotificationService.swift` lines 19-23 and have message strings that should be verified. This means the Phase 4 notification messages are untested for content correctness.

**Fix:** Add the missing cases to the comprehensive title test and add individual message tests:

```swift
func testAllNotificationsHaveDicticusTitle() {
    let cases: [DicticusNotification] = [
        .busy,
        .modelLoading,
        .transcriptionFailed(NSError(domain: "test", code: 1)),
        .recordingFailed(NSError(domain: "test", code: 2)),
        .unexpectedLanguage,
        .cleanupFailed,
        .llmLoading,
    ]
    for notification in cases {
        XCTAssertEqual(notification.title, "Dicticus", "Title mismatch for \(notification)")
    }
}

func testCleanupFailedMessage() {
    let notification = DicticusNotification.cleanupFailed
    XCTAssertEqual(notification.message, "AI cleanup failed. Raw text was pasted instead.")
}

func testLLMLoadingMessage() {
    let notification = DicticusNotification.llmLoading
    XCTAssertEqual(notification.message, "AI model still loading, please wait a moment.")
}
```

## Info

### IN-01: llama_backend_init() Called Without Corresponding llama_backend_free()

**File:** `Dicticus/Dicticus/Services/CleanupService.swift:68, 355-356`
**Issue:** `initializeBackend()` calls `llama_backend_init()` but the comment in `deinit` (line 355) notes that `llama_backend_free()` is intentionally not called. This is correct for a menu bar app that runs until quit, but there is no guard against calling `initializeBackend()` multiple times. While `llama_backend_init()` is idempotent in current llama.cpp versions, adding a static guard would be more robust.

**Fix:** Add a static flag:

```swift
private static var backendInitialized = false

static func initializeBackend() {
    guard !backendInitialized else { return }
    llama_backend_init()
    backendInitialized = true
}
```

### IN-02: Hardcoded HuggingFace URL for Model Download

**File:** `Dicticus/Dicticus/Services/ModelDownloadService.swift:16`
**Issue:** The model download URL is hardcoded as a static constant. If the unsloth HuggingFace repo changes the filename, moves the model, or the repo is taken down, the app's first-run experience breaks with no recovery path other than a code change and app update. This is acceptable for v1 but should be noted for future resilience.

**Fix:** No immediate fix needed. Consider making the URL configurable via a remote config endpoint in a future version, or providing a user-facing "download model from URL" option in settings.

### IN-03: CleanupPrompt German Text Uses ASCII Substitutions for Umlauts

**File:** `Dicticus/Dicticus/Models/CleanupPrompt.swift:22-26`
**Issue:** The German prompt uses ASCII substitutions for umlauts (Fuellwoerter, aehm, Grossschreibung, Aendere, Erklaerungen) instead of actual German characters (Fullworter, ahm, Grossschreibung, Andere, Erklarungen). While this avoids potential encoding issues and is fine since the LLM understands both forms, using proper German characters would make the prompt more natural and potentially improve the LLM's response quality for German text.

**Fix:** Consider using proper German characters in the prompt strings. This is purely cosmetic and does not affect functionality.

---

_Reviewed: 2026-04-18T14:32:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
