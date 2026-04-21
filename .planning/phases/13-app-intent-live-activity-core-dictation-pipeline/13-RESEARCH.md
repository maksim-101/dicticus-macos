# Phase 13: App Intent + Live Activity + Core Dictation Pipeline — Research

**Researched:** 2026-04-21
**Domain:** iOS App Intents, ActivityKit Live Activities, FluidAudio ASR, AVAudioSession, App Shortcuts (Siri)
**Confidence:** HIGH (core FluidAudio and ActivityKit patterns verified via Context7/official docs; AudioRecordingIntent ordering constraint from official Apple documentation; macOS TranscriptionService is battle-tested and directly portable)

---

<user_constraints>
## User Constraints (from STATE.md / locked decisions)

### Locked Decisions
- iOS uses AudioRecordingIntent (Option B: `openAppWhenRun = true`) — no 30s timeout constraint, unlimited recording
- Live Activity is mandatory for AudioRecordingIntent — must start before AVAudioSession activation
- Shared/ compiled as sources into both targets (NOT as SPM package — App Intents metadata extraction fails with static libraries)
- No AI cleanup on iOS v2.0 — llama.cpp GGUF has no CoreML acceleration, 3.1 GB impractical on iPhone RAM
- UserDefaults suiteName: "group.com.dicticus" for App Groups shared data
- Model stored in main app container (not App Groups — too large, not shared cross-platform)

### Claude's Discretion
- Implementation structure of the iOS dictation flow (single DictationViewModel vs wired DicticusApp)
- Widget Extension naming and bundle identifier scheme
- How to scope AVAudioSession category (`.record` vs `.playAndRecord` + `.default` mode)
- How to expose `AsrManager` / `VadManager` instances across the app lifecycle (property injection vs shared service pattern)

### Deferred Ideas (OUT OF SCOPE)
- AI cleanup on iOS (deferred to v2.1)
- Custom keyboard extension (deferred to v2.1)
- Model download UI (Phase 14)
- Custom dictionary UI (Phase 15)
- Onboarding flow (Phase 16)
- Back Tap / Action Button guided setup (Phase 16)
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| ASR-01 | User can transcribe speech in German and English on iPhone/iPad using on-device Parakeet TDT v3 | FluidAudio AsrManager + AsrModels.downloadAndLoad(version: .v3) supports 25 languages; macOS TranscriptionService is directly portable |
| ASR-02 | Transcription starts within 2 seconds of user stopping speech (model pre-warmed) | Verified: macOS ModelWarmupService pattern works; pre-warm on app foreground (scenePhase .active) |
| ASR-03 | ASR model loads automatically when app comes to foreground | ScenePhase.active trigger in DicticusApp; start ModelWarmupService.warmup() on first foreground |
| ACT-01 | User can trigger dictation via Siri Shortcut (AudioRecordingIntent, app opens to recording screen) | AudioRecordingIntent + openAppWhenRun pattern verified; AppShortcutsProvider required |
| ACT-02 | User sees a Live Activity recording indicator while dictating | ActivityKit Activity.request() must be called before AVAudioSession activation; Widget Extension target required |
| ACT-03 | User can record for unlimited duration (no time cap) | Option B: openAppWhenRun = true ensures app is in foreground; no 30s Shortcut timeout applies |
| ACT-06 | User can trigger dictation via Siri voice command | AppShortcutsProvider with phrase "Start dictation in \(.applicationName)" — Siri automatically surfaces registered phrases |
| TEXT-01 | Transcribed text is automatically copied to clipboard after dictation | UIPasteboard.general.string = result.text — one-liner, no entitlements needed |
</phase_requirements>

---

## Summary

Phase 13 wires four distinct iOS subsystems into a single end-to-end flow: App Intents (AudioRecordingIntent), ActivityKit (Live Activity / Dynamic Island), FluidAudio ASR (Parakeet TDT v3), and UIPasteboard for text delivery. The macOS TranscriptionService and ModelWarmupService are largely portable to iOS — the core FluidAudio API is identical, the SwiftUI/`@MainActor` patterns are the same, and the three-layer VAD pipeline (minimum duration guard, Silero VAD, empty result guard) can be reused verbatim.

The principal new complexity in Phase 13 is the mandatory ordering constraint from Apple: the Live Activity **must be started before** AVAudioSession is activated — if the system receives audio input without a corresponding Live Activity it kills the recording. This requires a new `DictationViewModel` that sequences (1) `Activity.request()` → (2) `AVAudioSession.setActive(true)` → (3) `audioEngine.start()` on every dictation session. An Xcode Widget Extension target is also required, because `ActivityConfiguration` must live in a `WidgetBundle` in a widget extension — not in the main app target.

The second constraint is App Intents metadata extraction: `AudioRecordingIntent` must be defined directly in the main app target's source files (not in a separate SPM package). This is already resolved by the Shared/ sources-only architecture chosen in Phase 12. The `AppShortcutsProvider` requires at minimum one phrase containing `\(.applicationName)` per shortcut to be surfaced by Siri.

**Primary recommendation:** Port macOS TranscriptionService / ModelWarmupService to iOS with minimal changes, add a new `DictationViewModel` that owns the Live Activity lifecycle, create the Widget Extension target in project.yml, and implement `AudioRecordingIntent.perform()` to call into `DictationViewModel.startDictation()`.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| App Intent definition (AudioRecordingIntent) | iOS App target | — | App Intents metadata extraction requires source-level visibility in main app target (not SPM package, not extension) |
| Live Activity lifecycle (start/update/end) | iOS App target (main process) | Widget Extension (renders UI) | `Activity.request()` called from main app; ActivityConfiguration rendered in widget extension process |
| Live Activity UI (Dynamic Island / Lock Screen) | Widget Extension target | — | `ActivityConfiguration` must be in a WidgetBundle inside a widget extension |
| AVAudioSession management | iOS App target | — | Microphone access is only available in the main app process; extensions cannot start AVAudioSession for recording |
| ASR inference (FluidAudio) | iOS App target | — | FluidAudio runs CoreML models that require full app memory headroom; cannot run in extension |
| Model pre-warm (AsrManager, VadManager) | iOS App target | — | Called on scenePhase .active; needs app lifecycle access |
| Siri voice phrase registration | iOS App target | — | AppShortcutsProvider must be in the main app target |
| Clipboard text delivery | iOS App target | — | UIPasteboard.general is accessible from main app; no entitlement needed |
| App Groups data sharing | iOS App target | Widget Extension (future) | Shared UserDefaults via "group.com.dicticus"; model not in App Groups (too large) |

---

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| FluidAudio | 0.13.6+ (SPM) | ASR inference on Neural Engine (Parakeet TDT v3) | Already in macOS target; identical API on iOS 17+; Apache 2.0 |
| ActivityKit | iOS 16.1+ (built-in) | Live Activity lifecycle management | Required by Apple for AudioRecordingIntent on iOS |
| WidgetKit | iOS 14+ (built-in) | Live Activity UI (ActivityConfiguration, DynamicIsland) | ActivityConfiguration lives in widget extension using WidgetKit |
| App Intents | iOS 16+ (built-in) | AudioRecordingIntent, AppShortcutsProvider, Siri phrase registration | Apple-mandated approach for system-level intents |
| AVFoundation | built-in | AVAudioEngine tap, AVAudioSession | Same pattern as macOS TranscriptionService |
| NaturalLanguage | built-in | Post-hoc language detection (de/en) | Same pattern as macOS TranscriptionService |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| GRDB | 7.0.0+ (SPM) | History persistence | Already in Shared/Services/HistoryService.swift |
| XcodeGen | 2.45.3 (Homebrew) | project.yml → xcodeproj generation | Adding Widget Extension target to iOS/project.yml |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| AudioRecordingIntent | A plain AppIntent with foreground navigation | Does not give the audio recording indicator or proper system status display |
| ActivityKit Live Activity | Custom overlay UI | Live Activity is mandatory for AudioRecordingIntent to keep recording active |
| AVAudioEngine tap | AVAudioRecorder | AVAudioEngine tap pattern is battle-tested in macOS codebase; direct sample access needed for FluidAudio |

**Installation (Widget Extension deps — added to project.yml):**
```bash
# No new SPM packages needed; ActivityKit and WidgetKit are built-in frameworks
# Widget Extension target added to iOS/project.yml
xcodegen generate --spec iOS/project.yml
```

**Version verification:**
- FluidAudio: verified via macOS build at `macOS/build/SourcePackages/checkouts/FluidAudio/` — already integrated
- XcodeGen: 2.45.3 confirmed via `xcodegen --version`
- Xcode: 26.4.1 (build 17E202) confirmed via `xcodebuild -version`

---

## Architecture Patterns

### System Architecture Diagram

```
Siri / Shortcuts App
        │
        │ "Start dictation in Dicticus" phrase
        ▼
AudioRecordingIntent.perform()
        │
        │ openAppWhenRun = true → app foregrounds
        ▼
DictationViewModel.startDictation()
        │
    ┌───┴─────────────────────────────────────┐
    │ 0. AVAudioApplication                   │  ← GUARD: mic permission
    │    .requestRecordPermission()            │
    └─────────────────────┬───────────────────┘
                          │
    ┌─────────────────────┴───────────────────┐
    │ 1. Activity.request(DictationAttributes)│  ← MUST be FIRST
    │    (starts Live Activity)               │
    └─────────────────────┬───────────────────┘
                          │
    ┌─────────────────────┴───────────────────┐
    │ 2. AVAudioSession.setActive(true)       │  ← AFTER Live Activity
    │    category: .record (or .playAndRecord)│
    └─────────────────────┬───────────────────┘
                          │
    ┌─────────────────────┴───────────────────┐
    │ 3. AVAudioEngine.installTap()           │
    │    + AVAudioEngine.start()              │
    │    (accumulate samples in AudioSampleBuffer)│
    └─────────────────────┬───────────────────┘
                          │ user stops (button or stop intent)
                          ▼
DictationViewModel.stopDictation()
        │
    ┌───┴─────────────────────────────────────┐
    │ 4. audioEngine.stop() + removeTap()     │
    └─────────────────────┬───────────────────┘
                          │
    ┌─────────────────────┴───────────────────┐
    │ 5. Resample to 16kHz (AudioConverter)   │
    │ 6. Silero VAD filter (VadManager)       │
    │ 7. AsrManager.transcribe(samples)       │
    │ 8. NLLanguageRecognizer (de/en)         │
    └─────────────────────┬───────────────────┘
                          │
    ┌─────────────────────┴───────────────────┐
    │ 9. UIPasteboard.general.string = text   │
    │10. activity.end(dismissalPolicy:.after) │
    └─────────────────────────────────────────┘

Widget Extension (separate process, read-only):
DictationLiveActivityConfiguration
  ├── Lock Screen / banner view
  └── DynamicIsland (compact + expanded + minimal)
```

### Recommended Project Structure
```
iOS/
├── project.yml                        ← add DicticusWidget extension target
├── Dicticus/
│   ├── DicticusApp.swift              ← add scenePhase .active → warmup()
│   ├── ContentView.swift              ← replace stub with DictationView
│   ├── DictationView.swift            ← recording UI (NEW)
│   ├── DictationViewModel.swift       ← Live Activity + AVAudio + ASR orchestrator (NEW)
│   ├── Intents/
│   │   ├── DictateIntent.swift        ← AudioRecordingIntent conformance (NEW)
│   │   └── DicticusShortcuts.swift    ← AppShortcutsProvider (NEW)
│   ├── LiveActivity/
│   │   └── DictationActivity.swift    ← ActivityAttributes + ContentState (NEW)
│   ├── Services/
│   │   ├── IOSModelWarmupService.swift← ported from macOS ModelWarmupService (NEW)
│   │   └── IOSTranscriptionService.swift ← ported from macOS TranscriptionService (NEW)
│   ├── Dicticus.entitlements
│   └── Info.plist
├── DicticusWidget/                    ← Widget Extension target (NEW)
│   ├── DicticusWidgetBundle.swift     ← @main WidgetBundle
│   ├── DictationLiveActivity.swift    ← ActivityConfiguration + DynamicIsland
│   └── Info.plist
└── DicticusTests/
    └── DicticusTests.swift
```

### Pattern 1: AudioRecordingIntent + openAppWhenRun

**What:** An `AppIntent` conforming to `AudioRecordingIntent` that foregrounds the app (Option B). `openAppWhenRun = true` removes the 30-second Shortcut timeout constraint.

**When to use:** Any time the app must remain the foreground recording controller. Required by the project decision to use Option B.

**Note:** `openAppWhenRun` is deprecated in favor of `supportedModes`, but `AudioRecordingIntent` as a `SystemIntent` has its own foreground-opening contract. The workaround is to declare `openAppWhenRun` in a backward-compat extension per Apple docs.

```swift
// Source: https://developer.apple.com/documentation/appintents/audiorecordingintent
import AppIntents

struct DictateIntent: AudioRecordingIntent {
    static let title: LocalizedStringResource = "Start Dictation"
    static let description = IntentDescription("Begin dictating in Dicticus")

    // Option B: app foregrounds, no 30-second constraint
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        // Delegate to DictationViewModel — it will:
        // 1. Start Live Activity
        // 2. Activate AVAudioSession
        // 3. Start recording
        NotificationCenter.default.post(name: .startDictation, object: nil)
        return .result()
    }
}

// Required: AppShortcutsProvider for Siri voice phrase ("Hey Siri, start dictation")
struct DicticusShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: DictateIntent(),
            phrases: [
                "Start dictation in \(.applicationName)",
                "Dictate with \(.applicationName)",
                "Begin dictation in \(.applicationName)"
            ],
            shortTitle: "Start Dictation",
            systemImageName: "mic.fill"
        )
    }
}
```

### Pattern 2: ActivityAttributes + Live Activity Lifecycle

**What:** Define `DictationAttributes` conforming to `ActivityAttributes`. Start the activity from the main app **before** AVAudioSession activation.

**When to use:** Every dictation session. Failure to start Live Activity before recording = system kills audio.

```swift
// Source: https://developer.apple.com/documentation/activitykit/displaying-live-data-with-live-activities
import ActivityKit

struct DictationAttributes: ActivityAttributes {
    // Static attributes (set once at creation, cannot change during activity)
    public struct ContentState: Codable, Hashable {
        var isRecording: Bool
        var elapsedSeconds: Int  // could drive a timer display in the Dynamic Island
    }
    // No static fields needed for this use case
}
```

**Starting the Live Activity (in DictationViewModel):**
```swift
// Source: https://developer.apple.com/documentation/activitykit/displaying-live-data-with-live-activities
import ActivityKit

var currentActivity: Activity<DictationAttributes>?

func startLiveActivity() throws {
    guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
    let attributes = DictationAttributes()
    let contentState = DictationAttributes.ContentState(isRecording: true, elapsedSeconds: 0)
    currentActivity = try Activity.request(
        attributes: attributes,
        content: ActivityContent(state: contentState, staleDate: nil),
        pushType: nil
    )
}

func endLiveActivity() async {
    let finalState = DictationAttributes.ContentState(isRecording: false, elapsedSeconds: 0)
    await currentActivity?.end(
        ActivityContent(state: finalState, staleDate: nil),
        dismissalPolicy: .after(.now + 3)
    )
    currentActivity = nil
}
```

### Pattern 3: Widget Extension — ActivityConfiguration + Dynamic Island

**What:** A WidgetBundle in the Widget Extension target that provides the Live Activity UI for the Lock Screen and Dynamic Island.

**When to use:** Required for Live Activity display. Must be a separate target (widget extension process).

```swift
// Source: https://developer.apple.com/documentation/activitykit/displaying-live-data-with-live-activities
import WidgetKit
import SwiftUI

struct DictationLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DictationAttributes.self) { context in
            // Lock Screen / banner view (non-Dynamic Island devices)
            HStack {
                Image(systemName: "mic.fill")
                    .foregroundColor(.red)
                Text(context.state.isRecording ? "Recording…" : "Processing…")
                Spacer()
            }
            .padding()
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded view (when user taps the island)
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "mic.fill").foregroundColor(.red)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Recording")
                }
            } compactLeading: {
                Image(systemName: "mic.fill").foregroundColor(.red)
            } compactTrailing: {
                Text("\(context.state.elapsedSeconds)s")
            } minimal: {
                Image(systemName: "mic.fill").foregroundColor(.red)
            }
        }
    }
}

@main
struct DicticusWidgetBundle: WidgetBundle {
    var body: some Widget {
        DictationLiveActivity()
    }
}
```

### Pattern 4: iOS TranscriptionService (porting from macOS)

**What:** The macOS `TranscriptionService` is nearly 1:1 portable. Key differences for iOS:
- No `NSPasteboard` — use `UIPasteboard.general.string = text`
- `AVAudioSession.setActive(true)` must be called; macOS does not need this
- `AVAudioSession.setCategory(.record)` or `.playAndRecord` with `.default` mode

```swift
// Source: macOS/Dicticus/Services/TranscriptionService.swift (battle-tested pattern)
// iOS difference: add AVAudioSession setup

func startRecording() throws {
    guard state == .idle else { throw TranscriptionError.busy }
    sampleBuffer.clear()

    // iOS requires explicit AVAudioSession activation AFTER Live Activity is started
    let session = AVAudioSession.sharedInstance()
    try session.setCategory(.record, mode: .default)
    try session.setActive(true)

    let inputNode = audioEngine.inputNode
    let inputFormat = inputNode.outputFormat(forBus: 0)
    Self.installTap(on: inputNode, format: inputFormat, buffer: sampleBuffer)
    try audioEngine.start()
    state = .recording
}
```

**Text delivery (iOS-specific):**
```swift
// Source: https://developer.apple.com/documentation/uikit/uipasteboard
import UIKit

UIPasteboard.general.string = result.text
```

### Pattern 5: DictationViewModel — Orchestrating the Sequence

**What:** A `@MainActor` ObservableObject that owns the sequence: mic permission check -> Live Activity -> AVAudioSession -> recording -> transcription -> clipboard -> end activity.

**When to use:** This is the single orchestrator. `DictateIntent.perform()` calls into this. `DictationView` observes it.

```swift
@MainActor
class DictationViewModel: ObservableObject {
    enum State { case idle, preparingLiveActivity, recording, transcribing }

    @Published var state: State = .idle
    @Published var lastResult: String?
    @Published var error: String?

    private var transcriptionService: IOSTranscriptionService?
    private var currentActivity: Activity<DictationAttributes>?

    // Called by DictateIntent.perform() (via NotificationCenter or direct ref)
    func startDictation() async {
        guard state == .idle else { return }

        // STEP 0: Guard on microphone permission (Pitfall 7)
        let permissionGranted = await AVAudioApplication.requestRecordPermission()
        guard permissionGranted else {
            self.error = "Microphone access denied. Enable in Settings > Privacy > Microphone."
            return
        }

        state = .preparingLiveActivity

        // STEP 1: Live Activity MUST start before AVAudioSession
        do {
            try startLiveActivity()
        } catch {
            // Non-fatal if Live Activities disabled by user — still attempt recording
        }

        // STEP 2: Activate AVAudioSession + start recording
        state = .recording
        do {
            try transcriptionService?.startRecording()
        } catch {
            await endLiveActivity()
            self.error = error.localizedDescription
            state = .idle
        }
    }

    func stopDictation() async {
        guard state == .recording else { return }
        state = .transcribing
        do {
            let result = try await transcriptionService?.stopRecordingAndTranscribe()
            if let text = result?.text {
                UIPasteboard.general.string = text
                lastResult = text
            }
        } catch {
            self.error = error.localizedDescription
        }
        await endLiveActivity()
        state = .idle
    }
}
```

### Pattern 6: ScenePhase → Model Warm-Up (ASR-03)

**What:** Trigger `warmup()` when the app enters the foreground. Identical to macOS pattern, using SwiftUI `@Environment(\.scenePhase)`.

```swift
// In DicticusApp.swift or top-level view modifier
@Environment(\.scenePhase) private var scenePhase
@StateObject private var warmupService = IOSModelWarmupService()

.onChange(of: scenePhase) { _, newPhase in
    if newPhase == .active {
        warmupService.warmup()  // no-op if already warming or ready
    }
}
```

### Pattern 7: XcodeGen Widget Extension Target in project.yml

**What:** Add a new `DicticusWidget` target of type `app-extension` with WidgetKit extension point.

```yaml
# Add to iOS/project.yml — under `targets:`
  DicticusWidget:
    type: app-extension
    platform: iOS
    sources:
      - path: DicticusWidget
    settings:
      PRODUCT_BUNDLE_IDENTIFIER: com.dicticus.ios.widget
      INFOPLIST_FILE: DicticusWidget/Info.plist
      SKIP_INSTALL: YES
      PRODUCT_NAME: DicticusWidget
    info:
      path: DicticusWidget/Info.plist
      properties:
        NSExtensionPointIdentifier: com.apple.widgetkit-extension
        NSExtension:
          NSExtensionPrincipalClass: "$(PRODUCT_MODULE_NAME).DicticusWidgetBundle"
    frameworks:
      - WidgetKit.framework
      - SwiftUI.framework

# In Dicticus target: add dependency
  Dicticus:
    ...
    dependencies:
      - package: GRDB
        product: GRDB
      - target: DicticusWidget  # ← add this
```

**Main app Info.plist must add:**
```
NSSupportsLiveActivities: true
NSSupportsLiveActivitiesFrequentUpdates: false  (we update infrequently)
```

### Anti-Patterns to Avoid

- **Starting AVAudioSession before Live Activity:** The audio session is killed by the system if no Live Activity is active. Always `Activity.request()` first.
- **Defining AudioRecordingIntent in a Swift Package / SPM module:** App Intents metadata extraction (appintentsmetadataprocessor) fails with static libraries. Keep the intent source files in the main app target.
- **Defining ActivityConfiguration in the main app target:** `ActivityConfiguration` must live in a WidgetBundle inside a widget extension. Putting it in the main app target causes a build error.
- **Sharing DictationAttributes between main app and widget extension via a shared SPM package:** The `DictationAttributes` struct must be visible to both targets — either duplicate it or add the source file to both targets' membership. Do NOT use a static SPM library for this.
- **Using `UIPasteboard` from a background thread:** `UIPasteboard.general` is main-thread-only; always dispatch to `@MainActor`.
- **Requesting microphone permission inside the intent perform() call:** Request permission on app foreground (`requestRecordPermission` in PermissionManager), not inside the intent flow. If permission is denied, the audio engine start will fail — handle this with a user-visible error.
- **Skipping microphone permission check before startRecording():** Always call `AVAudioApplication.requestRecordPermission()` as a guard before `startRecording()`. On first launch, iOS shows the permission dialog; on subsequent launches, it returns the cached result. If denied, display a user-visible error directing them to Settings.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| 16kHz audio resampling | Custom FFT/linear interpolation resampler | `AudioConverter().resampleBuffer(pcmBuffer)` (FluidAudio) | Already handles AVAudioPCMBuffer → 16kHz Float32; macOS codebase already has fallback via AVAudioConverter |
| Voice activity detection | Energy threshold filter | `VadManager` (FluidAudio) — Silero VAD v6 | Already wired in macOS TranscriptionService; three-layer VAD prevents hallucinations |
| Language detection | Regex or dictionary lookup | `NLLanguageRecognizer` (NaturalLanguage) | Same as macOS; handles de/en reliably |
| Siri integration | SiriKit intents (legacy) | `AppShortcutsProvider` + `AppIntent` | Modern approach; SiriKit INExtension is deprecated for new features |
| Global hotkey alternative | Custom touch gesture recognizer | `AudioRecordingIntent` + Siri Shortcut | The Shortcut IS the hotkey on iOS; custom keyboard (KEYB-01) is deferred to v2.1 |

**Key insight:** Phase 13 is a wiring phase, not a from-scratch implementation. The hard audio/ML work already exists in `macOS/Dicticus/Services/TranscriptionService.swift` and `ModelWarmupService.swift`. The iOS versions are adaptations, not rewrites.

---

## Common Pitfalls

### Pitfall 1: Live Activity Not Started Before AVAudioSession
**What goes wrong:** Audio recording stops immediately after starting — no error thrown, silent failure.
**Why it happens:** Apple's system policy: when `AudioRecordingIntent` is adopted, the system enforces that a Live Activity is active before it allows audio input to continue.
**How to avoid:** In `DictationViewModel.startDictation()`, call `Activity.request()` first, then `AVAudioSession.setActive(true)`, then `audioEngine.start()`. Never swap this order.
**Warning signs:** Recording appears to start (no exception) but `sampleBuffer` remains empty after stopping.

### Pitfall 2: App Intents Metadata Extraction Fails with SPM Static Libraries
**What goes wrong:** Xcode build succeeds but Siri/Shortcuts does not see the intent. The `appintentsmetadataprocessor` silently skips intents in static libraries.
**Why it happens:** App Intents requires Swift reflection metadata to be visible at the top-level binary. Static libraries are not included in the reflection scan.
**How to avoid:** Keep `DictateIntent.swift` and `DicticusShortcuts.swift` in the `Dicticus` app target source files, not in `Shared/`. The Phase 12 decision (Shared/ as sources, not SPM) already makes this safe for shared code — but new intent types must go in the app target.
**Warning signs:** "No shortcuts found for Dicticus" in Shortcuts app; intent not discoverable via Siri.

### Pitfall 3: ActivityConfiguration in Main App Target
**What goes wrong:** Build error: `ActivityConfiguration` cannot be used in a non-widget extension target.
**Why it happens:** `ActivityConfiguration` is a WidgetKit type designed to render in the widget extension process, not the main app.
**How to avoid:** All `ActivityConfiguration`/`DynamicIsland` views must be in the `DicticusWidget` extension target.
**Warning signs:** Compiler error "Cannot use 'ActivityConfiguration' here" in the main app target.

### Pitfall 4: DictationAttributes Not in Widget Extension Target Membership
**What goes wrong:** Widget extension fails to compile because it cannot find `DictationAttributes`.
**Why it happens:** `DictationAttributes` is defined in the main app target but the widget extension has no access to it.
**How to avoid:** Add `DictationActivity.swift` (containing `DictationAttributes`) to **both** targets in project.yml — or use a shared source path in project.yml.
**Warning signs:** Widget extension build fails with "use of unresolved identifier 'DictationAttributes'".

### Pitfall 5: AVAudioEngine Swift 6 Concurrency Crash
**What goes wrong:** Runtime crash on the audio thread: "accessing @MainActor-isolated property from a non-isolated context".
**Why it happens:** Swift 6 strict concurrency makes closures inside `@MainActor` methods inherit main actor isolation. AVAudioEngine calls the tap callback on the audio thread — not the main thread.
**How to avoid:** Use the same `nonisolated private static func installTap(...)` pattern from the macOS `TranscriptionService`. The `AudioSampleBuffer` class with `NSLock` provides thread-safe sample accumulation.
**Warning signs:** EXC_BAD_ACCESS or Swift concurrency violation crash during recording.

### Pitfall 6: Model Path on iOS vs macOS
**What goes wrong:** `AsrModels.downloadAndLoad(version: .v3)` tries to write to `~/Library/Application Support/FluidAudio/Models` — which is sandboxed differently on iOS.
**Why it happens:** iOS apps write to `Documents/`, `Library/`, or `Caches/` in their sandbox container. The FluidAudio default download path uses `applicationSupportDirectory` which maps correctly, but must be verified on day 1.
**How to avoid:** Use `AsrModels.downloadAndLoad(version: .v3)` without a custom path first; if it fails or writes to an unexpected location, use the `to:` parameter with `FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]`.
**Warning signs:** Model appears to download on first run but is not found on re-launch; `isFluidAudioAvailable()` returns false.

### Pitfall 7: Microphone Permission Not Requested Before Dictation Attempt
**What goes wrong:** `audioEngine.start()` throws `AVAudioSessionErrorCode.cannotStartRecording` or simply no audio is captured — no microphone permission dialog appears (iOS shows it only once).
**Why it happens:** iOS 17+ requires `NSMicrophoneUsageDescription` in Info.plist AND explicit permission request before use.
**How to avoid:** Call `AVAudioApplication.requestRecordPermission()` as a guard in `DictationViewModel.startDictation()` before starting the Live Activity or recording. If permission is denied, display a user-visible error directing the user to Settings > Privacy > Microphone.
**Warning signs:** `audioEngine.start()` throws error code -10875; no audio samples collected.

### Pitfall 8: increased-memory-limit Entitlement OOM Risk
**What goes wrong:** App crashes with `jetsam` kill on iPhone 12/13 base models (4 GB RAM) when loading the 1.24 GB Parakeet CoreML package.
**Why it happens:** iOS limits app memory to ~1.2–1.5 GB on 4 GB RAM devices without the entitlement.
**How to avoid:** Apply for `com.apple.developer.kernel.increased-memory-limit` in the Apple Developer Portal before TestFlight. This must be provisioned into the development and distribution profiles. The entitlement is approved for production apps with clear memory needs (CoreML is a valid justification).
**Warning signs:** `EXC_RESOURCE RESOURCE_TYPE_MEMORY` in crash log; `jetsam` in `os_log` output during model load.

---

## Code Examples

Verified patterns from official sources and existing codebase:

### FluidAudio Model Warm-Up (iOS)
```swift
// Source: FluidAudio README (Context7: /fluidinference/fluidaudio)
// Same API as macOS — model path defaults to applicationSupportDirectory/FluidAudio/Models
Task.detached(priority: .utility) {
    let models = try await AsrModels.downloadAndLoad(version: .v3)  // multilingual
    let manager = AsrManager(config: .default)
    try await manager.loadModels(models)
    let vad = try await VadManager(config: VadConfig(defaultThreshold: 0.75))
    // Store in @MainActor property
}
```

### FluidAudio Custom Storage Path (MEDIUM confidence — verify on device)
```swift
// Source: FluidAudio Documentation/ASR/TDT-CTC-110M.md (Context7: /fluidinference/fluidaudio)
// Use if default path fails on iOS sandbox
let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
let modelDir = appSupport.appendingPathComponent("FluidAudio/Models")
let models = try await AsrModels.downloadAndLoad(to: modelDir, version: .v3)
```

### FluidAudio Audio Transcription from Accumulated Samples
```swift
// Source: macOS/Dicticus/Services/TranscriptionService.swift (battle-tested)
let result = try await asrManager.transcribe(resampledSamples)
// result.text: String, result.confidence: Double
```

### AVAudioEngine Tap (Swift 6 safe)
```swift
// Source: macOS/Dicticus/Services/TranscriptionService.swift (battle-tested Swift 6 pattern)
nonisolated private static func installTap(
    on inputNode: AVAudioInputNode,
    format: AVAudioFormat,
    buffer: AudioSampleBuffer  // NSLock-protected thread-safe buffer
) {
    inputNode.installTap(onBus: 0, bufferSize: 4096, format: format) { pcmBuffer, _ in
        if let channelData = pcmBuffer.floatChannelData?[0] {
            let samples = Array(UnsafeBufferPointer(start: channelData, count: Int(pcmBuffer.frameLength)))
            buffer.append(samples)
        }
    }
}
```

### Live Activity Start (ActivityKit)
```swift
// Source: https://developer.apple.com/documentation/activitykit/displaying-live-data-with-live-activities
// Source: Context7 /websites/developer_apple_activitykit
if ActivityAuthorizationInfo().areActivitiesEnabled {
    let activity = try Activity.request(
        attributes: DictationAttributes(),
        content: ActivityContent(
            state: DictationAttributes.ContentState(isRecording: true, elapsedSeconds: 0),
            staleDate: nil
        ),
        pushType: nil
    )
    self.currentActivity = activity
}
```

### Live Activity End (ActivityKit)
```swift
// Source: Context7 /websites/developer_apple_activitykit
await currentActivity?.end(
    ActivityContent(
        state: DictationAttributes.ContentState(isRecording: false, elapsedSeconds: 0),
        staleDate: nil
    ),
    dismissalPolicy: .after(.now + 3)  // dismiss from lock screen after 3 seconds
)
```

### iOS Clipboard Write
```swift
// Source: https://developer.apple.com/documentation/uikit/uipasteboard
// VERIFIED via WebSearch — current as of 2024-2025
import UIKit
UIPasteboard.general.string = result.text
```

### Siri Phrase Registration
```swift
// Source: Context7 /websites/developer_apple_appintents
// Phrases must contain \(.applicationName) token at least once
struct DicticusShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: DictateIntent(),
            phrases: [
                "Start dictation in \(.applicationName)",
                "Dictate with \(.applicationName)"
            ],
            shortTitle: "Start Dictation",
            systemImageName: "mic.fill"
        )
    }
}
```

### Microphone Permission Request (iOS 17+)
```swift
// Source: https://developer.apple.com/documentation/avfaudio/avaudioapplication/requestrecordpermission(completionhandler:)
// iOS 17+ API: AVAudioApplication.requestRecordPermission (replaces AVAudioSession method)
let granted = await AVAudioApplication.requestRecordPermission()
guard granted else {
    // Display user-visible error directing to Settings > Privacy > Microphone
    return
}
// Also add NSMicrophoneUsageDescription to Info.plist
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `openAppWhenRun: Bool` static property | `supportedModes` (for non-SystemIntents) | iOS 17.2 | `openAppWhenRun` is deprecated but still works and is the documented pattern for `SystemIntent` subtypes like `AudioRecordingIntent` — use it with a `@available(*, deprecated)` extension annotation |
| `LiveActivityStartingIntent` | `LiveActivityIntent` or `AudioRecordingIntent` | iOS 17.0 | `LiveActivityStartingIntent` deprecated in iOS 17.0; use `AudioRecordingIntent` for recording scenarios |
| `AVAudioSession.requestRecordPermission(_:)` closure | `AVAudioApplication.requestRecordPermission()` async | iOS 17 | Prefer the async API; the closure API still works but is not Swift concurrency-friendly |
| `Activity.request(attributes:contentState:pushType:)` | `Activity.request(attributes:content:pushType:)` | iOS 16.2 | Old `contentState` parameter is deprecated; use `ActivityContent` wrapper |

**Deprecated/outdated:**
- `LiveActivityStartingIntent`: Deprecated in iOS 17.0 — use `AudioRecordingIntent` instead
- `openAppWhenRun` as a required protocol property: Replaced by `supportedModes`; keep for backward compatibility via extension

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | FluidAudio `AsrModels.downloadAndLoad(version: .v3)` defaults to `applicationSupportDirectory/FluidAudio/Models` on iOS — same as macOS | Standard Stack, Pitfall 6 | If iOS sandbox blocks this path, model load fails on first run; mitigation: use explicit `to:` parameter with verified path on day 1 |
| A2 | `AVAudioSession.setCategory(.record)` (not `.playAndRecord`) is sufficient for push-to-talk-only recording on iOS 17+ | Architecture Patterns Pattern 4 | If `.record` category causes issues with CallKit / other audio sessions, switch to `.playAndRecord` with `.default` mode |
| A3 | `increased-memory-limit` entitlement covers the Parakeet 1.24 GB CoreML model on 4 GB RAM iPhones | Common Pitfalls Pitfall 8 | Without this entitlement, app crashes on iPhone 12/13 base; must apply early in Developer Portal |
| A4 | Adding `DictationActivity.swift` to both the main app and widget extension target membership (in project.yml) is sufficient for sharing `DictationAttributes` without an SPM package | Architecture Patterns Pattern 3 | If Xcode 26 has restrictions on sharing source files across app + extension targets, a duplicate struct approach is fallback |
| A5 | Xcode 26 App Intents metadata processor successfully extracts `DictateIntent` when defined in the main app target source files (not SPM) | Common Pitfalls Pitfall 2 | If metadata extraction fails even from app target sources, the intent won't appear in Shortcuts; workaround is to check `SWIFT_REFLECTION_METADATA_LEVEL` build setting |

**If this table is empty:** N/A — five assumptions are flagged above.

---

## Open Questions (RESOLVED)

1. **FluidAudio model download path on iOS simulator vs device** -- RESOLVED
   - What we know: `AsrModels.downloadAndLoad(version: .v3)` works on macOS with default path; custom `to:` parameter is supported
   - What's unclear: Whether the default path resolves correctly in the iOS sandbox and whether the model is shared across simulator re-installs
   - Recommendation: On day 1 of Phase 13, run a spike on a simulator to confirm path, then test on device. Use `downloadAndLoad(to: appSupportDir)` as the explicit safe form.
   - **Resolution:** Plans mitigate this by design. IOSModelWarmupService uses `AsrModels.downloadAndLoad(version: .v3)` which defaults to `applicationSupportDirectory/FluidAudio/Models` -- this path is valid in the iOS sandbox. If the default path fails at runtime, the fallback is the explicit `to:` parameter with `FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]`. Plan 03 Task 3 (human-verify checkpoint) catches any path issues on first simulator launch. No planning change needed.

2. **`openAppWhenRun` deprecation and `AudioRecordingIntent` on iOS 18/26** -- RESOLVED
   - What we know: `openAppWhenRun` deprecated in favor of `supportedModes`; `AudioRecordingIntent` is a `SystemIntent` subtype
   - What's unclear: Whether `AudioRecordingIntent` has implicit foreground behavior that makes `openAppWhenRun = true` redundant on iOS 18
   - Recommendation: Declare both `openAppWhenRun = true` (in a `@available(*, deprecated)` extension) and implement `supportedModes` if needed — WWDC25 session "Enhance your app's audio recording capabilities" (developer.apple.com/videos/play/wwdc2025/251/) may clarify.
   - **Resolution:** Plans implement both backward-compat patterns. DictateIntent declares `@available(*, deprecated) static var openAppWhenRun: Bool = true` for iOS 17 compatibility, while conforming to `AudioRecordingIntent` (a `SystemIntent` subtype) which has implicit foreground behavior on iOS 18+. If `supportedModes` is required on iOS 26, it can be added at that time without architectural change. Plan 03 Task 3 (human-verify checkpoint on device) validates that the intent correctly foregrounds the app and begins recording. This is an execution-time verification, not a planning blocker.

3. **`increased-memory-limit` entitlement approval timeline** -- RESOLVED
   - What we know: Must be requested from Apple Developer Portal; approved for professional CoreML apps; not instant
   - What's unclear: Approval SLA and whether it affects TestFlight builds or only App Store builds
   - Recommendation: Submit entitlement request on day 1 of Phase 13. In parallel, test on higher-RAM devices (iPhone 15 Pro: 8 GB, no OOM risk) during development.
   - **Resolution:** Timeline risk acknowledged but does not block planning or development. The entitlement is declared in project.yml and Dicticus.entitlements (Plan 01). Development proceeds on high-RAM devices (iPhone 15 Pro+ with 8 GB) where no OOM risk exists. The entitlement request should be submitted to the Apple Developer Portal in parallel with Phase 13 execution. TestFlight builds work without the entitlement on high-RAM devices; only 4 GB devices (iPhone 12/13 base) require it for production.

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Xcode | iOS build | ✓ | 26.4.1 (17E202) | — |
| XcodeGen | project.yml → xcodeproj | ✓ | 2.45.3 | Manual Xcode target creation |
| FluidAudio (SPM) | ASR inference | ✓ | Resolved in macOS/build/SourcePackages/ | — |
| ActivityKit (built-in) | Live Activity | ✓ | iOS 16.1+, project targets iOS 17.0 | — |
| App Intents (built-in) | AudioRecordingIntent | ✓ | iOS 16+, project targets iOS 17.0 | — |
| iOS Simulator (iPhone 17 Pro) | Build verification | ✓ | Xcode 26.4.1 | Any available simulator |
| Physical iPhone | Siri / Live Activity final test | [ASSUMED] | Unknown | Simulator for most features; Siri requires device |

**Missing dependencies with no fallback:**
- Physical iPhone for Siri voice command testing (ACT-06). Simulator does not support Siri invocation of App Shortcuts.

**Missing dependencies with fallback:**
- `increased-memory-limit` entitlement: Available fallback is to test on higher-RAM devices only during development.

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | XCTest (existing, iOS target: DicticusTests) |
| Config file | iOS/project.yml DicticusTests target |
| Quick run command | `xcodebuild test -project iOS/Dicticus.xcodeproj -scheme Dicticus -destination "platform=iOS Simulator,name=iPhone 17 Pro"` |
| Full suite command | Same — DicticusTests is the only test bundle |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| ASR-01 | Transcription of de/en audio via Parakeet v3 | Integration (model-dependent) | `xcodebuild test ... -only-testing:DicticusTests/IOSTranscriptionServiceTests` | Created by Plan 02 |
| ASR-02 | Transcription latency < 2s from pre-warmed model | Integration | `xcodebuild test ... -only-testing:DicticusTests/IOSTranscriptionServiceTests` | Created by Plan 02 |
| ASR-03 | Model warmup triggered on scenePhase .active | Unit | `xcodebuild test ... -only-testing:DicticusTests/IOSModelWarmupServiceTests` | Created by Plan 02 |
| ACT-01 | DictateIntent.perform() triggers dictation flow | Unit (mock DictationViewModel) | `xcodebuild test ... -only-testing:DicticusTests/DictationViewModelTests` | Created by Plan 03 |
| ACT-02 | Live Activity starts before AVAudioSession | Unit (mock Activity) | `xcodebuild test ... -only-testing:DicticusTests/DictationViewModelTests` | Created by Plan 03 |
| ACT-03 | Recording continues beyond 30s | Integration (requires device) | Manual on device | — |
| ACT-06 | Siri phrase surfaces Dicticus shortcut | Manual (requires device + Siri) | Manual | — |
| TEXT-01 | UIPasteboard.general.string set after transcription | Unit | `xcodebuild test ... -only-testing:DicticusTests/DictationViewModelTests` | Created by Plan 03 |

### Sampling Rate
- **Per task commit:** `xcodebuild build -project iOS/Dicticus.xcodeproj -scheme Dicticus -destination "platform=iOS Simulator,name=iPhone 17 Pro" | xcpretty`
- **Per wave merge:** Full test suite run
- **Phase gate:** Full suite green before `/gsd-verify-work`

---

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | — |
| V3 Session Management | no | — |
| V4 Access Control | yes | AVAudioApplication.requestRecordPermission() — iOS permission system |
| V5 Input Validation | yes | containsNonLatinScript() filter (ported from macOS) on ASR output before clipboard write |
| V6 Cryptography | no | — |

### Known Threat Patterns for this Stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| ASR hallucination (non-Latin script output) | Tampering | containsNonLatinScript() filter (already in macOS TranscriptionService) |
| Clipboard poisoning (malformed ASR text) | Tampering | Non-Latin script filter + empty result guard prevent garbage on clipboard |
| Microphone access without permission | Elevation of privilege | iOS permission system + NSMicrophoneUsageDescription; gate startDictation on AVAudioApplication.requestRecordPermission() check |
| Model file tampering | Tampering | FluidAudio downloads from HuggingFace via HTTPS; CoreML compilation verifies model integrity — no additional action needed |
| Live Activity data exposure | Information disclosure | ContentState contains only `isRecording: Bool` and `elapsedSeconds: Int` — no sensitive data |

---

## Sources

### Primary (HIGH confidence)
- `/fluidinference/fluidaudio` (Context7) — model loading, AudioConverter, VAD streaming, custom storage path
- `/websites/developer_apple_activitykit` (Context7) — Activity.request(), ActivityAttributes, ContentState, DynamicIsland, end()
- `/websites/developer_apple_appintents` (Context7) — AudioRecordingIntent protocol definition, AppShortcutsProvider, openAppWhenRun deprecation
- `macOS/Dicticus/Services/TranscriptionService.swift` — battle-tested AVAudioEngine tap pattern, Swift 6 concurrency solution, three-layer VAD, resampling
- `macOS/Dicticus/Services/ModelWarmupService.swift` — warm-up lifecycle, timeout watchdog, sequential loading

### Secondary (MEDIUM confidence)
- [Apple ActivityKit — Displaying Live Data with Live Activities](https://developer.apple.com/documentation/activitykit/displaying-live-data-with-live-activities) — Activity.request() example, NSSupportsLiveActivities key
- [UIPasteboard — Apple Developer Documentation](https://developer.apple.com/documentation/uikit/uipasteboard/) — confirmed via WebSearch, multiple tutorials
- [Apple Forum: Memory Issues on 4 GB iOS devices (ml-stable-diffusion #291)](https://github.com/apple/ml-stable-diffusion/issues/291) — increased-memory-limit context
- [AppMakers.Dev — Clipboard in SwiftUI](https://appmakers.dev/clipboard-copy-and-paste-in-swiftui/) — UIPasteboard.general.string pattern

### Tertiary (LOW confidence)
- [Hacking with Swift Forums — AudioRecordingIntent with Live Activity](https://www.hackingwithswift.com/forums/swift/starting-an-audio-recording-liveactivity-with-action-button/29100) — referenced but inaccessible (403); guidance derived from official docs instead
- [WWDC25 — Enhance your app's audio recording capabilities](https://developer.apple.com/videos/play/wwdc2025/251/) — URL found; not yet accessed; may clarify openAppWhenRun/supportedModes for AudioRecordingIntent in iOS 26

---

## Metadata

**Confidence breakdown:**
- Standard Stack: HIGH — FluidAudio API verified via Context7; ActivityKit/AppIntents from official Apple docs; macOS implementation in codebase
- Architecture: HIGH — Core patterns verified from official docs; sequencing constraint (Live Activity before AVAudioSession) confirmed from AudioRecordingIntent Apple docs
- Pitfalls: HIGH (most derived from existing macOS codebase experience or official Apple docs) / MEDIUM (model path on iOS — A1 assumption)

**Research date:** 2026-04-21
**Valid until:** 2026-05-21 (stable APIs; FluidAudio active development — check for breaking changes if > 30 days)
