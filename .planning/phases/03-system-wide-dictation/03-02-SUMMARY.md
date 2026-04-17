---
phase: 03-system-wide-dictation
plan: 02
subsystem: macOS app - hotkey state machine, icon state, HotkeyManager wiring
tags: [swift6, main-actor, keyboard-shortcuts, push-to-talk, state-machine, tdd]
dependency_graph:
  requires:
    - KeyboardShortcuts.Name.plainDictation (03-01)
    - KeyboardShortcuts.Name.aiCleanup (03-01)
    - TextInjector (03-01)
    - NotificationService / DicticusNotification (03-01)
    - TranscriptionService (02.x)
    - ModelWarmupService (01.x / 02.x)
  provides:
    - HotkeyManager (push-to-talk state machine)
    - DictationMode enum (plain, aiCleanup stub)
    - Extended DicticusApp icon state machine (mic / mic.fill / waveform.circle / mic.slash)
    - hotkeyManager.setup() wiring to TranscriptionService after warmup
  affects:
    - Dicticus/Dicticus/Services/HotkeyManager.swift (created)
    - Dicticus/Dicticus/DicticusApp.swift (modified)
    - Dicticus/Dicticus/Services/TextInjector.swift (modified — @MainActor added)
    - Dicticus/DicticusTests/HotkeyManagerTests.swift (created)
    - Dicticus/Dicticus.xcodeproj/project.pbxproj (regenerated via xcodegen)
tech_stack:
  added:
    - HotkeyManager @MainActor ObservableObject pattern
    - KeyboardShortcuts.events(for:) async stream consumption
    - DictationMode Sendable enum
  patterns:
    - "@MainActor class for Swift 6 strict concurrency on service objects"
    - "Task { [weak self] in } inside @MainActor class — inherits actor isolation"
    - "TDD: tests written alongside implementation (all passing)"
    - "Weak references to TranscriptionService and ModelWarmupService from HotkeyManager"
key_files:
  created:
    - Dicticus/Dicticus/Services/HotkeyManager.swift
    - Dicticus/DicticusTests/HotkeyManagerTests.swift
  modified:
    - Dicticus/Dicticus/DicticusApp.swift
    - Dicticus/Dicticus/Services/TextInjector.swift
decisions:
  - "@MainActor on TextInjector — NSPasteboard.general and CGEvent.post are main-thread-only APIs; @MainActor annotation is the correct isolation for all call sites and resolves Swift 6 Sendable error"
  - "Task { [weak self] in } without explicit actor annotation inside @MainActor class — Task inherits enclosing actor isolation in Swift 6, no need for explicit @MainActor attribute on closure (which caused a syntax error)"
  - "aiCleanup hotkey registered but silently no-ops in Phase 3 per D-13 — wired to LLM pipeline in Phase 4"
  - "isKeyDown resets to false on model-not-ready and busy guard paths — allows user to retry without releasing and re-pressing"
metrics:
  duration: "18 minutes"
  completed: "2026-04-17T10:40:00Z"
  tasks_completed: 2
  files_created: 2
  files_modified: 3
  tests_added: 10
  tests_passing: 10
---

# Phase 03 Plan 02: HotkeyManager Push-to-Talk State Machine Summary

**One-liner:** HotkeyManager @MainActor state machine wired to TranscriptionService via KeyboardShortcuts async streams, with three-state icon (mic / mic.fill / waveform.circle) in DicticusApp.

## What Was Built

The central coordination layer that ties hotkey events to the ASR pipeline and text injection — pressing the hotkey starts recording, releasing it transcribes and pastes text at cursor.

### HotkeyManager.swift

`@MainActor class HotkeyManager: ObservableObject` implementing the complete push-to-talk state machine:

- **`@Published var isRecording`** — drives DicticusApp icon state (mic.fill when true)
- **`@Published var lastPostedNotification`** — testability hook, not used in production UI
- **`private var isKeyDown`** — D-03: suppresses key repeat; second keyDown is a no-op
- **`handleKeyDown(mode:)`** — checks model readiness (D-17), checks busy state (D-19), calls `transcriptionService.startRecording()`
- **`handleKeyUp(mode:)`** — calls `stopRecordingAndTranscribe()`, injects result via `TextInjector`, silently discards `tooShort` (D-02) and `silenceOnly` (D-16) errors
- **`setup(transcriptionService:warmupService:)`** — registers `KeyboardShortcuts.events(for: .plainDictation)` and `.aiCleanup` async streams; `.aiCleanup` is a silent no-op stub per D-13

### DicticusApp.swift changes

- Added `@StateObject private var hotkeyManager = HotkeyManager()`
- In `onChange(of: warmupService.isReady)`: creates `TranscriptionService`, then calls `hotkeyManager.setup(transcriptionService: service, warmupService: warmupService)`
- Added `.environmentObject(hotkeyManager)` to MenuBarView
- Extended `iconName` to three-state machine:
  - `mic.slash` — permissions missing (degraded)
  - `mic.fill` — recording in progress (D-09)
  - `waveform.circle` — transcribing in progress (D-11/UI-SPEC)
  - `mic` — idle or warming
- `.symbolEffect(.pulse)` now activates during both warming AND transcribing
- `.foregroundStyle(.red)` applied when `isRecording` (D-09: red mic during recording)

### DictationMode enum

```swift
enum DictationMode: Sendable {
    case plain
    case aiCleanup  // Wired to LLM pipeline in Phase 4
}
```

## Tests

| Suite | Tests | Result |
|-------|-------|--------|
| HotkeyManagerTests | 10 | PASS |
| Full suite (all phases) | All | PASS |

HotkeyManagerTests cover: key repeat suppression (D-03), key-up resets flag, model-not-ready path (D-17), two hotkeys registered with distinct names (APP-04), icon state idle/recording properties, short press no-crash (D-02), reject-while-transcribing guard (D-19), DictationMode enum cases, and FluidAudio integration test (skipped when model not cached).

## Commits

| Hash | Task | Description |
|------|------|-------------|
| c2aecad | Task 1 | feat(03-02): add HotkeyManager push-to-talk state machine with tests |
| 55361bb | Task 2 | feat(03-02): wire HotkeyManager into DicticusApp, extend icon state machine |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Swift 6 concurrency error: TextInjector not @MainActor**
- **Found during:** Task 1, first build attempt
- **Issue:** Swift 6 strict concurrency rejected `await self.textInjector.injectText(...)` inside a Task because `TextInjector` (plain `class`) is not `Sendable`. The compiler reported "Sending 'self.textInjector' risks causing data races".
- **Fix:** Added `@MainActor` to `TextInjector` class declaration. `NSPasteboard.general` and `CGEvent.post` are both main-thread-only APIs — `@MainActor` is the correct isolation domain and matches all actual call sites. This is also consistent with the `NotificationService` pattern from Plan 01.
- **Files modified:** `Dicticus/Dicticus/Services/TextInjector.swift`
- **Commit:** c2aecad

**2. [Rule 1 - Bug] Swift syntax error: Task closure attribute placement**
- **Found during:** Task 1, second build attempt
- **Issue:** `Task { [weak self] @MainActor in }` is a syntax error in Swift — the closure attribute `@MainActor` cannot appear after the capture list.
- **Fix:** Removed explicit `@MainActor` from Task closures. Tasks created inside a `@MainActor` class inherit the enclosing actor's isolation automatically in Swift 6 — no explicit annotation needed.
- **Files modified:** `Dicticus/Dicticus/Services/HotkeyManager.swift`
- **Commit:** c2aecad

## Threat Model Review

Threats T-03-05 through T-03-08 from the plan's threat register:

- **T-03-05 (mitigate — DoS via key repeat flooding):** Implemented — `isKeyDown` flag fires before any resource allocation; `service.state != .idle` guard rejects while transcribing. Both guards are O(1) checks.
- **T-03-06 (accept — CGEvent Accessibility elevation):** Accepted — CGEvent posting requires Accessibility permission already granted by user. `TextInjector` is only called after transcription succeeds; no new surface added.
- **T-03-07 (mitigate — clipboard exposure window):** TextInjector's 50ms window is unchanged. `@MainActor` isolation added in this plan does not extend the exposure window.
- **T-03-08 (accept — KeyboardShortcuts UserDefaults tampering):** Accepted per plan.

## Known Stubs

- **`DictationMode.aiCleanup`** — intentional Phase 3 stub per D-13. `handleKeyDown(mode: .aiCleanup)` path exists but the `aiCleanup` KeyboardShortcuts event handler is an explicit `break`. Phase 4 will wire this to the LLM pipeline.

## Threat Flags

None. No new network endpoints, auth paths, or file access patterns introduced beyond what was planned.

## Self-Check: PASSED

Files confirmed present:
- FOUND: Dicticus/Dicticus/Services/HotkeyManager.swift
- FOUND: Dicticus/DicticusTests/HotkeyManagerTests.swift
- FOUND: Dicticus/Dicticus/DicticusApp.swift (modified)
- FOUND: Dicticus/Dicticus/Services/TextInjector.swift (modified)

Commits confirmed:
- FOUND: c2aecad (feat(03-02): add HotkeyManager push-to-talk state machine with tests)
- FOUND: 55361bb (feat(03-02): wire HotkeyManager into DicticusApp, extend icon state machine)

Tests: 10 HotkeyManagerTests passed, full suite passed — TEST SUCCEEDED
