# Phase 1: Foundation & App Shell - Research

**Researched:** 2026-04-14
**Domain:** macOS SwiftUI menu bar app, permissions APIs, ML model warm-up, unsigned distribution
**Confidence:** HIGH

## Summary

Phase 1 delivers a macOS menu bar app shell using SwiftUI's `MenuBarExtra` API (macOS 13+) with three primary capabilities: (1) menu bar presence with no dock icon via `LSUIElement`, (2) first-run permissions onboarding for Microphone, Accessibility, and Input Monitoring with direct System Settings links, and (3) background ML model warm-up infrastructure using WhisperKit's CoreML compilation. The app targets macOS 15 (Sequoia) with Swift 6 and is distributed outside the App Store as an unsigned DMG requiring Hardened Runtime and notarization via `notarytool`.

The development environment has Xcode 26.4, Swift 6.3, and macOS 26.4.1 installed. No code signing identities exist yet -- the developer will need an Apple Developer account ($99/year) for notarization, but development and testing work without one. WhisperKit v0.18.0 is the current release with macOS 13+ support via SPM. The whisper.cpp SPM wrapper (whisper.spm) is being archived; WhisperKit is the correct path for macOS CoreML-accelerated ASR.

**Primary recommendation:** Use WhisperKit v0.18.0 via SPM for model warm-up infrastructure. Use `.menuBarExtraStyle(.window)` for the dropdown to support custom permission onboarding UI. Defer notarization/DMG to Phase 5 (already planned) -- Phase 1 runs from Xcode during development.

<user_constraints>

## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Sequential per-permission prompts -- guide user through Microphone, Accessibility, and Input Monitoring permissions one at a time with direct links to System Settings panes
- **D-02:** If user denies a permission, show degraded state indicator in the menu bar dropdown with a re-prompt option -- non-blocking, user can grant permissions later from the menu
- **D-03:** Model warm-up starts immediately at app launch in background (matches INFRA-03 requirement) -- no delay until first hotkey press
- **D-04:** Progress shown via menu bar icon animation (e.g., pulsing or loading indicator) plus status text in the dropdown menu -- no splash screen, no modal, non-intrusive
- **D-05:** Menu bar dropdown in Phase 1 shows: permission status indicators, model warm-up status, and Quit -- minimal for foundation phase; settings and mode controls come in later phases
- **D-06:** Menu bar icon uses SF Symbol monochrome template image -- native macOS appearance, adapts to light/dark mode automatically
- **D-07:** Single app target with Swift Package Manager for dependencies -- simplest approach for a menu bar app; helpers/extensions can be added in later phases if needed
- **D-08:** whisper.cpp and llama.cpp integrated via SPM with C library wrappers -- clean dependency management, avoids manual framework embedding

### Claude's Discretion
- Xcode project naming and bundle identifier conventions
- Specific SF Symbol choice for menu bar icon
- Internal module/file organization within the single target
- Entitlements plist configuration details

### Deferred Ideas (OUT OF SCOPE)
None -- discussion stayed within phase scope

</user_constraints>

<phase_requirements>

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| APP-01 | Menu bar app with minimal UI (no main window) | SwiftUI `MenuBarExtra` with `LSUIElement = YES` -- verified pattern, multiple tutorials confirm |
| APP-02 | First-run onboarding guides user through Microphone and Accessibility permissions | `AVCaptureDevice.requestAccess`, `AXIsProcessTrustedWithOptions`, `CGPreflightListenEventAccess` APIs documented with System Settings URL schemes |
| INFRA-03 | Core ML warm-up happens in background at launch (not on first hotkey press) | WhisperKit `init()` triggers CoreML compilation; wrap in background `Task` at app launch |
| INFRA-05 | App distributed as unsigned/notarized DMG (not App Store -- sandbox incompatible) | Hardened Runtime + `notarytool` + `stapler` workflow documented; requires Apple Developer account; DMG creation via `hdiutil` or `create-dmg` |

</phase_requirements>

## Critical Clarification: ASR Engine for macOS

There is a contradiction in project documents that must be resolved before planning:

- **CLAUDE.md stack table** lists `whisper.cpp` as macOS ASR engine and `WhisperKit` as iOS-only [VERIFIED: CLAUDE.md]
- **STATE.md** says "WhisperKit for macOS ASR with Core ML warm-up at launch" [VERIFIED: STATE.md]
- **CONTEXT.md D-08** says "whisper.cpp and llama.cpp integrated via SPM" [VERIFIED: CONTEXT.md]
- **INFRA-03** requirement says "Core ML warm-up" which is a WhisperKit concept (whisper.cpp uses GGML, not CoreML) [VERIFIED: WhisperKit docs]

**Research recommendation:** Use **WhisperKit** for macOS ASR. Rationale:
1. WhisperKit provides native Swift API with SPM integration -- no C bridging needed [VERIFIED: GitHub argmaxinc/WhisperKit]
2. WhisperKit uses CoreML which leverages Apple Neural Engine -- matches the "Core ML warm-up" requirement [VERIFIED: WhisperKit README]
3. whisper.spm (the SPM wrapper for whisper.cpp) is being archived with a notice to "use the Swift package directly from whisper.cpp" -- but whisper.cpp has no native Package.swift [VERIFIED: whisper.spm README, whisper.cpp repo]
4. WhisperKit v0.18.0 supports macOS 13+ and includes the `large-v3-turbo` model [VERIFIED: Package.swift, GitHub releases]

**D-08 compatibility:** llama.cpp still needs SPM integration for Phase 4. The ggml-org/llama.cpp package exists on Swift Package Index (macOS 12+) but has known Objective-C++ compilation issues. This is a Phase 4 concern, not Phase 1. For Phase 1, only WhisperKit warm-up is needed.

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Swift + SwiftUI | Swift 6.3 / macOS 15 target | App shell, UI | Native, zero overhead, MenuBarExtra API built-in [VERIFIED: Xcode 26.4 installed] |
| WhisperKit | v0.18.0 | ASR model warm-up (CoreML compilation) | Swift-native, SPM, CoreML Neural Engine acceleration, macOS 13+ [VERIFIED: GitHub releases 2026-04-01] |
| XCTest | Built-in | Unit and UI testing | Xcode-integrated, standard for Swift projects [VERIFIED: Apple docs] |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| AVFoundation | Built-in | Microphone permission check | `AVCaptureDevice.authorizationStatus(for: .audio)` [VERIFIED: Apple docs] |
| ApplicationServices | Built-in | Accessibility permission check | `AXIsProcessTrusted()`, `AXIsProcessTrustedWithOptions()` [VERIFIED: Apple docs] |
| IOKit | Built-in | Input Monitoring permission check | `IOHIDCheckAccess(kIOHIDRequestTypeListenEvent)` [CITED: trycatchdebug.net] |
| CoreGraphics | Built-in | Input Monitoring permission check (alternative) | `CGPreflightListenEventAccess()`, `CGRequestListenEventAccess()` [CITED: developer.apple.com forums] |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| WhisperKit | whisper.cpp via SwiftWhisper | SwiftWhisper wraps whisper.cpp C API; no CoreML acceleration, needs GGML models instead of CoreML, more manual memory management [VERIFIED: SwiftWhisper docs] |
| WhisperKit | Apple SpeechAnalyzer | Requires macOS 26+, only 10 languages, too new/bleeding edge [VERIFIED: argmaxinc.com/blog] |
| MenuBarExtra `.window` | MenuBarExtra `.menu` | `.menu` style only supports standard menu items (Button, Toggle, Divider); cannot do custom permission rows with badges [VERIFIED: Apple docs] |

**SPM dependency (Phase 1 only):**
```swift
// Package.swift or Xcode > File > Add Package Dependencies
dependencies: [
    .package(url: "https://github.com/argmaxinc/WhisperKit.git", from: "0.18.0"),
]
```

Target dependency:
```swift
.product(name: "WhisperKit", package: "WhisperKit")
```

Note: The WhisperKit repo redirects to `argmax-oss-swift` internally but the `WhisperKit` URL still works for SPM resolution. [VERIFIED: GitHub API shows Package.swift at argmax-oss-swift]

## Architecture Patterns

### Recommended Project Structure
```
Dicticus/
├── Dicticus.xcodeproj/           # Xcode project
├── Dicticus/
│   ├── DicticusApp.swift          # @main App struct with MenuBarExtra
│   ├── Info.plist                 # LSUIElement, usage descriptions
│   ├── Dicticus.entitlements      # Hardened Runtime entitlements
│   ├── Assets.xcassets/           # App icon (menu bar uses SF Symbol)
│   ├── Views/
│   │   ├── MenuBarView.swift      # Main dropdown content view
│   │   ├── PermissionRow.swift    # Reusable permission status row
│   │   └── OnboardingView.swift   # First-launch sequential permission flow
│   ├── Services/
│   │   ├── PermissionManager.swift    # ObservableObject for all permission checks
│   │   └── ModelWarmupService.swift   # WhisperKit initialization + progress
│   └── Utilities/
│       └── SystemSettingsURLs.swift   # URL constants for System Settings panes
└── DicticusTests/
    ├── PermissionManagerTests.swift
    └── ModelWarmupServiceTests.swift
```
[ASSUMED -- based on standard SwiftUI app patterns]

### Pattern 1: MenuBarExtra App Entry Point
**What:** SwiftUI App struct with MenuBarExtra scene and no WindowGroup
**When to use:** Menu bar-only apps with no main window
**Example:**
```swift
// Source: Apple Developer Documentation + nilcoalescing.com tutorial
import SwiftUI

@main
struct DicticusApp: App {
    @StateObject private var permissionManager = PermissionManager()
    @StateObject private var warmupService = ModelWarmupService()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(permissionManager)
                .environmentObject(warmupService)
        } label: {
            // SF Symbol adapts to menu bar automatically
            Image(systemName: warmupService.isReady ? "mic" : "mic.badge.xmark")
                .symbolEffect(.pulse, isActive: warmupService.isWarming)
        }
        .menuBarExtraStyle(.window)
    }
}
```
[VERIFIED: MenuBarExtra API from Apple docs, `.symbolEffect(.pulse)` available macOS 14+]

### Pattern 2: Permission Checking with Polling
**What:** ObservableObject that checks permissions and polls for changes
**When to use:** Permissions granted outside the app (user goes to System Settings manually)
**Example:**
```swift
// Source: jano.dev/apple/macos/swift/2025/01/08/Accessibility-Permission.html
import AVFoundation
import ApplicationServices

@MainActor
class PermissionManager: ObservableObject {
    @Published var microphoneGranted = false
    @Published var accessibilityGranted = false
    @Published var inputMonitoringGranted = false

    private var pollTimer: Timer?

    func checkAll() {
        microphoneGranted = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        accessibilityGranted = AXIsProcessTrusted()
        inputMonitoringGranted = CGPreflightListenEventAccess()
    }

    func requestMicrophone() async -> Bool {
        return await AVCaptureDevice.requestAccess(for: .audio)
    }

    func requestAccessibility() {
        let options: NSDictionary = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true
        ]
        AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    func requestInputMonitoring() -> Bool {
        return CGRequestListenEventAccess()
    }

    func startPolling() {
        pollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkAll()
            }
        }
    }

    func stopPolling() {
        pollTimer?.invalidate()
    }
}
```
[VERIFIED: AVCaptureDevice API from Apple docs; AXIsProcessTrusted from ApplicationServices; CGPreflightListenEventAccess from CoreGraphics]

### Pattern 3: System Settings Deep Links
**What:** URL scheme to open specific Privacy & Security panes
**When to use:** "Grant Access" / "Open Settings" buttons
**Example:**
```swift
// Source: gist.github.com/dagronf + multiple community sources
enum SystemSettingsURL {
    static let microphone = URL(string:
        "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!
    static let accessibility = URL(string:
        "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
    static let inputMonitoring = URL(string:
        "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")!

    static func open(_ url: URL) {
        NSWorkspace.shared.open(url)
    }
}
```
[CITED: Multiple community sources; URL scheme is undocumented by Apple but widely used and stable since macOS 13]

### Pattern 4: Background Model Warm-up
**What:** WhisperKit initialization in a detached Task at app launch
**When to use:** INFRA-03 -- warm up CoreML models immediately
**Example:**
```swift
// Source: helrabelo.dev/blog/whisperkit-on-macos + WhisperKit README
import WhisperKit

@MainActor
class ModelWarmupService: ObservableObject {
    @Published var isWarming = false
    @Published var isReady = false
    @Published var error: String?

    private var whisperKit: WhisperKit?

    func warmup() {
        isWarming = true
        Task.detached(priority: .utility) { [weak self] in
            do {
                // WhisperKit downloads + compiles CoreML model on first run
                // This can take several minutes on first launch
                let pipe = try await WhisperKit(
                    WhisperKitConfig(model: "large-v3-turbo")
                )
                await MainActor.run {
                    self?.whisperKit = pipe
                    self?.isWarming = false
                    self?.isReady = true
                }
            } catch {
                await MainActor.run {
                    self?.isWarming = false
                    self?.error = "Model load failed. Restart app."
                }
            }
        }
    }
}
```
[VERIFIED: WhisperKit init API from README; CoreML compilation timing from helrabelo.dev blog]

### Anti-Patterns to Avoid
- **Using `.menu` style for complex UI:** The `.menu` style only supports Button, Toggle, Divider, and nested Menu items. It cannot render ProgressView, custom badges, or multi-element rows. Use `.window` style for the dropdown. [VERIFIED: Apple docs MenuBarExtraStyle]
- **Blocking main thread during model load:** WhisperKit CoreML compilation takes 1-10+ seconds depending on model size. Always use `Task.detached(priority: .utility)` for warm-up. [VERIFIED: helrabelo.dev benchmarks]
- **Calling `openSettings()` from MenuBarExtra:** The SwiftUI `openSettings()` environment action does not work reliably in menu bar apps due to activation policy issues. Use `NSWorkspace.shared.open()` with URL schemes instead. [VERIFIED: steipete.me/posts/2025]
- **Assuming permissions persist across app restarts without re-checking:** macOS users can revoke permissions at any time in System Settings. Always check on launch and poll. [ASSUMED]
- **Using `SettingsLink` in menu bar apps:** Broken since Sonoma for `.accessory` policy apps. Use manual URL scheme approach or `NSApp.sendAction` workaround. [VERIFIED: steipete.me/posts/2025]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| CoreML ASR model management | Custom model download + CoreML compilation pipeline | WhisperKit | Handles model download from HuggingFace, CoreML compilation, memory management, model caching automatically [VERIFIED: WhisperKit README] |
| Menu bar icon with system appearance | Custom NSImage rendering | SF Symbols via `Image(systemName:)` | Automatically adapts to light/dark mode, menu bar tinting, accessibility settings [VERIFIED: Apple HIG] |
| Permission status polling | Manual NSDistributedNotificationCenter observers | Timer-based polling with 2s interval | macOS does not broadcast permission change notifications; polling is the standard approach used by Rectangle, Dato, etc. [CITED: community patterns] |
| DMG creation | Manual `hdiutil` scripting | `create-dmg` (sindresorhus) or Xcode archive | Handles background layout, code signing, retina icons automatically [VERIFIED: GitHub create-dmg] |

**Key insight:** WhisperKit abstracts the entire CoreML compilation lifecycle. Hand-rolling CoreML model compilation with raw `MLModel.compileModel(at:)` calls means managing model download, format conversion, compilation caching, memory cleanup, and error recovery -- all of which WhisperKit handles.

## Common Pitfalls

### Pitfall 1: MenuBarExtra Window Dismissal
**What goes wrong:** The dropdown window created by `.menuBarExtraStyle(.window)` does not auto-dismiss when the user clicks outside it on some macOS versions.
**Why it happens:** SwiftUI MenuBarExtra window management has inconsistent behavior across macOS 13/14/15.
**How to avoid:** Test dismissal behavior on the target macOS version. Consider using `NSPanel` with `.nonactivating` style if SwiftUI behavior is unreliable.
**Warning signs:** Users report dropdown staying open after clicking elsewhere.
[CITED: cindori.com/developer/hands-on-menu-bar, steipete.me/posts/2025]

### Pitfall 2: First-Launch CoreML Compilation Takes Minutes
**What goes wrong:** Users see the app as "stuck" on first launch because CoreML model compilation for large-v3-turbo can take 2-10+ minutes.
**Why it happens:** CoreML compiles the neural network graph for the specific hardware (Neural Engine, GPU, CPU) on first run. Subsequent launches use cached compilation.
**How to avoid:** Show clear "Preparing models..." text with indeterminate progress. The UI spec already covers this (D-04). Consider showing estimated time or a "this only happens once" message.
**Warning signs:** No visual feedback during compilation; app appears frozen.
[VERIFIED: helrabelo.dev benchmarks show 8-10s for large model on M1; first-run CoreML compilation adds significant additional time]

### Pitfall 3: Accessibility Permission Requires App Restart
**What goes wrong:** After granting Accessibility permission in System Settings, the app still reports `AXIsProcessTrusted() == false`.
**Why it happens:** macOS caches the TCC (Transparency, Consent, and Control) database state per-process. Some permission grants require the app to be restarted to take effect.
**How to avoid:** Poll with `AXIsProcessTrusted()` every 2 seconds. If the value changes from false to true, it worked without restart. If it remains false after the user claims to have granted it, suggest restarting the app.
**Warning signs:** Permission shows as granted in System Settings but app still shows "Denied."
[CITED: developer.apple.com/forums/thread/794253]

### Pitfall 4: No Code Signing Identity Available
**What goes wrong:** `notarytool` and code signing fail because no Developer ID certificate exists.
**Why it happens:** The development machine has 0 valid signing identities (verified). An Apple Developer Program membership ($99/year) is required for Developer ID certificates.
**How to avoid:** For Phase 1 development, run directly from Xcode (automatic signing with personal team). Defer notarization and DMG creation to Phase 5. Document this dependency.
**Warning signs:** `security find-identity -v -p codesigning` returns 0 identities.
[VERIFIED: local environment check shows 0 valid identities]

### Pitfall 5: LSUIElement Hides Settings Windows
**What goes wrong:** When `LSUIElement = YES`, any settings or secondary windows opened from the menu bar app appear behind other windows or don't receive focus.
**Why it happens:** Agent apps (LSUIElement) use `NSApplication.ActivationPolicy.accessory`, which doesn't participate in normal window management.
**How to avoid:** Temporarily switch to `.regular` activation policy when showing a window, then switch back to `.accessory` when it closes. Use `NSApp.activate(ignoringOtherApps: true)` before presenting.
**Warning signs:** Windows open but are invisible to the user.
[VERIFIED: steipete.me/posts/2025/showing-settings-from-macos-menu-bar-items]

### Pitfall 6: WhisperKit Model Download Requires Internet
**What goes wrong:** WhisperKit automatically downloads models from HuggingFace on first initialization. If offline, initialization fails.
**Why it happens:** Models are not bundled with the app binary (large-v3-turbo is ~626 MB).
**How to avoid:** Handle download failure gracefully with a "No internet -- model download required" error message. Consider pre-downloading the model during a setup step or bundling a smaller fallback model.
**Warning signs:** WhisperKit init throws on first launch with no network.
[VERIFIED: WhisperKit README -- models download on-demand from HuggingFace]

## Code Examples

### Info.plist Configuration
```xml
<!-- Source: Apple Developer Documentation -->
<key>LSUIElement</key>
<true/>
<key>NSMicrophoneUsageDescription</key>
<string>Dicticus needs microphone access to transcribe your speech. Your audio never leaves this device.</string>
```
[VERIFIED: Apple docs for LSUIElement and NSMicrophoneUsageDescription]

### Entitlements Configuration
```xml
<!-- Source: Apple Developer Documentation -->
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- Hardened Runtime is required for notarization -->
    <key>com.apple.security.app-sandbox</key>
    <false/>
    <!-- Required for microphone access -->
    <key>com.apple.security.device.audio-input</key>
    <true/>
</dict>
</plist>
```
[VERIFIED: Apple docs -- unsandboxed apps disable sandbox but enable hardened runtime; audio-input entitlement needed for microphone]

### Menu Bar Icon with Animated Warm-up State
```swift
// Source: Apple Developer Documentation (SF Symbols + symbolEffect)
// Requires macOS 14+ for .symbolEffect
MenuBarExtra {
    MenuBarView()
} label: {
    Image(systemName: iconName)
        .symbolEffect(.pulse, isActive: isWarming)
}

// Computed property for icon state:
var iconName: String {
    if !permissionManager.allGranted {
        return "mic.slash"       // Degraded: missing permissions
    } else if warmupService.isWarming {
        return "mic"             // Warming up (pulse animation active)
    } else {
        return "mic"             // Ready
    }
}
```
[VERIFIED: `.symbolEffect(.pulse)` available in macOS 14+ via Apple docs]

### Permission Row Component
```swift
// Source: UI-SPEC.md interaction states
struct PermissionRow: View {
    let title: String
    let status: PermissionStatus
    let action: () -> Void
    let settingsURL: URL

    var body: some View {
        HStack {
            Image(systemName: status.iconName)
                .foregroundColor(status.color)
            Text(title)
                .font(.body)
            Spacer()
            Text(status.label)
                .font(.caption)
                .foregroundColor(.secondary)
            if status != .granted {
                Button(status == .denied ? "Open Settings" : "Grant Access") {
                    if status == .denied {
                        NSWorkspace.shared.open(settingsURL)
                    } else {
                        action()
                    }
                }
                .controlSize(.small)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
    }
}

enum PermissionStatus {
    case granted, pending, denied

    var iconName: String {
        switch self {
        case .granted: return "checkmark.circle.fill"
        case .pending: return "clock"
        case .denied: return "xmark.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .granted: return .green
        case .pending: return .secondary
        case .denied: return .red
        }
    }

    var label: String {
        switch self {
        case .granted: return "Granted"
        case .pending: return "Required"
        case .denied: return "Denied"
        }
    }
}
```
[ASSUMED -- based on UI-SPEC.md contract and standard SwiftUI patterns]

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| NSStatusBar + NSMenu | SwiftUI MenuBarExtra | macOS 13 (2022) | Fully declarative menu bar apps in SwiftUI |
| whisper.spm (SPM wrapper) | WhisperKit (native Swift) | 2024 | whisper.spm is being archived; WhisperKit provides cleaner Swift API |
| `showSettingsWindow:` (private API) | `openSettings()` environment action | macOS 13 | But openSettings is broken in menu bar apps -- use NSWorkspace URL scheme |
| altool (notarization) | notarytool (notarization) | November 2023 | altool no longer accepted by Apple; must use notarytool or Xcode 14+ |
| Apple SFSpeechRecognizer | WhisperKit / Apple SpeechAnalyzer | 2024-2025 | WhisperKit offers better multilingual quality; SpeechAnalyzer (macOS 26+) is too new |

**Deprecated/outdated:**
- `whisper.spm`: Repository will be archived; use WhisperKit or whisper.cpp directly [VERIFIED: whisper.spm README]
- `altool` for notarization: No longer accepted since November 2023 [VERIFIED: Apple docs]
- `showSettingsWindow:` selector: Stopped working in Sonoma [VERIFIED: steipete.me]
- Stanford BDHG llama.cpp fork: Last release May 2024 (0.3.3), likely stale [VERIFIED: GitHub releases]

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Project structure with Views/Services/Utilities organization | Architecture Patterns | Low -- restructuring is trivial in early project |
| A2 | Permission status polling every 2 seconds is sufficient | Architecture Patterns | Low -- can adjust interval; no known notification API exists |
| A3 | macOS does not broadcast permission change notifications requiring polling | Don't Hand-Roll | Medium -- if notifications exist, polling wastes CPU |
| A4 | `x-apple.systempreferences:` URL scheme for Input Monitoring uses `Privacy_ListenEvent` anchor | Code Examples | Medium -- undocumented scheme could change between macOS versions |
| A5 | WhisperKit `large-v3-turbo` model identifier works as `"large-v3-turbo"` in WhisperKitConfig | Code Examples | Medium -- model identifier format may differ; verify against WhisperKit model list |
| A6 | `.symbolEffect(.pulse)` works on template images in menu bar | Code Examples | Medium -- may need fallback for menu bar rendering context |

## Open Questions

1. **WhisperKit vs whisper.cpp for macOS ASR**
   - What we know: STATE.md says WhisperKit; CLAUDE.md stack table says whisper.cpp; CONTEXT.md D-08 says whisper.cpp SPM
   - What's unclear: Which is the definitive decision for macOS ASR
   - Recommendation: Use WhisperKit -- it matches the "Core ML warm-up" requirement (INFRA-03) and provides native Swift API. Flag to user for confirmation before Phase 2 implementation.

2. **Apple Developer Account for Notarization**
   - What we know: 0 code signing identities on machine; notarization requires Developer ID certificate ($99/year Apple Developer Program)
   - What's unclear: Whether user has or plans to get an Apple Developer account
   - Recommendation: Phase 1 runs from Xcode (personal team signing). INFRA-05 (DMG distribution) is listed as Phase 1 requirement but Phase 5 also covers DMG packaging. Recommend treating INFRA-05 as "establish entitlements and project configuration for unsigned distribution" in Phase 1, with actual DMG packaging in Phase 5.

3. **WhisperKit Model Identifier for large-v3-turbo**
   - What we know: WhisperKit README shows model format like `"large-v3-v20240930_626MB"`
   - What's unclear: Exact identifier string for large-v3-turbo GGML-equivalent in WhisperKit's CoreML model catalog
   - Recommendation: Use WhisperKit's auto-recommendation (`WhisperKit()` with no model specified) for Phase 1 warm-up; specify exact model in Phase 2 when ASR pipeline is built

4. **First-Launch Model Download Size and Duration**
   - What we know: large-v3-turbo is ~626 MB as CoreML model; download + CoreML compilation on first launch
   - What's unclear: Total first-launch time (download + compilation) on typical connection
   - Recommendation: Show download progress separately from compilation progress; handle offline case

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Xcode | Build system, project creation | Yes | 26.4 | -- |
| Swift | Language | Yes | 6.3 | -- |
| macOS (development) | Runtime | Yes | 26.4.1 | Target macOS 15 for deployment |
| hdiutil | DMG creation | Yes | built-in | -- |
| notarytool | Notarization | Yes | 1.1.1 (40) via xcrun | -- |
| Code signing identity | Notarization, distribution | No | -- | Develop with personal team; acquire Developer ID before Phase 5 |
| create-dmg | Automated DMG creation | No | -- | Use hdiutil directly or install via `brew install create-dmg` or `npm install -g create-dmg` |
| whisper.cpp (Homebrew) | Not needed in Phase 1 | No | -- | WhisperKit handles ASR |

**Missing dependencies with no fallback:**
- Code signing identity -- blocks notarization and DMG distribution. Not needed for Phase 1 development (Xcode handles local signing), but required before Phase 5 delivery.

**Missing dependencies with fallback:**
- `create-dmg` -- not installed but `hdiutil` is available as built-in fallback. Can install later.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | XCTest (built into Xcode 26.4) |
| Config file | Xcode project test target (auto-generated) |
| Quick run command | `xcodebuild test -scheme Dicticus -destination 'platform=macOS' -only-testing DicticusTests` |
| Full suite command | `xcodebuild test -scheme Dicticus -destination 'platform=macOS'` |

### Phase Requirements to Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| APP-01 | App has MenuBarExtra scene, no WindowGroup | unit | Verify App.body contains MenuBarExtra | No -- Wave 0 |
| APP-02 | Permission check returns correct status | unit | `PermissionManagerTests` -- mock permission APIs | No -- Wave 0 |
| APP-02 | System Settings URLs are valid | unit | Test URL construction for all 3 panes | No -- Wave 0 |
| INFRA-03 | Model warm-up starts at launch and reports progress | unit | `ModelWarmupServiceTests` -- mock WhisperKit | No -- Wave 0 |
| INFRA-05 | Entitlements configured (sandbox disabled, audio-input enabled) | manual-only | Inspect entitlements file; verified by Xcode build | N/A |

### Sampling Rate
- **Per task commit:** `xcodebuild test -scheme Dicticus -destination 'platform=macOS' -only-testing DicticusTests`
- **Per wave merge:** `xcodebuild test -scheme Dicticus -destination 'platform=macOS'`
- **Phase gate:** Full suite green before `/gsd-verify-work`

### Wave 0 Gaps
- [ ] `DicticusTests/PermissionManagerTests.swift` -- covers APP-02 permission logic
- [ ] `DicticusTests/ModelWarmupServiceTests.swift` -- covers INFRA-03 warm-up lifecycle
- [ ] `DicticusTests/SystemSettingsURLTests.swift` -- covers APP-02 URL construction
- [ ] Test target creation in Xcode project -- needs to be set up during project scaffolding

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | No | N/A -- local-only app, no user accounts |
| V3 Session Management | No | N/A -- no sessions |
| V4 Access Control | Yes (limited) | macOS TCC permission model -- request only needed permissions |
| V5 Input Validation | No | No user text input in Phase 1 |
| V6 Cryptography | No | No crypto operations in Phase 1 |

### Known Threat Patterns for macOS Menu Bar App

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Over-requesting permissions | Information Disclosure | Request only Microphone, Accessibility, Input Monitoring -- minimum for functionality [VERIFIED: principle of least privilege] |
| Model download MITM | Tampering | WhisperKit downloads from HuggingFace over HTTPS; Hardened Runtime prevents library injection [VERIFIED: WhisperKit uses HTTPS] |
| Clipboard exposure (future phases) | Information Disclosure | Not applicable in Phase 1 -- clipboard handling comes in Phase 3 |
| Entitlement escalation | Elevation of Privilege | Disable sandbox (`com.apple.security.app-sandbox: false`) but enable Hardened Runtime -- standard for unsandboxed notarized apps [VERIFIED: Apple docs] |

## Sources

### Primary (HIGH confidence)
- [WhisperKit GitHub](https://github.com/argmaxinc/WhisperKit) -- v0.18.0 release, SPM setup, API usage, macOS 13+ platform support
- [WhisperKit Package.swift](https://raw.githubusercontent.com/argmaxinc/argmax-oss-swift/main/Package.swift) -- platform requirements, dependencies, Swift tools version
- [Apple MenuBarExtra docs](https://developer.apple.com/documentation/SwiftUI/MenuBarExtra) -- API reference, style options
- [Apple AVCaptureDevice docs](https://developer.apple.com/documentation/avfoundation/avcapturedevice) -- microphone permission API
- [Apple Notarization docs](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution) -- notarytool workflow
- [whisper.spm repository](https://github.com/ggerganov/whisper.spm) -- archival notice confirmed
- Local environment: Xcode 26.4, Swift 6.3, macOS 26.4.1, 0 signing identities

### Secondary (MEDIUM confidence)
- [nilcoalescing.com MenuBarExtra tutorial](https://nilcoalescing.com/blog/BuildAMacOSMenuBarUtilityInSwiftUI/) -- complete code examples for menu bar app
- [helrabelo.dev WhisperKit macOS integration](https://www.helrabelo.dev/blog/whisperkit-on-macos-integrating-on-device-ml) -- CoreML compilation benchmarks, memory usage
- [steipete.me MenuBarExtra settings pitfalls](https://steipete.me/posts/2025/showing-settings-from-macos-menu-bar-items) -- activation policy issues, SwiftUI bugs
- [jano.dev Accessibility permission](https://jano.dev/apple/macos/swift/2025/01/08/Accessibility-Permission.html) -- AXIsProcessTrusted usage
- [Argmax blog on SpeechAnalyzer](https://www.argmaxinc.com/blog/apple-and-argmax) -- Apple SpeechAnalyzer requires macOS 26+

### Tertiary (LOW confidence)
- System Settings URL schemes (`x-apple.systempreferences:`) -- undocumented by Apple, community-sourced, stable but could change
- Input Monitoring check via `CGPreflightListenEventAccess()` -- limited documentation, verified via forum posts and community usage

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- WhisperKit verified via GitHub releases and Package.swift; SwiftUI MenuBarExtra well-documented
- Architecture: HIGH -- patterns sourced from official docs and verified tutorials
- Pitfalls: HIGH -- cross-referenced from multiple developer blogs and Apple forums
- Permissions API: MEDIUM -- Microphone and Accessibility well-documented; Input Monitoring has limited official docs
- Distribution (INFRA-05): MEDIUM -- notarization workflow documented but no signing identity available yet

**Research date:** 2026-04-14
**Valid until:** 2026-05-14 (30 days -- stable APIs, WhisperKit may release minor updates)
