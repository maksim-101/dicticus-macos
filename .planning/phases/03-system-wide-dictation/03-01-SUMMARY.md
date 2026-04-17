---
phase: 03-system-wide-dictation
plan: 01
subsystem: macOS app - text injection, hotkeys, notifications
tags: [swift6, spm, keyboard-shortcuts, clipboard, cgevent, notifications, tdd]
dependency_graph:
  requires: []
  provides:
    - KeyboardShortcuts 2.4.0 SPM dependency
    - KeyboardShortcuts.Name.plainDictation (Ctrl+Shift+S)
    - KeyboardShortcuts.Name.aiCleanup (Ctrl+Shift+D)
    - TextInjector (clipboard save/write/Cmd+V paste/restore pipeline)
    - NotificationService (UNUserNotificationCenter wrapper)
    - DicticusNotification enum (busy, modelLoading, transcriptionFailed, recordingFailed)
  affects:
    - Dicticus/project.yml
    - Dicticus/Dicticus.xcodeproj/project.pbxproj
tech_stack:
  added:
    - KeyboardShortcuts 2.4.0 (sindresorhus) via SPM
    - UserNotifications framework (UNUserNotificationCenter)
    - CoreGraphics (CGEvent for paste synthesis)
    - AppKit (NSPasteboard for clipboard management)
  patterns:
    - TDD (RED tests first, then GREEN implementation)
    - "@MainActor singleton for Swift 6 concurrency compliance"
    - Clipboard save/write/CGEvent-paste/restore pipeline (VocaMac/Speak2 pattern)
    - UNUserNotificationCenter with nil trigger for immediate delivery
key_files:
  created:
    - Dicticus/Dicticus/Extensions/KeyboardShortcuts+Names.swift
    - Dicticus/Dicticus/Services/TextInjector.swift
    - Dicticus/Dicticus/Services/NotificationService.swift
    - Dicticus/DicticusTests/TextInjectorTests.swift
    - Dicticus/DicticusTests/NotificationServiceTests.swift
  modified:
    - Dicticus/project.yml
    - Dicticus/Dicticus.xcodeproj/project.pbxproj
decisions:
  - "@MainActor on NotificationService singleton for Swift 6 strict concurrency compliance — consistent with TranscriptionService pattern"
  - "Control+Shift+S and Control+Shift+D as default hotkey combos — Fn key not supported by KeyboardShortcuts (RESEARCH.md Pitfall 1); user can reconfigure"
  - "KeyboardShortcuts added to DicticusTests target so test files can import it for future HotkeyManagerTests"
metrics:
  duration: "31 minutes"
  completed: "2026-04-17T08:30:22Z"
  tasks_completed: 2
  files_created: 5
  files_modified: 2
  tests_added: 9
  tests_passing: 9
---

# Phase 03 Plan 01: KeyboardShortcuts + TextInjector + NotificationService Summary

**One-liner:** KeyboardShortcuts 2.4.0 SPM wired with clipboard-based text injection and UNUserNotificationCenter error notifications, all Swift 6 compliant.

## What Was Built

Three foundational building blocks that Plan 02 (HotkeyManager) and Plan 03 (MenuBarView UI) consume:

1. **KeyboardShortcuts 2.4.0 SPM dependency** — added to `project.yml` for both the main Dicticus target and DicticusTests target. Resolved and verified with `xcodebuild -resolvePackageDependencies`.

2. **KeyboardShortcuts+Names.swift** — defines `KeyboardShortcuts.Name.plainDictation` (default: Ctrl+Shift+S) and `KeyboardShortcuts.Name.aiCleanup` (default: Ctrl+Shift+D). Fn key intentionally not used per RESEARCH.md Pitfall 1.

3. **TextInjector.swift** — clipboard save/write/Cmd+V paste/restore pipeline. Saves all pasteboard item types (string, RTF, HTML, images), writes transcription text, synthesizes Cmd+V via CGEvent (V=keyCode 9, layout-independent), waits 50ms, then restores original clipboard. Follows proven VocaMac/Speak2/Maccy pattern.

4. **NotificationService.swift** — `@MainActor` singleton wrapping `UNUserNotificationCenter`. Posts immediate notifications (nil trigger) for four error states: busy, modelLoading, transcriptionFailed, recordingFailed. Exact message wording matches UI-SPEC copywriting contract.

## Tests

| Suite | Tests | Result |
|-------|-------|--------|
| TextInjectorTests | 4 | PASS |
| NotificationServiceTests | 5 | PASS |
| **Total** | **9** | **PASS** |

TextInjectorTests cover: clipboard string save/restore round-trip, multi-type (string+RTF) save/restore, empty clipboard handling, and paste synthesis no-crash guarantee.

NotificationServiceTests cover: exact message strings for all 4 notification cases, and title="Dicticus" for all cases.

## Commits

| Hash | Task | Description |
|------|------|-------------|
| bd44c94 | Task 1 | feat(03-01): add KeyboardShortcuts SPM dep, hotkey names, TextInjector with tests |
| 74eddf4 | Task 2 | feat(03-01): add NotificationService with UNUserNotificationCenter wrapper and tests |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Swift 6 concurrency error on NotificationService.shared singleton**
- **Found during:** Task 2, first test run
- **Issue:** Swift 6 strict concurrency mode (`SWIFT_VERSION: "6.0"`) rejected `static let shared = NotificationService()` on a plain `class` — error: "Static property 'shared' is not concurrency-safe because non-'Sendable' type 'NotificationService' may have shared mutable state"
- **Fix:** Added `@MainActor` to `NotificationService` class declaration. All future call sites (HotkeyManager in Plan 02, app lifecycle) will be on @MainActor, making this the correct isolation domain. Matches pattern used by TranscriptionService.
- **Files modified:** `Dicticus/Dicticus/Services/NotificationService.swift`
- **Commit:** 74eddf4

## Threat Model Review

Threats T-03-01 through T-03-04 from the plan's threat register:

- **T-03-01 (mitigate — clipboard exposure window):** Implemented — save/write/paste/restore with 50ms delay. Window minimized.
- **T-03-02 (accept — clipboard managers may capture text):** Accepted — no `org.nspasteboard.AutoGeneratedType` marker added (out of scope for Plan 01, deferred).
- **T-03-03 (mitigate — CGEvent needs Accessibility):** `synthesizePaste()` is implemented; Accessibility gating will be enforced in Plan 02 HotkeyManager which calls `injectText()` only when `PermissionManager.allGranted`.
- **T-03-04 (accept — hotkey conflict):** KeyboardShortcuts handles conflict detection at the library level.

## Known Stubs

None. All files implement complete, working functionality. No placeholder data or TODO stubs.

## Threat Flags

None. No new network endpoints, auth paths, or file access patterns introduced beyond what was planned.

## Self-Check: PASSED

Files confirmed present:
- FOUND: Dicticus/Dicticus/Extensions/KeyboardShortcuts+Names.swift
- FOUND: Dicticus/Dicticus/Services/TextInjector.swift
- FOUND: Dicticus/Dicticus/Services/NotificationService.swift
- FOUND: Dicticus/DicticusTests/TextInjectorTests.swift
- FOUND: Dicticus/DicticusTests/NotificationServiceTests.swift

Commits confirmed:
- FOUND: bd44c94 (feat(03-01): add KeyboardShortcuts SPM dep, hotkey names, TextInjector with tests)
- FOUND: 74eddf4 (feat(03-01): add NotificationService with UNUserNotificationCenter wrapper and tests)

Tests: 9 passed, 0 failed — TEST SUCCEEDED
