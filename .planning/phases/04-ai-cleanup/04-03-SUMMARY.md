---
phase: 04-ai-cleanup
plan: "03"
subsystem: ai-cleanup-integration
tags: [llm, cleanup, hotkey, icon-state, warmup, integration]
dependency_graph:
  requires: ["04-01", "04-02"]
  provides: ["complete-ai-cleanup-pipeline"]
  affects: ["HotkeyManager", "ModelWarmupService", "DicticusApp", "NotificationService"]
tech_stack:
  added: []
  patterns:
    - "Sequential LLM warmup after ASR (D-07/D-08)"
    - "Mode-aware handleKeyDown/handleKeyUp branching on DictationMode"
    - "WeakRef CleanupService pattern matching transcriptionService/warmupService"
    - "sparkles SF Symbol for AI cleanup icon state (D-14/D-15)"
key_files:
  created: []
  modified:
    - Dicticus/Dicticus/Services/ModelWarmupService.swift
    - Dicticus/Dicticus/Services/NotificationService.swift
    - Dicticus/Dicticus/Services/HotkeyManager.swift
    - Dicticus/Dicticus/DicticusApp.swift
    - Dicticus/DicticusTests/ModelWarmupServiceTests.swift
    - Dicticus/DicticusTests/HotkeyManagerTests.swift
decisions:
  - "CleanupService @MainActor init must run via MainActor.run() inside Task.detached — cannot call @MainActor isolated init/static methods from background task directly"
  - "setup() gained cleanupService param without breaking existing call sites — DicticusApp updated in same plan"
  - "AI cleanup icon uses sparkles SF Symbol per D-14/D-15 — distinct visual cue from waveform.circle (transcribing)"
metrics:
  duration: "~12 minutes"
  completed_date: "2026-04-18"
  tasks_completed: 2
  files_modified: 6
requirements_covered:
  - AICLEAN-01
  - INFRA-02
---

# Phase 4 Plan 03: AI Cleanup Integration Summary

**One-liner:** Wired CleanupService into ModelWarmupService startup, HotkeyManager AI cleanup pipeline, and DicticusApp icon state machine — completing the full ASR + LLM + paste pipeline.

## What Was Built

This plan connects all Phase 4 building blocks (ModelDownloadService from Plan 01, CleanupService from Plan 02) into the running app:

1. **ModelWarmupService Step 4** — After ASR + VAD init, downloads Gemma 3 1B GGUF (if not cached) and loads it via CleanupService sequentially to avoid memory spikes. Exposes `cleanupServiceInstance` for DicticusApp wiring.

2. **NotificationService** — Added `cleanupFailed` and `llmLoading` cases with user-friendly messages per D-19/D-20.

3. **HotkeyManager** — Added `cleanupService` weak ref, updated `setup()` to accept `CleanupService?`, replaced Phase 3 stubs with live `handleKeyDown/handleKeyUp(mode: .aiCleanup)` calls, added D-20 LLM readiness guard in `handleKeyDown`, and mode-aware `handleKeyUp` branching: plain pastes raw ASR text; aiCleanup runs LLM cleanup then pastes (with cleanupFailed fallback).

4. **DicticusApp** — Added `@State var cleanupService`, wired from `warmupService.cleanupServiceInstance` in the `isReady` onChange handler, updated `setup()` call to pass `cleanupService`, updated `iconName` to return `"sparkles"` when `cleanup.state == .cleaning`, and extended `symbolEffect(.pulse)` to include cleanup state.

## Tasks

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Extend ModelWarmupService for LLM warmup and add cleanup notifications | 4476f79 | ModelWarmupService.swift, NotificationService.swift, ModelWarmupServiceTests.swift |
| 2 | Wire CleanupService into HotkeyManager pipeline and DicticusApp icon state | 0b8ecd4 | HotkeyManager.swift, DicticusApp.swift, HotkeyManagerTests.swift |

## Test Results

- 119 tests total, 0 failures, 2 skipped (FluidAudio integration tests — require model download, skip gracefully)
- New tests added:
  - `testCleanupServiceInstanceIsNilBeforeWarmup` (ModelWarmupServiceTests)
  - `testAICleanupKeyDownBeforeLLMReady` (HotkeyManagerTests)
  - `testAICleanupModeEnumExists` (HotkeyManagerTests)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed @MainActor isolation for CleanupService init inside Task.detached**
- **Found during:** Task 1 build
- **Issue:** Plan spec showed `CleanupService.initializeBackend()` and `CleanupService()` called directly inside `Task.detached`. But `CleanupService` is `@MainActor`-isolated — Swift 6 strict concurrency prevents calling `@MainActor` initializers/static methods from a non-isolated background task.
- **Fix:** Wrapped CleanupService creation in `try await MainActor.run { () throws -> CleanupService in ... }` to run on the correct actor while still inside the detached utility task. The `try await` correctly propagates the `loadModel(from:)` throwing call.
- **Files modified:** Dicticus/Dicticus/Services/ModelWarmupService.swift
- **Commit:** 4476f79

## Known Stubs

None — all Phase 3 stubs (`break  // D-13: No action in Phase 3`) removed and replaced with live pipeline.

## Threat Flags

No new trust boundaries introduced beyond what the plan's threat model covers (T-04-07, T-04-08, T-04-09). The LLM output path (CleanupService -> textInjector) follows the same clipboard restore pattern as the plain dictation path.

## Self-Check: PASSED

Files exist:
- Dicticus/Dicticus/Services/ModelWarmupService.swift — FOUND
- Dicticus/Dicticus/Services/NotificationService.swift — FOUND
- Dicticus/Dicticus/Services/HotkeyManager.swift — FOUND
- Dicticus/Dicticus/DicticusApp.swift — FOUND
- Dicticus/DicticusTests/ModelWarmupServiceTests.swift — FOUND
- Dicticus/DicticusTests/HotkeyManagerTests.swift — FOUND

Commits exist:
- 4476f79 (Task 1) — FOUND
- 0b8ecd4 (Task 2) — FOUND
