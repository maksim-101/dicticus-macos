---
phase: 05-polish-distribution
reviewed: 2026-04-18T14:30:00Z
depth: standard
files_reviewed: 10
files_reviewed_list:
  - Dicticus/Dicticus/DicticusApp.swift
  - Dicticus/Dicticus/Models/ModifierCombo.swift
  - Dicticus/Dicticus/Services/HotkeyManager.swift
  - Dicticus/Dicticus/Services/ModifierHotkeyListener.swift
  - Dicticus/Dicticus/Views/MenuBarView.swift
  - Dicticus/Dicticus/Views/SettingsSection.swift
  - Dicticus/DicticusTests/ModifierHotkeyListenerTests.swift
  - Dicticus/project.yml
  - scripts/build-dmg.sh
  - scripts/verify-memory.sh
findings:
  critical: 0
  warning: 3
  info: 3
  total: 6
status: issues_found
---

# Phase 5: Code Review Report

**Reviewed:** 2026-04-18T14:30:00Z
**Depth:** standard
**Files Reviewed:** 10
**Status:** issues_found

## Summary

Reviewed all files from the Phase 5 polish and distribution work, covering the modifier hotkey listener system (CGEventTap-based push-to-talk), settings UI with LaunchAtLogin, build/DMG packaging script, and memory verification tooling.

Overall code quality is high. The CGEventTap callback architecture is well-structured with a clean separation between the pure transition-detection function (fully testable) and the side-effecting callback. The HotkeyManager state machine is thorough with proper key-repeat suppression, busy-state rejection, and error notifications.

Three warnings were found: a missing duplicate-combo validation that allows the user to make one hotkey mode unreachable, a missing `deinit` in the CGEventTap listener that could cause a use-after-free if the object were deallocated out of order, and a data race on property writes from a background thread. Three informational items were noted.

## Warnings

### WR-01: No validation prevents assigning the same modifier combo to both dictation modes

**File:** `Dicticus/Dicticus/Views/SettingsSection.swift:38-68`
**Issue:** Both Picker controls offer the full set of `ModifierCombo.allCases` without any constraint preventing the user from selecting the same combo (e.g., `.fnShift`) for both plain dictation and AI cleanup. When both combos are identical, `detectTransition` iterates plain first (line 241 of ModifierHotkeyListener.swift), so the AI cleanup modifier hotkey becomes permanently unreachable. There is no UI feedback warning the user about the conflict.
**Fix:** Add validation in either the `SettingsSection` (filter available options) or in `ModifierHotkeyListener`'s `didSet` (reject duplicates). The simplest approach is filtering the Picker options:
```swift
// In the AI Cleanup picker, exclude the combo already used for plain dictation:
Picker("", selection: $cleanupCombo) {
    ForEach(ModifierCombo.allCases.filter { $0 != plainDictationCombo }) { combo in
        Text(combo.displayName).tag(combo)
    }
}

// And vice versa for the plain dictation picker:
Picker("", selection: $plainDictationCombo) {
    ForEach(ModifierCombo.allCases.filter { $0 != cleanupCombo }) { combo in
        Text(combo.displayName).tag(combo)
    }
}
```

### WR-02: Missing `deinit` in ModifierHotkeyListener risks use-after-free via unretained CGEventTap pointer

**File:** `Dicticus/Dicticus/Services/ModifierHotkeyListener.swift:27`
**Issue:** The class passes `Unmanaged.passUnretained(self)` as the `userInfo` pointer to `CGEvent.tapCreate` (line 156). If the listener is deallocated before `stop()` is called, the CGEventTap callback will dereference a dangling pointer, causing a crash. The class has a `stop()` method but no `deinit` that calls it. Currently safe because the listener is a `@StateObject` in `DicticusApp` (lives for app lifetime), but this is fragile -- any future refactor that changes the ownership model would introduce a crash.
**Fix:** Add a `deinit` that calls `stop()`:
```swift
deinit {
    stop()
}
```

### WR-03: Data race on `runLoop`, `eventTap`, and `runLoopSource` properties between background thread and main thread

**File:** `Dicticus/Dicticus/Services/ModifierHotkeyListener.swift:177-184`
**Issue:** In `start()`, `self.runLoop = rl` is written from the detached background thread (line 180). The `stop()` method reads `self.runLoop` and `self.eventTap` from whatever thread calls it (typically main). These are stored properties on a non-isolated class with no synchronization. The `@unchecked Sendable` comment (lines 19-26) documents thread safety for `previousFlags` and `@Published` properties but does not address the `runLoop`/`eventTap`/`runLoopSource` access pattern. While the current usage is low-risk (start/stop are called once), TSan would flag this.
**Fix:** Either protect these with a lock, or assign them before detaching the thread where possible. The simplest fix is to use `os_unfair_lock` or `NSLock`:
```swift
private let lock = NSLock()
private var _runLoop: CFRunLoop?
private var runLoop: CFRunLoop? {
    get { lock.withLock { _runLoop } }
    set { lock.withLock { _runLoop = newValue } }
}
// Similarly for eventTap and runLoopSource
```

## Info

### IN-01: Unused variable `BUDGET_BYTES` in verify-memory.sh

**File:** `scripts/verify-memory.sh:13`
**Issue:** `BUDGET_BYTES=3221225472` is declared but never referenced anywhere in the script. Only `BUDGET_MB` (line 14) is used in the comparison on line 52.
**Fix:** Remove the unused variable:
```bash
# Remove line 13:
# BUDGET_BYTES=3221225472  # 3 GB in bytes
```

### IN-02: Fragile footprint output parsing in verify-memory.sh

**File:** `scripts/verify-memory.sh:49`
**Issue:** `grep -oE '[0-9]+' | head -1` extracts the first number from the `phys_footprint` line. If the `footprint` tool ever changes its output format (e.g., including a line number prefix, or outputting bytes before MB), the first extracted number would be incorrect. The script does have a fallback warning (lines 63-66) for unparseable output, which partially mitigates this.
**Fix:** Use a more specific regex that anchors to the expected format:
```bash
FOOTPRINT_MB=$(echo "$FOOTPRINT_LINE" | grep -oE '[0-9]+ MB' | grep -oE '[0-9]+')
```

### IN-03: `ModifierCombo` uses string interpolation for UserDefaults serialization

**File:** `Dicticus/Dicticus/Services/ModifierHotkeyListener.swift:36,45,56,63`
**Issue:** The `didSet` handlers use `"\(plainDictationCombo)"` and `"\(cleanupCombo)"` for serialization, and `init` uses `"\($0)"` for comparison during deserialization. This relies on Swift's default `String(describing:)` output for enum cases, which produces the case name (e.g., `"fnShift"`). While this works today and `ModifierCombo` conforms to `Codable`, using `Codable` or `RawRepresentable` with explicit raw values would be more robust against future refactors (e.g., renaming a case).
**Fix:** Consider adding `RawRepresentable` conformance with explicit string raw values:
```swift
enum ModifierCombo: String, CaseIterable, Identifiable, Codable, Equatable, Sendable {
    case fnShift = "fnShift"
    case fnControl = "fnControl"
    case fnOption = "fnOption"
}
```
Then use `combo.rawValue` for serialization and `ModifierCombo(rawValue:)` for deserialization.

---

_Reviewed: 2026-04-18T14:30:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
