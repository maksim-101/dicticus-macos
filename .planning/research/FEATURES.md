# Feature Landscape

**Domain:** iOS dictation app (iPhone + iPad) — Shortcut-based activation, on-device ASR
**Researched:** 2026-04-21
**Confidence:** HIGH for table stakes and Shortcut/Intent patterns; MEDIUM for onboarding UX specifics

---

## Context: What Already Exists on macOS

Dicticus macOS v1.1 ships: push-to-talk hotkeys, FluidAudio + Parakeet TDT v3 ASR, Gemma 4 E2B
AI cleanup, custom dictionary (find-replace), transcription history with search, menu bar UI.

iOS v2.0 is a **new platform target** — not a port. The activation model, text delivery path, and
onboarding are entirely different. AI cleanup is explicitly deferred to v2.x to keep scope tight.

---

## Table Stakes (Users Expect These)

Features a dictation app on iOS must have. Missing any of these makes the app feel unfinished
compared to Wispr Flow, Google Eloquent, and Apple's own dictation.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Shortcut/App Intent activation | iOS has no global hotkeys. Shortcuts is the system-level answer. Users of dictation tools on iOS expect Action Button, Back Tap, and Siri voice activation as first-class options. Wispr Flow documents all three explicitly. | MEDIUM | Implement as `AudioRecordingIntent` conforming App Intent. Action Button on iPhone 15 Pro+ and iPhone 16+. Siri via App Shortcuts. Back Tap via Accessibility > Touch settings — no API, user configures it to point at the Shortcut. |
| Clipboard text output | The standard iOS text delivery mechanism for apps that can't inject text directly into other apps. Wispr Flow defaults to clipboard when keyboard is not active. Every user expecting Shortcut-based dictation expects the result on the clipboard for immediate paste. | LOW | Write to `UIPasteboard.general.string` after transcription. Optionally also return as Shortcut output string so users can chain Shortcuts actions. |
| Microphone permission request with explanation | iOS requires a permission prompt. Apps that request mic without explaining why see high denial rates. Research: explaining the reason lifts grant rates by 81% (Pew Research, cited in NN/g). | LOW | `NSMicrophoneUsageDescription` key in Info.plist with a clear, benefit-focused description. Prime the user with a contextual explanation screen before the system prompt fires. |
| Recording in progress visual indicator | Users pressing Action Button or Back Tap need immediate confirmation that recording started. Without visual feedback the interaction feels broken — did it work or not? Wispr Flow shows a waveform animation. iOS Voice Memos shows a red banner. | MEDIUM | iOS requires a Live Activity when adopting `AudioRecordingIntent` — the system terminates audio if no Live Activity is started. Use Live Activity with Dynamic Island compact/minimal views showing a pulsing waveform. Mandatory, not optional. |
| Transcription result display | Users expect to see what was transcribed before or after pasting. App must show the result text (even transiently) so users can verify accuracy. | LOW | Show in app main view after transcription. For Action Button flows, Live Activity can update with result preview text. |
| "Tap to copy" on result | Users expect a one-tap copy of the last result if clipboard wasn't automatically set. | LOW | Copy button on result card. Auto-copy can also be enabled by default. |
| Model download on first launch | The ~1.24 GB Parakeet CoreML model cannot be bundled in the app binary (App Store 200 MB OTA limit). First launch must download the model. Users expect progress feedback and not a frozen screen. | HIGH | URLSession background download task with progress callback. Show download screen with progress bar, estimated time, file size disclosure. Gate access to dictation feature until model is ready. |
| Error state for failed transcription | VAD silence detection may discard audio. Network model download may fail. Processing may time out. Users need clear error messages, not silent failures. | LOW | Define explicit error states: no speech detected, model not loaded, microphone denied. Show actionable error messages ("Nothing was heard — try speaking louder"). |
| Custom dictionary (find-replace) | Already ships on macOS. iOS users who have corrected their dictionary on macOS expect it to work on iPhone too. New iOS users expect at least the feature to exist. | MEDIUM | Reuse `DictionaryService` from `Shared/`. Either sync via iCloud (`NSUbiquitousKeyValueStore` or CloudKit) or start with local-only and add sync later. iCloud sync is a differentiator (see below). |

---

## Differentiators (Competitive Advantage)

Features that set Dicticus iOS apart from competitors. Not universally expected, but high value.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| True on-device privacy (no cloud, ever) | Wispr Flow, Speechify, and Dragon send audio to cloud. Google Eloquent is offline but requires account sign-in and Google infrastructure. Dicticus processes on Neural Engine with zero network calls after model download. | LOW (constraint, not extra work) | Call out explicitly in onboarding. Privacy is a primary purchase driver for the target audience. |
| iCloud custom dictionary sync | macOS and iOS dictionaries stay in sync automatically. Users who add a correction on one device get it everywhere. No competitor offers cross-device local-dictionary sync. | MEDIUM | Use `NSUbiquitousKeyValueStore` for small dictionaries (< 1 MB). For larger sets, use CloudKit private database. iCloud entitlement required. Test sync latency and conflict resolution. |
| Shortcut output string (chaining) | Advanced users can chain Shortcuts: Dictate → Translate → Share. Returning the transcript as a Shortcut output value (not just clipboard) enables automation workflows. Wispr Flow returns the transcript as a Shortcuts result. | LOW | `AppIntent.perform()` returns `some IntentResult & ReturnsValue<String>`. Single line of code change, high user value for power users. |
| Action Button setup guided wizard | Wispr Flow's nine-step setup wizard has high activation rates. Dicticus should provide a guided in-app walkthrough for Action Button configuration. The Apple-mandated "Swipe right to speak" permission step is confusing without guidance. | MEDIUM | Onboarding step with screenshots, deep links to Settings > Action Button, and a live test at the end. Only shown on iPhone 15 Pro/iPhone 16+. |
| Back Tap and Control Center activation | Back Tap (double/triple) + Control Center widget cover users without Action Button. Together with Action Button, these cover the full iOS activation surface. Wispr Flow documents all three. | LOW (Back Tap: user-configured, no API) | Provide setup instructions for Back Tap in onboarding. For Control Center: implement a ControlCenter widget using `ControlWidget` (iOS 18+). |
| Transcription history on iOS | The macOS history feature ported to iOS. Users want to recover past dictations when clipboard was overwritten. Google Eloquent offers session history. | MEDIUM | Reuse `HistoryService` from `Shared/` (SQLite via GRDB). FTS5 search. Simple list view. |
| Universal app (iPhone + iPad) | iPad users want dictation too. A universal binary with size-class-adaptive layout (compact = iPhone-optimized, regular = iPad sidebar layout) costs little extra build effort with SwiftUI. | LOW-MEDIUM | Use `NavigationSplitView` for iPad (sidebar + detail), `NavigationStack` for iPhone. `@Environment(\.horizontalSizeClass)` for adaptive elements. Dictation flow itself is identical; only chrome differs. |
| Siri voice activation | "Hey Siri, dictate with Dicticus" via App Shortcuts. Hands-free use case: walking, cooking, driving. Wispr Flow supports "Turn on/off Flow" via Siri. | LOW | `AppShortcutsProvider` with `AppShortcut` mapping the `DictateIntent` to Siri phrases. Parameterless intent maps well. |

---

## Anti-Features (Commonly Requested, Often Problematic)

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| Always-listening / wake word | "Hands-free without pressing anything" sounds great. | Battery drain, iOS background microphone restrictions, privacy concern. iOS will show persistent microphone indicator. App Review rejection risk. Core constraint violation. | Push-to-activate (Action Button, Back Tap) covers the use case with explicit intent. |
| AI cleanup on iOS v1 | "Why isn't cleanup on iPhone yet?" | llama.cpp with Gemma 4 E2B (~3.1 GB GGUF) on iPhone: inference is slow on Neural Engine via llama.cpp (no CoreML path for GGUF), Model takes 3+ GB of RAM. iPhone has 6-8 GB total RAM. Not viable for v2.0. | Defer to v2.x. Document why. Ship custom dictionary as the accuracy improvement story for iOS. |
| Custom keyboard extension for text-at-cursor | "I want text injected directly like macOS". | iOS restricts microphone access in keyboard extensions — you cannot record audio from within a UIInputViewController. The workaround (bounce through main app) requires a complex IPC architecture. | Deferred to v2.1 per PROJECT.md. Clipboard paste is the v2.0 approach. |
| Real-time streaming transcription | "Show text as I speak". | FluidAudio's Parakeet TDT v3 is batch-mode. Streaming requires a different ASR architecture (chunked sliding window). Over-engineering for v2.0. | Batch mode with clear recording → processing → done state transitions is fast enough (< 3 s for typical utterances). |
| Cloud sync of transcription history | "Sync my history across all my devices". | No cloud infrastructure. Privacy constraint. Server cost. | Start with local-only history. iCloud CloudKit private database is a viable v2.x path at minimal server cost. |
| Model bundled in the app | "No download required on install". | Parakeet CoreML package is ~1.24 GB. App Store 200 MB OTA download limit applies. TestFlight has a 4 GB limit but App Store does not. App slicing does not help with ML models. | Download on first launch with clear progress UI. Consider pre-warming during onboarding (user sets up, download completes in background before they try first dictation). |
| Automatic model updates | "Get the newest Parakeet automatically". | Silent model updates change transcription behavior unexpectedly. Large downloads without user consent violate iOS background download conventions. | Version the model URL explicitly. Prompt user when a new model version is available. Keep "update model" as a user-initiated action. |
| Onboarding account creation | "Sign up to save your data". | Dicticus has no server backend. Account creation implies cloud dependency. Target audience values privacy above convenience. | Local-only. Optional iCloud sync via entitlement (no account required beyond Apple ID). |

---

## Feature Dependencies

```
Model Download + Storage
    └──required by──> Transcription (ASR)
                          └──required by──> Shortcut/App Intent activation
                          └──required by──> Live Activity recording indicator

Microphone Permission
    └──required by──> Audio Capture
                          └──required by──> Transcription

App Intent (DictateIntent)
    └──enables──> Shortcut activation
    └──enables──> Action Button activation
    └──enables──> Siri activation
    └──enables──> Back Tap (user-configured, no code dep)
    └──enables──> Control Center widget

Live Activity
    └──required by──> AudioRecordingIntent (iOS mandate — audio stops if no Live Activity)
    └──enhances──> Recording visual indicator (Dynamic Island compact view)

Clipboard output
    └──enhances──> Shortcut output string (both can exist simultaneously)

Custom Dictionary (Shared/)
    └──can be enhanced by──> iCloud sync

History Service (Shared/)
    └──optional dep on──> SQLite / GRDB (already used on macOS)
```

### Dependency Notes

- **Live Activity is mandatory for AudioRecordingIntent:** Apple's documentation is explicit — if an AudioRecordingIntent-conforming intent starts audio recording without a Live Activity, iOS terminates the recording. This is not optional.
- **Model download gates everything:** No model = no ASR = no dictation. Onboarding must complete model download before allowing the user to test dictation.
- **App Groups required for keyboard extension path (future):** Keyboard extension (v2.1) will need App Groups entitlement to access the model files downloaded by the main app. Design the model storage path using App Groups container from v2.0 to avoid migration.

---

## MVP Definition

### Launch With (v2.0)

The minimum feature set to make Dicticus iOS usable and shippable.

- [ ] **FluidAudio + Parakeet TDT v3 on iOS** — Core ASR, without this nothing works
- [ ] **Model download on first launch** — Progress UI, error recovery, completion gating
- [ ] **Microphone permission priming + request** — Contextual explanation before system prompt
- [ ] **Audio capture (push-to-activate)** — AVAudioSession, tap-to-record in-app
- [ ] **App Intent (DictateIntent)** — AudioRecordingIntent conformance, Shortcut/Action Button/Siri
- [ ] **Live Activity** — Recording state indicator (mandatory for AudioRecordingIntent)
- [ ] **Clipboard output** — Copy result to UIPasteboard after transcription
- [ ] **Shortcut return value** — Intent returns transcript as `String` for chaining
- [ ] **Custom dictionary** — Reuse `DictionaryService` from `Shared/`, local-only
- [ ] **Onboarding** — Mic permission + model download + Action Button setup guide
- [ ] **Universal app** — iPhone + iPad via size-class-adaptive SwiftUI

### Add After Validation (v2.x)

Features to add once core is working and user feedback is collected.

- [ ] **iCloud dictionary sync** — Once macOS + iOS dictionaries exist separately, sync becomes valuable
- [ ] **Transcription history on iOS** — Port `HistoryService` from `Shared/`
- [ ] **Control Center widget** — ControlWidget for iOS 18+ users
- [ ] **AI cleanup on iOS** — Only viable when CoreML GGUF path or smaller model exists

### Future Consideration (v2.1+)

Features requiring significant architectural work.

- [ ] **Custom keyboard extension (text-at-cursor)** — Main-app bounce architecture; complex IPC
- [ ] **Swiss German ASR** — Dialect model, separate milestone

---

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| FluidAudio ASR on iOS | HIGH | MEDIUM | P1 |
| Model download + progress UI | HIGH | MEDIUM | P1 |
| App Intent / AudioRecordingIntent | HIGH | MEDIUM | P1 |
| Live Activity recording indicator | HIGH | MEDIUM | P1 (mandatory) |
| Microphone permission priming | HIGH | LOW | P1 |
| Clipboard output | HIGH | LOW | P1 |
| Shortcut return value string | HIGH | LOW | P1 |
| Onboarding (mic + download + Action Button) | HIGH | MEDIUM | P1 |
| Custom dictionary (local) | MEDIUM | LOW | P1 |
| Universal app (iPhone + iPad) | MEDIUM | LOW-MEDIUM | P1 |
| Transcription history | MEDIUM | MEDIUM | P2 |
| iCloud dictionary sync | MEDIUM | MEDIUM | P2 |
| Control Center widget | LOW | LOW | P2 |
| Siri phrase configuration | MEDIUM | LOW | P2 |
| AI cleanup on iOS | HIGH | HIGH | P3 (deferred) |
| Custom keyboard extension | HIGH | HIGH | P3 (deferred) |

**Priority key:**
- P1: Must have for v2.0 launch
- P2: Add in v2.x after validation
- P3: Future milestone

---

## Competitor Feature Analysis

| Feature | Wispr Flow (iPhone) | Google Eloquent (iOS) | Apple Dictation | Dicticus v2.0 |
|---------|---------------------|-----------------------|-----------------|---------------|
| Activation | Action Button, Back Tap, Shortcut | In-keyboard mic tap | In-keyboard mic tap | Action Button, Back Tap, Siri, Shortcut |
| Privacy | Cloud (AI-polished output) | On-device + Google account | On-device (iOS 15+) | Fully on-device, no account |
| ASR | Cloud (custom model) | Gemma Nano + on-device | Apple ASR (neural) | Parakeet TDT v3 via FluidAudio (Neural Engine) |
| Text delivery | Keyboard insertion (keyboard active) / clipboard | Keyboard insertion | In-field injection | Clipboard + Shortcut return value |
| AI cleanup | Yes (cloud) | Yes (Gemma Nano) | No | No (v2.0) |
| Custom dictionary | Yes (synced) | Yes | No | Yes (local, iCloud sync v2.x) |
| Model download | N/A (cloud) | Yes (on-device model) | Pre-installed | Yes (~1.24 GB, first launch) |
| Price | Subscription ($8/mo) | Free (requires Google account) | Free (system) | One-time / free (TBD) |
| Open model | No | No | No | Yes (Parakeet v3, Apache 2.0) |

---

## iOS-Specific UX Patterns

### Shortcut Activation Flow

The canonical pattern for Shortcut-based dictation (from Wispr Flow research):

1. User triggers via Action Button / Back Tap / Siri phrase
2. App intent runs: `AudioRecordingIntent` conformance
3. **Live Activity starts immediately** (required, or audio is terminated)
4. Dynamic Island compact view shows pulsing waveform
5. Audio capture begins (AVAudioSession)
6. User speaks; user taps Dynamic Island to stop (or fixed timeout)
7. ASR runs on buffer (Parakeet TDT v3 via FluidAudio)
8. Custom dictionary applied
9. Text copied to clipboard
10. Live Activity updates with transcript preview (first ~50 chars)
11. Live Activity ends (or stays as "last result" for a few seconds)
12. Intent returns transcript string as Shortcut output

**Key constraint:** If `openAppWhenRun = false`, the intent runs in the background — the app does not foreground. This is the desired behavior for Action Button / Back Tap flows. The Live Activity is the only UI surface available.

**Stopping mechanism options:**
- Fixed timeout (e.g., 30 s silence) — simplest, but requires VAD to cut early
- VAD-based stop (FluidAudio has built-in VAD) — preferred
- User taps Dynamic Island to stop — requires Live Activity interaction

### Model Download UX

Based on patterns from Google Eloquent, WhisperKit (iOS), and general CoreML model apps:

1. **First-launch gate:** Show download screen before any dictation UI. Do not let users attempt dictation until model is ready.
2. **Progress bar** with percentage and remaining MB displayed. `URLSession` background download provides `totalBytesExpectedToWrite` via delegate.
3. **Size disclosure upfront:** "Downloading Parakeet ASR model (1.24 GB) — this is a one-time download." Set expectations before the user taps "Download".
4. **Wi-Fi check:** Show a warning if on cellular. Optionally block download on cellular by default with "Download on Wi-Fi" toggle.
5. **Background continuation:** `URLSession` background configuration ensures download continues if user backgrounds the app. Resume app state on foreground.
6. **Error recovery:** Clear "Download failed — retry" button. Show error code for debugging.
7. **Storage check:** Verify at least 1.5 GB free before starting download. Show "Not enough storage — free up space" message if insufficient.

### Permission Priming

Research finding: contextual explanation before the system prompt doubles opt-in rates (Pew Research, appcues.com). Pattern:

1. Show a custom screen explaining WHY mic is needed: "Dicticus records your voice locally on this device to transcribe it. No audio leaves your phone."
2. Show WHAT will happen: "iOS will ask for microphone access."
3. Offer "Not Now" — better to delay than to be denied. A denied permission requires the user to go to Settings.
4. Then trigger the system prompt.

Do NOT ask for microphone permission before the user has seen the app's core value. Show one dictation demo (or explanation) first.

### Live Activity Requirement

`AudioRecordingIntent` on iOS/iPadOS mandates a Live Activity. This means:

- The app requires `ActivityKit` (iOS 16.2+)
- The minimum target is iOS 16.2 (or iOS 17 for FluidAudio)
- FluidAudio requires iOS 17.0+, so iOS 17.0 is the effective floor
- Live Activity must be **started within `perform()`** before audio capture begins
- Dynamic Island compact view: waveform animation + "Dictating..." label
- Lock Screen: same, slightly larger
- On iPhone without Dynamic Island (pre-iPhone 14 Pro), Live Activity shows only on Lock Screen

---

## Shared Code Implications for macOS

These iOS features require extracting from `macOS/` into `Shared/`:

| Service | Currently In | Move To | iOS Need |
|---------|-------------|---------|----------|
| `DictionaryService` | `macOS/` | `Shared/` | Custom dictionary on iOS |
| `HistoryService` | `macOS/` | `Shared/` | History on iOS (v2.x) |
| `TextProcessingService` | `macOS/` | `Shared/` | Orchestration logic |
| `ITNUtility` | `macOS/` | `Shared/` | Number normalization |
| `CleanupPrompt` | `macOS/` | `Shared/` | Future iOS cleanup |

Platform-specific code stays in `macOS/` or new `iOS/`:
- `HotkeyManager`, `PasteService`, `MenuBarApp` → `macOS/` only
- `AppIntentHandler`, `LiveActivityManager`, `AppDelegate (iOS)` → `iOS/` only
- `AudioCaptureService` → both, but with platform-specific AVAudioSession configuration

---

## Sources

- [Apple AudioRecordingIntent documentation](https://developer.apple.com/documentation/appintents/audiorecordingintent) — Live Activity requirement confirmed; must start Live Activity or audio stops (HIGH confidence via Context7)
- [Apple App Intents openAppWhenRun / supportedModes](https://developer.apple.com/documentation/appintents/appintent/supportedmodes-5zhmb) — background execution without foreground launch (HIGH confidence via Context7)
- [Wispr Flow Shortcuts setup for iPhone](https://docs.wisprflow.ai/articles/1986921789-how-to-set-up-flow-shortcuts-for-iphone) — clipboard output, return value patterns (HIGH confidence — live product documentation)
- [Wispr Flow Action Button setup](https://docs.wisprflow.ai/articles/4500510662-set-up-the-action-button-for-flow-on-iphone) — nine-step guided wizard, "Swipe right to speak" constraint (HIGH confidence — live product documentation)
- [FluidAudio GitHub README](https://github.com/FluidInference/FluidAudio) — iOS 17.0+ requirement, downloadAndLoad() API (HIGH confidence — official repo)
- [Parakeet TDT v3 CoreML model](https://huggingface.co/FluidInference/parakeet-tdt-0.6b-v3-coreml) — ~1.24 GB model size (HIGH confidence)
- [Apple permission priming research via appcues](https://www.appcues.com/blog/mobile-permission-priming) — 81% lift with clear reason, contextual timing (MEDIUM confidence — industry study)
- [NN/g permission request design](https://www.nngroup.com/articles/permission-requests/) — contextual timing, cost-benefit framing (HIGH confidence — authoritative UX research)
- [URLSession background download documentation](https://www.momentslog.com/development/ios/handling-large-file-downloads-with-urlsession-background-tasks-and-progress-tracking) — progress tracking delegate methods (MEDIUM confidence)
- [iOS App Intents WWDC24 session](https://developer.apple.com/videos/play/wwdc2024/10176/) — design for system experiences including Action Button (HIGH confidence)
- [WWDC25 audio recording capabilities](https://developer.apple.com/videos/play/wwdc2025/251/) — audio device selection, recording enhancements in iOS 26 (HIGH confidence — note: iOS 26 = iOS next cycle, check compatibility)
- [Live Activity / Dynamic Island guide](https://newly.app/articles/ios-live-activities) — ActivityKit requirements, Dynamic Island compact/minimal views (MEDIUM confidence)
- [SwiftUI NavigationSplitView for universal apps](https://www.createwithswift.com/exploring-the-navigationsplitview/) — iPhone/iPad adaptive navigation (HIGH confidence)

---

*Feature research for: iOS dictation app (Dicticus v2.0)*
*Researched: 2026-04-21*
