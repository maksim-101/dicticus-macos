---
phase: 01-foundation-app-shell
plan: 02
subsystem: macOS Permissions Onboarding
tags: [swift, swiftui, permissions, avfoundation, applicationservices, coregraphics, tdd, xctest]
dependency_graph:
  requires: [01-01]
  provides: [PermissionManager, SystemSettingsURLs, PermissionRow, OnboardingView, permission polling]
  affects: [01-03]
tech_stack:
  added: [AVFoundation (microphone check), ApplicationServices (AXIsProcessTrusted), CoreGraphics (CGPreflightListenEventAccess)]
  patterns: ["@MainActor ObservableObject with Timer polling", "@preconcurrency import for C globals in Swift 6", "@testable import Dicticus for unit tests", "TDD red-green cycle with xcodebuild"]
key_files:
  created:
    - Dicticus/Dicticus/Services/PermissionManager.swift
    - Dicticus/Dicticus/Utilities/SystemSettingsURLs.swift
    - Dicticus/Dicticus/Views/PermissionRow.swift
    - Dicticus/Dicticus/Views/OnboardingView.swift
    - Dicticus/DicticusTests/PermissionManagerTests.swift
    - Dicticus/DicticusTests/SystemSettingsURLTests.swift
  modified:
    - Dicticus/Dicticus/DicticusApp.swift
    - Dicticus/Dicticus/Views/MenuBarView.swift
    - Dicticus/project.yml
decisions:
  - "@preconcurrency import ApplicationServices chosen to satisfy Swift 6 strict concurrency on kAXTrustedCheckOptionPrompt C global"
  - "GENERATE_INFOPLIST_FILE=YES added to DicticusTests target in project.yml to fix xcodebuild test signing error"
  - "@testable import Dicticus required in test files because types are in the app module (not a separate library)"
  - "startPolling() called from MenuBarView.onAppear so polling lifecycle is tied to dropdown visibility"
  - "nonisolated(unsafe) annotation dropped from String constant — String is Sendable, annotation was redundant"
metrics:
  duration: "5 minutes"
  completed_date: "2026-04-15"
  tasks_completed: 2
  tasks_total: 2
  files_created: 6
  files_modified: 3
requirements_satisfied: [APP-02]
---

# Phase 01 Plan 02: Permissions Onboarding System Summary

**One-liner:** PermissionManager with 2s polling for Microphone/Accessibility/Input Monitoring, sequential onboarding flow, and live permission status rows in menu bar dropdown backed by 22 passing unit tests.

## What Was Built

A complete permissions onboarding system for the Dicticus menu bar app:

- `PermissionManager.swift` — `@MainActor ObservableObject` checking all three permissions (AVCaptureDevice, AXIsProcessTrusted, CGPreflightListenEventAccess), polling every 2 seconds with `[weak self]` timer to prevent retain cycles, and UserDefaults persistence for onboarding completion state
- `SystemSettingsURLs.swift` — URL constants using the `x-apple.systempreferences:` deep link scheme to open Privacy_Microphone, Privacy_Accessibility, and Privacy_ListenEvent panes directly
- `PermissionRow.swift` — Reusable view component showing status badge (checkmark/clock/xmark), permission name, status label (Granted/Required/Denied), and contextual action button (Grant Access or Open Settings)
- `OnboardingView.swift` — Sequential 3-step first-launch flow (Microphone → Accessibility → Input Monitoring) with Grant Access and "I'll do this later" skip link per D-01/D-02
- `MenuBarView.swift` (updated) — Now shows all three PermissionRow instances, starts polling on appear, launches OnboardingView on first run via UserDefaults check
- `DicticusApp.swift` (updated) — Creates `@StateObject permissionManager`, injects via `.environmentObject`, menu bar icon switches to `mic.slash` when any permission is missing (D-06 degraded state)
- `PermissionManagerTests.swift` — 14 unit tests covering PermissionStatus enum values, allGranted logic, and UserDefaults onboarding persistence
- `SystemSettingsURLTests.swift` — 7 unit tests verifying URL scheme and Privacy anchor for all 3 permissions

## Commits

| Task | Commit | Description |
|------|--------|-------------|
| Task 1 RED: Failing tests | 4e3d420 | test(01-02): add failing tests for PermissionStatus, PermissionManager, SystemSettingsURLs |
| Task 1 GREEN: Implementation | 548f77d | feat(01-02): implement PermissionManager, SystemSettingsURLs, and PermissionRow |
| Task 2: Wire up OnboardingView | bec82d5 | feat(01-02): wire OnboardingView, permission rows, and PermissionManager into app |

## Verification Results

- `xcodebuild build` → BUILD SUCCEEDED (0 errors, 0 warnings)
- `xcodebuild test -only-testing DicticusTests` → 22 tests passed (0 failures)
  - DicticusTests: 1 test (placeholder)
  - PermissionManagerTests: 14 tests
  - SystemSettingsURLTests: 7 tests

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Swift 6 strict concurrency error on `kAXTrustedCheckOptionPrompt`**
- **Found during:** Task 1 GREEN phase (first test run)
- **Issue:** Swift 6 treats C global `kAXTrustedCheckOptionPrompt` as shared mutable state, causing a concurrency error when accessed from `@MainActor` context
- **Fix:** Added `@preconcurrency import ApplicationServices` which instructs Swift 6 to suppress concurrency diagnostics for this pre-concurrency framework
- **Files modified:** `PermissionManager.swift`
- **Commit:** 548f77d

**2. [Rule 3 - Blocker] DicticusTests target missing `GENERATE_INFOPLIST_FILE`**
- **Found during:** Task 1 RED phase (initial test run)
- **Issue:** xcodebuild refused to sign the test bundle because the target lacked an Info.plist
- **Fix:** Added `GENERATE_INFOPLIST_FILE: YES` to DicticusTests settings in project.yml and regenerated with xcodegen
- **Files modified:** `project.yml`, `project.pbxproj`
- **Commit:** 4e3d420

**3. [Rule 3 - Blocker] `@testable import Dicticus` missing from test files**
- **Found during:** Task 1 GREEN phase
- **Issue:** Test files could not find `PermissionStatus`, `PermissionManager`, or `SystemSettingsURL` — the types live in the app module and require explicit testable import
- **Fix:** Added `@testable import Dicticus` to both test files
- **Files modified:** `PermissionManagerTests.swift`, `SystemSettingsURLTests.swift`
- **Commit:** 548f77d

## Known Stubs

None. All three PermissionRow instances read live data from `permissionManager` published properties. The comment `// Warm-up status row will be added here by Plan 03` is intentional scaffolding, not a stub — the dropdown renders correctly without it.

## Threat Flags

No new security surface beyond the plan's threat model. All three T-02 mitigations implemented:

- **T-02-03 (DoS — Poll timer):** Timer uses `[weak self]` capture; `stopPolling()` invalidates and nils the timer reference. No retain cycle possible.

## Self-Check: PASSED

Files verified to exist:
- Dicticus/Dicticus/Services/PermissionManager.swift: FOUND
- Dicticus/Dicticus/Utilities/SystemSettingsURLs.swift: FOUND
- Dicticus/Dicticus/Views/PermissionRow.swift: FOUND
- Dicticus/Dicticus/Views/OnboardingView.swift: FOUND
- Dicticus/DicticusTests/PermissionManagerTests.swift: FOUND
- Dicticus/DicticusTests/SystemSettingsURLTests.swift: FOUND

Commits verified:
- 4e3d420: FOUND
- 548f77d: FOUND
- bec82d5: FOUND
