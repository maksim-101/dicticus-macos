---
phase: 05-polish-distribution
plan: 02
subsystem: settings-ui-hotkey-wiring
tags: [swift, swiftui, observableobject, cgeventtap, launchatlogin, userdefaults]
dependency_graph:
  requires: [05-01 (ModifierCombo, ModifierHotkeyListener)]
  provides: [SettingsSection, ModifierHotkeyListener wired to HotkeyManager]
  affects: [MenuBarView (Settings section inserted), DicticusApp (modifierListener lifecycle)]
tech_stack:
  added: [Combine (for ObservableObject conformance)]
  patterns: [ObservableObject @Published with UserDefaults didSet persistence, @EnvironmentObject for cross-view state sharing]
key_files:
  created:
    - Dicticus/Dicticus/Views/SettingsSection.swift
  modified:
    - Dicticus/Dicticus/Views/MenuBarView.swift
    - Dicticus/Dicticus/Services/HotkeyManager.swift
    - Dicticus/Dicticus/Services/ModifierHotkeyListener.swift
    - Dicticus/Dicticus/DicticusApp.swift
    - Dicticus/Dicticus.xcodeproj/project.pbxproj
decisions:
  - "ModifierHotkeyListener made ObservableObject with @Published properties — required for SwiftUI Picker bindings via @EnvironmentObject in SettingsSection"
  - "UserDefaults persistence via @Published didSet — clean separation between SwiftUI observation and persistence, init loads saved values bypassing didSet to avoid redundant writes on launch"
  - "setupModifierListener() called after ASR warmup (same callsite as setup()) — CGEventTap only activates when app is ready to record, matching KeyboardShortcuts behavior"
  - "HotkeyManager retains modifierListener strongly — both live for app lifetime, no retain cycle risk"
metrics:
  duration: "~4 minutes"
  completed: "2026-04-18T11:24:45Z"
  tasks_completed: 2
  files_changed: 6
---

# Phase 05 Plan 02: Settings UI and ModifierHotkeyListener Wiring Summary

SettingsSection SwiftUI view with LaunchAtLogin toggle and modifier hotkey pickers wired to ObservableObject ModifierHotkeyListener, which routes CGEventTap events into HotkeyManager's push-to-talk pipeline.

## What Was Built

**Task 1: SettingsSection view and MenuBarView update**

Created `SettingsSection.swift` — a `VStack`-based view with:
- `LaunchAtLogin.Toggle("Launch at Login")` — SMAppService is source of truth, no UserDefaults caching (D-02/D-04)
- Two `Picker` controls (plain dictation, AI cleanup) in `.pickerStyle(.menu)` with `ModifierCombo.allCases` options — matches HotkeySettingsView row layout pattern (HStack + Spacer + Picker)
- Accessibility labels on both pickers per UI-SPEC contract
- External keyboard note in `.caption`/`.foregroundStyle(.secondary)` per copywriting contract

Updated `MenuBarView.swift`:
- Added `@EnvironmentObject var modifierListener: ModifierHotkeyListener`
- Inserted `SettingsSection(plainDictationCombo: $modifierListener.plainDictationCombo, cleanupCombo: $modifierListener.cleanupCombo)` between the last transcription section and Quit, with unconditional `Divider` above and below per UI-SPEC dropdown structure

**Task 2: ModifierHotkeyListener as ObservableObject + HotkeyManager wiring**

Updated `ModifierHotkeyListener.swift`:
- Added `ObservableObject` conformance alongside existing `@unchecked Sendable`
- `@Published var plainDictationCombo` and `@Published var cleanupCombo` with `didSet` UserDefaults persistence (keys: `"modifierPlainDictation"`, `"modifierAiCleanup"`)
- `init()` loads persisted values from UserDefaults with fallback to defaults (`.fnShift`, `.fnControl` per D-09); assigns via `_property = Published(initialValue:)` to bypass `didSet` on launch

Updated `HotkeyManager.swift`:
- Added `private var modifierListener: ModifierHotkeyListener?` property
- Added `setupModifierListener(_ listener:)` method — sets `onComboActivated` and `onComboReleased` closures routing to `handleKeyDown(mode:)` / `handleKeyUp(mode:)`, then calls `listener.start()`

Updated `DicticusApp.swift`:
- Added `@StateObject private var modifierListener = ModifierHotkeyListener()`
- Passed as `.environmentObject(modifierListener)` to `MenuBarView`
- Called `hotkeyManager.setupModifierListener(modifierListener)` after `hotkeyManager.setup(...)` in the `onChange(of: warmupService.isReady)` callback

## Commits

| Task | Commit | Description |
|------|--------|-------------|
| Task 1 | 2028fa6 | SettingsSection view with LaunchAtLogin toggle and modifier hotkey pickers |
| Task 2 | 87383bf | Wire ModifierHotkeyListener into HotkeyManager and DicticusApp |

## Test Results

- All DicticusTests pass (including 9 ModifierHotkeyListenerTests from Plan 01)
- Build succeeded with `** BUILD SUCCEEDED **`
- `** TEST SUCCEEDED **` — no regressions

## Deviations from Plan

None — plan executed exactly as written.

The plan correctly anticipated that `ModifierHotkeyListener` needed `ObservableObject` conformance for SwiftUI bindings, and specified the `init()` / `didSet` pattern for UserDefaults persistence. The implementation followed the plan specification without deviation.

## Known Stubs

None — all bindings are live:
- `LaunchAtLogin.Toggle` reads from `SMAppService` (LaunchAtLogin-Modern handles this internally)
- Picker bindings write to `ModifierHotkeyListener.plainDictationCombo` / `cleanupCombo` which persist to UserDefaults and are read by the CGEventTap callback on the next transition
- `onComboActivated`/`onComboReleased` closures route to the full push-to-talk pipeline in `HotkeyManager`

## Threat Flags

None — T-05-04 (UserDefaults tamper) and T-05-05 (login item elevation) were both in the plan's threat model and addressed as specified (fallback defaults on decode failure; SMAppService standard API).

## Self-Check: PASSED

| Item | Status |
|------|--------|
| Dicticus/Dicticus/Views/SettingsSection.swift | FOUND |
| Dicticus/Dicticus/Views/MenuBarView.swift (contains SettingsSection) | FOUND |
| Dicticus/Dicticus/Services/HotkeyManager.swift (contains setupModifierListener) | FOUND |
| Dicticus/Dicticus/Services/ModifierHotkeyListener.swift (ObservableObject + @Published) | FOUND |
| Dicticus/Dicticus/DicticusApp.swift (contains modifierListener + setupModifierListener) | FOUND |
| Commit 2028fa6 (Task 1) | FOUND |
| Commit 87383bf (Task 2) | FOUND |
