# Technology Stack: v2.0 iOS App — Shortcut Dictation

**Project:** Dicticus v2.0 — iOS App (iPhone + iPad)
**Researched:** 2026-04-21
**Overall Confidence:** HIGH (FluidAudio iOS requirements verified via Context7 + official docs; App Intents via Apple documentation and WWDC materials; model size verified via HuggingFace repo)

---

## Existing Stack (Validated in v1.0/v1.1 — DO NOT CHANGE on macOS)

| Technology | Purpose | Status |
|------------|---------|--------|
| FluidAudio 0.13.6+ | ASR via Parakeet TDT v3 on ANE | macOS shipped |
| llama.swift 2.8832.0+ (llama.cpp) | LLM cleanup via Gemma 4 E2B | macOS shipped — NOT on iOS v1 |
| Gemma 4 E2B IT QAT Q4_K_M GGUF | AI cleanup model | macOS only — NOT on iOS v1 |
| Swift 6 / SwiftUI / MenuBarExtra | macOS app shell | macOS shipped |
| KeyboardShortcuts (sindresorhus) | Global hotkeys | macOS only |
| LaunchAtLogin-Modern | Login item | macOS only |
| NSPasteboard + CGEvent | Text injection at cursor | macOS only |
| GRDB 7.x | Transcription history + FTS5 | macOS shipped — share on iOS |
| Sparkle 2.x | Auto-update | macOS only |
| xcodegen | Project generation | Shared — extend project.yml |

---

## New Stack for v2.0 iOS App

### Core Technologies

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| FluidAudio | 0.13.6+ (same SPM package) | ASR inference via Parakeet TDT v3 on Neural Engine | Same SDK runs on iOS 17+. Requires `iOS 17.0+` per official docs (Context7 + CLAUDE.md). The same `AsrManager` + `AsrModels.downloadAndLoad(version: .v3)` API works unchanged on iOS. CoreML model compiles to ANE; same ~190–210x realtime performance as macOS. No code changes to FluidAudio integration logic. |
| Swift 6 / SwiftUI | iOS 18 target | iOS app UI | Same language as macOS target. UIKit not needed — SwiftUI covers all required UI patterns: onboarding, model download progress, Shortcut feedback screen. |
| App Intents framework | iOS 16+ (AppShortcutsProvider), iOS 17+ recommended | Shortcut/Action Button/Siri activation | Apple's first-party Swift framework for surfacing app actions in Shortcuts, Siri, and the Action Button (iPhone 15 Pro+). Use `AppIntent` + `AppShortcutsProvider`. No third-party dependency. `openAppWhenRun = true` brings app to foreground before microphone starts — required because AVAudioSession cannot record from a background-launched intent. |
| AVFoundation / AVAudioSession | iOS built-in | Audio capture on iOS | Same framework as macOS but with iOS-specific session categories. Set `.record` category and `.default` mode before starting `AVAudioEngine` tap. `NSMicrophoneUsageDescription` required in Info.plist. No background recording mode needed — the App Intent brings the app foreground via `openAppWhenRun`. |
| UIPasteboard | iOS built-in | Text output to clipboard | Standard iOS clipboard API: `UIPasteboard.general.string = transcribedText`. The Shortcut's output can also be returned as a `String` result from the `AppIntent.perform()` method, enabling "paste" automation in Shortcuts without manual clipboard step. Both paths needed: clipboard for Action Button activation, result value for Shortcuts automation. |
| URLSession (background configuration) | iOS built-in | First-launch Parakeet model download | Parakeet TDT v3 CoreML package is **2.69 GB** (verified from HuggingFace repo: multiple `.mlmodelc` bundles). FluidAudio's `AsrModels.downloadAndLoad(version: .v3)` handles download + compile internally, caching to `~/Library/Application Support/FluidAudio/Models/`. Use a foreground download with progress UI on first launch — background URLSession is optional but enables resumable downloads if the user leaves the app. |
| App Groups entitlement | iOS entitlement (Xcode capability) | Shared model storage for future keyboard extension | Set up `group.com.dicticus.app` now so the future keyboard extension (v2.1) can access models downloaded by the main app. The App Groups container is at `FileManager.default.containerURL(forSecurityApplicationGroupIdentifier:)`. FluidAudio supports custom cache directories via `AsrModels.downloadAndLoad(to: customDir, version: .v3)` — point `to:` at the App Groups container so models don't need re-downloading when the keyboard extension is added. |

### Supporting Libraries

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| GRDB.swift | 7.x (same as macOS) | Transcription history on iOS | The `HistoryService` and `DictionaryService` should be extracted to `Shared/` and linked into the iOS target. GRDB is pure Swift and cross-platform with no platform-specific dependencies. Database file goes in the App Groups container (`group.com.dicticus.app`) so it's accessible to the future keyboard extension. |
| NaturalLanguage | iOS built-in | Post-hoc language detection (de/en) | Same usage as macOS `TranscriptionService` — `NLLanguageRecognizer` identifies de/en after transcription for metadata labeling. Already used on macOS; just include it in the iOS target. |

### Development Tools

| Tool | Purpose | Notes |
|------|---------|-------|
| xcodegen | Add iOS target to existing `project.yml` | The macOS `project.yml` already exists. Add an `iOS` target block with `platform: iOS`, `deploymentTarget: "17.0"`, FluidAudio + GRDB dependencies. Do NOT add KeyboardShortcuts, LaunchAtLogin, or Sparkle to the iOS target. |
| TestFlight | iOS beta distribution | Standard Apple workflow: Archive → App Store Connect → TestFlight. Requires Apple Distribution certificate + App Store provisioning profile. The same Apple Developer Program account used for macOS signing covers iOS. |
| Instruments / Xcode Memory Graph | Model memory profiling on device | Parakeet TDT v3 uses ~66 MB at inference per the FluidAudio benchmark. On an iPhone with 6–8 GB RAM, this is fine. Verify on device before release. |

---

## iOS-Specific Architecture Decisions

### App Intent Design: `openAppWhenRun = true` is Mandatory

AVAudioSession microphone recording requires the app to be in the foreground. An App Intent launched from a Shortcut, Action Button, or Siri runs in the background unless `openAppWhenRun` is set. The correct pattern:

```swift
import AppIntents

struct DictateIntent: AppIntent {
    static var title: LocalizedStringResource = "Dictate with Dicticus"
    static let openAppWhenRun: Bool = true  // REQUIRED — brings app foreground before mic starts

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        // App is now in foreground; AVAudioSession can start
        let text = await DictationCoordinator.shared.startDictationSession()
        UIPasteboard.general.string = text
        return .result(value: text)
    }
}

struct DicticusShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: DictateIntent(),
            phrases: ["Dictate with \(.applicationName)", "Start \(.applicationName)"],
            shortTitle: "Dictate",
            systemImageName: "mic.fill"
        )
    }
}
```

**Why `openAppWhenRun = true` not `ForegroundContinuableIntent`:** `ForegroundContinuableIntent` is for intents that *start* in the background and *may* need foreground. For dictation, foreground is always required — there is no background path. Using `openAppWhenRun` is simpler and more reliable.

### Model Download Strategy: Foreground with Progress UI

The Parakeet TDT v3 CoreML package is 2.69 GB. Strategies ranked:

1. **Recommended: In-app foreground download on first launch** — Show a dedicated onboarding screen with a `ProgressView`. Use `AsrModels.downloadAndLoad(to: appGroupsContainer, version: .v3)` which handles resumable download internally. This is what FluidAudio's own iOS example app does. No On-Demand Resources or App Store overhead.

2. **Alternative: Background URLSession** — Only necessary if users are likely to background the app during download. For a 2.69 GB file on modern LTE/WiFi, a focused 2–5 minute download is acceptable. Use background session if empirical testing shows users abandon the download.

3. **Do NOT bundle in app binary** — A 2.69 GB bundle would be rejected by App Store upload limits and makes TestFlight distribution impractical.

4. **Do NOT use On-Demand Resources (ODR)** — ODR size limits per variant are 30 GB, so technically possible, but ODR requires App Store hosting and cannot be used during TestFlight. Blocks development velocity.

**Model cache location:** Use the App Groups shared container as the custom cache directory:
```swift
let modelCacheDir = FileManager.default.containerURL(
    forSecurityApplicationGroupIdentifier: "group.com.dicticus.app"
)!.appendingPathComponent("Models")

let models = try await AsrModels.downloadAndLoad(to: modelCacheDir, version: .v3)
```
This means models downloaded once are accessible to the future keyboard extension without re-downloading.

### Shared Code Extraction to `Shared/`

Services that contain no platform-specific imports can move to `Shared/`:

| Service | Can Share? | Notes |
|---------|-----------|-------|
| `DictionaryService.swift` | Yes | Pure Swift, UserDefaults only — or migrate to App Groups UserDefaults (`UserDefaults(suiteName:)`) for keyboard extension access |
| `CleanupPrompt.swift` | Yes | Pure Swift, no imports |
| `TranscriptionResult.swift` | Yes | Pure Swift model |
| `ModifierCombo.swift` | No | macOS-only (NSEvent) |
| `TranscriptionService.swift` | No — refactor | AVFoundation is cross-platform but the class has macOS-specific logic (NSEvent, AudioSampleBuffer). Extract the FluidAudio inference part to `Shared/ASRService.swift`, keep macOS audio capture in `macOS/` |
| `HistoryService.swift` | Yes — with DB path change | Change DB path to App Groups container |
| `CleanupService.swift` | No | llama.swift is iOS-compatible but NO AI cleanup on iOS v1 — keep macOS only |
| `HotkeyManager.swift` | No | macOS KeyboardShortcuts only |
| `TextInjector.swift` | No | macOS NSPasteboard + CGEvent only |

### iOS Audio Session Configuration

```swift
// iOS audio session setup before starting AVAudioEngine
let session = AVAudioSession.sharedInstance()
try session.setCategory(.record, mode: .default, options: [])
try session.setActive(true)
// Then start AVAudioEngine tap as in macOS TranscriptionService
// The AudioSampleBuffer class and tap pattern are identical to macOS
```

**Key iOS vs macOS difference:** On macOS, `AVAudioEngine` uses the system default input without explicit session category. On iOS, you must explicitly set `.record` category and call `setActive(true)`. The engine setup and Float32 sample tap are identical.

### Universal App (iPhone + iPad): No Significant Extra Work

SwiftUI layouts automatically adapt to iPad screen sizes. The dictation flow is:
1. User taps Action Button / runs Shortcut → `DictateIntent.perform()` → app launches full-screen
2. App shows recording UI (single large view)
3. Transcription finishes → result shown + copied to clipboard
4. User taps "Done" or app dismisses

This single-view flow works identically on iPhone and iPad without `UITraitCollection` customization. Use `.navigationStack` at the root and `@Environment(\.horizontalSizeClass)` only if iPad gets a persistent history panel in a future phase.

---

## xcodegen project.yml iOS Target Addition

```yaml
# Add to existing packages section:
packages:
  FluidAudio:
    url: https://github.com/FluidInference/FluidAudio.git
    from: 0.13.6
  GRDB:
    url: https://github.com/groue/GRDB.swift.git
    from: 7.0.0
  # ... existing packages unchanged

# Add new iOS target:
targets:
  # ... existing Dicticus macOS target unchanged

  DicticusIOS:
    type: application
    platform: iOS
    deploymentTarget: "17.0"
    sources:
      - path: iOS/DicticusIOS
      - path: Shared  # Shared services extracted here
    info:
      path: iOS/DicticusIOS/Info.plist
      properties:
        CFBundleIdentifier: com.dicticus.ios
        CFBundleVersion: "1"
        CFBundleShortVersionString: "2.0.0"
        NSMicrophoneUsageDescription: "Dicticus needs microphone access to transcribe your speech. Your audio never leaves this device."
        UILaunchScreen: {}
        UISupportedInterfaceOrientations:
          - UIInterfaceOrientationPortrait
          - UIInterfaceOrientationLandscapeLeft
          - UIInterfaceOrientationLandscapeRight
    entitlements:
      path: iOS/DicticusIOS/DicticusIOS.entitlements
      properties:
        com.apple.security.application-groups:
          - group.com.dicticus.app
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.dicticus.ios
        SWIFT_VERSION: "6.0"
        IPHONEOS_DEPLOYMENT_TARGET: "17.0"
        TARGETED_DEVICE_FAMILY: "1,2"  # 1=iPhone, 2=iPad (universal)
        CODE_SIGN_STYLE: Automatic
        DEVELOPMENT_TEAM: ${DEVELOPER_TEAM_ID}
    dependencies:
      - package: FluidAudio
        product: FluidAudio
      - package: GRDB
        product: GRDB
    # NO: KeyboardShortcuts, LaunchAtLogin, llama, Sparkle
```

---

## What NOT to Add to iOS v1

| Do Not Add | Why | What to Use Instead |
|------------|-----|---------------------|
| llama.swift / llama.cpp | AI cleanup is explicitly out of scope for iOS v1. ~3.1 GB model is too large for typical iOS device usage; no keyboard extension can run LLM anyway. | Defer to iOS v2 milestone. |
| Sparkle | macOS-only updater framework. iOS updates via App Store / TestFlight. | TestFlight automatic updates |
| KeyboardShortcuts (sindresorhus) | macOS `NSEvent`-based global hotkeys. No iOS equivalent. | App Intents AppShortcutsProvider |
| LaunchAtLogin-Modern | macOS login item only. | Not applicable |
| UIInputViewController (keyboard extension) | Cannot access microphone from within the extension process. Keyboard approach is deferred to v2.1 with main-app bounce architecture. | App Intent + `openAppWhenRun = true` |
| SFSpeechRecognizer (Apple built-in ASR) | Poor German offline quality, no de/en auto-detection, requires permission prompt every session. | FluidAudio + Parakeet TDT v3 |
| Whisper / WhisperKit | 5–10x slower than Parakeet on ANE, ~8x more memory. Superseded by FluidAudio. | FluidAudio |
| On-Demand Resources (ODR) | Blocked during TestFlight, requires App Store review for model updates. | In-app URLSession foreground download |
| Bundled CoreML model in app binary | 2.69 GB exceeds practical App Store binary size for TestFlight and initial deployment. | Download on first launch |

---

## Alternatives Considered

| Recommended | Alternative | Why Not |
|-------------|-------------|---------|
| App Intents (AppShortcutsProvider) | SiriKit Intents (deprecated) | SiriKit requires a separate extension process; App Intents runs in-process in the main app and is Swift-native. App Intents is the modern replacement (iOS 16+, actively enhanced at WWDC 2025). |
| `openAppWhenRun = true` | `ForegroundContinuableIntent` | `ForegroundContinuableIntent` is for intents that can partially run in background and optionally escalate. Dictation always requires foreground (mic). `openAppWhenRun` is the right primitive — simpler, no escalation path to maintain. |
| In-app foreground download (first launch) | On-Demand Resources | ODR is blocked during TestFlight, requires App Store, and adds App Store Connect asset management overhead. In-app download with progress UI is simpler and faster to ship. |
| App Groups shared container for models | Per-target `applicationSupportDirectory` | Setting up App Groups now costs nothing but enables the future keyboard extension to access downloaded models without re-downloading. The 2.69 GB model must not be downloaded twice. |
| FluidAudio `AsrModels.downloadAndLoad(to:)` custom path | FluidAudio default cache path | Default cache is `~/Library/Application Support/FluidAudio/Models/` which is NOT in the App Groups container. Point the custom `to:` parameter at the App Groups container so future keyboard extension can access the model. |
| GRDB (shared from macOS target) | CoreData / SwiftData | Same reasoning as macOS: no FTS5, no direct SQLite control. The shared `HistoryService` must use the same schema as macOS for potential future Mac ↔ iOS sync. |
| SwiftUI universal app | Separate iPhone/iPad targets | A single universal target with `TARGETED_DEVICE_FAMILY: "1,2"` is idiomatic Apple development. The dictation UI is simple enough to work at both sizes without divergent codebases. |

---

## Version Compatibility

| Package | iOS Min | Swift | Notes |
|---------|---------|-------|-------|
| FluidAudio 0.13.6+ | iOS 17.0 | Swift 5.9+ (Swift 6 ready) | Confirmed via Context7 + FluidAudio CLAUDE.md + HuggingFace model card. ANE support requires Apple Silicon; A12+ chips qualify (iPhone XS+, which all run iOS 17). |
| App Intents framework | iOS 16+ | Swift 5.7+ | AppShortcutsProvider requires iOS 16. Action Button integration requires iOS 17 (iPhone 15 Pro hardware). Targeting iOS 17 as minimum covers both. |
| UIPasteboard | iOS 3+ | Any | Stable API. `UIPasteboard.general.string = text` is the idiomatic approach. |
| AVFoundation / AVAudioSession | iOS 7+ | Any | `.record` category available since iOS 3. `AVAudioEngine` since iOS 8. No version concerns at iOS 17 target. |
| GRDB 7.x | iOS 13+ | Swift 5.7+ | No iOS-specific concerns. Pure Swift. Same SPM package as macOS. |
| NaturalLanguage | iOS 12+ | Any | `NLLanguageRecognizer` available since iOS 12. No concerns at iOS 17 target. |

---

## Sources

- FluidAudio iOS platform requirements: Context7 `/fluidinference/fluidaudio` — "iOS 17.0+ / macOS 14.0+" (HIGH confidence, sourced from FluidAudio CLAUDE.md and official docs)
- FluidAudio iOS ASR example: https://github.com/FluidInference/FluidAudio/blob/main/Documentation/ASR/TDT-CTC-110M.md (HIGH confidence — official repo)
- FluidAudio manual model loading: https://github.com/FluidInference/FluidAudio/blob/main/Documentation/ASR/ManualModelLoading.md (HIGH confidence — official repo)
- Parakeet TDT v3 CoreML model size (2.69 GB): https://huggingface.co/FluidInference/parakeet-tdt-0.6b-v3-coreml/tree/main (HIGH confidence — verified from HuggingFace file listing)
- App Intents framework introduction (iOS 16): https://developer.apple.com/documentation/appintents (HIGH confidence)
- App Shortcuts / AppShortcutsProvider: https://developer.apple.com/documentation/appintents/app-shortcuts (HIGH confidence)
- Action Button App Intents integration: https://developer.apple.com/documentation/appintents/actionbutton (HIGH confidence — requires iOS 17 hardware iPhone 15 Pro+)
- openAppWhenRun developer forum: https://developer.apple.com/forums/thread/723623 (MEDIUM confidence — community + Apple engineer response)
- ForegroundContinuableIntent: https://developer.apple.com/documentation/appintents/foregroundcontinuableintent (HIGH confidence — official docs)
- App Groups configuration: https://developer.apple.com/documentation/Xcode/configuring-app-groups (HIGH confidence — official Xcode docs)
- UIPasteboard: https://developer.apple.com/documentation/uikit/uipasteboard/ (HIGH confidence)
- FluidAudio custom cache directory: Context7 `/fluidinference/fluidaudio` — `downloadAndLoad(to: cacheDir, version: .v3)` (HIGH confidence — from official repo documentation)
- FluidAudio model default cache location: Context7 `/fluidinference/fluidaudio` — `~/Library/Application Support/FluidAudio/Models/` (HIGH confidence — from official repo)

---

*Stack research for: iOS dictation app — Dicticus v2.0*
*Researched: 2026-04-21*
