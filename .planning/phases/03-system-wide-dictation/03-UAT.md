---
status: complete
phase: 03-system-wide-dictation
source: [03-01-SUMMARY.md, 03-02-SUMMARY.md, 03-03-SUMMARY.md]
started: 2026-04-17T14:00:00Z
updated: 2026-04-17T14:30:00Z
---

## Current Test

[testing complete]

## Tests

### 1. Push-to-Talk Dictation
expected: Hold configured hotkey, speak, release. Transcribed text appears at cursor in frontmost app within ~2-3 seconds.
result: pass

### 2. Text Injection in Multiple Apps
expected: Dictate into at least two different apps (e.g., Notes and a browser text field). Text appears at cursor in both.
result: issue
reported: "Text injection works in both Safari and Claude Desktop. But when speaking English to spell a URL, Parakeet transcribed it as Russian (Cyrillic). Parakeet TDT v3 supports 25 languages and can output any of them — our NLLanguageRecognizer {de, en} constraint only labels post-hoc, it doesn't prevent Parakeet from outputting other languages."
severity: major

### 3. Recording Indicator
expected: While holding the hotkey, the menu bar icon changes to a red microphone (mic.fill). On release, it returns to normal.
result: pass

### 4. Clipboard Preservation
expected: Copy some text to clipboard before dictating. After dictation completes and text is injected, paste (Cmd+V) — the original clipboard content is restored, not the transcribed text.
result: pass

### 5. Short Press Suppression
expected: Tap the hotkey very quickly (< 0.3s) and release. No text is injected, no error notification — the short press is silently discarded.
result: pass

### 6. Hotkey Configuration
expected: Open the menu bar dropdown. The "Hotkeys" section shows two KeyboardShortcuts recorders: "Plain Dictation" and "AI Cleanup". Clicking a recorder lets you change the hotkey.
result: pass

### 7. Last Transcription Preview
expected: After a successful dictation, open the menu bar dropdown. A "Last Transcription" section shows the transcribed text (truncated to 2 lines) with a "Copy" button.
result: pass

### 8. Copy Last Transcription
expected: Click the "Copy" button next to the last transcription. Paste (Cmd+V) somewhere — the transcribed text is pasted.
result: pass

### 9. Permission Status Display
expected: Open the menu bar dropdown. Two permission rows show: Microphone and Accessibility. Each shows its current grant status (Granted/Required/Denied).
result: pass

### 10. Model Not Ready Guard
expected: If you force-quit and relaunch the app, try pressing the hotkey immediately while models are warming up. A notification should appear saying models are loading — no crash.
result: pass

## Summary

total: 10
passed: 9
issues: 1
pending: 0
skipped: 0
blocked: 0

## Gaps

- truth: "Dictation in English/German produces text in the correct language (de or en only)"
  status: failed
  reason: "User reported: speaking English to spell a URL produced Russian (Cyrillic) output. Parakeet TDT v3 can output in any of its 25 supported languages — NLLanguageRecognizer constraint is post-hoc only."
  severity: major
  test: 2
  root_cause: ""
  artifacts: []
  missing: []
  debug_session: ""

## Additional Observations (not test failures)

- **Missing space between dictation segments** (reported during Test 3): When dictating multiple segments (press hotkey, speak, release, press again, speak, release), text segments concatenate without a space, creating merged words. Severity: major (usability).
- **Copy button no visual feedback** (reported during Test 4): The Copy button in Last Transcription section has no click animation or flash to confirm the copy action. Severity: cosmetic.
- **mic.slash icon on app restart** (reported during Test 10): After force-quit and relaunch, menu bar icon shows mic.slash until the dropdown is opened (permission polling starts in MenuBarView.onAppear, not at app launch). Severity: minor.
