---
phase: 17-keyboard-extension
status: complete
date: 2026-04-23
milestone: v2.1
requirements: [KEYB-01, KEYB-02]
---

# Phase 17 Summary: iOS Keyboard Extension

Phase 17 successfully implemented a custom iOS keyboard extension for Dicticus, enabling direct text injection into any app without manual clipboard pasting. This overcomes the major "platform gap" between the macOS experience (global hotkey) and the iOS experience (shortcut-based).

## Strategic Achievement: The "Bounce" Architecture

Since iOS restricts microphone access within keyboard extensions for privacy, we implemented a high-performance "bounce" flow:
1. **Trigger:** User taps the 🎙️ button on the Dicticus keyboard.
2. **Handover:** Keyboard sets a `kbSource` flag in shared `UserDefaults` (App Groups) and opens the main app via `dicticus://` URL scheme.
3. **Action:** The main app immediately starts recording/transcribing.
4. **Delivery:** Once finished, the app writes the result to shared storage and signals readiness.
5. **Injection:** The keyboard extension, which has been polling efficiently in the background, detects the result and uses `UITextDocumentProxy` to insert the text at the cursor.

## Key Components

### 1. Foundation & IPC
- **App Groups:** Configured `group.com.dicticus` for cross-process state sharing.
- **URL Schemes:** Implemented `dicticus://dictate?source=keyboard` handler in the main app for instant activation.
- **Polling Loop:** Efficient `Timer`-based polling (0.5s) in the keyboard extension to retrieve results.

### 2. Custom QWERTZ Layout
- **SwiftUI Integration:** Used `UIHostingController` to build the keyboard UI in SwiftUI.
- **Layout:** Full QWERTZ implementation including Shift logic, Delete, Space, and Return.
- **Adaptive UI:** Full support for Light and Dark modes using `@Environment(\.colorScheme)`.
- **Tactile Feedback:** Integrated `UIImpactFeedbackGenerator` for haptic response on key presses.

### 3. Dynamic Island Integration
- **Interactive Stop:** Added a dedicated Stop button to the Live Activity (Dynamic Island/Lock Screen).
- **Background Reliability:** Migrated to `LiveActivityIntent` to ensure the Stop action works reliably from the widget context.

### 4. Robustness & Cleanup
- **Auto-Cleanup:** Implemented logic in `DictationViewModel` to clear stale keyboard states on app launch, preventing infinite polling loops if the app had previously crashed.
- **Error Handling:** Ensured the keyboard stops polling even if transcription fails, by signaling `kbResultReady` with an empty result or error state.

## Technical Decisions

| ID | Decision | Rationale |
|----|----------|-----------|
| **D-18** | Cleanup on init | Prevents stale `kbSource` flags from blocking app-only dictation after a crash. |
| **D-19** | 0.5s Polling | Balance between responsiveness and battery/CPU usage in the restricted extension environment. |
| **D-20** | LiveActivityIntent | Required for interactive elements in Dynamic Island to bypass background execution limits. |

## Verification Results

- **Functional:** Verified full loop: Keyboard -> App -> Record -> Transcribe -> Auto-insert -> Original App.
- **UX:** Haptics and Dark Mode provide a native-feeling experience.
- **Memory:** Extension stays well under the ~30MB limit as ASR processing happens in the main app process.

## Next Steps

- **Phase 18 (iCloud Sync):** Sync the Custom Dictionary and History between macOS and iOS devices.
- **Phase 19 (AI Cleanup iOS):** Bring the "Local AI Cleanup" feature to iOS once memory/performance optimization is complete.
