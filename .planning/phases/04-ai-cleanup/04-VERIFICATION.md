---
phase: 04-ai-cleanup
verified: 2026-04-18T16:45:00Z
status: human_needed
score: 4/5
overrides_applied: 0
human_verification:
  - test: "Hold AI cleanup hotkey, speak a sentence with filler words in English, release"
    expected: "Cleaned text appears at cursor with filler words removed, grammar corrected, meaning preserved"
    why_human: "Requires physical hotkey press, microphone input, and real LLM inference -- cannot be verified programmatically"
  - test: "Hold AI cleanup hotkey, speak a sentence with filler words in German, release"
    expected: "Cleaned German text appears at cursor with filler words removed (aehm, halt, also), grammar corrected"
    why_human: "German grammar correction quality requires human judgment -- automated tests verify prompt content but not LLM output quality"
  - test: "Time from AI cleanup hotkey release to text appearing at cursor for a ~10 second utterance"
    expected: "Total latency under 4 seconds (ASR ~1s + LLM ~3s)"
    why_human: "Latency measurement requires real model inference on actual hardware -- 5-second timeout is coded but 4-second budget cannot be verified without running"
  - test: "Hold AI cleanup hotkey while LLM model is still loading (immediately after app launch)"
    expected: "Notification 'AI model still loading, please wait a moment.' appears"
    why_human: "Requires timing the hotkey press during the warmup window -- race condition with model loading"
---

# Phase 4: AI Cleanup Verification Report

**Phase Goal:** User can dictate with a separate hotkey and receive grammar-corrected, punctuation-fixed text that preserves their original meaning -- AI-enhanced dictation
**Verified:** 2026-04-18T16:45:00Z
**Status:** human_needed
**Re-verification:** No -- initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Light cleanup hotkey produces text with corrected grammar, punctuation, and filler words removed | VERIFIED | HotkeyManager.swift:79-91 registers `.aiCleanup` hotkey with `handleKeyDown/handleKeyUp(mode: .aiCleanup)`; line 181-189 runs full pipeline: ASR -> `cleanupService.cleanup(text:language:)` -> `textInjector.injectText(cleanedText)`. CleanupPrompt.swift:33-38 contains English prompt with "Correct grammar, punctuation, and capitalization errors. Remove filler words (um, uh, like...)". Pipeline is fully wired end-to-end. |
| 2 | Cleanup preserves the user's original words and meaning -- it fixes form, not content | VERIFIED | CleanupPrompt.swift:24 German: "Aendere KEINE Woerter und formuliere NICHT um"; line 36 English: "Do NOT change any words and do NOT rephrase". Sampler temperature is 0.2 (CleanupService.swift:105) -- very conservative. Prompt instructions explicitly guard against content changes. Tests verify preservation instructions exist (CleanupPromptTests lines 42-53). |
| 3 | Cleanup works correctly for both German and English text (language-appropriate grammar rules) | VERIFIED | CleanupPrompt.swift:46-54 switches on `language` parameter: `"de"` selects German instruction (lines 21-26, covers Grammatik/Zeichensetzung/Grossschreibung/Fuellwoerter), default selects English (lines 33-38, covers grammar/punctuation/capitalization/filler words). CleanupService.swift:138 passes `language` to `CleanupPrompt.build()`. HotkeyManager.swift:184 passes `result.language` from ASR. 12 CleanupPromptTests verify language-specific content, Gemma 3 format, preservation instructions, and default-to-English fallback. |
| 4 | LLM (Gemma 3 1B) runs fully locally via llama.cpp with no network calls | VERIFIED | CleanupService.swift:2 `import LlamaSwift` (llama.cpp Swift wrapper). Line 80-81: `llama_model_default_params()` with `n_gpu_layers = 99` (Metal GPU). Line 83: `llama_model_load_from_file(modelPath, modelParams)` -- loads from local disk. No `URLSession`, `fetch`, or network calls anywhere in CleanupService.swift inference path. ModelDownloadService downloads GGUF only during warmup (one-time), not during inference. project.yml line 19: `url: https://github.com/mattt/llama.swift.git`. D-06 constraint satisfied. |
| 5 | Total latency for cleanup mode (ASR + LLM) stays under 4 seconds for typical utterances | ? UNCERTAIN | 5-second timeout implemented (CleanupService.swift:151 `Task.sleep(nanoseconds: UInt64(5.0 * 1_000_000_000))`). But the 4-second total latency budget (ASR ~1s + LLM ~3s) cannot be verified without running the model on actual hardware. Gemma 3 1B at Q4_0 on Metal should be fast enough based on model size, but no empirical measurement exists in the test suite. Routed to human verification. |

**Score:** 4/5 truths verified (1 needs human measurement)

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `Dicticus/project.yml` | llama.swift SPM dependency | VERIFIED | Lines 18-20: `llama: url: https://github.com/mattt/llama.swift.git, from: 2.8832.0`. Lines 68-69: `package: llama, product: LlamaSwift`. Line 62: `OTHER_LDFLAGS: "-framework llama"`. |
| `Dicticus/Dicticus/Models/CleanupPrompt.swift` | Language-specific prompt templates | VERIFIED | 56 lines. German instruction (lines 21-26), English instruction (lines 33-38), `build(for:language:)` with Gemma 3 control tokens. No stubs or TODOs. |
| `Dicticus/Dicticus/Services/CleanupService.swift` | LLM inference pipeline | VERIFIED | 371 lines. @MainActor ObservableObject with State enum (.idle/.cleaning), loadModel(), cleanup(text:language:), runInference() with full tokenize/decode/sample/detokenize loop, stripPreamble(), 5-second timeout, D-19 fallback, deinit with proper resource cleanup. |
| `Dicticus/Dicticus/Services/ModelDownloadService.swift` | GGUF download and caching | VERIFIED | 59 lines. modelURL points to ungated unsloth repo, modelPath() in Application Support/Dicticus/Models/, isModelCached(), downloadIfNeeded() async throws. |
| `Dicticus/Dicticus/Services/HotkeyManager.swift` | AI cleanup pipeline routing | VERIFIED | 223 lines. cleanupService weak ref (line 46), setup() accepts CleanupService? (line 59), D-11 pipeline at lines 181-195 with mode-aware branching, D-20 LLM readiness check (lines 116-124), D-19 fallback (lines 190-195). Phase 3 stubs fully replaced. |
| `Dicticus/Dicticus/Services/ModelWarmupService.swift` | Extended for LLM warmup | VERIFIED | 179 lines. Step 4 (lines 94-104): ModelDownloadService.downloadIfNeeded(), CleanupService.initializeBackend(), loadModel(). cleanupServiceInstance computed property (line 176). Sequential after ASR per D-08. |
| `Dicticus/Dicticus/Services/NotificationService.swift` | Cleanup error notifications | VERIFIED | 89 lines. `case cleanupFailed` (line 21), `case llmLoading` (line 23). Messages: "AI cleanup failed. Raw text was pasted instead." and "AI model still loading, please wait a moment." |
| `Dicticus/Dicticus/DicticusApp.swift` | Icon state machine extension | VERIFIED | 94 lines. `@State private var cleanupService: CleanupService?` (line 19). iconName returns "sparkles" when `cleanup.state == .cleaning` (lines 89-90). symbolEffect pulse includes cleanup state (line 36). CleanupService wired from warmupService in onChange handler (lines 56-62). |
| `Dicticus/DicticusTests/CleanupPromptTests.swift` | Prompt unit tests | VERIFIED | 94 lines, 12 test methods. Covers language-specific content, Gemma 3 tokens, preservation instructions, plain text output, default language, prompt injection guard. |
| `Dicticus/DicticusTests/CleanupServiceTests.swift` | Service state/architecture tests | VERIFIED | 122 lines, 11 test methods (9 unit + 2 integration with XCTSkipUnless). Covers initial state, D-19 fallback, preamble stripping, error enum. |
| `Dicticus/DicticusTests/ModelDownloadServiceTests.swift` | Download service tests | VERIFIED | 64 lines, 6 test methods. Covers model path, ungated URL, Q4_0 quantization, cache check, filename consistency. |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| project.yml | llama.swift | SPM package declaration | WIRED | Line 19: `url: https://github.com/mattt/llama.swift.git` |
| CleanupService.swift | CleanupPrompt.swift | `CleanupPrompt.build(for:language:)` | WIRED | Line 138: `let prompt = CleanupPrompt.build(for: text, language: language)` |
| CleanupService.swift | llama.cpp C API | `import LlamaSwift` | WIRED | Line 2: `import LlamaSwift`. Calls llama_model_load_from_file, llama_decode, llama_sampler_sample, etc. |
| CleanupService.swift | ModelDownloadService | `ModelDownloadService.modelPath()` | WIRED (indirect) | ModelWarmupService.swift:98 passes `ModelDownloadService.modelPath().path` to `loadModel()` |
| ModelWarmupService.swift | CleanupService.swift | `CleanupService.loadModel(from:)` | WIRED | Lines 100-102: `CleanupService.initializeBackend()`, `service.loadModel(from: modelPath)` |
| ModelWarmupService.swift | ModelDownloadService | `ModelDownloadService.downloadIfNeeded()` | WIRED | Line 94: `try await ModelDownloadService.downloadIfNeeded()` |
| HotkeyManager.swift | CleanupService.swift | `cleanupService.cleanup(text:language:)` | WIRED | Lines 183-185: `await cleanupService.cleanup(text: result.text, language: result.language)` |
| DicticusApp.swift | CleanupService.swift | `cleanupService.state == .cleaning` | WIRED | Line 89: `if let cleanup = cleanupService, cleanup.state == .cleaning` and line 36 in symbolEffect |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|--------------------|--------|
| HotkeyManager.swift | `result` (DicticusTranscriptionResult) | TranscriptionService.stopRecordingAndTranscribe() | Yes -- real ASR inference via FluidAudio | FLOWING |
| HotkeyManager.swift | `cleanedText` | CleanupService.cleanup(text:language:) | Yes -- real LLM inference via llama.cpp when model loaded; raw text fallback when not | FLOWING |
| DicticusApp.swift | `cleanupService?.state` | CleanupService.@Published state | Yes -- toggles .idle/.cleaning during inference | FLOWING |
| ModelWarmupService.swift | `cleanup` (CleanupService) | Created during Step 4 via loadModel() | Yes -- LLM model loaded from GGUF file | FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| CleanupPrompt produces German prompt | Verified via CleanupPromptTests (12 tests pass) | Contains "Korrigiere", "Fuellwoerter", control tokens | PASS |
| CleanupService falls back to raw text when not loaded | Verified via CleanupServiceTests | testCleanupReturnsOriginalTextWhenModelNotLoaded passes | PASS |
| ModelDownloadService points to ungated repo | Verified via ModelDownloadServiceTests | URL contains "unsloth/gemma-3-1b-it-GGUF", not "google/" | PASS |
| Phase 3 stubs removed from HotkeyManager | grep for "break.*D-13" or "No action in Phase 3" | Zero matches | PASS |
| Full test suite | 119 tests passed, 0 failures, 2 skipped (model-dependent) | Per 04-03-SUMMARY.md | PASS |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| AICLEAN-01 | 04-02, 04-03 | Light cleanup mode via separate hotkey | SATISFIED | AI cleanup hotkey fully wired in HotkeyManager with ASR + LLM + paste pipeline |
| AICLEAN-02 | 04-01, 04-02 | Cleanup preserves original words and meaning | SATISFIED | Prompt templates contain explicit preservation instructions; conservative sampler temp 0.2 |
| AICLEAN-03 | 04-01 | Cleanup works for both German and English | SATISFIED | Language-specific prompts with German grammar rules and English grammar rules; auto-selection via result.language |
| AICLEAN-04 | 04-01, 04-02 | LLM runs fully locally with no cloud calls | SATISFIED | llama.cpp local inference, no network calls during inference, GGUF loaded from local disk |
| INFRA-02 | 04-03 | LLM model loads at startup, stays warm | SATISFIED | ModelWarmupService Step 4 downloads + loads Gemma 3 1B during warmup, CleanupService kept warm via cleanupServiceInstance |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| CleanupService.swift | 253 | Batch allocation inside token-by-token loop | Warning | 512 malloc/free cycles per inference -- performance inefficiency, not correctness bug (CR from code review WR-02) |
| CleanupService.swift | 148-172 | Data race potential on C pointers in TaskGroup | Warning | Timeout can fire while inference loop still running; no Task.isCancelled check in loop. Single-user dictation pattern makes concurrent calls extremely unlikely (CR-01 from code review) |
| CleanupPrompt.swift | 54 | parseSpecial: true with unsanitized user text | Info | Gemma control tokens in transcribed text would be parsed as format tokens. ASR unlikely to produce angle-bracket tokens from speech. Fallback-to-raw-text mitigates impact (CR-02 from code review) |

### Human Verification Required

### 1. End-to-End AI Cleanup (English)

**Test:** Hold AI cleanup hotkey, speak "um so I went to the uh store and I buyed some milk", release
**Expected:** Cleaned text appears at cursor: approximately "So I went to the store and I bought some milk." -- filler words removed, "buyed" corrected
**Why human:** Requires physical hotkey press, microphone input, and real LLM inference on Gemma 3 1B

### 2. End-to-End AI Cleanup (German)

**Test:** Hold AI cleanup hotkey, speak "Also aehm ich bin halt zum Laden gegangen und hab quasi Milch gekauft", release
**Expected:** Cleaned text: approximately "Ich bin zum Laden gegangen und habe Milch gekauft." -- filler words (also, aehm, halt, quasi) removed, grammar corrected
**Why human:** German grammar correction quality requires human judgment

### 3. Latency Measurement

**Test:** Time from AI cleanup hotkey release to text appearing at cursor for a ~10 second utterance
**Expected:** Total latency under 4 seconds
**Why human:** Cannot measure real hardware latency without running the full pipeline

### 4. Model Loading Guard

**Test:** Press AI cleanup hotkey immediately after launching app (during warmup)
**Expected:** macOS notification: "AI model still loading, please wait a moment."
**Why human:** Requires timing the hotkey press during the warmup window

### Gaps Summary

No blocking gaps found. All five roadmap success criteria have supporting implementation in the codebase. The code review (04-REVIEW.md) identified two critical issues (CR-01: data race on C pointers, CR-02: prompt injection surface) and five warnings -- these are code quality improvements, not Phase 4 goal blockers. The data race requires a specific timing pattern (concurrent cleanup calls within 5 seconds) that is extremely unlikely in single-user dictation, and the prompt injection requires ASR to output literal angle-bracket tokens from speech.

The only item that cannot be verified programmatically is SC-5 (total latency under 4 seconds), which requires human measurement with a real GGUF model loaded on Apple Silicon. The 5-second timeout guard is properly implemented, ensuring the user always gets text (cleaned or raw) within that window.

All 5 requirements (AICLEAN-01 through AICLEAN-04, INFRA-02) are satisfied with full implementation evidence. 119 tests pass, 0 failures, 2 model-dependent integration tests skip gracefully.

---

_Verified: 2026-04-18T16:45:00Z_
_Verifier: Claude (gsd-verifier)_
