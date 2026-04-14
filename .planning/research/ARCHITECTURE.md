# Architecture Patterns

**Domain:** Local multi-platform dictation app (macOS primary, iOS stretch, Windows stretch)
**Researched:** 2026-04-14
**Overall confidence:** HIGH for macOS / MEDIUM for iOS / MEDIUM for Windows

---

## Answer: Is This 1, 2, or 3 Apps?

**3 separate native apps with a shared model layer.**

The platform constraints make true code sharing at the app level impractical:

- macOS requires a native Swift app for menu bar, CGEventTap, and AVAudioEngine
- iOS is architecturally incompatible with macOS at the UI layer; the most viable approach is an App Intent (Shortcut) or standalone app, not a custom keyboard (see iOS section below)
- Windows requires Win32/WinRT APIs with no Swift equivalent

A Rust or C++ "core" is theoretically possible but adds enormous complexity for marginal gain — whisper.cpp already provides a battle-tested C API callable from Swift AND C# simultaneously, and llama.cpp does the same. Use the C API as the shared inference substrate; write platform shells in the platform's native language.

**Recommended answer:** 2 real apps to start (macOS + Windows), iOS deferred pending feasibility research. The macOS app is app #1. Windows is app #2, sharing only model files and configuration formats (JSON), not runtime code.

---

## Recommended Architecture

### Overall Pipeline

```
[User Input]
     |
     v
[Hotkey / Trigger Layer]          (platform-specific)
     |
     v
[Audio Capture]                   (platform-specific, outputs 16kHz PCM float32)
     |
     v
[VAD — Voice Activity Detection]  (shared logic, part of ASR library)
     |
     v
[ASR Inference]                   (whisper.cpp / WhisperKit — outputs raw transcript)
     |
     v
[Mode Router]                     (based on which hotkey triggered: plain / cleanup / rewrite)
     |
     +--[plain]---> [Text Output]
     |
     +--[cleanup]-> [LLM Inference — light prompt] -> [Text Output]
     |
     +--[rewrite]-> [LLM Inference — heavy prompt] -> [Text Output]
                                                              |
                                                              v
                                                     [Text Injection]  (platform-specific)
```

---

## Component Boundaries

### macOS App

| Component | Responsibility | Communicates With |
|-----------|---------------|-------------------|
| MenuBarController | NSStatusItem UI, show/hide status, mode indicator | HotkeyMonitor, PipelineOrchestrator |
| HotkeyMonitor | CGEventTap for keydown/keyup; resolves key → mode | AudioRecorder, MenuBarController |
| AudioRecorder | AVAudioEngine mic capture; buffers 16kHz PCM; starts/stops on hotkey events | ASREngine |
| ASREngine | Wraps WhisperKit (Swift) or whisper.cpp (C API); async transcription; language detection | PipelineOrchestrator |
| PipelineOrchestrator | Receives raw transcript; routes to LLM or directly to output based on mode | ASREngine, LLMEngine, TextInjector |
| LLMEngine | Wraps llama.cpp (C API) or MLX Swift; stateless inference with system prompt per mode | PipelineOrchestrator |
| TextInjector | NSPasteboard write + Cmd+V simulation via CGEvent; or Accessibility paste action | PipelineOrchestrator |
| ModelManager | Load/unload models on startup; memory pressure handling; warm-up | ASREngine, LLMEngine |
| SettingsStore | UserDefaults-backed config: hotkeys, model paths, mode prompts | All components |

### iOS App (if built)

| Component | Responsibility | Communicates With |
|-----------|---------------|-------------------|
| App Intent / Action | Entry point from Shortcuts; requests mic, triggers pipeline | AudioRecorder, PipelineOrchestrator |
| AudioRecorder | AVAudioSession mic capture; push-to-talk via button in intent UI | ASREngine |
| ASREngine | WhisperKit (CoreML) inference | PipelineOrchestrator |
| LLMEngine | MLX Swift or llama.cpp via C | PipelineOrchestrator |
| ClipboardWriter | UIPasteboard; Shortcuts can return text to invoking context | PipelineOrchestrator |

### Windows App

| Component | Responsibility | Communicates With |
|-----------|---------------|-------------------|
| TrayIcon | NotifyIcon in system tray; equivalent of menu bar | HotkeyManager, PipelineOrchestrator |
| HotkeyManager | RegisterHotKey or SetWindowsHookEx for key-down/up; resolves key → mode | AudioRecorder |
| AudioRecorder | WASAPI or NAudio for mic capture; outputs 16kHz PCM | ASREngine |
| ASREngine | whisper.cpp C API via P/Invoke (C#) | PipelineOrchestrator |
| PipelineOrchestrator | Mode routing logic | ASREngine, LLMEngine, TextInjector |
| LLMEngine | llama.cpp C API via P/Invoke (C#) | PipelineOrchestrator |
| TextInjector | Clipboard write + SendInput Ctrl+V simulation | PipelineOrchestrator |
| ModelManager | Model loading and memory management | ASREngine, LLMEngine |

---

## Data Flow: macOS Happy Path

```
1. User holds hotkey (e.g., Option+F19 → "cleanup" mode)
   HotkeyMonitor receives CGEvent keydown → starts AudioRecorder

2. AudioRecorder captures audio via AVAudioEngine
   Taps installTap on inputNode → accumulates 16kHz PCM float32 buffers

3. User releases hotkey
   HotkeyMonitor receives CGEvent keyup → stops AudioRecorder
   Assembles full PCM buffer → sends to ASREngine

4. ASREngine runs WhisperKit transcription
   - Language detection: auto (de/en)
   - Returns: TranscriptionResult { text: String, language: String }

5. PipelineOrchestrator receives result
   - Mode = cleanup → sends to LLMEngine with light cleanup prompt
   - Mode = plain → skip LLM
   - Mode = rewrite → sends to LLMEngine with heavy rewrite prompt

6. LLMEngine returns polished text string

7. TextInjector:
   a. Saves current clipboard contents
   b. Writes text to NSPasteboard
   c. Posts Cmd+V CGEvent to frontmost app
   d. Restores original clipboard after 200ms delay

8. MenuBarController updates icon briefly (success flash)
```

---

## Patterns to Follow

### Pattern 1: Process Isolation for Inference (XPC Service)

**What:** Run ASR and LLM inference in a separate XPC process from the menu bar app.

**When:** If model crashes or OOMs, the menu bar app survives. Required for App Store distribution (sandboxing). Also allows macOS to manage the inference process's memory separately.

**Tradeoff:** Adds IPC complexity. For v1 (direct distribution, not App Store), run inference in-process for simplicity. Switch to XPC if App Store is a goal.

**Verdict for v1:** In-process, same app. XPC in a later milestone if App Store distribution is required.

### Pattern 2: Lazy Model Loading + Warm-Up

**What:** Load ASR and LLM models once at app launch (or first use), keep in memory for the lifetime of the app. Do not reload per-request.

**Why:** WhisperKit model load on Apple Silicon: ~1-3 seconds for medium models. llama.cpp 1-3B model load: ~2-4 seconds. Both are unacceptable on-demand; both are acceptable once at startup.

**Implementation:** ModelManager actor loads models asynchronously at launch; blocks first transcription until ready; shows "loading" in menu bar icon.

### Pattern 3: Clipboard Restore for Text Injection

**What:** Save clipboard → write text → send Cmd+V → restore clipboard.

**Why:** The most reliable cross-app text insertion method on macOS and Windows. Accessibility API insertion (via `NSApp.sendAction(#selector(paste:))`) requires the target app to be Accessibility-aware. CGEvent Cmd+V simulation works in browsers, terminals, Office apps, Electron apps — everywhere.

**Risk:** 200ms restore window is too short if clipboard manager apps intercept. Workaround: use a private UTType pasteboard item alongside the string so clipboard managers know not to snapshot it.

### Pattern 4: Mode as Hotkey Identity (Not State)

**What:** Each mode (plain, cleanup, rewrite) has its own hotkey. There is no "current mode" toggle state.

**Why:** No mode-switching UI needed. No state management bugs. Easier to understand for the user. Different muscle memory per action.

**Implementation:** HotkeyMonitor maps each registered key to a `DictationMode` enum. PipelineOrchestrator receives the mode alongside the audio.

### Pattern 5: Actor-Based Concurrency for Audio + Inference

**What:** Use Swift actors for AudioRecorder and ASREngine to prevent data races on shared audio buffers and model state.

**Why:** AVAudioEngine taps fire on a real-time audio thread. Inference runs on a background thread. Without isolation, concurrent buffer mutations cause crashes. Swift actors provide compile-time safety.

```swift
actor AudioRecorder {
    private var buffer: [Float] = []
    func appendSamples(_ samples: [Float]) { buffer.append(contentsOf: samples) }
    func consumeBuffer() -> [Float] { defer { buffer = [] }; return buffer }
}
```

---

## Anti-Patterns to Avoid

### Anti-Pattern 1: Always-On CGEventTap Without Input Monitoring Permission

**What goes wrong:** CGEventTap at `kCGEventTapOptionDefault` (passive listening for key-down/up) requires Input Monitoring permission in macOS 10.15+. Apps that skip the permission prompt or use undocumented APIs get their event tap silently disabled.

**Why it happens:** Developers test with accessibility permissions enabled in dev, ship without the proper entitlements and permission request flow.

**Prevention:** In `Info.plist`, include `NSInputMonitoringUsageDescription`. At app launch, check `CGPreflightInputMonitoringAccess()` and guide user to System Preferences if not granted. Use `KeyboardShortcuts` library for standard shortcuts (no permission needed), fall back to CGEventTap only for modifier-key-only or push-to-talk.

**Note on push-to-talk specifically:** Standard hotkey libraries (KeyboardShortcuts) support keydown/keyup for standard key combos (Option+F19). If pure modifier key detection is needed (hold Option alone), CGEventTap is required with Input Monitoring permission. Prefer a combo (modifier + function key) to avoid the harder permission requirement.

### Anti-Pattern 2: Blocking the Main Thread with Inference

**What goes wrong:** ASR inference on whisper.cpp for a 10-second utterance takes 0.5–2 seconds on Apple Silicon. LLM inference adds another 1–3 seconds. Running either on the main thread freezes the menu bar and any UI.

**Prevention:** Both ASR and LLM run on background async tasks (`Task.detached` or dedicated serial queues). Menu bar shows a spinner/indicator while inference runs.

### Anti-Pattern 3: Reloading Models Per Request

**What goes wrong:** Model cold-start latency (2-5 seconds each) appears as user-visible lag on every dictation.

**Prevention:** Keep models warm in memory. ModelManager loads once at app start and pins them in RAM. On memory pressure notification, optionally unload LLM (less frequently needed) but keep ASR loaded.

### Anti-Pattern 4: iOS Custom Keyboard for Dictation

**What goes wrong:** iOS custom keyboard extensions cannot access the microphone. This is a hard platform constraint. Building a dictation feature inside a keyboard extension is impossible.

**Prevention:** Use App Intents (Shortcuts) or a standalone app with a prominent record button instead. The Shortcuts approach lets the user run "Dictate with Dicticus" from any Shortcuts-enabled surface including Action Button on iPhone 15+.

### Anti-Pattern 5: Shared Runtime Code Between macOS and Windows

**What goes wrong:** Attempting to share Swift UI code with Windows via Catalyst or MAUI leads to painful platform-specific workarounds. The OS integration surface (hotkeys, accessibility, audio capture) is completely different per platform.

**Prevention:** Share only model files (GGUF format), configuration schema (JSON), and system prompts (plain text). Accept that macOS (Swift) and Windows (C# WPF or WinUI 3) are separate codebases with separate build pipelines. The inference libraries (whisper.cpp, llama.cpp) abstract the hardware differences via their C APIs.

---

## iOS Constraints and Recommended Approach

### Option A: App Intent + Shortcuts (RECOMMENDED)

An App Intent allows Dicticus to be triggered from the Shortcuts app, the Action Button (iPhone 15+), Back Tap, or a Shortcuts widget. The intent:
1. Records audio via the containing app (not extension — full mic access)
2. Runs WhisperKit + MLX LLM inference
3. Returns a string result to Shortcuts
4. Shortcuts can pipe the result into other apps via "Copy to Clipboard" action

**Limitations:** Cannot paste directly into the foreground app from an intent. User must manually paste after the result is in clipboard. This is a UX tradeoff, not a showstopper.

**Memory constraint:** On older iPhones, WhisperKit + an LLM simultaneously may exceed memory limits. Recommendation: ASR-only on iPhone, skip LLM cleanup on iOS, or use a very small model (Gemma-2 1B via MLX).

### Option B: Standalone iOS App with Record Button

A simple fullscreen iOS app with a large hold-to-record button. Transcribed text shown on screen, one-tap copy. Less integrated than Shortcuts but simpler to build and test.

**Best for:** Validating the iOS pipeline before investing in App Intent integration.

### Option C: Custom Keyboard Extension (NOT VIABLE)

iOS keyboard extensions have no microphone access. Confirmed platform constraint. Do not pursue.

---

## Cross-Platform Code Sharing Strategy

### What to Share

| Artifact | Format | Used By |
|----------|--------|---------|
| ASR model files | GGUF (whisper.cpp) or CoreML mlmodelc (WhisperKit) | macOS: WhisperKit; Windows: whisper.cpp |
| LLM model files | GGUF (llama.cpp Q4 quantized) | macOS: llama.cpp; Windows: llama.cpp; iOS: MLX or llama.cpp |
| System prompt templates | Plain text files | All platforms |
| Configuration schema | JSON | All platforms |

### What Cannot Be Shared

| Artifact | Why |
|----------|-----|
| Audio capture code | AVAudioEngine (Apple) vs WASAPI/NAudio (Windows) |
| Hotkey registration | CGEventTap (macOS) vs RegisterHotKey/SetWindowsHookEx (Windows) |
| Text injection | NSPasteboard + Cmd+V CGEvent (macOS) vs Clipboard + SendInput (Windows) |
| UI layer | NSStatusItem + SwiftUI (macOS) vs NotifyIcon + WPF/WinUI3 (Windows) |
| Inference wrapper | WhisperKit/MLX Swift (Apple only) vs whisper.cpp P/Invoke (Windows) |

### Language Decision per Platform

- **macOS:** Swift 5.9+ with Swift Concurrency (actors, async/await). Use WhisperKit for ASR (CoreML optimized). Use MLX Swift or llama.cpp C API via Swift for LLM.
- **Windows:** C# with .NET 8. Use whisper.cpp via P/Invoke or a NuGet wrapper. Use llama.cpp via P/Invoke or LLamaSharp.
- **iOS:** Swift, same language as macOS. WhisperKit supports iOS 16+. MLX Swift supports iOS.

---

## Model Management

### ASR Model Choice

WhisperKit is the recommended ASR engine for macOS and iOS because:
- First-class Apple Silicon optimization (CoreML + Neural Engine)
- Supports Whisper large-v3 and turbo variants
- Swift native API with async/await
- Maintained by Argmax with production quality
- Compatible with macOS 14+ and iOS 16+

For Parakeet V3 specifically: Parakeet is an NVIDIA NeMo model. It does not run via WhisperKit or whisper.cpp natively. MacWhisper appears to use a proprietary CoreML conversion of Parakeet. For v1, use Whisper large-v3-turbo via WhisperKit as the ASR engine (comparable quality, confirmed Apple Silicon support). Parakeet integration requires separate feasibility research.

### LLM Model Choice

For cleanup/rewrite modes, a 1-3B parameter model is sufficient:
- Gemma-2 2B (MLX quantized): ~1.2GB VRAM, fast on Apple Silicon
- Phi-3 Mini (3.8B, 4-bit): ~2GB VRAM, strong instruction following
- Qwen2.5 1.5B: compact, multilingual (German/English)

Load both ASR and LLM at startup. On a 16GB Apple Silicon Mac, this is comfortably within memory limits.

### Memory Budget (estimated, Apple Silicon 16GB)

| Model | VRAM Estimate |
|-------|--------------|
| Whisper large-v3-turbo (CoreML) | ~600MB |
| Gemma-2 2B 4-bit (MLX) | ~1.2GB |
| OS + app overhead | ~200MB |
| **Total** | **~2GB** |

Well within Apple Silicon unified memory architecture. No memory pressure expected.

---

## Suggested Build Order (Phase Dependencies)

The dependency graph drives phase ordering:

```
Phase 1: macOS Audio Pipeline
  - AVAudioEngine mic capture
  - Push-to-talk hotkey (CGEventTap or KeyboardShortcuts)
  - No inference yet; log audio to file to validate capture
  Deliverable: Hold key → audio file saved

Phase 2: macOS ASR Integration
  - WhisperKit model loading and inference
  - Language detection (de/en auto)
  - Basic text output to console/log
  Depends on: Phase 1 (audio capture)
  Deliverable: Hold key → transcript printed

Phase 3: macOS Text Injection
  - Clipboard-based paste at cursor
  - CGEvent Cmd+V simulation
  - Clipboard restore
  Depends on: Phase 2 (text to inject)
  Deliverable: Full plain dictation working

Phase 4: macOS Menu Bar App
  - NSStatusItem + SwiftUI menu
  - Mode indicator (idle / recording / processing)
  - Settings panel for hotkey configuration
  Depends on: Phase 3 (core pipeline working)
  Deliverable: Polished menu bar experience

Phase 5: macOS LLM Integration
  - llama.cpp or MLX Swift LLM loading
  - Cleanup and rewrite mode prompts
  - Mode routing by hotkey
  Depends on: Phase 3 (text output)
  Deliverable: Three-mode dictation (plain / cleanup / rewrite)

Phase 6: iOS App (stretch goal)
  - Standalone record + transcribe app
  - WhisperKit on iOS
  - App Intent for Shortcuts integration
  Depends on: Phases 1-5 lessons applied
  Deliverable: Shortcuts-triggered dictation on iPhone

Phase 7: Windows App (stretch goal)
  - C# WinUI3 or WPF app
  - whisper.cpp P/Invoke via LLamaSharp/Whisper.net
  - RegisterHotKey or SetWindowsHookEx
  - SendInput clipboard paste
  Depends on: macOS phases complete (architecture proven)
  Deliverable: Parity feature set on Windows
```

---

## Scalability Considerations

This is a single-user local app. Scalability concerns are about resource usage, not load:

| Concern | Mitigation |
|---------|-----------|
| Model memory | Keep warm; unified memory handles it on Apple Silicon |
| Inference latency | WhisperKit on M-series: <1s for typical utterance; LLM: <2s for 1-3B model |
| Audio buffer accumulation | Cap max recording at 60s; warn user at 30s |
| Multiple rapid triggers | Queue requests; discard overlapping captures |
| Background memory pressure | Unload LLM on memory warning; ASR stays loaded |

---

## Sources

- WhisperKit source (argmaxinc/WhisperKit): C API, threading model, CoreML integration — HIGH confidence
- whisper.cpp (ggerganov/whisper.cpp): C API, platform support, Metal backend — HIGH confidence
- llama.cpp (ggerganov/llama.cpp): C API, quantization, platform support — HIGH confidence
- MLX Swift (ml-explore/mlx-swift): Apple Silicon LLM inference, iOS/macOS support — HIGH confidence
- KeyboardShortcuts library: keydown/keyup support, modifier key limitations — HIGH confidence (verified from source)
- Win32 RegisterHotKey (learn.microsoft.com): push-to-talk limitation (modifier-only not supported) — HIGH confidence
- Win32 SendInput (learn.microsoft.com): Windows text injection mechanism — HIGH confidence
- iOS custom keyboard extension: microphone access blocked — MEDIUM confidence (API docs indirect)
- .NET MAUI (learn.microsoft.com): Windows platform capabilities — HIGH confidence (official docs)
- macOS NSPasteboard + Cmd+V paste pattern — MEDIUM confidence (common pattern, no direct official source retrieved)
