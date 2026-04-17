---
phase: 03-system-wide-dictation
reviewed: 2026-04-17T14:30:00Z
depth: standard
files_reviewed: 13
files_reviewed_list:
  - Dicticus/Dicticus/DicticusApp.swift
  - Dicticus/Dicticus/Extensions/KeyboardShortcuts+Names.swift
  - Dicticus/Dicticus/Services/HotkeyManager.swift
  - Dicticus/Dicticus/Services/NotificationService.swift
  - Dicticus/Dicticus/Services/TextInjector.swift
  - Dicticus/Dicticus/Services/TranscriptionService.swift
  - Dicticus/Dicticus/Views/HotkeySettingsView.swift
  - Dicticus/Dicticus/Views/LastTranscriptionView.swift
  - Dicticus/Dicticus/Views/MenuBarView.swift
  - Dicticus/DicticusTests/HotkeyManagerTests.swift
  - Dicticus/DicticusTests/NotificationServiceTests.swift
  - Dicticus/DicticusTests/TextInjectorTests.swift
  - Dicticus/DicticusTests/TranscriptionServiceTests.swift
findings:
  critical: 0
  warning: 3
  info: 3
  total: 6
status: issues_found
---

# Phase 3: Code Review Report

**Reviewed:** 2026-04-17T14:30:00Z
**Depth:** standard
**Files Reviewed:** 13
**Status:** issues_found

## Summary

Phase 3 implements system-wide push-to-talk dictation via hotkeys, text injection (clipboard + Cmd+V), notification error reporting, and the full TranscriptionService pipeline including three-layer VAD, resampling, script validation, and language detection. Overall code quality is high: state machines are well-structured, concurrency boundaries are handled carefully (AudioSampleBuffer, nonisolated tap, @MainActor isolation), and error handling is thorough with specific TranscriptionError cases mapped to user notifications. Three warnings and three info-level items were identified, with the most notable being duplicate event listener Tasks if HotkeyManager.setup() is called more than once.

## Warnings

### WR-01: HotkeyManager.setup() creates duplicate event listener Tasks on repeated calls

**File:** `Dicticus/Dicticus/Services/HotkeyManager.swift:52-85`
**Issue:** The `setup()` method creates two `Task` instances with `for await` loops on `KeyboardShortcuts.events(for:)`, but never cancels previous Tasks if called again. The doc comment claims "Safe to call multiple times" (line 51), but this is incorrect. In `DicticusApp.swift:38`, the `.onChange(of: warmupService.isReady)` closure calls `setup()` whenever `isReady` changes. If `isReady` toggles (e.g., during error recovery or re-warmup), each call spawns additional event listeners, causing `handleKeyDown`/`handleKeyUp` to be invoked multiple times per keypress. This would result in duplicate recordings or duplicate text injections.
**Fix:** Store the Tasks and cancel them before creating new ones:
```swift
private var plainDictationTask: Task<Void, Never>?
private var aiCleanupTask: Task<Void, Never>?

func setup(transcriptionService: TranscriptionService, warmupService: ModelWarmupService) {
    self.transcriptionService = transcriptionService
    self.warmupService = warmupService

    // Cancel previous listeners before creating new ones
    plainDictationTask?.cancel()
    aiCleanupTask?.cancel()

    plainDictationTask = Task { [weak self] in
        for await event in KeyboardShortcuts.events(for: .plainDictation) {
            guard let self else { return }
            // ... existing handling ...
        }
    }

    aiCleanupTask = Task { [weak self] in
        for await event in KeyboardShortcuts.events(for: .aiCleanup) {
            guard let self else { return }
            // ... existing handling ...
        }
    }

    NotificationService.shared.setup()
}
```

### WR-02: Clipboard restore race with slow target applications

**File:** `Dicticus/Dicticus/Services/TextInjector.swift:49`
**Issue:** The 50ms delay between synthesizing Cmd+V (step 3) and restoring the clipboard (step 5) assumes the target application will read the clipboard within 50ms. Heavyweight apps (Electron-based editors, IDEs, or apps under load) may not process the paste event within this window, causing the original clipboard contents to be pasted instead of the transcription. The delay is hard-coded with no retry or verification mechanism.
**Fix:** Increase the delay to 100-150ms and/or use `NSPasteboard.changeCount` to detect when the target app has read the clipboard before restoring:
```swift
// Step 4: Wait for target app to process paste
// 100ms provides more headroom for slow apps (Electron, heavy IDEs)
try? await Task.sleep(nanoseconds: 100_000_000)

// Step 5: Restore original clipboard
restoreClipboard(pasteboard, saved: saved)
```
A more robust approach would be to monitor `pasteboard.changeCount` after the paste, but that adds complexity and the 100ms increase covers most real-world cases.

### WR-03: NotificationServiceTests missing coverage for .unexpectedLanguage case

**File:** `Dicticus/DicticusTests/NotificationServiceTests.swift:30-40`
**Issue:** The `testAllNotificationsHaveDicticusTitle` test at line 31-39 only checks 4 of 5 `DicticusNotification` cases. The `.unexpectedLanguage` case (added with Phase 3 script validation) is not covered by any individual message test, nor is it included in the "all notifications have Dicticus title" exhaustiveness check. If the title or message for `.unexpectedLanguage` were broken, no test would catch it.
**Fix:** Add the missing case to the existing test and add a dedicated message test:
```swift
func testUnexpectedLanguageMessage() {
    let notification = DicticusNotification.unexpectedLanguage
    XCTAssertEqual(notification.message, "Unexpected language detected. Please try again.")
}

func testAllNotificationsHaveDicticusTitle() {
    let cases: [DicticusNotification] = [
        .busy,
        .modelLoading,
        .transcriptionFailed(NSError(domain: "test", code: 1)),
        .recordingFailed(NSError(domain: "test", code: 2)),
        .unexpectedLanguage  // Add missing case
    ]
    for notification in cases {
        XCTAssertEqual(notification.title, "Dicticus", "Title mismatch for \(notification)")
    }
}
```

## Info

### IN-01: Unconditional leading space prepended to injected text

**File:** `Dicticus/Dicticus/Services/TextInjector.swift:43`
**Issue:** The injected text always has a space prepended (`" " + text`). The comment explains this prevents word merging for consecutive dictation segments, but it introduces a leading space when dictating into an empty field, a new line, or after existing whitespace. Users may notice unexpected leading spaces in their text.
**Fix:** Consider making the space conditional based on context (e.g., check if cursor is at start of field), or document this as a known limitation that users can address. At minimum, move the comment to a named constant:
```swift
let spaceSeparator = " "
pasteboard.setString(spaceSeparator + text, forType: .string)
```

### IN-02: DispatchQueue.main.asyncAfter used in SwiftUI View

**File:** `Dicticus/Dicticus/Views/LastTranscriptionView.swift:40`
**Issue:** `DispatchQueue.main.asyncAfter` is used for the "Copied!" feedback timer reset. In modern SwiftUI (macOS 14+), structured concurrency via `Task` with `Task.sleep` is preferred, as it integrates with Swift's concurrency model and is automatically cancelled if the view disappears.
**Fix:**
```swift
Button(showCopied ? "Copied!" : "Copy") {
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(text, forType: .string)
    showCopied = true
    Task {
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        showCopied = false
    }
}
```

### IN-03: TranscriptionService.restrictLanguage is dead code in production

**File:** `Dicticus/Dicticus/Services/TranscriptionService.swift:400-403`
**Issue:** The `restrictLanguage(_:)` instance method is defined but never called in production code. Language restriction is handled inline by `detectLanguage(_:)` which already constrains results to `{de, en}` via `languageConstraints`. The method exists only to be tested via the `#if DEBUG` static wrapper `testRestrictLanguage`. This is dead code in the production path.
**Fix:** Either remove the instance method and keep only the `#if DEBUG` static test helper, or document it as intentionally unused (reserved for Phase 4 when language restriction may be applied differently).

---

_Reviewed: 2026-04-17T14:30:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
