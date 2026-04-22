# Phase 13: App Intent + Live Activity + Core Dictation Pipeline — Pattern Map

**Mapped:** 2026-04-21
**Files analyzed:** 12 new/modified files
**Analogs found:** 10 / 12 (2 files have no codebase analog — new iOS-only patterns)

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `iOS/Dicticus/Services/IOSTranscriptionService.swift` | service | streaming + request-response | `macOS/Dicticus/Services/TranscriptionService.swift` | exact (port) |
| `iOS/Dicticus/Services/IOSModelWarmupService.swift` | service | event-driven | `macOS/Dicticus/Services/ModelWarmupService.swift` | exact (port) |
| `iOS/Dicticus/DicticusApp.swift` | provider (app root) | event-driven | `macOS/Dicticus/DicticusApp.swift` | role-match |
| `iOS/Dicticus/ContentView.swift` | component | request-response | `iOS/Dicticus/ContentView.swift` (current stub) | exact (replace) |
| `iOS/Dicticus/DictationView.swift` | component | request-response | `macOS/Dicticus/DicticusApp.swift` (MenuBarView pattern) | partial-match |
| `iOS/Dicticus/DictationViewModel.swift` | service (orchestrator) | event-driven | `macOS/Dicticus/Services/TranscriptionService.swift` | partial-match |
| `iOS/Dicticus/Intents/DictateIntent.swift` | controller | request-response | no analog | none |
| `iOS/Dicticus/Intents/DicticusShortcuts.swift` | config | — | no analog | none |
| `iOS/Dicticus/LiveActivity/DictationActivity.swift` | model | — | `Shared/Models/TranscriptionResult.swift` | partial-match |
| `iOS/DicticusWidget/DicticusWidgetBundle.swift` | provider (entry point) | — | `macOS/Dicticus/DicticusApp.swift` (@main pattern) | partial-match |
| `iOS/DicticusWidget/DictationLiveActivity.swift` | component | event-driven | no codebase analog | none |
| `iOS/project.yml` | config | — | `macOS/project.yml` | role-match |

---

## Pattern Assignments

### `iOS/Dicticus/Services/IOSTranscriptionService.swift` (service, streaming + request-response)

**Analog:** `macOS/Dicticus/Services/TranscriptionService.swift` — copy verbatim, then apply iOS diffs below.

**Imports pattern** (macOS lines 1–5):
```swift
import SwiftUI
import FluidAudio
@preconcurrency import AVFoundation
import NaturalLanguage
import os
```
iOS version: swap `import SwiftUI` for `import Foundation` (no SwiftUI needed in service). Keep all others identical.

**Error enum — copy verbatim** (macOS lines 8–24):
```swift
enum TranscriptionError: Error, Sendable {
    case tooShort
    case silenceOnly
    case noResult
    case modelNotReady
    case notRecording
    case busy
    case unexpectedLanguage
}
```

**AudioSampleBuffer — copy verbatim** (macOS lines 31–54):
```swift
final class AudioSampleBuffer: @unchecked Sendable {
    private var samples: [Float] = []
    private let lock = NSLock()

    func append(_ newSamples: [Float]) {
        lock.lock(); samples.append(contentsOf: newSamples); lock.unlock()
    }
    func drain() -> [Float] {
        lock.lock(); let r = samples; samples.removeAll(); lock.unlock(); return r
    }
    func clear() { lock.lock(); samples.removeAll(); lock.unlock() }
}
```

**Class header — copy verbatim, rename** (macOS lines 70–71):
```swift
@MainActor
class IOSTranscriptionService: ObservableObject {
```

**startRecording() — add AVAudioSession setup for iOS** (macOS lines 133–146 + iOS diff):
```swift
func startRecording() throws {
    guard state == .idle else { throw TranscriptionError.busy }
    sampleBuffer.clear()

    // iOS ONLY: activate AVAudioSession AFTER Live Activity is started (see DictationViewModel)
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

**nonisolated installTap — copy verbatim** (macOS lines 152–165):
```swift
nonisolated private static func installTap(
    on inputNode: AVAudioInputNode,
    format: AVAudioFormat,
    buffer: AudioSampleBuffer
) {
    inputNode.installTap(onBus: 0, bufferSize: 4096, format: format) { pcmBuffer, _ in
        if let channelData = pcmBuffer.floatChannelData?[0] {
            let frameCount = Int(pcmBuffer.frameLength)
            let samples = Array(UnsafeBufferPointer(start: channelData, count: frameCount))
            buffer.append(samples)
        }
    }
}
```

**stopRecordingAndTranscribe() — copy verbatim** (macOS lines 182–245). No changes needed — the three-layer VAD pipeline, resampling, and language detection are identical.

**Text delivery — iOS replaces NSPasteboard**:
```swift
// macOS (NOT used in iOS):
// NSPasteboard.general.setString(trimmedText, forType: .string)

// iOS (add to IOSTranscriptionService or DictationViewModel after result):
import UIKit
UIPasteboard.general.string = trimmedText
// Note: call from @MainActor context only
```

**Resampling helpers — copy verbatim** (macOS lines 257–336): `resampleAudio(_:from:to:)` and `resampleLinear(_:from:to:)` are pure Swift, no platform dependency.

**Script validation — copy verbatim** (macOS lines 343–389): `containsNonLatinScript(_:)` is pure Swift. Same Cyrillic/CJK/Arabic guard applies on iOS.

**Language detection — copy verbatim** (macOS lines 397–421): `detectLanguage(_:)` and `restrictLanguage(_:)` use NaturalLanguage framework, identical on iOS.

**isFluidAudioAvailable() — copy verbatim** (macOS lines 456–461): same filesystem path applies on iOS sandbox (applicationSupportDirectory).

---

### `iOS/Dicticus/Services/IOSModelWarmupService.swift` (service, event-driven)

**Analog:** `macOS/Dicticus/Services/ModelWarmupService.swift` — port with iOS simplification (no LLM step).

**Key diff:** iOS v2.0 has no AI cleanup (locked decision). Remove Step 4 (LLM download/load) and all `cleanupService`, `isLlmReady`, `llmStatus`, and `LlmStatus` references.

**Imports pattern** (macOS lines 1–3):
```swift
import SwiftUI
import FluidAudio
import os.log
```

**Class header and published properties** (macOS lines 44–53, stripped of LLM props):
```swift
@MainActor
class IOSModelWarmupService: ObservableObject {
    @Published var isWarming = false
    @Published var isReady = false
    @Published var error: String?

    private var asrManager: AsrManager?
    private var vadManager: VadManager?
    private var warmupTask: Task<Void, Never>?
    private var watchdogTask: Task<Void, Never>?
    private let warmupTimeoutSeconds: UInt64 = 600
}
```

**warmup() — copy Steps 1–3, drop Step 4** (macOS lines 93–198 pattern):
```swift
func warmup() {
    guard !isWarming && !isReady else { return }
    isWarming = true
    error = nil

    warmupTask = Task.detached(priority: .utility) { [weak self] in
        do {
            // Step 1: Download + load Parakeet TDT v3 CoreML models
            let models = try await AsrModels.downloadAndLoad(version: .v3)

            // Step 2: Create AsrManager and load models
            let manager = AsrManager(config: .default)
            try await manager.loadModels(models)

            // Step 3: Initialize Silero VAD v6
            let vad = try await VadManager(config: VadConfig(
                defaultThreshold: Float(IOSTranscriptionService.vadProbabilityThreshold)
            ))

            try Task.checkCancellation()

            await MainActor.run {
                self?.asrManager = manager
                self?.vadManager = vad
                self?.isWarming = false
                self?.isReady = true
                self?.watchdogTask?.cancel()
                self?.watchdogTask = nil
            }
            // NOTE: No Step 4 (LLM) on iOS v2.0 — locked decision
        } catch is CancellationError {
            await MainActor.run {
                self?.isWarming = false
                self?.error = "Model load timed out or was cancelled. Restart app."
                self?.watchdogTask?.cancel()
                self?.watchdogTask = nil
            }
        } catch {
            await MainActor.run {
                self?.isWarming = false
                self?.error = "Model load failed. Restart app."
                self?.watchdogTask?.cancel()
                self?.watchdogTask = nil
            }
        }
    }

    // Timeout watchdog — same pattern as macOS (macOS lines 192–199)
    watchdogTask = Task { [weak self] in
        try? await Task.sleep(nanoseconds: (self?.warmupTimeoutSeconds ?? 600) * 1_000_000_000)
        guard let self else { return }
        if self.isWarming { self.cancelWarmup() }
    }
}
```

**cancelWarmup() — copy verbatim** (macOS lines 206–210):
```swift
func cancelWarmup() {
    warmupTask?.cancel()
    warmupTask = nil
    isWarming = false
}
```

**Accessor properties** (macOS lines 215–223):
```swift
var asrManagerInstance: AsrManager? { asrManager }
var vadManagerInstance: VadManager? { vadManager }
```

---

### `iOS/Dicticus/DicticusApp.swift` (app root, event-driven)

**Analog:** `macOS/Dicticus/DicticusApp.swift` + current `iOS/Dicticus/DicticusApp.swift`

**Current iOS state** (all 17 lines — read above). Replace body to add scenePhase warmup and DictationViewModel wiring.

**Pattern to copy from macOS lines 1–17 and 55–78**:
```swift
import SwiftUI
import FluidAudio

@main
struct DicticusApp: App {
    @StateObject private var warmupService = IOSModelWarmupService()
    @StateObject private var dictionaryService = DictionaryService.shared
    @StateObject private var historyService = HistoryService.shared
    @StateObject private var viewModel = DictationViewModel()

    // Optional because it cannot be created until warmup completes
    @State private var transcriptionService: IOSTranscriptionService?

    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(warmupService)
                .environmentObject(dictionaryService)
                .environmentObject(historyService)
                .environmentObject(viewModel)
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                warmupService.warmup()  // no-op if already warming or ready (guard in warmup())
            }
        }
        .onChange(of: warmupService.isReady) { _, isReady in
            if isReady,
               let asrManager = warmupService.asrManagerInstance,
               let vadManager = warmupService.vadManagerInstance {
                let service = IOSTranscriptionService(asrManager: asrManager, vadManager: vadManager)
                transcriptionService = service
                viewModel.transcriptionService = service
            }
        }
    }
}
```
Key difference from macOS: `WindowGroup` not `MenuBarExtra`. No hotkey/modifier listener. scenePhase trigger replaces `.task { warmupService.warmup() }`.

---

### `iOS/Dicticus/ContentView.swift` (component, request-response)

**Analog:** `iOS/Dicticus/ContentView.swift` (current stub — lines 1–17).

Current file is a 17-line placeholder with `Text("Dicticus iOS Scaffold")`. Replace body to embed `DictationView`:

```swift
import SwiftUI

struct ContentView: View {
    @EnvironmentObject var viewModel: DictationViewModel

    var body: some View {
        DictationView()
            .environmentObject(viewModel)
    }
}

#Preview {
    ContentView()
        .environmentObject(DictationViewModel())
}
```

---

### `iOS/Dicticus/DictationView.swift` (component, request-response)

**Analog:** No exact SwiftUI view analog exists for a recording UI in this codebase. The macOS `MenuBarView` (menu bar dropdown) serves as a distant structural analog for @EnvironmentObject injection and published state observation.

**Pattern to adopt — @EnvironmentObject observation from macOS DicticusApp.swift lines 27–50**:
```swift
import SwiftUI

struct DictationView: View {
    @EnvironmentObject var viewModel: DictationViewModel

    var body: some View {
        VStack(spacing: 24) {
            // State-driven icon (mirrors macOS icon state machine pattern)
            Image(systemName: iconName)
                .imageScale(.large)
                .foregroundStyle(viewModel.state == .recording ? .red : .primary)

            Text(statusLabel)
                .font(.headline)

            // Record / Stop button
            Button(action: handleButton) {
                Text(viewModel.state == .idle ? "Start Dictation" : "Stop")
                    .frame(minWidth: 140)
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.state == .transcribing)

            if let result = viewModel.lastResult {
                Text(result)
                    .font(.body)
                    .padding()
                    .background(.secondarySystemBackground)
                    .cornerRadius(8)
            }

            if let error = viewModel.error {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.caption)
            }
        }
        .padding()
    }

    private var iconName: String {
        switch viewModel.state {
        case .idle:                  return "mic"
        case .preparingLiveActivity: return "mic"
        case .recording:             return "mic.circle.fill"
        case .transcribing:          return "waveform.circle"
        }
    }

    private var statusLabel: String {
        switch viewModel.state {
        case .idle:                  return "Ready"
        case .preparingLiveActivity: return "Starting…"
        case .recording:             return "Recording…"
        case .transcribing:          return "Transcribing…"
        }
    }

    private func handleButton() {
        Task {
            if viewModel.state == .idle {
                await viewModel.startDictation()
            } else if viewModel.state == .recording {
                await viewModel.stopDictation()
            }
        }
    }
}
```

---

### `iOS/Dicticus/DictationViewModel.swift` (orchestrator service, event-driven)

**Analog:** `macOS/Dicticus/Services/TranscriptionService.swift` (state machine pattern) + RESEARCH.md Pattern 5.

**State machine — mirror TranscriptionService.State pattern** (macOS lines 76–82):
```swift
import SwiftUI
import ActivityKit
import UIKit

@MainActor
class DictationViewModel: ObservableObject {
    enum State: Equatable {
        case idle
        case preparingLiveActivity
        case recording
        case transcribing
    }

    @Published var state: State = .idle
    @Published var lastResult: String?
    @Published var error: String?

    // Set by DicticusApp once warmup completes (property injection pattern from macOS DicticusApp)
    var transcriptionService: IOSTranscriptionService?

    private var currentActivity: Activity<DictationAttributes>?
```

**startDictation() — implements mandatory ordering from RESEARCH.md Pattern 5**:
```swift
    func startDictation() async {
        guard state == .idle else { return }
        state = .preparingLiveActivity

        // STEP 1: Live Activity MUST start before AVAudioSession — system kills audio otherwise
        do {
            try startLiveActivity()
        } catch {
            // Non-fatal: Live Activities may be disabled by user — still attempt recording
        }

        // STEP 2: Activate AVAudioSession + start recording (inside IOSTranscriptionService.startRecording())
        state = .recording
        do {
            try transcriptionService?.startRecording()
        } catch {
            await endLiveActivity()
            self.error = error.localizedDescription
            state = .idle
        }
    }
```

**stopDictation() — clipboard write on @MainActor (UIPasteboard is main-thread-only)**:
```swift
    func stopDictation() async {
        guard state == .recording else { return }
        state = .transcribing
        do {
            if let result = try await transcriptionService?.stopRecordingAndTranscribe() {
                // @MainActor context guaranteed — UIPasteboard.general is main-thread-only
                UIPasteboard.general.string = result.text
                lastResult = result.text
            }
        } catch {
            self.error = error.localizedDescription
        }
        await endLiveActivity()
        state = .idle
    }
```

**Live Activity helpers** (RESEARCH.md Pattern 2 — verbatim from Apple docs pattern):
```swift
    private func startLiveActivity() throws {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        currentActivity = try Activity.request(
            attributes: DictationAttributes(),
            content: ActivityContent(
                state: DictationAttributes.ContentState(isRecording: true, elapsedSeconds: 0),
                staleDate: nil
            ),
            pushType: nil
        )
    }

    private func endLiveActivity() async {
        await currentActivity?.end(
            ActivityContent(
                state: DictationAttributes.ContentState(isRecording: false, elapsedSeconds: 0),
                staleDate: nil
            ),
            dismissalPolicy: .after(.now + 3)
        )
        currentActivity = nil
    }
}
```

---

### `iOS/Dicticus/Intents/DictateIntent.swift` (controller, request-response)

**Analog:** None in codebase. Pattern from RESEARCH.md Pattern 1 (official Apple docs).

```swift
import AppIntents

struct DictateIntent: AudioRecordingIntent {
    static let title: LocalizedStringResource = "Start Dictation"
    static let description = IntentDescription("Begin dictating in Dicticus")

    // Backward-compat: openAppWhenRun deprecated in favor of supportedModes,
    // but AudioRecordingIntent (SystemIntent) requires this for foreground contract.
    @available(*, deprecated)
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        // Post to NotificationCenter; DictationViewModel observes and calls startDictation()
        // Avoids holding a direct reference to DictationViewModel from Intent (lifecycle mismatch)
        NotificationCenter.default.post(name: .startDictation, object: nil)
        return .result()
    }
}
```

Note: `Notification.Name.startDictation` must be declared as a static extension in a shared file (e.g., at top of `DictateIntent.swift`):
```swift
extension Notification.Name {
    static let startDictation = Notification.Name("com.dicticus.startDictation")
}
```

---

### `iOS/Dicticus/Intents/DicticusShortcuts.swift` (config)

**Analog:** None in codebase. Pattern from RESEARCH.md Pattern 1 (official Apple docs / Context7).

```swift
import AppIntents

struct DicticusShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: DictateIntent(),
            phrases: [
                // \(.applicationName) token is REQUIRED at least once per phrase for Siri registration
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

---

### `iOS/Dicticus/LiveActivity/DictationActivity.swift` (model)

**Analog:** `Shared/Models/TranscriptionResult.swift` — same Codable/Hashable/Sendable value-type pattern.

**Pattern from TranscriptionResult.swift lines 8–17** (value type + Sendable):
```swift
import ActivityKit
import Foundation

// Must be added to BOTH Dicticus app target AND DicticusWidget target in project.yml
// (see Pitfall 4 in RESEARCH.md — widget extension cannot see main app types)
struct DictationAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var isRecording: Bool
        var elapsedSeconds: Int
    }
    // No static fields needed for this use case
}
```

**project.yml source membership** — `DictationActivity.swift` must appear in sources for BOTH `Dicticus` and `DicticusWidget` targets (see project.yml pattern assignment below).

---

### `iOS/DicticusWidget/DicticusWidgetBundle.swift` (entry point)

**Analog:** `macOS/Dicticus/DicticusApp.swift` — same `@main` / `App` entry-point pattern, different protocol.

```swift
import WidgetKit
import SwiftUI

@main
struct DicticusWidgetBundle: WidgetBundle {
    var body: some Widget {
        DictationLiveActivity()
    }
}
```

---

### `iOS/DicticusWidget/DictationLiveActivity.swift` (component, event-driven)

**Analog:** None in codebase. Pattern from RESEARCH.md Pattern 3 (official Apple ActivityKit docs).

```swift
import WidgetKit
import SwiftUI

struct DictationLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DictationAttributes.self) { context in
            // Lock Screen / notification banner view (shown on non-Dynamic Island devices)
            HStack {
                Image(systemName: "mic.fill").foregroundColor(.red)
                Text(context.state.isRecording ? "Recording…" : "Processing…")
                Spacer()
                Text("\(context.state.elapsedSeconds)s")
                    .monospacedDigit()
            }
            .padding()
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "mic.fill").foregroundColor(.red)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.isRecording ? "Recording" : "Processing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Tap to open Dicticus")
                        .font(.caption)
                }
            } compactLeading: {
                Image(systemName: "mic.fill").foregroundColor(.red)
            } compactTrailing: {
                Text("\(context.state.elapsedSeconds)s").monospacedDigit()
            } minimal: {
                Image(systemName: "mic.fill").foregroundColor(.red)
            }
        }
    }
}
```

---

### `iOS/project.yml` (config — MODIFY)

**Analog:** `macOS/project.yml` and current `iOS/project.yml`.

**Current iOS project.yml** (read above — 44 lines). Apply three changes:

**1. Add FluidAudio SPM package** (mirrors macOS/project.yml lines 13–14):
```yaml
packages:
  GRDB:
    url: https://github.com/groue/GRDB.swift.git
    from: 7.0.0
  FluidAudio:                                    # ADD
    url: https://github.com/FluidInference/FluidAudio.git
    from: 0.13.6
```

**2. Add DicticusWidget extension target** (RESEARCH.md Pattern 7):
```yaml
  DicticusWidget:
    type: app-extension
    platform: iOS
    sources:
      - path: DicticusWidget
      # DictationActivity.swift must be in both targets (Pitfall 4 in RESEARCH.md)
      - path: Dicticus/LiveActivity/DictationActivity.swift
    settings:
      PRODUCT_BUNDLE_IDENTIFIER: com.dicticus.ios.widget
      INFOPLIST_FILE: DicticusWidget/Info.plist
      SKIP_INSTALL: YES
      PRODUCT_NAME: DicticusWidget
      SWIFT_VERSION: "6.0"
      DEVELOPMENT_TEAM: ${DEVELOPER_TEAM_ID}
    info:
      path: DicticusWidget/Info.plist
      properties:
        NSExtension:
          NSExtensionPointIdentifier: com.apple.widgetkit-extension
    frameworks:
      - WidgetKit.framework
      - SwiftUI.framework
```

**3. Add DicticusWidget dependency to Dicticus target and FluidAudio package dep**:
```yaml
  Dicticus:
    ...
    dependencies:
      - package: GRDB
        product: GRDB
      - package: FluidAudio      # ADD
        product: FluidAudio
      - target: DicticusWidget   # ADD
```

**4. Info.plist additions required** in `iOS/Dicticus/Info.plist` (not project.yml, but same change wave):
```xml
<key>NSMicrophoneUsageDescription</key>
<string>Dicticus needs microphone access to transcribe your speech. Your audio never leaves this device.</string>
<key>NSSupportsLiveActivities</key>
<true/>
<key>NSSupportsLiveActivitiesFrequentUpdates</key>
<false/>
```

---

## Shared Patterns

### @MainActor ObservableObject
**Source:** `macOS/Dicticus/Services/TranscriptionService.swift` lines 70–71 and `macOS/Dicticus/Services/ModelWarmupService.swift` lines 43–44
**Apply to:** `IOSTranscriptionService`, `IOSModelWarmupService`, `DictationViewModel`
```swift
@MainActor
class ServiceName: ObservableObject {
    @Published var state: State = .idle
    @Published var error: String?
}
```

### Task.detached(priority: .utility) for Background Work
**Source:** `macOS/Dicticus/Services/ModelWarmupService.swift` lines 98–185
**Apply to:** `IOSModelWarmupService.warmup()` — FluidAudio model loading must not block the main thread
```swift
warmupTask = Task.detached(priority: .utility) { [weak self] in
    // ... async work ...
    await MainActor.run { self?.isReady = true }
}
```

### nonisolated Static installTap (Swift 6 Audio Thread Safety)
**Source:** `macOS/Dicticus/Services/TranscriptionService.swift` lines 152–165
**Apply to:** `IOSTranscriptionService` — critical pattern; violating it causes EXC_BAD_ACCESS on audio thread
```swift
nonisolated private static func installTap(
    on inputNode: AVAudioInputNode,
    format: AVAudioFormat,
    buffer: AudioSampleBuffer
) {
    inputNode.installTap(onBus: 0, bufferSize: 4096, format: format) { pcmBuffer, _ in
        // No @MainActor isolation here — this closure runs on the real-time audio thread
        if let channelData = pcmBuffer.floatChannelData?[0] {
            let samples = Array(UnsafeBufferPointer(start: channelData, count: Int(pcmBuffer.frameLength)))
            buffer.append(samples)  // NSLock-protected — thread-safe
        }
    }
}
```

### ScenePhase → warmup() Trigger
**Source:** `macOS/Dicticus/DicticusApp.swift` lines 48–54 (`.task { warmupService.warmup() }`)
**Apply to:** `iOS/Dicticus/DicticusApp.swift` — iOS uses scenePhase .active instead of .task
```swift
@Environment(\.scenePhase) private var scenePhase
// ...
.onChange(of: scenePhase) { _, newPhase in
    if newPhase == .active {
        warmupService.warmup()  // guard in warmup() makes this idempotent
    }
}
```

### warmupService.isReady → service wiring
**Source:** `macOS/Dicticus/DicticusApp.swift` lines 55–78
**Apply to:** `iOS/Dicticus/DicticusApp.swift`
```swift
.onChange(of: warmupService.isReady) { _, isReady in
    if isReady,
       let asrManager = warmupService.asrManagerInstance,
       let vadManager = warmupService.vadManagerInstance {
        let service = IOSTranscriptionService(asrManager: asrManager, vadManager: vadManager)
        transcriptionService = service
        viewModel.transcriptionService = service  // property injection
    }
}
```

### Three-Layer VAD Defense
**Source:** `macOS/Dicticus/Services/TranscriptionService.swift` lines 205–228
**Apply to:** `IOSTranscriptionService.stopRecordingAndTranscribe()` — copy verbatim
```swift
// Layer 1: minimum duration guard (reject < 0.3s clips)
guard durationSeconds >= minimumDurationSeconds else { throw TranscriptionError.tooShort }

// Layer 2: Silero VAD pre-filter
let vadResults = try await vadManager.process(resampledSamples)
let hasVoice = vadResults.contains { $0.probability > silenceThreshold }
guard hasVoice else { throw TranscriptionError.silenceOnly }

// Layer 3: empty result guard
let trimmedText = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
guard !trimmedText.isEmpty else { throw TranscriptionError.noResult }
```

### Non-Latin Script Guard
**Source:** `macOS/Dicticus/Services/TranscriptionService.swift` lines 343–389
**Apply to:** `IOSTranscriptionService` — copy verbatim. `containsNonLatinScript(_:)` is pure Swift, no platform dep.

### XCTest Pattern for FluidAudio-Dependent Tests
**Source:** `macOS/DicticusTests/TranscriptionServiceTests.swift` lines 206–220
**Apply to:** All `iOS/DicticusTests/` test files that need FluidAudio
```swift
@MainActor
final class IOSTranscriptionServiceTests: XCTestCase {
    private func makeServiceOrSkip() async throws -> IOSTranscriptionService {
        try XCTSkipUnless(
            IOSTranscriptionService.isFluidAudioAvailable(),
            "Skipping — FluidAudio Parakeet model not loaded."
        )
        guard let service = try? await IOSTranscriptionService.makeForTesting() else {
            throw XCTSkip("FluidAudio init failed.")
        }
        return service
    }
}
```

---

## No Analog Found

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `iOS/Dicticus/Intents/DictateIntent.swift` | controller | request-response | No App Intents / AudioRecordingIntent usage anywhere in codebase. Use RESEARCH.md Pattern 1. |
| `iOS/Dicticus/Intents/DicticusShortcuts.swift` | config | — | No AppShortcutsProvider in codebase. Use RESEARCH.md Pattern 1 (Siri phrase section). |
| `iOS/DicticusWidget/DictationLiveActivity.swift` | component | event-driven | No WidgetKit / ActivityConfiguration in codebase. Use RESEARCH.md Pattern 3. |

---

## Metadata

**Analog search scope:** `macOS/Dicticus/Services/`, `macOS/Dicticus/DicticusApp.swift`, `macOS/DicticusTests/`, `iOS/Dicticus/`, `iOS/project.yml`, `Shared/Models/`, `Shared/Services/`
**Files scanned:** 23
**Key constraint:** `DictationActivity.swift` (containing `DictationAttributes`) must be listed in BOTH the `Dicticus` target and `DicticusWidget` target source paths in `iOS/project.yml` — otherwise the widget extension fails to compile (RESEARCH.md Pitfall 4).
**Pattern extraction date:** 2026-04-21
