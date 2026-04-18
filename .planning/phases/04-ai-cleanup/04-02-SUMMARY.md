---
phase: 04-ai-cleanup
plan: 02
subsystem: llm-inference
tags: [llm, llama-cpp, cleanup-service, inference, swift6, tdd, sampler]
dependency_graph:
  requires: [04-01-llm-foundation]
  provides: [CleanupService, CleanupError]
  affects: [04-03-warmup-wiring, 04-04-hotkey-wiring]
tech_stack:
  added: []
  patterns: [nonisolated(unsafe) for C pointer properties in @MainActor deinit, UnsafeMutablePointer<llama_sampler> for fully-defined C struct, OpaquePointer for forward-declared C structs, llama_memory_clear replacing deprecated llama_kv_cache_clear, OTHER_LDFLAGS for explicit xcframework C symbol linking in test builds]
key_files:
  created:
    - Dicticus/Dicticus/Services/CleanupService.swift
    - Dicticus/DicticusTests/CleanupServiceTests.swift
  modified:
    - Dicticus/project.yml
    - Dicticus/Dicticus.xcodeproj/project.pbxproj
decisions:
  - "llama_kv_cache_clear removed in current llama.cpp — use llama_memory_clear(llama_get_memory(ctx), false) instead"
  - "llama_tokenize/llama_token_to_piece/llama_vocab_is_eog take llama_vocab* not llama_model* — get via llama_model_get_vocab(model)"
  - "llama_sampler is a fully-defined struct in llama.h, so UnsafeMutablePointer<llama_sampler> not OpaquePointer"
  - "Swift 6 deinit is nonisolated — @MainActor class C pointer properties need nonisolated(unsafe) to be freed in deinit"
  - "OTHER_LDFLAGS=-framework llama required in project.yml: LlamaSwift re-exports the C module but the test dylib linker needs explicit llama.framework for direct C API callers (CleanupService is the first file to call llama_* C functions directly)"
metrics:
  duration: "~45 minutes"
  completed_date: "2026-04-18"
  tasks_completed: 2
  files_created: 2
  files_modified: 2
---

# Phase 4 Plan 2: CleanupService — LLM Inference Pipeline

One-liner: CleanupService wraps llama.cpp C API behind @MainActor ObservableObject for Gemma 3 1B inference with 5-second timeout, KV cache clearing via llama_memory_clear, conservative sampling (temp 0.2), and D-19 raw text fallback.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Create CleanupService with llama.cpp inference pipeline | 53fb7fc | CleanupService.swift |
| 2 | Unit tests for CleanupService state machine and architecture | e06397b | CleanupServiceTests.swift, project.yml, project.pbxproj |

## What Was Built

**CleanupService** (`Dicticus/Services/CleanupService.swift`): Full LLM inference pipeline in 355 lines. @MainActor ObservableObject following D-12 pattern. Stores llama_model, llama_context (OpaquePointer — forward-declared), and llama_sampler (UnsafeMutablePointer — fully-defined struct) as private nonisolated(unsafe) properties. `loadModel(from:)` loads GGUF, creates context (n_ctx=2048, n_batch=512, n_threads=4), builds sampler chain (temp=0.2, top-k=40, top-p=0.9, dist). `cleanup(text:language:)` builds Gemma 3 prompt via CleanupPrompt.build, races inference against 5-second timeout via withThrowingTaskGroup, strips preambles, returns raw text on any failure (D-19). `runInference` is a nonisolated static method: clears KV cache via llama_memory_clear, resets sampler, tokenizes via llama_vocab*, batch-decodes prompt, samples until EOG, detokenizes. `stripPreamble` removes 10 known Gemma output preamble patterns.

**CleanupServiceTests** (`DicticusTests/CleanupServiceTests.swift`): 9 tests — initial state (idle, isLoaded=false), D-19 fallback for English and German when not loaded, preamble stripping for English/German/Sure!/whitespace cases, error enum verification, plus 2 integration tests guarded by XCTSkipUnless for ModelDownloadService.isModelCached(). All 7 unit tests pass; 2 integration tests skip gracefully without the GGUF model.

**project.yml fix**: Added `OTHER_LDFLAGS: "-framework llama"` to Dicticus target build settings. This resolved a test-build linker failure where `Dicticus.debug.dylib` could not find `_llama_*` symbols. CleanupService is the first file in the project to directly call llama C API functions; the LlamaSwift wrapper re-exports the C module but the linker needs llama.framework explicit for test dylib builds.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] llama.cpp API changes from plan spec**
- **Found during:** Task 1 build + verification
- **Issue:** Plan spec referenced outdated API: `llama_kv_cache_clear(context)` removed; `llama_tokenize/token_to_piece/vocab_is_eog` now take `llama_vocab*` not `llama_model*`; `llama_model_get_model` doesn't exist (correct is `llama_get_model`). Read the actual `llama.h` from DerivedData to identify current API.
- **Fix:** Used `llama_memory_clear(llama_get_memory(ctx), false)` for KV cache clearing. Got vocab via `llama_model_get_vocab(model)`. Used correct function signatures throughout.
- **Files modified:** `CleanupService.swift`
- **Commit:** 53fb7fc

**2. [Rule 1 - Bug] llama_sampler type mismatch**
- **Found during:** Task 1 build (first build attempt)
- **Issue:** Plan spec used `OpaquePointer` for all llama C types. But `llama_sampler` is a fully-defined struct in llama.h, not forward-declared — Swift maps it to `UnsafeMutablePointer<llama_sampler>`, not `OpaquePointer`. First build failed with type mismatch errors.
- **Fix:** Changed `sampler` property and `runInference` parameter to `UnsafeMutablePointer<llama_sampler>`.
- **Files modified:** `CleanupService.swift`
- **Commit:** e06397b (combined with Swift 6 deinit fix below)

**3. [Rule 1 - Bug] Swift 6 deinit isolation constraint**
- **Found during:** Task 1 build (second build attempt)
- **Issue:** Swift 6 makes `deinit` nonisolated even in @MainActor classes. Accessing `model`, `context`, `sampler` from deinit to call llama_free/llama_model_free/llama_sampler_free failed: "cannot access property with non-Sendable type from nonisolated deinit".
- **Fix:** Added `nonisolated(unsafe)` to all three C pointer properties. Safe because: (1) these are only written during `loadModel()` which runs on MainActor, (2) `runInference` receives copies via local vars, (3) deinit is guaranteed to run after all other accesses complete.
- **Files modified:** `CleanupService.swift`
- **Commit:** e06397b

**4. [Rule 3 - Blocker] Test build linker failure**
- **Found during:** Task 2 test run
- **Issue:** `xcodebuild test` failed with `Undefined symbol: _llama_backend_init` (and all other llama symbols). CleanupService is the first file to directly call llama C functions. The LlamaSwift SPM product re-exports the C `llama` module, but the test build creates `Dicticus.debug.dylib` and the linker needs `llama.framework` explicitly to resolve C symbols — auto-linking from `@_exported import llama` doesn't propagate through the test dylib build chain.
- **Fix:** Added `OTHER_LDFLAGS: "-framework llama"` to the Dicticus target in `project.yml`, regenerated xcodeproj via xcodegen. All 9 CleanupServiceTests tests then pass (7 unit + 2 skipped).
- **Files modified:** `project.yml`, `project.pbxproj`
- **Commit:** e06397b

## Known Stubs

None — CleanupService is a complete implementation. The integration tests (`testCleanupProducesOutputWithModel`, `testCleanupStateTransitionsDuringInference`) use XCTSkipUnless to guard against missing GGUF model, which is the correct pattern (not a stub — the tests fully exercise the code path when the model is present).

## Threat Flags

| Flag | File | Description |
|------|------|-------------|
| threat_flag: supply-chain | Dicticus/project.yml | OTHER_LDFLAGS now explicitly links llama.framework (the xcframework binary). This is the same binary already depended on via LlamaSwift; the explicit flag adds no new trust boundary, just makes the existing one visible to the linker. |

## Self-Check: PASSED

| Item | Status |
|------|--------|
| CleanupService.swift | FOUND |
| CleanupServiceTests.swift | FOUND |
| Commit 53fb7fc (Task 1) | FOUND |
| Commit e06397b (Task 2) | FOUND |
| All CleanupServiceTests pass | VERIFIED (7 passed, 2 skipped) |
| Full test suite passes | VERIFIED (all suites passed) |
