---
phase: 03-system-wide-dictation
plan: 03
subsystem: macOS app - menu bar dropdown UI (hotkey config + last transcription preview)
tags: [swift6, swiftui, keyboard-shortcuts, menu-bar, clipboard, ui]
dependency_graph:
  requires:
    - KeyboardShortcuts.Name.plainDictation / .aiCleanup (03-01)
    - HotkeyManager with isRecording / lastPostedNotification (03-02)
    - TranscriptionService.lastResult (02.x)
    - hotkeyManager @EnvironmentObject injected by DicticusApp (03-02)
  provides:
    - HotkeySettingsView (KeyboardShortcuts.Recorder for both hotkeys)
    - LastTranscriptionView (2-line truncated text + Copy button)
    - Updated MenuBarView with complete Phase 3 dropdown layout
    - HotkeyManager.lastTranscriptionText computed property
  affects:
    - Dicticus/Dicticus/Views/HotkeySettingsView.swift (created)
    - Dicticus/Dicticus/Views/LastTranscriptionView.swift (created)
    - Dicticus/Dicticus/Views/MenuBarView.swift (modified)
    - Dicticus/Dicticus/Services/HotkeyManager.swift (modified)
    - Dicticus/Dicticus.xcodeproj/project.pbxproj (regenerated via xcodegen)
tech_stack:
  added: []
  patterns:
    - "KeyboardShortcuts.Recorder embedded in VStack with HStack label+recorder layout"
    - "Conditional section visibility via if let text, !text.isEmpty in SwiftUI body"
    - "NSPasteboard.general.clearContents() + setString() for Copy button action"
    - "Computed property bridging HotkeyManager to TranscriptionService.lastResult"
key_files:
  created:
    - Dicticus/Dicticus/Views/HotkeySettingsView.swift
    - Dicticus/Dicticus/Views/LastTranscriptionView.swift
  modified:
    - Dicticus/Dicticus/Views/MenuBarView.swift
    - Dicticus/Dicticus/Services/HotkeyManager.swift
    - Dicticus/Dicticus.xcodeproj/project.pbxproj
decisions:
  - "lastTranscriptionText as computed property on HotkeyManager (not @Published) — reads TranscriptionService.lastResult at access time; no need for separate published binding since MenuBarView already observes hotkeyManager"
  - "Conditional Divider above Quit button — only rendered when LastTranscriptionView is visible, matching UI-SPEC Dropdown Menu Structure"
metrics:
  duration: "2 minutes"
  completed: "2026-04-17T10:46:00Z"
  tasks_completed: 1
  tasks_pending: 1
  files_created: 2
  files_modified: 3
  tests_added: 0
  tests_passing: 78
---

# Phase 03 Plan 03: HotkeySettingsView + LastTranscriptionView + MenuBarView Update Summary

**One-liner:** HotkeySettingsView and LastTranscriptionView added to MenuBarView dropdown; HotkeyManager.lastTranscriptionText bridges to TranscriptionService.lastResult; full build and 78-test suite pass.

## What Was Built

### Task 1: Create HotkeySettingsView, LastTranscriptionView, and update MenuBarView (COMPLETE)

**HotkeySettingsView.swift** — Hotkey configuration section per D-20/UI-SPEC:
- Section heading `Text("Hotkeys")` in `.headline` (semibold)
- Two `KeyboardShortcuts.Recorder` rows: "Plain Dictation" and "AI Cleanup"
- Same `.padding(.horizontal).padding(.vertical, 4)` pattern as PermissionRow

**LastTranscriptionView.swift** — Last transcription preview per D-21/UI-SPEC:
- Renders only when `text` is non-nil and non-empty (section hidden at session start)
- Section heading `Text("Last Transcription")` in `.headline`
- Body text with `.lineLimit(2)`, `.truncationMode(.tail)`, `accessibilityLabel("Last transcription")`
- "Copy" button: `.controlSize(.small)`, `.buttonStyle(.bordered)`, `accessibilityLabel("Copy last transcription")`
- Copy action: `NSPasteboard.general.clearContents()` + `setString(_:forType:.string)`

**MenuBarView.swift** — Updated dropdown layout per D-22/UI-SPEC Dropdown Menu Structure:
- Added `@EnvironmentObject var hotkeyManager: HotkeyManager`
- Embedded `HotkeySettingsView()` after permission rows (with Divider)
- Embedded `LastTranscriptionView(text: hotkeyManager.lastTranscriptionText)` after hotkeys
- Conditional Divider between last transcription and Quit — only when text is present

**HotkeyManager.swift** — Added computed property:
```swift
var lastTranscriptionText: String? {
    transcriptionService?.lastResult?.text
}
```

### Task 2: Human verification of end-to-end dictation workflow (PENDING)

This task is a `checkpoint:human-verify` — no code changes required. Human must run the built app and verify 10 end-to-end scenarios covering dictation in Notes, Safari, Terminal, icon state transitions, clipboard preservation, hotkey configuration, and last transcription preview.

## Tests

| Suite | Tests | Result |
|-------|-------|--------|
| Full suite (all phases) | 78 | PASS |

No new tests added — this plan adds UI-only views with no testable logic beyond what's exercised by the existing suite. LastTranscriptionView's Copy button action uses `NSPasteboard` directly (same pattern as TextInjectorTests already cover). HotkeyManager.lastTranscriptionText is a trivial computed property.

## Commits

| Hash | Task | Description |
|------|------|-------------|
| 464c675 | Task 1 | feat(03-03): add HotkeySettingsView, LastTranscriptionView, update MenuBarView dropdown layout |

## Deviations from Plan

None — plan executed exactly as written.

## Threat Model Review

Threats T-03-09 through T-03-11 from the plan's threat register:

- **T-03-09 (accept — LastTranscriptionView Copy button clipboard write):** Implemented — `NSPasteboard.general.clearContents()` + `setString(_:forType:.string)` in Copy button action. User-initiated explicit action. Text is already visible in the dropdown.
- **T-03-10 (accept — lastTranscriptionText memory-only):** Implemented — computed property reads `transcriptionService?.lastResult?.text` which is in-memory only, not persisted. Cleared on app restart.
- **T-03-11 (accept — KeyboardShortcuts.Recorder UserDefaults):** Accepted per plan. KeyboardShortcuts.Recorder writes to UserDefaults; same risk as T-03-08, user can reconfigure.

## Known Stubs

- **Task 2 (human verify)** — The checkpoint task requires human testing of the complete end-to-end workflow. The app builds and all automated tests pass; human verification scenarios are documented in the plan and must be completed before Phase 3 is fully signed off.

## Threat Flags

None. No new network endpoints, auth paths, or file access patterns introduced beyond what was planned.

## Self-Check: PASSED

Files confirmed present:
- FOUND: Dicticus/Dicticus/Views/HotkeySettingsView.swift
- FOUND: Dicticus/Dicticus/Views/LastTranscriptionView.swift
- FOUND: Dicticus/Dicticus/Views/MenuBarView.swift (modified)
- FOUND: Dicticus/Dicticus/Services/HotkeyManager.swift (modified)

Commits confirmed:
- FOUND: 464c675 (feat(03-03): add HotkeySettingsView, LastTranscriptionView, update MenuBarView dropdown layout)

Build: BUILD SUCCEEDED
Tests: 78 passed, 0 failed — TEST SUCCEEDED
