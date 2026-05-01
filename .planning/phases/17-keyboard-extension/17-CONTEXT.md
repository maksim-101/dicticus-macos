# Phase 17: Keyboard Extension - Context

**Gathered:** 2026-04-22
**Status:** Ready for planning

<domain>
## Phase Boundary

Custom iOS keyboard extension with full QWERTZ layout and integrated dictation button. Tapping dictate bounces to the main Dicticus app for recording + transcription (iOS blocks mic access in keyboard extensions), then auto-inserts the result at the cursor via `textDocumentProxy`. Eliminates the manual paste step from the current Shortcut flow.

</domain>

<decisions>
## Implementation Decisions

### App-Bounce Architecture
- **D-01:** Keyboard extension triggers main app via custom URL scheme (`dicticus://dictate?source=keyboard`). Main app records audio, transcribes via FluidAudio/Parakeet, applies ITN + dictionary corrections, writes final text to App Group shared UserDefaults. Keyboard extension polls App Group and auto-inserts at cursor.
- **D-02:** App Group `group.com.dicticus` is already configured — reuse existing entitlement.
- **D-03:** Keyboard extension polls shared UserDefaults every 0.5s while waiting for a result. No Darwin notifications — polling is simpler and more reliable.
- **D-04:** Main app handles the full text processing pipeline (ASR → ITN → Dictionary corrections) before writing to App Group. Keyboard extension stays thin — just reads and inserts.

### Keyboard UI & Scope
- **D-05:** Full QWERTZ keyboard built from scratch with `UIInputViewController` + SwiftUI. Single bilingual layout — always QWERTZ for both German and English (no Umlauts, matching user's current default keyboard).
- **D-06:** No KeyboardKit dependency. KeyboardKit v10 is closed-source with telemetry (LicenseKit phones home) — incompatible with Dicticus privacy constraint.
- **D-07:** Emoji access via globe key switching to system emoji keyboard (`advanceToNextInputMode()`). No custom emoji picker in v1.
- **D-08:** No word suggestions, autocorrect, or swipe typing in v1. Deferred to a future phase.
- **D-09:** Keyboard includes: letter keys, shift/caps lock, number+symbol layer (123), backspace, space, return, globe key, and prominent dictation button (🎙️).

### User Flow & Activation
- **D-10:** Recording auto-starts immediately when main app opens from keyboard bounce. No extra tap required.
- **D-11:** Auto-stop on silence (VAD) is the default, with a manual Stop button in the Live Activity (Dynamic Island) as override for longer dictations with natural pauses.
- **D-12:** User swipes back to the original app on their own after recording starts. Recording continues in background. Same pattern as Wispr Flow.
- **D-13:** Live Activity (Dynamic Island) shows recording progress while user is in the original app. Reuse existing `DictationActivity` from Phase 13.

### Text Return & Insertion
- **D-14:** Transcribed and corrected text is written to `UserDefaults(suiteName: "group.com.dicticus")` with keys `kbResult` (text) and `kbResultReady` (boolean flag).
- **D-15:** Keyboard extension inserts text at cursor via `textDocumentProxy.insertText()`. Bulk insert of the full result, not character-by-character.
- **D-16:** After successful insert, keyboard clears the App Group keys to prevent re-insertion.

### Claude's Discretion
- Key sizing, spacing, and visual styling for the QWERTZ layout
- Exact polling implementation (Timer vs RunLoop-based)
- Keyboard height and safe area handling
- How to handle the case where user switches away from Dicticus keyboard before result arrives
- Number/symbol layer layout details
- Dark mode / Liquid Glass adaptation for iOS 26

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### iOS Keyboard Extension APIs
- Apple's Custom Keyboard guide — `UIInputViewController`, `textDocumentProxy`, `advanceToNextInputMode()`, `RequestsOpenAccess` entitlement, App Groups for extension ↔ app communication
- Apple's App Extension Programming Guide — extension lifecycle, memory limits (30-50MB), background execution constraints

### Existing Dicticus iOS Code
- `iOS/Dicticus/Services/IOSTranscriptionService.swift` — Full ASR pipeline (FluidAudio, VAD, language detection) — reused by keyboard bounce flow
- `iOS/Dicticus/DictationViewModel.swift` — Recording state machine, Live Activity lifecycle — needs adaptation for keyboard-triggered flow
- `iOS/Dicticus/Intents/DictateIntent.swift` — Current App Intent entry point — URL scheme handler will follow similar pattern
- `iOS/Dicticus/LiveActivity/DictationActivity.swift` — Dynamic Island UI — reuse, add Stop button
- `iOS/DicticusWidget/DictationLiveActivity.swift` — Widget extension for Live Activity
- `iOS/Dicticus/Dicticus.entitlements` — App Group already configured as `group.com.dicticus`
- `iOS/project.yml` — xcodegen config — needs new keyboard extension target

### Shared Code
- `Shared/Services/DictionaryService.swift` — Find-and-replace corrections, applied in main app before App Group write
- `Shared/Services/TextProcessingService.swift` — Orchestrates ASR → ITN → Dictionary pipeline
- `Shared/Utilities/ITNUtility.swift` — Inverse text normalization (numbers as digits)
- `Shared/Models/TranscriptionResult.swift` — Result model

### Research Findings (from this discussion)
- iOS keyboard extensions CANNOT access the microphone — restriction unchanged since iOS 8 through iOS 26
- All major keyboards (Gboard, SwiftKey, Wispr Flow) use bounce-to-host-app architecture
- KeyboardKit v10 is closed-source with telemetry — ruled out for privacy reasons
- iOS 26 `SpeechAnalyzer` supports German but needs quality benchmarking vs Parakeet v3
- iOS 26 Interactive Snippets cannot record audio — display-only overlay in Siri/Spotlight

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `IOSTranscriptionService` — Full record→transcribe pipeline, reuse for keyboard-triggered dictation
- `DictationViewModel` — State machine (idle/recording/transcribing), adapt for URL-scheme trigger
- `DictationActivity` + `DictationLiveActivity` — Dynamic Island UI, add interactive Stop button
- `TextProcessingService` — Orchestrates ASR → ITN → Dictionary, runs in main app process
- `DictionaryService`, `ITNUtility` — Already in `Shared/`, accessible to main app

### Established Patterns
- App Group `group.com.dicticus` — already configured in entitlements and project.yml
- xcodegen (`project.yml`) — new keyboard extension target follows same pattern as `DicticusWidget`
- Live Activity pattern — request/update/end lifecycle established in Phase 13
- `AudioRecordingIntent` pattern — auto-start recording on app open, established in Phase 13

### Integration Points
- `iOS/project.yml` — add `DicticusKeyboard` target (type: `app-extension`, extension point: `com.apple.keyboard-service`)
- `DicticusApp.swift` — add URL scheme handler (`dicticus://dictate?source=keyboard`) to start recording
- `DictationViewModel` — add keyboard-specific flow: after transcription, write to App Group instead of clipboard
- New `DicticusKeyboard/` directory — `KeyboardViewController.swift` (UIInputViewController subclass) + SwiftUI keyboard views

</code_context>

<specifics>
## Specific Ideas

- User's default keyboard is English + German QWERTZ without Umlauts — the Dicticus keyboard should match this exact layout
- "Same as Wispr Flow" for the bounce-back UX — user learns to swipe back after tapping dictate
- Dictation is the star feature — the keyboard is the vehicle to eliminate manual paste

</specifics>

<deferred>
## Deferred Ideas

- **Word suggestions bar** — UITextChecker-based or Apple Intelligence-powered predictions (future phase)
- **SpeechAnalyzer benchmarking** — iOS 26's new STT framework supports German; could eliminate 1.24GB model download if quality is acceptable. Needs head-to-head comparison with Parakeet v3.
- **Interactive Snippets** — iOS 26 App Intents feature for showing post-dictation results inline in Siri/Spotlight (display only, cannot record)
- **`supportedModes` migration** — Replace deprecated `openAppWhenRun` with iOS 26's `supportedModes: [.foreground(.immediate)]`
- **Live Activity Stop button** — Add `Button(intent: StopDictationIntent())` to Dynamic Island expanded view (available since iOS 17, not yet implemented)
- **`AVInputPickerInteraction`** — iOS 26 in-app mic selection UI for AirPods vs built-in mic
- **Shortcuts "Use Model" action** — Apple Intelligence cleanup as alternative to llama.cpp on iOS (Phase 19 consideration)

</deferred>

---

*Phase: 17-keyboard-extension*
*Context gathered: 2026-04-22*
