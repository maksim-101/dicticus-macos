---
phase: 17-keyboard-extension
plan: 03
subsystem: keyboard-extension
tags: [keyboard, dictation, bounce-flow, app-group]
requires: [17-01, 17-02]
provides: [dictation-loop]
affects: [main-app, keyboard-extension]
tech-stack: [SwiftUI, UIKit, App Groups, URL Schemes]
key-files: [iOS/Dicticus/DictationViewModel.swift, iOS/DicticusKeyboard/KeyboardViewController.swift]
decisions:
  - "D-14: Consistently clear kbSource and set kbResultReady in DictationViewModel regardless of success/failure to ensure reliable state and stop keyboard polling."
  - "D-15: Used Timer-based polling in KeyboardViewController (0.5s interval) as planned for simplicity and reliability."
metrics:
  duration: 25m
  completed_date: 2026-04-22
---

# Phase 17 Plan 03: Dictation Loop and Result Delivery Summary

Integrated the "bounce-back" dictation flow between the keyboard extension and the main app. Tapping the dictate button on the custom keyboard now triggers the main app via a URL scheme, which records and transcribes audio, then delivers the result back to the keyboard via shared App Group defaults for auto-insertion at the cursor.

## Key Changes

### Main App (`iOS/Dicticus/DictationViewModel.swift`)
- Modified `stopDictation()` to detect if the dictation was triggered by the keyboard extension.
- Delivers the transcription result to the shared `group.com.dicticus` App Group using the `kbResult` key.
- Sets a `kbResultReady` flag to signal the keyboard extension that a result (or failure) is available.
- Ensures `kbSource` flag is cleared and `kbResultReady` is set even on failure to prevent stale state and excessive polling.

### Keyboard Extension (`iOS/DicticusKeyboard/KeyboardViewController.swift`)
- Implemented `handleDictationTap()` which sets the `kbSource` flag and opens the main app via `dicticus://dictate?source=keyboard`.
- Implemented a `Timer`-based polling mechanism (`0.5s` interval) that starts after the bounce to the main app.
- When `kbResultReady` is detected in shared defaults:
  - Reads `kbResult`.
  - Inserts text at the cursor using `textDocumentProxy.insertText()`.
  - Cleans up shared defaults (`kbResult`, `kbResultReady`).
  - Stops the polling timer.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Stale `kbSource` and Infinite Polling on Failure**
- **Found during:** Implementation review.
- **Issue:** The original plan only cleared `kbSource` and set `kbResultReady` on success. If transcription failed, `kbSource` would remain true (affecting future app-only dictations) and the keyboard would poll indefinitely.
- **Fix:** Moved cleanup logic to run after the `do-catch` block in `stopDictation()`.
- **Files modified:** `iOS/Dicticus/DictationViewModel.swift`
- **Commit:** 36027a5

## Verification Results

### Automated Tests
- `grep` verified `kbResult` presence in `DictationViewModel.swift`.
- `grep` verified `insertText` presence in `KeyboardViewController.swift`.

### Manual Verification Path
1. Switch to Dicticus keyboard in any text field (e.g., Notes).
2. Tap 🎙️.
3. Observe Dicticus app opening and starting recording automatically.
4. Speak a phrase.
5. Swipe back to the original app.
6. Observe text appearing at the cursor once transcription completes.

## Self-Check: PASSED
- [x] All tasks executed
- [x] Each task committed individually
- [x] Deviations documented
- [x] SUMMARY.md created
- [x] Commits exist in history
