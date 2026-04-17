---
phase: 03-system-wide-dictation
verified: 2026-04-17T21:30:00Z
status: human_needed
score: 5/5
overrides_applied: 0
human_verification:
  - test: "Hold Control+Shift+S in Notes.app, speak a sentence, release. Verify transcribed text appears at cursor."
    expected: "Transcribed text appears at cursor position in Notes"
    why_human: "End-to-end workflow requires real audio input, ASR inference, and CGEvent paste into a live app"
  - test: "Hold Control+Shift+S in Safari address bar, speak, release. Verify text appears."
    expected: "Transcribed text appears in browser text field"
    why_human: "Cross-app text injection via CGEvent cannot be verified programmatically"
  - test: "Hold Control+Shift+S in Terminal.app, speak, release. Verify text appears at prompt."
    expected: "Transcribed text appears at terminal command prompt"
    why_human: "Terminal paste behavior differs from standard text fields"
  - test: "Observe menu bar icon during dictation: idle=mic, recording=mic.fill, transcribing=waveform.circle"
    expected: "Icon transitions through three states visually"
    why_human: "Visual rendering of SF Symbols and foregroundStyle requires human observation"
  - test: "Copy text to clipboard, dictate, then paste in a new location. Verify original clipboard restored."
    expected: "Original clipboard content pastes, not the transcription text"
    why_human: "Clipboard save/restore timing depends on real app paste processing"
  - test: "Press Control+Shift+D (AI cleanup hotkey). Verify nothing happens."
    expected: "No recording, no notification, no error"
    why_human: "Confirming absence of action requires human observation"
  - test: "Open menu bar dropdown, verify Hotkeys section with two recorder views."
    expected: "Plain Dictation and AI Cleanup recorder views visible and interactive"
    why_human: "KeyboardShortcuts.Recorder rendering requires human visual check"
  - test: "After dictation, open dropdown, verify Last Transcription section with text and Copy button."
    expected: "Truncated text shown with Copy button; clicking Copy shows Copied! feedback"
    why_human: "Visual feedback timing and text rendering require human observation"
---

# Phase 3: System-Wide Dictation Verification Report

**Phase Goal:** User can hold a hotkey, speak, release, and transcribed text appears at the cursor in any app -- the core user-facing workflow
**Verified:** 2026-04-17T21:30:00Z
**Status:** human_needed
**Re-verification:** No -- initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | User holds a configurable hotkey, speaks, releases, and text appears at the cursor position in the frontmost app | VERIFIED (code) | HotkeyManager.swift: `KeyboardShortcuts.events(for: .plainDictation)` handles keyDown->startRecording, keyUp->stopRecordingAndTranscribe->textInjector.injectText. TextInjector.swift: clipboard save, write " "+text, CGEvent Cmd+V, 50ms wait, clipboard restore. Full pipeline wired in DicticusApp.swift via `hotkeyManager.setup(transcriptionService: service, warmupService: warmupService)`. Human test needed for real audio path. |
| 2 | Text injection works in browsers, native apps, and terminal | VERIFIED (code) | TextInjector uses single CGEvent Cmd+V code path (D-08). Posts to `.cgAnnotatedSessionEventTap` for cross-app delivery. No app-specific branches. Human test needed to confirm cross-app paste. |
| 3 | Menu bar icon changes visually while recording is active | VERIFIED | DicticusApp.swift:61-71 `iconName` computed property: mic.slash (no perms), mic.fill (recording), waveform.circle (transcribing), mic (idle). `.foregroundStyle(hotkeyManager.isRecording ? .red : .primary)` and `.symbolEffect(.pulse, isActive: warmupService.isWarming || transcriptionService?.state == .transcribing)`. Three-state icon machine is wired. |
| 4 | Different hotkey combos registered for plain dictation vs AI cleanup mode | VERIFIED | KeyboardShortcuts+Names.swift: `plainDictation` (Ctrl+Shift+S) and `aiCleanup` (Ctrl+Shift+D) defined with distinct key combos. HotkeyManager.swift registers both via `KeyboardShortcuts.events(for:)`. `aiCleanup` handler is `break` (silent no-op per D-13, wired to LLM in Phase 4). |
| 5 | Original clipboard contents preserved after text injection | VERIFIED | TextInjector.swift:36 `saveClipboard()` captures all pasteboard items with all types. Line 49: 50ms delay. Line 52: `restoreClipboard()` writes back all saved items. 4 tests in TextInjectorTests.swift verify round-trip (string, multi-type, empty, paste no-crash). |

**Score:** 5/5 truths verified (code-level; human verification needed for end-to-end)

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `Dicticus/project.yml` | KeyboardShortcuts SPM dependency | VERIFIED | Lines 15-17: `KeyboardShortcuts: url: https://github.com/sindresorhus/KeyboardShortcuts.git from: 2.4.0` |
| `Dicticus/Dicticus/Extensions/KeyboardShortcuts+Names.swift` | Hotkey name constants with defaults | VERIFIED | 15 lines. `static let plainDictation` (Ctrl+Shift+S) and `static let aiCleanup` (Ctrl+Shift+D). Imports KeyboardShortcuts. |
| `Dicticus/Dicticus/Services/TextInjector.swift` | Clipboard save/write/paste/restore pipeline | VERIFIED | 107 lines. @MainActor. `injectText()`, `saveClipboard()`, `restoreClipboard()`, `synthesizePaste()`. Space prepended per gap closure. CGEvent keyCode 9 + `.cgAnnotatedSessionEventTap`. |
| `Dicticus/Dicticus/Services/NotificationService.swift` | UNUserNotificationCenter wrapper | VERIFIED | 81 lines. @MainActor singleton. 5 notification cases: busy, modelLoading, transcriptionFailed, recordingFailed, unexpectedLanguage. Exact UI-SPEC wording. |
| `Dicticus/Dicticus/Services/HotkeyManager.swift` | Push-to-talk state machine | VERIFIED | 182 lines. @MainActor ObservableObject. `handleKeyDown(mode:)` with isKeyDown guard (D-03), warmup check (D-17), busy check (D-19). `handleKeyUp(mode:)` with tooShort/silenceOnly silent discard, unexpectedLanguage notification. `lastTranscriptionText` computed property. |
| `Dicticus/Dicticus/DicticusApp.swift` | Icon state machine + HotkeyManager wiring | VERIFIED | 73 lines. `@StateObject hotkeyManager`. `hotkeyManager.setup()` in onChange. `.environmentObject(hotkeyManager)`. `iconName`: mic.slash/mic.fill/waveform.circle/mic. `permissionManager.checkAll()` at launch. |
| `Dicticus/Dicticus/Views/HotkeySettingsView.swift` | Hotkey config with Recorder views | VERIFIED | 39 lines. `KeyboardShortcuts.Recorder(for: .plainDictation)` and `.aiCleanup`. Heading "Hotkeys". |
| `Dicticus/Dicticus/Views/LastTranscriptionView.swift` | Last transcription preview + copy | VERIFIED | 53 lines. `.lineLimit(2)`, `.truncationMode(.tail)`. Copy button with "Copied!" feedback (showCopied state, 1.5s reset). Hidden when text is nil. |
| `Dicticus/Dicticus/Views/MenuBarView.swift` | Updated dropdown with Phase 3 sections | VERIFIED | 89 lines. `@EnvironmentObject var hotkeyManager`. Embeds `HotkeySettingsView()` and `LastTranscriptionView(text: hotkeyManager.lastTranscriptionText)`. Preserves Phase 1 content. |
| `Dicticus/DicticusTests/TextInjectorTests.swift` | Clipboard round-trip tests | VERIFIED | 81 lines. 4 tests: string save/restore, multi-type, empty, synthesizePaste no-crash. |
| `Dicticus/DicticusTests/NotificationServiceTests.swift` | Notification message tests | VERIFIED | 41 lines. 5 tests covering all notification messages and title. |
| `Dicticus/DicticusTests/HotkeyManagerTests.swift` | State machine tests | VERIFIED | 122 lines. 10 tests: key repeat suppression, key-up reset, model-not-ready, two hotkeys registered, icon state, short press, reject-while-transcribing, DictationMode cases, integration. |
| `Dicticus/Dicticus/Services/TranscriptionService.swift` | Non-Latin script detection (Plan 04) | VERIFIED | `case unexpectedLanguage` in TranscriptionError. `containsNonLatinScript()` static method with Latin Unicode ranges. Guard in `stopRecordingAndTranscribe()` before result construction. |
| `Dicticus/DicticusTests/TranscriptionServiceTests.swift` | Script detection tests (Plan 04) | VERIFIED | 8 tests for containsNonLatinScript: Latin, German umlauts, Cyrillic, CJK, Arabic, empty, punctuation, combining accents. |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| HotkeyManager.swift | TranscriptionService.swift | `transcriptionService.startRecording()` / `stopRecordingAndTranscribe()` | WIRED | Lines 106, 140, 153: weak var transcriptionService used in handleKeyDown/handleKeyUp |
| HotkeyManager.swift | TextInjector.swift | `textInjector.injectText(result.text)` | WIRED | Line 155: `await self.textInjector.injectText(result.text)` in handleKeyUp Task |
| DicticusApp.swift | HotkeyManager.swift | `@StateObject hotkeyManager`, `.environmentObject(hotkeyManager)` | WIRED | Lines 9, 21, 30, 47, 65: created, injected into MenuBarView, observed for icon state |
| MenuBarView.swift | HotkeySettingsView.swift | `HotkeySettingsView()` embedded in VStack | WIRED | Line 58: direct instantiation in dropdown body |
| MenuBarView.swift | LastTranscriptionView.swift | `LastTranscriptionView(text: hotkeyManager.lastTranscriptionText)` | WIRED | Line 63: passed with computed property from HotkeyManager |
| LastTranscriptionView.swift | NSPasteboard | Copy button `NSPasteboard.general.setString(text, forType: .string)` | WIRED | Lines 36-37: clearContents + setString in button action |
| TranscriptionService.swift | TranscriptionError.unexpectedLanguage | `containsNonLatinScript()` guard | WIRED | Lines 229-231: guard before result construction in stopRecordingAndTranscribe |
| HotkeyManager.handleKeyUp | DicticusNotification.unexpectedLanguage | catch case | WIRED | Lines 163-169: catches unexpectedLanguage error, posts notification |
| project.yml | pbxproj | xcodegen generate | WIRED | KeyboardShortcuts in both main target and test target dependencies |
| KeyboardShortcuts+Names.swift | KeyboardShortcuts | `import KeyboardShortcuts` | WIRED | Line 1: import; Lines 7-14: extension with two static names |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|-------------------|--------|
| LastTranscriptionView | `text: String?` | `hotkeyManager.lastTranscriptionText` -> `transcriptionService?.lastResult?.text` | Yes (from ASR pipeline via stopRecordingAndTranscribe) | FLOWING |
| MenuBarView | `hotkeyManager.lastTranscriptionText` | HotkeyManager computed property -> TranscriptionService.lastResult | Yes (set in stopRecordingAndTranscribe line 242) | FLOWING |
| DicticusApp iconName | `hotkeyManager.isRecording`, `transcriptionService?.state` | HotkeyManager @Published + TranscriptionService @Published | Yes (set by handleKeyDown/handleKeyUp and startRecording/stopRecording) | FLOWING |

### Behavioral Spot-Checks

Step 7b: SKIPPED (requires running the macOS app with microphone access, FluidAudio model cache, and Accessibility permissions -- cannot be done in a headless context)

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-----------|-------------|--------|----------|
| TRNS-01 | 03-02, 03-03, 03-04 | User can push-to-talk via configurable hotkey and text appears at cursor in any app | SATISFIED (code) | HotkeyManager push-to-talk -> TranscriptionService -> TextInjector pipeline. Human test needed for end-to-end. |
| TRNS-05 | 03-03, 03-04 | Transcription works in any text field (browser, native apps, terminal) | SATISFIED (code) | Single CGEvent Cmd+V code path via `.cgAnnotatedSessionEventTap`. Human test needed for cross-app. |
| APP-03 | 03-02 | Visual recording indicator while push-to-talk is active | SATISFIED | DicticusApp.swift `iconName`: mic.fill during recording, waveform.circle during transcribing, red foreground style. |
| APP-04 | 03-01, 03-02 | Different hotkey combos for plain dictation vs AI cleanup mode | SATISFIED | Two KeyboardShortcuts.Name constants with distinct defaults. Both registered in HotkeyManager.setup(). aiCleanup is silent stub (Phase 4). |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| DicticusTests/PermissionManagerTests.swift | 43, 51, 59, 67 | References removed `inputMonitoringStatus` property | WARNING | Test file references property removed in Phase 3 commit `54299d0`. Blocks `xcodebuild test` compilation for full DicticusTests target. Not a Phase 3 goal blocker (PermissionManager functionality works, only test file is stale) but prevents running automated test suite. |
| HotkeyManager.swift | 7-8 | `case aiCleanup // Wired to LLM pipeline in Phase 4` | INFO | Intentional Phase 3 stub per D-13. aiCleanup handler is `break`. Will be wired in Phase 4. |

### Human Verification Required

### 1. End-to-End Dictation in Notes.app (TRNS-01)
**Test:** Hold Control+Shift+S in Notes.app, speak a sentence clearly, release the hotkey.
**Expected:** Transcribed text appears at the cursor position in Notes.
**Why human:** Requires real audio input through microphone, FluidAudio ASR inference, and CGEvent paste into a live application.

### 2. Cross-App Text Injection - Browser (TRNS-05)
**Test:** Click in Safari address bar or search field, hold Control+Shift+S, speak, release.
**Expected:** Transcribed text appears in the browser text field.
**Why human:** Cross-app text injection via CGEvent cannot be verified programmatically without a running target app.

### 3. Cross-App Text Injection - Terminal (TRNS-05)
**Test:** Open Terminal.app, hold Control+Shift+S, speak, release.
**Expected:** Transcribed text appears at the command prompt.
**Why human:** Terminal paste behavior differs from standard text fields; requires manual observation.

### 4. Menu Bar Icon State Transitions (APP-03)
**Test:** Observe menu bar icon during full dictation cycle: idle, recording, transcribing, back to idle.
**Expected:** Icon transitions: mic -> mic.fill (red) -> waveform.circle (pulsing) -> mic.
**Why human:** Visual rendering of SF Symbols, foregroundStyle, and symbolEffect requires human observation.

### 5. Clipboard Preservation (Roadmap SC #5)
**Test:** Copy distinctive text to clipboard, do a dictation, then paste in a different app.
**Expected:** Original clipboard content pastes (not the transcription text).
**Why human:** 50ms clipboard restore timing depends on real app paste processing speed.

### 6. AI Cleanup Hotkey Silent (D-13, APP-04)
**Test:** Press Control+Shift+D (AI cleanup hotkey).
**Expected:** Nothing happens -- no recording, no notification, no error.
**Why human:** Confirming absence of any action requires human observation.

### 7. Hotkey Configuration UI (D-14, D-20)
**Test:** Open menu bar dropdown, look for Hotkeys section.
**Expected:** Two KeyboardShortcuts.Recorder views for "Plain Dictation" and "AI Cleanup". Clicking allows reassignment.
**Why human:** KeyboardShortcuts.Recorder rendering and interaction require human visual check.

### 8. Last Transcription Preview + Copy Feedback (D-21)
**Test:** After a successful dictation, open the dropdown, verify Last Transcription section.
**Expected:** Truncated text shown, "Copy" button present. Clicking Copy shows "Copied!" for 1.5 seconds.
**Why human:** Visual feedback timing and text rendering require human observation.

### Gaps Summary

No code-level gaps found. All 5 roadmap success criteria are supported by substantive, wired code with real data flow. The PermissionManagerTests compilation issue (referencing removed `inputMonitoringStatus`) is a WARNING-level anti-pattern that does not block Phase 3 goal achievement but should be fixed before running the full automated test suite.

The phase requires human verification because the core workflow (hold hotkey, speak, release, text appears at cursor) involves real audio input, ASR inference, and cross-app CGEvent paste -- none of which can be tested programmatically in a headless context.

---

_Verified: 2026-04-17T21:30:00Z_
_Verifier: Claude (gsd-verifier)_
