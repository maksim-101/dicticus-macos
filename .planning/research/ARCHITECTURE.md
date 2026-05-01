# Architecture Research: iOS App Integration

**Domain:** iOS dictation app integrated with existing macOS Swift/SwiftUI codebase
**Researched:** 2026-04-21
**Confidence:** HIGH (official Apple docs + Context7, existing codebase directly inspected)

---

## Standard Architecture

### System Overview

```
┌──────────────────────────────────────────────────────────────────────┐
│                         iOS App (com.dicticus.ios)                   │
├──────────────────────────────────────────────────────────────────────┤
│  ┌────────────────────┐   ┌─────────────────────────────────────┐    │
│  │   SwiftUI App UI   │   │         DictateIntent (AppIntent)   │    │
│  │  (model mgmt,      │   │  conforms to AudioRecordingIntent   │    │
│  │   dictionary,      │   │  + supports Live Activity           │    │
│  │   history)         │   │  openAppWhenRun = true              │    │
│  └────────┬───────────┘   └──────────────┬──────────────────────┘    │
│           │                              │ perform() async           │
├───────────┴──────────────────────────────┴──────────────────────────┤
│                      Service Layer (platform-agnostic logic)          │
│  ┌──────────────────┐ ┌──────────────┐ ┌───────────────────────┐    │
│  │TranscriptionSvc  │ │ Dictionary   │ │   TextProcessingSvc   │    │
│  │(FluidAudio ASR)  │ │ Service      │ │  (Dict → ITN → out)   │    │
│  └──────────────────┘ └──────────────┘ └───────────────────────┘    │
│  ┌──────────────────┐ ┌──────────────┐                               │
│  │  HistoryService  │ │  ITNUtility  │                               │
│  │  (GRDB/SQLite)   │ │  (struct)    │                               │
│  └──────────────────┘ └──────────────┘                               │
├──────────────────────────────────────────────────────────────────────┤
│                         Platform Adapters                             │
│  ┌──────────────────────────┐  ┌───────────────────────────────┐    │
│  │  iOSAudioCaptureService  │  │  iOSPermissionManager         │    │
│  │  (AVAudioSession record) │  │  (microphone permission)      │    │
│  └──────────────────────────┘  └───────────────────────────────┘    │
│  ┌──────────────────────────┐                                        │
│  │  ClipboardOutputService  │                                        │
│  │  (UIPasteboard + share)  │                                        │
│  └──────────────────────────┘                                        │
├──────────────────────────────────────────────────────────────────────┤
│                   Model Layer (shared file layout)                    │
│  ┌────────────────────────────────────────────────────────────────┐  │
│  │  FluidAudio / Parakeet TDT v3 (CoreML — Neural Engine)        │  │
│  │  Stored at: App Container (no App Groups needed for models)   │  │
│  └────────────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────────┘

App Groups container (group.com.dicticus):
  └── shared UserDefaults — custom dictionary + case-sensitive flag
      (read/write from iOS app; future: macOS app also reads if needed)
```

### Component Responsibilities

| Component | Responsibility | Lives In |
|-----------|----------------|----------|
| `DictateIntent` | AppIntent entry point — orchestrates record → transcribe → copy | `iOS/` |
| `iOSAudioCaptureService` | AVAudioSession config, AVAudioEngine record on iOS | `iOS/` |
| `iOSPermissionManager` | Microphone `AVCaptureDevice.requestAccess` on iOS | `iOS/` |
| `ClipboardOutputService` | Write to `UIPasteboard.general`, return text to Shortcut | `iOS/` |
| `ModelWarmupService` (iOS) | Download Parakeet CoreML, warm FluidAudio on launch | `iOS/` |
| `TranscriptionService` | Audio capture + FluidAudio ASR pipeline | Extracted to `Shared/` |
| `DictionaryService` | Find-and-replace corrections, reads shared UserDefaults | Extracted to `Shared/` |
| `ITNUtility` | Number word → digit conversion (pure struct, no imports) | Extracted to `Shared/` |
| `TextProcessingService` | Orchestrate Dict → ITN → output | Extracted to `Shared/` |
| `HistoryService` | GRDB SQLite transcription log | Extracted to `Shared/` |
| `CleanupPrompt` | Prompt builder (no-op on iOS v2.0 — deferred) | Extracted to `Shared/` |
| `DicticusTranscriptionResult` | Sendable value type for ASR output | Extracted to `Shared/` |
| `TranscriptionEntry` | GRDB model for history | Extracted to `Shared/` |

---

## Recommended Project Structure

```
dicticus/
├── macOS/
│   ├── project.yml                     ← existing, unchanged
│   ├── Dicticus/                       ← macOS-only sources (hotkeys, menu bar, TextInjector)
│   └── DicticusTests/
│
├── Shared/                             ← extracted platform-agnostic Swift code
│   ├── Services/
│   │   ├── TranscriptionService.swift  ← moved from macOS (remove AVAudioEngine tap — keep
│   │   │                                  pipeline; audio input abstracted via protocol)
│   │   ├── DictionaryService.swift     ← moved from macOS (swap UserDefaults.standard →
│   │   │                                  UserDefaults(suiteName: "group.com.dicticus"))
│   │   ├── HistoryService.swift        ← moved from macOS (path: App Support, same logic)
│   │   ├── TextProcessingService.swift ← moved from macOS (no changes needed)
│   │   └── CleanupService.swift        ← keep in macOS/ for v2.0 (llama.cpp — not on iOS yet)
│   ├── Utilities/
│   │   └── ITNUtility.swift            ← moved from macOS (pure struct, zero deps)
│   ├── Models/
│   │   ├── TranscriptionResult.swift   ← moved from macOS
│   │   ├── CleanupPrompt.swift         ← moved from macOS (iOS uses plain-mode only)
│   │   └── DictionaryMetadata.swift    ← extracted from DictionaryService.swift
│   └── Extensions/
│       └── (any cross-platform extensions)
│
├── iOS/
│   ├── project.yml                     ← NEW: xcodegen config for iOS target
│   ├── DicticusIOS/                    ← iOS app sources
│   │   ├── DicticusIOSApp.swift        ← @main entry, warmup at launch
│   │   ├── ContentView.swift           ← simple SwiftUI root (model status, settings)
│   │   ├── Intents/
│   │   │   └── DictateIntent.swift     ← AppIntent conforming to AudioRecordingIntent
│   │   ├── Services/
│   │   │   ├── iOSAudioCaptureService.swift
│   │   │   ├── iOSPermissionManager.swift
│   │   │   ├── iOSModelWarmupService.swift
│   │   │   └── ClipboardOutputService.swift
│   │   └── Views/
│   │       ├── ModelStatusView.swift
│   │       ├── DictionaryView.swift    ← reuse from macOS with minor adaptation
│   │       └── HistoryView.swift       ← reuse from macOS with minor adaptation
│   └── DicticusIOSTests/
│
├── scripts/
│   ├── build-dmg.sh
│   └── build-ipa.sh                    ← NEW
└── .planning/
```

### Structure Rationale

- **Shared/**: Zero platform-specific imports (no AppKit, UIKit, KeyboardShortcuts, Sparkle). Contains only Foundation, GRDB, FluidAudio, NaturalLanguage. Compiled into both targets via xcodegen `sources` reference.
- **iOS/project.yml**: Separate xcodegen spec keeps macOS project generation independent. Follows the same pattern as macOS/project.yml. Both xcodeprojs share the same SPM packages.
- **iOS/DicticusIOS/Intents/**: Grouping all AppIntent types together makes metadata extraction reliable. The App Intents compiler build phase scans source files — keep intents in a predictable location.
- **CleanupService stays in macOS/**: llama.cpp Metal is not supported on iOS v2.0. Moving it now would add iOS-incompatible C library linkage to the iOS target.

---

## Architectural Patterns

### Pattern 1: AppIntent as the iOS Activation Entry Point

**What:** `DictateIntent` conforms to `AudioRecordingIntent` (which inherits from `AppIntent`). The Shortcuts app calls `perform()` asynchronously. The intent opens the app to foreground, records audio, transcribes, and returns the text as a `String` Shortcut output.

**When to use:** This is the only viable push-to-talk mechanism on iOS for a standalone app. `AudioRecordingIntent` is required to display the iOS recording indicator and (critically) to keep AVAudioSession alive during recording.

**Critical constraint:** On iOS, `AudioRecordingIntent` requires a Live Activity to be started when recording begins, or iOS stops the audio session. This is enforced by the system; ignoring it causes silent recording failure.

**Example skeleton:**

```swift
import AppIntents
import ActivityKit

struct DictateIntent: AudioRecordingIntent {
    static var title: LocalizedStringResource = "Dictate"
    static var description = IntentDescription("Record speech and copy transcription to clipboard.")

    // Opens the app to foreground so AVAudioSession can record
    static var openAppWhenRun: Bool { true }

    func perform() async throws -> some ReturnsValue<String> {
        // 1. Start Live Activity (required by AudioRecordingIntent on iOS)
        let activity = try? Activity<DictationAttributes>.request(...)

        // 2. Request microphone permission if needed
        // 3. Start AVAudioSession + AVAudioEngine recording
        // 4. Wait for user to end the Shortcut (or use fixed duration)
        // 5. Stop recording, run FluidAudio transcription
        // 6. Apply DictionaryService + ITNUtility
        // 7. Write to UIPasteboard.general
        // 8. End Live Activity
        // 9. Return text as Shortcut output value

        let text = try await transcribeAndProcess()
        UIPasteboard.general.string = text
        await activity?.end(nil, dismissalPolicy: .immediate)
        return .result(value: text)
    }
}
```

**Trade-offs:** Opening the app to foreground for recording is required because AVAudioSession background recording requires explicit background audio entitlement and is not appropriate for a push-to-talk flow. The foreground activation is also what makes the UX feel responsive (app appears, shows recording indicator, dismisses after paste).

### Pattern 2: Shared Code via Direct Source Inclusion (No Local SPM Package)

**What:** `Shared/` sources are referenced directly in both `macOS/project.yml` and `iOS/project.yml` using relative paths, not wrapped in a local Swift Package.

**Why:** App Intents metadata extraction requires the intent types to be in the final app target's compilation unit. When App Intents types are in a static library (the default for SPM packages), the compiler's `appintentmetadataprocessor` may not find them. This is a documented pitfall in the Apple Developer Forums. Direct source inclusion sidesteps this entirely.

**Example in iOS/project.yml:**

```yaml
targets:
  DicticusIOS:
    type: application
    platform: iOS
    sources:
      - path: DicticusIOS          # iOS-specific sources
      - path: ../Shared            # shared sources, cross-platform
```

**When not to use:** If shared code grows to include platform-conditional compilation (`#if os(iOS)`) extensively, extract to a local Swift Package instead and add the `AppIntentsPackage` conformance to the package target.

**Trade-offs:** Pro: simple, no SPM package boilerplate, no dynamic/static linking headaches. Con: Xcode will show Shared/ sources under both targets in the navigator — this is cosmetic only.

### Pattern 3: App Groups for Dictionary Sync (Prepare, Don't Require)

**What:** `DictionaryService` reads and writes from `UserDefaults(suiteName: "group.com.dicticus")` instead of `UserDefaults.standard`. Both macOS and iOS apps declare the same App Group entitlement.

**When to use:** Even if macOS ↔ iOS sync is not implemented in v2.0, using App Groups container from day one avoids a migration pass later. Dictionary data is small (< 10 KB) so there is no performance concern.

**Migration in DictionaryService:** Change the two `UserDefaults.standard` references to use a shared suite. The existing `migrateOldFormat()` pattern can be reused to migrate any data previously stored under `UserDefaults.standard`.

```swift
private static let defaults = UserDefaults(suiteName: "group.com.dicticus") ?? .standard
```

**Trade-offs:** App Group requires provisioning profile addition (one-time). iCloud sync across devices is out of scope — App Groups only share data between apps on the same device.

---

## Data Flow

### Shortcut → Clipboard Flow (Primary iOS Path)

```
User triggers Shortcut
  (Action Button / Back Tap / Siri / Shortcuts app)
        ↓
DictateIntent.perform() called by system
        ↓
App opens to foreground (openAppWhenRun = true)
        ↓
Live Activity started (required for AudioRecordingIntent on iOS)
        ↓
iOSAudioCaptureService.startRecording()
  AVAudioSession.setCategory(.record, mode: .measurement)
  AVAudioEngine installs tap → AudioSampleBuffer
        ↓
[User speaks — same push-to-talk UX as macOS conceptually]
[For v2.0: Shortcut runs a fixed-duration record or user taps a button in app]
        ↓
iOSAudioCaptureService.stopRecordingAndTranscribe()
  Resample to 16kHz
  VadManager.process() [Silero VAD]
  AsrManager.transcribe() [Parakeet TDT v3 on Neural Engine]
  NLLanguageRecognizer → language code
  → DicticusTranscriptionResult
        ↓
TextProcessingService.process(text, language, mode: .plain)
  DictionaryService.apply(text)    ← reads group.com.dicticus UserDefaults
  ITNUtility.applyITN(text, language)
  [CleanupService skipped — not available on iOS v2.0]
  HistoryService.save(entry)       ← GRDB in iOS App Container
        ↓
UIPasteboard.general.string = processedText
        ↓
Live Activity ended
        ↓
.result(value: processedText) returned to Shortcuts
  → Shortcut output: text string (available to next Shortcut action)
        ↓
App dismisses / returns to previous context
```

### Model Warmup Flow (iOS App Launch)

```
App launches (or comes to foreground)
        ↓
iOSModelWarmupService.warmup()
  AsrModels.downloadAndLoad(version: .v3)
    → Downloads to App Container (not App Groups — model is large, per-app)
    → Cached after first download
  AsrManager.loadModels(models)
  VadManager init
        ↓
@Published isReady = true
  → ContentView shows "Ready" state
  → DictateIntent can now execute without model load delay
```

### Key Data Flows Summary

1. **Intent → audio → transcription:** `DictateIntent.perform()` → `iOSAudioCaptureService` → `TranscriptionService` → `TextProcessingService` → `UIPasteboard`
2. **Dictionary sync (same device, v2.0+):** `DictionaryService` reads `group.com.dicticus` UserDefaults; edits in iOS app settings visible immediately in next dictation
3. **History (per-platform):** Each platform writes its own GRDB database in its App Container — no cross-platform history sync in v2.0
4. **Shortcut output:** `DictateIntent` returns `String` value, enabling chaining with other Shortcuts actions (e.g., "Paste" action, "Send Message" action)

---

## Scaling Considerations

This is a local on-device app with a single user. Traditional scaling concerns do not apply. The relevant performance constraints are:

| Concern | Approach |
|---------|----------|
| Model cold start | Warm at app launch; cache after first download |
| Intent launch latency | `openAppWhenRun = true` brings app to foreground; model warm = fast |
| Memory on older iPhones | Parakeet TDT v3 uses ~66 MB per inference on ANE; total footprint should stay under 300 MB |
| Battery impact | Push-to-talk only — recording only when user holds, same as macOS |

---

## Anti-Patterns

### Anti-Pattern 1: Putting App Intents Types in a Static SPM Package

**What people do:** Create a local `DicticusShared` Swift Package, add `DictateIntent` there, reference the package from the iOS app target.

**Why it's wrong:** The App Intents compiler infrastructure (`appintentmetadataprocessor`) runs as an Xcode build phase and needs to find intent types in the main target's compilation unit. Static library linking (the default for SPM) means intent metadata is often not extracted correctly. The Apple Developer Forums confirm this is a common issue. The workaround (adding `AppIntentsPackage` conformance) adds boilerplate and is fragile.

**Do this instead:** Keep `DictateIntent.swift` in `iOS/DicticusIOS/Intents/` (inside the app target's sources). Reference `Shared/` sources directly via xcodegen `sources` paths.

### Anti-Pattern 2: Background-Only Recording Without Live Activity

**What people do:** Set `openAppWhenRun = false`, try to record in the background, skip Live Activity.

**Why it's wrong:** `AudioRecordingIntent` on iOS explicitly requires starting a Live Activity when recording begins. If no Live Activity is started, iOS stops the audio session. This is not a soft recommendation — it is enforced by the system. The app will appear to work in the simulator but fail on device.

**Do this instead:** Start a minimal Live Activity with `ActivityKit` at the top of `perform()`, before any audio session activation. End it when transcription completes.

### Anti-Pattern 3: Sharing Model Files via App Groups

**What people do:** Store Parakeet CoreML model files in the App Groups shared container (`group.com.dicticus`) so macOS and iOS can share the same downloaded files.

**Why it's wrong:** App Group containers are not shared between macOS and iOS. Even under the same developer team, each platform's App Group maps to a different physical container. On macOS, app groups use `~/Library/Group Containers/`; on iOS, each device has its own container. File sharing across platforms requires iCloud Drive or manual transfer, which is out of scope.

**Do this instead:** Each platform downloads and stores its own model files in its App Container. Use App Groups only for small config data (dictionary, settings) where the data is created on-device.

### Anti-Pattern 4: TranscriptionService as a @MainActor Global Singleton on iOS

**What people do:** Use the existing `static let shared` pattern for TranscriptionService, initialized at app start.

**Why it's wrong:** `DictateIntent.perform()` is called in a detached async context by the App Intents runtime. If `TranscriptionService` is `@MainActor` and initialized lazily on first access from the intent, it will stall waiting for the main actor while the intent's async context is running. The existing macOS initialization pattern (creating services after warmup and wiring via `@State`) works because all wiring happens on the main actor at app launch.

**Do this instead:** Keep the warmup-then-wire pattern: `iOSModelWarmupService` runs at app launch on `@MainActor`, stores the warm `AsrManager` and `VadManager` instances. The intent accesses the already-initialized services (no lazy initialization).

### Anti-Pattern 5: Using the iOS Custom Keyboard Extension for Recording

**What people do:** Build a `UIInputViewController` keyboard extension that tries to use `AVAudioSession` for live microphone access.

**Why it's wrong:** iOS blocks microphone access in keyboard extensions. Extensions run in a sandboxed process that does not have the `UIBackgroundModes: audio` entitlement and cannot activate an `AVAudioSession` with the `.record` category. This was tested in the macOS project research phase and confirmed by Apple's documentation.

**Do this instead:** Use the Shortcut-based activation (v2.0). The keyboard extension approach (bounce architecture via main app) is deferred to v2.1.

---

## Integration Points

### New vs. Existing Components

| Component | Status | Action |
|-----------|--------|--------|
| `TranscriptionService` | **Extract** to `Shared/` | Remove macOS-specific `AVAudioEngine` tap wiring; abstract via `AudioInputProtocol` or keep concrete (simpler) |
| `DictionaryService` | **Extract** to `Shared/` | Change `UserDefaults.standard` → `UserDefaults(suiteName: "group.com.dicticus")` |
| `ITNUtility` | **Extract** to `Shared/` | No changes needed (pure struct, Foundation only) |
| `TextProcessingService` | **Extract** to `Shared/` | No changes needed |
| `HistoryService` | **Extract** to `Shared/` | Database path resolution via platform-agnostic `FileManager` call already used |
| `CleanupPrompt` | **Extract** to `Shared/` | No changes; iOS will call `process(mode: .plain)` only |
| `DicticusTranscriptionResult` | **Extract** to `Shared/` | No changes |
| `TranscriptionEntry` | **Extract** to `Shared/` | No changes |
| `DictateIntent` | **New** in `iOS/` | Core AppIntent entry point |
| `iOSAudioCaptureService` | **New** in `iOS/` | AVAudioSession + recording on iOS |
| `iOSModelWarmupService` | **New** in `iOS/` | Parallel to macOS `ModelWarmupService` |
| `iOSPermissionManager` | **New** in `iOS/` | `AVCaptureDevice.requestAccess` for iOS |
| `ClipboardOutputService` | **New** in `iOS/` | `UIPasteboard.general` |
| `DictationAttributes` (ActivityKit) | **New** in `iOS/` | Live Activity state for recording indicator |
| `iOS/project.yml` | **New** | xcodegen config mirroring macOS/project.yml pattern |
| `macOS/DicticusApp.swift` | **No change** | macOS-specific, untouched |
| `macOS/Services/CleanupService.swift` | **No change** | Stays in macOS only |
| `macOS/Services/HotkeyManager.swift` | **No change** | macOS-only |
| `macOS/Services/TextInjector.swift` | **No change** | macOS-only |

### Build Order for Implementation

1. **Extract Shared/ sources first** — required before iOS project can compile. This is pure file movement + one `UserDefaults` suite change in `DictionaryService`. macOS app must still build and pass all 158 tests after extraction.
2. **Create iOS/project.yml** — define iOS target, reference Shared/ sources, add FluidAudio + GRDB packages. Verify empty iOS app compiles.
3. **iOSModelWarmupService + iOSAudioCaptureService** — get FluidAudio running and recording on iOS simulator/device.
4. **DictateIntent skeleton** — bare AppIntent that opens app and returns a hardcoded string. Verify it appears in Shortcuts app.
5. **Wire intent → audio → transcription** — full pipeline inside `perform()`.
6. **Live Activity** — add `DictationAttributes` and `ActivityKit` integration. Required for `AudioRecordingIntent` compliance.
7. **DictionaryService + TextProcessingService** — connect post-ASR processing.
8. **Clipboard output + Shortcut return value** — complete the data flow.
9. **iOS UI** — model status, dictionary management, history views.

### Internal Boundaries

| Boundary | Communication | Notes |
|----------|---------------|-------|
| `DictateIntent` ↔ `TranscriptionService` | Direct call on `@MainActor` | Intent opens app to foreground; services live on main actor — no actor-crossing issues |
| `Shared/` ↔ `macOS/` | Source compilation only | Shared sources compiled into both targets; no runtime communication |
| `DictionaryService` ↔ App Groups | `UserDefaults(suiteName:)` | Both platforms read same key; no notification needed (reads at each dictation) |
| `DictateIntent` ↔ `ActivityKit` | `Activity<DictationAttributes>.request()` | Live Activity must be started before `AVAudioSession.setActive(true)` |
| `iOS/` ↔ Model files | App Container `Application Support/Dicticus/` | FluidAudio manages its own download/cache path; no cross-platform sharing |

---

## iOS/project.yml Recommended Skeleton

```yaml
name: DicticusIOS
options:
  bundleIdPrefix: com.dicticus
  deploymentTarget:
    iOS: "17.0"
  xcodeVersion: "16.0"
  defaultConfig: Debug

# Reuse same package definitions as macOS — SPM caches are shared
packages:
  FluidAudio:
    url: https://github.com/FluidInference/FluidAudio.git
    from: 0.13.6
  GRDB:
    url: https://github.com/groue/GRDB.swift.git
    from: 7.0.0

targets:
  DicticusIOS:
    type: application
    platform: iOS
    deploymentTarget: "17.0"
    sources:
      - path: DicticusIOS         # iOS-only sources (intents, UI, platform services)
      - path: ../Shared           # shared logic (no platform-specific imports)
    info:
      path: DicticusIOS/Info.plist
      properties:
        CFBundleDisplayName: Dicticus
        CFBundleIdentifier: com.dicticus.ios
        CFBundleShortVersionString: "2.0.0"
        NSMicrophoneUsageDescription: "Dicticus needs microphone access to transcribe your speech. Your audio never leaves this device."
        NSSupportsLiveActivities: YES
        UILaunchScreen: {}
    entitlements:
      path: DicticusIOS/DicticusIOS.entitlements
      properties:
        com.apple.security.application-groups:
          - group.com.dicticus
        com.apple.developer.activitykit: true  # Live Activities
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.dicticus.ios
        SWIFT_VERSION: "6.0"
        IPHONEOS_DEPLOYMENT_TARGET: "17.0"
        CODE_SIGN_STYLE: Automatic
        DEVELOPMENT_TEAM: ${DEVELOPER_TEAM_ID}
    dependencies:
      - package: FluidAudio
        product: FluidAudio
      - package: GRDB
        product: GRDB

  DicticusIOSTests:
    type: bundle.unit-test
    platform: iOS
    sources:
      - path: DicticusIOSTests
    settings:
      base:
        SWIFT_VERSION: "6.0"
        GENERATE_INFOPLIST_FILE: YES
    dependencies:
      - target: DicticusIOS
```

**Notes on the project.yml:**
- iOS deployment target is 17.0 (minimum for `AudioRecordingIntent` and `ActivityKit` Live Activities as commonly used)
- `NSSupportsLiveActivities: YES` is required in Info.plist for `AudioRecordingIntent`
- App Groups entitlement requires manual provisioning profile configuration in Apple Developer portal; xcodegen generates the entitlements file correctly but provisioning must be registered separately
- `KeyboardShortcuts`, `Sparkle`, `LaunchAtLogin`, and `llama` packages are omitted — macOS-only

---

## Sources

- App Intents `AudioRecordingIntent` protocol: https://developer.apple.com/documentation/appintents/audiorecordingintent (HIGH confidence — Context7 + official docs)
- App Intents `IntentResult` / `ReturnsValue`: https://developer.apple.com/documentation/appintents/intentresult (HIGH confidence — Context7)
- App Intents `openAppWhenRun` / `supportedModes`: https://developer.apple.com/documentation/appintents/appintent/supportedmodes (HIGH confidence — Context7)
- App Intents with SPM static library issue: https://developer.apple.com/forums/thread/759160 (MEDIUM confidence — Apple Developer Forums)
- XcodeGen multi-target, entitlements, App Groups: https://github.com/yonaskolb/XcodeGen/blob/master/Docs/ProjectSpec.md (HIGH confidence — Context7)
- XcodeGen sources path for shared code: https://context7.com/yonaskolb/xcodegen/llms.txt (HIGH confidence — Context7)
- App Groups shared UserDefaults pattern: https://developer.apple.com/documentation/xcode/configuring-app-groups (HIGH confidence — Apple docs)
- FluidAudio iOS + AVAudioEngine tap: https://github.com/fluidinference/fluidaudio/blob/main/README.md (HIGH confidence — Context7)
- Existing macOS codebase (directly inspected): macOS/Dicticus/Services/, macOS/project.yml (HIGH confidence)

---
*Architecture research for: Dicticus iOS app integration with existing macOS Swift codebase*
*Researched: 2026-04-21*
