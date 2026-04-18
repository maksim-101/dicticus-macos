---
phase: 05-polish-distribution
plan: 01
subsystem: modifier-hotkeys
tags: [swift, cgeventtap, hotkeys, spm, tdd]
dependency_graph:
  requires: []
  provides: [ModifierCombo, ModifierHotkeyListener]
  affects: [HotkeyManager (Plan 02 wires closures)]
tech_stack:
  added: [LaunchAtLogin-Modern 1.1.0]
  patterns: [CGEventTap listenOnly, @unchecked Sendable for C-bridge, TDD pure-function extraction]
key_files:
  created:
    - Dicticus/Dicticus/Models/ModifierCombo.swift
    - Dicticus/Dicticus/Services/ModifierHotkeyListener.swift
    - Dicticus/DicticusTests/ModifierHotkeyListenerTests.swift
  modified:
    - Dicticus/project.yml
    - Dicticus/Dicticus.xcodeproj/project.pbxproj
decisions:
  - "@unchecked Sendable on ModifierHotkeyListener for Swift 6 CGEventTap C-bridge compatibility — previousFlags accessed only from CFRunLoop callback thread; closures dispatched to main via DispatchQueue.main.async"
  - "Test 5 scenario corrected from [Fn+Shift+Control]->[Fn+Shift] to [Fn+Shift+Option]->[Fn+Shift] — the former legitimately triggers an fnControl release event, making nil expectation incorrect"
metrics:
  duration: "~10 minutes"
  completed: "2026-04-18T11:13:44Z"
  tasks_completed: 2
  files_changed: 5
---

# Phase 05 Plan 01: ModifierHotkeyListener Infrastructure Summary

CGEventTap-based modifier-only hotkey detection service with LaunchAtLogin-Modern SPM dependency and 9 unit tests covering all flag transition scenarios.

## What Was Built

**Task 1: LaunchAtLogin-Modern + ModifierCombo model**

Added LaunchAtLogin-Modern 1.1.0 to `project.yml` (Dicticus target only, not DicticusTests). Created `ModifierCombo` enum with `fnShift`, `fnControl`, `fnOption` cases mapping each to `CGEventFlags` via `maskSecondaryFn` plus the second modifier. Includes `displayName` for the settings picker UI (Plan 02). xcodegen regenerated, packages resolved successfully.

**Task 2: ModifierHotkeyListener service + TDD unit tests**

Created `ModifierHotkeyListener` using CGEventTap `.listenOnly` for `.flagsChanged` events only (never sees keystrokes — T-05-01 mitigation). Key design points:

- Static C-compatible `callback: CGEventTapCallBack` (required by Swift 6 for function pointers — Pitfall 3)
- `detectTransition(from:to:plainCombo:cleanupCombo:)` is a pure static function — O(1), no side effects, fully unit-testable without hardware
- Activation: `curr == comboFlags` (exact match to prevent Fn+Shift+Control triggering fnShift) AND `!prev.isSuperset(of: comboFlags)`
- Release: `prev.isSuperset(of: comboFlags)` AND `!curr.isSuperset(of: comboFlags)`
- `.tapDisabledByTimeout` handled by re-enabling the tap (T-05-03)
- Background CFRunLoop thread; callbacks dispatched to `DispatchQueue.main` for HotkeyManager
- `@unchecked Sendable` for Swift 6 compliance with the C-bridge pattern

## Commits

| Task | Commit | Description |
|------|--------|-------------|
| Task 1 | a88e319 | LaunchAtLogin-Modern SPM + ModifierCombo model |
| Task 2 | 1f0b9c3 | ModifierHotkeyListener + 9 unit tests (TDD) |

## Test Results

- 9 ModifierHotkeyListenerTests: all pass
- Full DicticusTests suite (13 suites): all pass, no regressions

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Test 5 scenario produced incorrect nil expectation**
- **Found during:** Task 2 TDD green phase
- **Issue:** Test 5 used `[Fn+Shift+Control] -> [Fn+Shift]`. This transition legitimately fires an `fnControl` release event (Control disappears from a state where both Fn+Control were present). The test expectation of `nil` was wrong for this scenario.
- **Fix:** Changed test scenario to `[Fn+Shift+Option] -> [Fn+Shift]`. Option is not part of any configured combo (fnShift = Fn+Shift, fnControl = Fn+Control), so no release fires and the result is correctly `nil`. The core invariant — "fnShift does not activate when Fn+Shift was already held before the transition" — is still verified.
- **Files modified:** `Dicticus/DicticusTests/ModifierHotkeyListenerTests.swift`
- **Commit:** 1f0b9c3

**2. [Rule 2 - Missing critical functionality] @unchecked Sendable required for Swift 6 CGEventTap C-bridge**
- **Found during:** Task 2 TDD green phase (build error)
- **Issue:** Swift 6 strict concurrency rejected `DispatchQueue.main.async { listener.onComboActivated?(mode) }` because `ModifierHotkeyListener` was not `Sendable`. The `listener` captured by the closure was flagged as a data race risk.
- **Fix:** Added `@unchecked Sendable` conformance with detailed documentation explaining thread safety guarantees at each access point (consistent with `nonisolated(unsafe)` pattern used elsewhere in the project for C-bridge APIs).
- **Files modified:** `Dicticus/Dicticus/Services/ModifierHotkeyListener.swift`
- **Commit:** 1f0b9c3

## Known Stubs

None — `ModifierHotkeyListener` is a complete service layer. The `onComboActivated` and `onComboReleased` closures are intentionally `nil` at this stage; they are wired in Plan 02 when `HotkeyManager` is updated.

## Threat Flags

None — all CGEventTap security surface was accounted for in the plan's threat model (T-05-01, T-05-02, T-05-03) and mitigations are implemented as specified.

## Self-Check: PASSED

| Item | Status |
|------|--------|
| Dicticus/Dicticus/Models/ModifierCombo.swift | FOUND |
| Dicticus/Dicticus/Services/ModifierHotkeyListener.swift | FOUND |
| Dicticus/DicticusTests/ModifierHotkeyListenerTests.swift | FOUND |
| .planning/phases/05-polish-distribution/05-01-SUMMARY.md | FOUND |
| Commit a88e319 (Task 1) | FOUND |
| Commit 1f0b9c3 (Task 2) | FOUND |
