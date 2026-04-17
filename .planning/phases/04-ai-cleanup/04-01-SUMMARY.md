---
phase: 04-ai-cleanup
plan: 01
subsystem: llm-foundation
tags: [llm, llama-swift, model-download, cleanup-prompt, gemma3, spm, tdd]
dependency_graph:
  requires: []
  provides: [llama-swift-spm, ModelDownloadService, CleanupPrompt]
  affects: [04-02-CleanupService, 04-03-warmup-wiring]
tech_stack:
  added: [llama.swift 2.8833.0, Gemma 3 1B IT Q4_0 GGUF (unsloth)]
  patterns: [URLSession.download async/await, ApplicationSupportDirectory caching, Gemma 3 single-turn chat format]
key_files:
  created:
    - Dicticus/Dicticus/Services/ModelDownloadService.swift
    - Dicticus/Dicticus/Models/CleanupPrompt.swift
    - Dicticus/DicticusTests/CleanupPromptTests.swift
    - Dicticus/DicticusTests/ModelDownloadServiceTests.swift
  modified:
    - Dicticus/project.yml
    - Dicticus/Dicticus.xcodeproj/project.pbxproj
    - Dicticus/Dicticus.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved
decisions:
  - "llama.swift product name is LlamaSwift (not llama) — Package.swift exposes library as LlamaSwift; project.yml uses package alias 'llama' with product: LlamaSwift"
  - "SPM resolved 2.8833.0 from from: 2.8832.0 floor — correct semver behavior, no action needed"
  - "unsloth/gemma-3-1b-it-GGUF chosen over google/gemma-3-1b-it-qat-q4_0-gguf — Google repo is gated (requires login + license), unsloth mirror is publicly accessible"
  - "DicticusTests does not import LlamaSwift directly — llama dependency added to test target for completeness but tests only use @testable import Dicticus"
metrics:
  duration: "~20 minutes"
  completed_date: "2026-04-17"
  tasks_completed: 2
  files_created: 4
  files_modified: 3
---

# Phase 4 Plan 1: LLM Foundation — llama.swift SPM, ModelDownloadService, CleanupPrompt

One-liner: llama.swift 2.8833.0 SPM dependency wired, Gemma 3 1B GGUF download service cached to Application Support, language-specific German/English cleanup prompts with Gemma 3 chat format tokens.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Add llama.swift SPM dependency, create ModelDownloadService and CleanupPrompt | f40dde3 | project.yml, ModelDownloadService.swift, CleanupPrompt.swift, project.pbxproj, Package.resolved |
| 2 | Unit tests for CleanupPrompt and ModelDownloadService | 6cd1bf1 | CleanupPromptTests.swift, ModelDownloadServiceTests.swift, project.pbxproj |

## What Was Built

**llama.swift SPM dependency** (`project.yml`): Added `llama.swift` at `from: 2.8832.0` (resolved to 2.8833.0). The package exposes product `LlamaSwift` — the plan spec said `llama` but the actual Package.swift names it `LlamaSwift`. Added to both Dicticus and DicticusTests targets. Project regenerated via xcodegen and BUILD SUCCEEDED.

**ModelDownloadService** (`Dicticus/Services/ModelDownloadService.swift`): Downloads the Gemma 3 1B IT Q4_0 GGUF from `unsloth/gemma-3-1b-it-GGUF` (ungated HuggingFace repo). Uses `URLSession.shared.download(from:)` for automatic temp file handling, then moves to `~/Library/Application Support/Dicticus/Models/gemma-3-1b-it-Q4_0.gguf`. Provides `isModelCached()` and `downloadIfNeeded() async throws`.

**CleanupPrompt** (`Dicticus/Models/CleanupPrompt.swift`): Language-specific Gemma 3 cleanup prompts. German instruction covers Grammatik/Zeichensetzung/Grossschreibung with explicit "KEINE Woerter aendern" and "NICHT umformulieren" guards. English instruction covers grammar/punctuation/capitalization with "Do NOT change any words" and "do NOT rephrase" guards. Both output plain text only. Gemma 3 single-turn chat format with `<start_of_turn>user` / `<end_of_turn>` / `<start_of_turn>model` tokens. Unknown language defaults to English.

**Tests** (19 passing): 12 CleanupPromptTests verify language-specific content, Gemma 3 control tokens, preservation instructions, plain text output, default language fallback, and prompt injection guard (user text in data position after "Text: " delimiter). 7 ModelDownloadServiceTests verify model path, ungated unsloth URL, Q4_0 quantization, Application Support caching, and cache-check logic.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed case-sensitive assertion in testEnglishPromptContainsPreservationInstruction**
- **Found during:** Task 2 test run
- **Issue:** Test asserted `prompt.contains("do NOT change")` but the prompt uses sentence-case `"Do NOT change"` (capital D) as written in the plan's code spec. Swift `String.contains` is case-sensitive.
- **Fix:** Changed assertion to use `prompt.lowercased().contains("do not change")` to match regardless of capitalization, preserving intent of the test without altering the prompt implementation.
- **Files modified:** `Dicticus/DicticusTests/CleanupPromptTests.swift`
- **Commit:** 6cd1bf1

### Architectural Adjustments

**llama.swift product name:** The plan spec used `product: llama` but the actual `Package.swift` in `mattt/llama.swift` exposes the library as `LlamaSwift`. Changed to `product: LlamaSwift` to match the actual package definition. This is a correctness fix, not an architectural deviation.

## Known Stubs

None — ModelDownloadService and CleanupPrompt are fully wired implementations with real URLs and prompt content. No placeholder values.

## Threat Flags

| Flag | File | Description |
|------|------|-------------|
| threat_flag: supply-chain | Dicticus/project.yml | llama.swift SPM dependency pulls llama.cpp xcframework (~50MB binary) from GitHub releases at build time. GGUF model pulled from HuggingFace at runtime. Both are well-known open-source artifacts but represent new external trust anchors. |

## Self-Check: PASSED

All created files found on disk. Both task commits verified in git log.

| Item | Status |
|------|--------|
| ModelDownloadService.swift | FOUND |
| CleanupPrompt.swift | FOUND |
| CleanupPromptTests.swift | FOUND |
| ModelDownloadServiceTests.swift | FOUND |
| Commit f40dde3 (Task 1) | FOUND |
| Commit 6cd1bf1 (Task 2) | FOUND |
