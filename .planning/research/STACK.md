# Technology Stack

**Project:** Dicticus — Local Dictation App
**Researched:** 2026-04-14
**Overall Confidence:** MEDIUM (most findings verified with official docs; some platform edge cases flagged)

---

## Critical Pre-Stack Finding: Parakeet V3 is English-Only

**This is the most important finding for the project.**

NVIDIA Parakeet TDT 1.1B achieves 1.39% WER on LibriSpeech clean English — exceptional quality — but it is **English-only by design**. It cannot auto-detect language and has no German support. The user requires German + English with auto-detection.

**Verdict:** Parakeet cannot be the primary ASR engine for this project. It could be used as an English-only fast path, but the primary engine must be something multilingual.

The practical replacement is **whisper-large-v3-turbo** running via **whisper.cpp** with CoreML acceleration. This is what MacWhisper uses under the hood (the app's discussion page confirms whisper.cpp apps include MacWhisper). It supports 99 languages including German, auto-detects language, and on Apple Silicon with CoreML the encoder runs on the Neural Engine for 3x+ speedup over CPU.

**Confidence:** HIGH (sourced directly from Parakeet HuggingFace model card, OpenAI Whisper repo, whisper.cpp documentation)

---

## Recommended Stack

### 1. ASR Engine

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| whisper.cpp | v1.8.4 (Homebrew) | Primary ASR inference on macOS + Windows | C library, Apple Silicon first-class, CoreML/Metal acceleration, large-v3-turbo runs at <2s latency, 99 languages including German with auto-detection |
| whisper-large-v3-turbo (GGML) | - | Default model | 809M params, q5_0 quantization = 547 MiB on disk, 6.3x faster than large-v3 with <2% WER degradation; multilingual including German |
| WhisperKit | current | iOS ASR via CoreML | Swift-native wrapper over Whisper CoreML models, iOS 18.0+, Swift Package Manager, the only practical path for on-device ASR on iPhone without a Python stack |

**Do NOT use:**
- **NVIDIA Parakeet TDT** as primary: English-only, no German, requires NVIDIA GPU or heavy Python/NeMo stack on CPU, no Apple Silicon optimization path
- **faster-whisper**: CUDA-only GPU acceleration, no native Apple Silicon support; CPU fallback works but defeats the purpose
- **Apple SFSpeechRecognizer**: Offline mode has poor German quality vs Whisper, no auto-detection between languages, not controllable at the model level
- **distil-whisper large-v3**: English-only (explicitly stated in model card)
- **sherpa-onnx**: Supports Parakeet ONNX exports (English-only) and some multilingual models, but the Swift API is lower-level and less mature than WhisperKit; viable fallback if WhisperKit proves insufficient

**Confidence:** HIGH for whisper.cpp selection. MEDIUM for WhisperKit on iOS (depends on iOS feasibility research).

---

### 2. Local LLM for Text Cleanup

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| llama.cpp | current (8796+ commits, active) | LLM inference runtime | Apple Silicon Metal first-class, 1.5-8bit quantization, runs on macOS and Windows, C library embeddable in native apps |
| Gemma 3 1B IT (QAT Q4_0 GGUF) | Google Gemma 3 | Light cleanup mode | ~1 GB on disk, 140+ language support including German, instruction-tuned, fast enough for <1s cleanup latency on M-series |
| Phi-3 Mini 4K (Q4_K_M GGUF) | 3.8B params | Heavier rewrite mode | 2.2 GB on disk, stronger reasoning for structural rewrites, good multilingual performance |

**Model selection rationale:**
- Light cleanup (grammar, punctuation, filler removal): Gemma 3 1B. Small, fast, multilingual. At Q4_0 it fits in ~1 GB RAM alongside the Whisper model without pressure on 16GB Apple Silicon machines.
- Heavier rewrite (restructure sentences, formal register): Phi-3 Mini. 3.8B at Q4 gives meaningfully better output quality for complex rewrites. 2.2 GB is still comfortable.
- Both run via llama.cpp Metal backend on macOS, and llama.cpp CPU/GPU on Windows.

**Alternative considered:** MLX + mlx-lm (Apple ML Research, v0.31.1). Excellent Apple Silicon performance via unified memory, but macOS-only. Since Windows is a target, llama.cpp wins on cross-platform portability. MLX could be the on-device path on Mac if a shared inference server isn't used.

**Do NOT use:**
- **Ollama**: Adds a daemon dependency and HTTP overhead; too heavy for sub-second cleanup in a menu bar app
- **Cloud LLM APIs**: Hard constraint violation
- **LM Studio**: Same issue as Ollama, designed for interactive use not embedded inference

**Confidence:** MEDIUM. LLM for grammar cleanup at 1B scale is relatively new territory — quality needs validation in Phase 1. Gemma 3 1B multilingual German cleanup quality is unverified by independent benchmark.

---

### 3. macOS App Shell

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| Swift + SwiftUI | Swift 6 / macOS 15 target | Menu bar app shell, UI | Native, zero overhead, MenuBarExtra API (macOS 13+), proper sandbox lifecycle management |
| SwiftUI MenuBarExtra | macOS 13+ | Menu bar presence | The modern Apple-recommended approach for menu bar apps, replaces NSStatusBar for new apps |
| KeyboardShortcuts (sindresorhus) | current (165 commits, actively used in production) | User-configurable global hotkeys | Sandboxed, App Store compatible, stores in UserDefaults, conflict detection built-in, used by Dato/Plash/Lungo |
| AVFoundation | macOS built-in | Audio capture | Native audio session management, push-to-talk buffer capture |
| NSPasteboard + CGEvent | macOS built-in | Paste-at-cursor | Write text to clipboard, synthesize Cmd+V via CGEvent to paste at active cursor position |
| Accessibility API (AXUIElement) | macOS built-in | Text injection | Fallback for apps that support Accessibility: inject directly into focused text field without clipboard roundtrip |

**Architecture decision — NOT sandboxed:**
A sandboxed Mac App Store app cannot use `NSEvent.addGlobalMonitorForEvents` for push-to-talk key-down detection while the app is in background. The app needs Accessibility permission (which requires the user granting it once in System Settings). This is standard for all dictation/clipboard/hotkey tools (Maccy, Rectangle, MacWhisper). Distribute via direct download or a dedicated developer ID, not the Mac App Store.

**Paste-at-cursor implementation pattern (verified from community tools):**
1. Write transcribed text to `NSPasteboard.general`
2. Synthesize `CGEvent` Cmd+V keystroke to the focused application
3. After a brief delay (50ms), restore original clipboard contents
This is the most reliable cross-app approach. Direct AXUIElement injection works in more apps but requires richer Accessibility permissions and fails in some sandboxed apps.

**Confidence:** HIGH for Swift/SwiftUI + KeyboardShortcuts. MEDIUM for paste-at-cursor reliability (clipboard manipulation is inherently racy; needs testing across target apps).

---

### 4. Windows App

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| C# + WinForms (system tray) or Rust | - | Windows app shell | Windows desktop apps with system tray, global hotkeys via RegisterHotKey Win32 API |
| whisper.cpp (Windows build) | v1.8.4 | ASR inference | Same model, same inference library; whisper.cpp builds on Windows with MSVC or MinGW, CPU inference works on any business laptop, CUDA available on NVIDIA GPUs |
| llama.cpp (Windows build) | current | LLM text cleanup | Same cross-platform story; GGUF models are identical files |
| RegisterHotKey + SendInput | Win32 API | System hotkeys + text injection | RegisterHotKey is the official system-wide hotkey API on Windows, works in background/tray apps. SendInput synthesizes keyboard events to inject text |

**Verdict on 1 vs 2 vs 3 separate apps:**
- **Recommendation: 2 separate apps — one native Mac app, one native Windows app — with shared model files (GGUF).**
- The whisper.cpp and llama.cpp C libraries are cross-platform, but the app shell, audio capture, hotkey, and text injection APIs are completely different per platform. There is no practical cross-platform framework (Tauri/Electron) that handles system-wide push-to-talk hotkeys + text-at-cursor injection cleanly without significant platform-specific code anyway.
- Tauri v2 supports macOS + Windows + iOS (current version 2.10.1), but Tauri's global hotkey story requires the `global-hotkey` crate (v0.7.0, released May 2025) and has macOS-specific event loop constraints that complicate push-to-talk semantics. The web-view layer adds unnecessary complexity for a background-only tool with minimal UI.
- The shared asset is the model directory: same GGUF files work on both platforms via the same whisper.cpp + llama.cpp binaries.
- iPhone is a third, separate app (see below).

**Confidence:** MEDIUM for Windows app architecture (C# vs Rust is undecided; C# is faster to implement for a solo developer, Rust shares more code with a potential future Tauri path).

---

### 5. iPhone App

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| Swift + SwiftUI | Swift 6 / iOS 18 | Container app | Required host for keyboard extension |
| WhisperKit | current | On-device ASR | Swift-native, iOS 18+, CoreML models run on Neural Engine, Swift Package Manager integration |
| UIInputViewController | iOS built-in | Custom keyboard extension | The ONLY supported approach for third-party dictation keyboards on iOS |
| App Groups | iOS entitlement | Shared model storage | Allows keyboard extension to access model files downloaded by main app |

**Critical iOS finding: Custom keyboard extension CANNOT access the microphone.**

iOS keyboard extensions run in a hardened sandbox that explicitly prohibits microphone access. This is not a documentation gap — it is a deliberate security policy documented in Apple's extension programming guide.

**The only viable iOS approach is:**
A "Full Access" keyboard extension that displays a "Tap to dictate" button. When tapped, it opens the main container app (via URL scheme or share extension) to perform audio capture and transcription, then returns the text to the keyboard extension via App Group shared storage or UIPasteboard.

This is awkward UX (requires briefly switching to the main app) but it is the only approach that keeps processing on-device. The alternative — using iOS native SFSpeechRecognizer from within the main app, triggered by the Shortcut or a widget — provides a simpler architecture but SFSpeechRecognizer's offline quality for German is significantly below Whisper large-v3-turbo.

**iOS Shortcut approach (alternative, simpler):**
An iOS Shortcut that triggers the container app's dictation action and copies result to clipboard. Works in any text field via iOS's native "Paste" affordance. Worse UX than a keyboard (requires manual Paste) but dramatically simpler to implement and avoids the keyboard extension complexity. **Recommended for Phase 1 iPhone support.**

**Do NOT build:**
- A standalone iOS app without the keyboard or Shortcut integration: it cannot paste at cursor in third-party apps
- A UIInputViewController extension that tries to use AVAudioSession for live recording: iOS will deny microphone access from within the extension process

**Confidence:** HIGH for the technical constraints (microphone block is well-documented). MEDIUM for the recommended workaround (roundtrip UX needs user validation).

---

## Supporting Libraries

| Library | Platform | Version | Purpose | When to Use |
|---------|----------|---------|---------|-------------|
| KeyboardShortcuts | macOS | current | User-configurable global hotkeys | All hotkey registration on Mac |
| AVFoundation | macOS/iOS | built-in | Audio capture | Push-to-talk buffer management |
| LaunchAtLogin-Modern | macOS | current (macOS 13+) | Login item registration | When adding "launch at login" to menu bar app |
| whisper.cpp C API | macOS + Windows | v1.8.4 | ASR inference | Wrap in Swift (macOS) or C# P/Invoke (Windows) |
| llama.cpp C API | macOS + Windows | current | LLM text cleanup | Same wrapping strategy as whisper.cpp |
| WhisperKit | iOS | current | ASR on iPhone | Swift Package Manager only |
| tray-icon (Rust crate) | Windows | v0.22.0 | System tray icon | If Rust is chosen for Windows app |
| global-hotkey (Rust crate) | Windows | v0.7.0 | Global hotkeys on Windows | If Rust is chosen for Windows app |

---

## Architecture: 2-App Split With Shared Models

```
dicticus/
├── models/                    # Shared GGUF files (identical on both platforms)
│   ├── whisper-large-v3-turbo-q5_0.bin
│   ├── gemma-3-1b-it-q4_0.gguf
│   └── phi-3-mini-q4_k_m.gguf
│
├── mac/                       # Native Swift app (macOS 13+)
│   ├── whisper.cpp (Swift bridge)
│   ├── llama.cpp (Swift bridge)
│   ├── KeyboardShortcuts package
│   └── SwiftUI MenuBarExtra
│
├── windows/                   # Native C# or Rust app
│   ├── whisper.cpp (P/Invoke or Rust FFI)
│   ├── llama.cpp (P/Invoke or Rust FFI)
│   ├── RegisterHotKey (Win32)
│   └── SendInput (Win32)
│
└── ios/                       # Native Swift app (iOS 18+)
    ├── WhisperKit (Swift Package)
    └── UIInputViewController (keyboard extension) or Shortcuts action
```

---

## Alternatives Considered and Rejected

| Category | Recommended | Alternative | Why Not |
|----------|-------------|-------------|---------|
| ASR | whisper.cpp + large-v3-turbo | Parakeet TDT | English-only, no German, requires NVIDIA GPU or heavy Python stack |
| ASR | whisper.cpp + large-v3-turbo | faster-whisper | CUDA-only acceleration, no Apple Silicon native path |
| ASR | whisper.cpp + large-v3-turbo | Apple SFSpeechRecognizer | Poor German offline quality, no auto-detection between languages |
| ASR | whisper.cpp + large-v3-turbo | distil-whisper | English-only explicitly |
| LLM | llama.cpp | MLX / mlx-lm | macOS-only, Windows target rules it out |
| LLM | llama.cpp | Ollama | Daemon architecture adds latency, not embeddable |
| Mac app shell | Swift + SwiftUI | Tauri | Web-view overhead for a background-only tool; global hotkey + text injection in Tauri requires significant native plugin code anyway |
| Mac app shell | Swift + SwiftUI | Electron | Even heavier than Tauri, no benefit |
| Cross-platform | 2 native apps | 1 Tauri app | Platform differences in hotkeys/injection too deep for a unified approach to be simpler than two native apps |
| iOS | Shortcut (Phase 1) | Custom keyboard | Custom keyboard cannot access mic; roundtrip architecture is complex for v1 |

---

## Installation Reference

```bash
# macOS: Install whisper.cpp (includes Metal/CoreML support)
brew install whisper-cpp

# Download model (large-v3-turbo q5_0, ~547 MB)
# (Use the script bundled with whisper.cpp)
whisper-cpp-download-ggml-model large-v3-turbo-q5_0

# llama.cpp: Build from source or Homebrew
brew install llama.cpp

# Download Gemma 3 1B (cleanup model, ~1 GB)
# huggingface-cli download google/gemma-3-1b-it-qat-q4_0-gguf
```

---

## Open Questions for Phase-Specific Research

1. **whisper.cpp Swift API**: The repo has `examples/whisper.swiftui` but there is no official `SwiftPackage.swift` exposing a clean Swift API. Confirm whether to use the C header directly via a Swift module map, or use the WhisperKit fallback for macOS too.

2. **llama.cpp Swift API**: Same question — does a stable Swift wrapper exist, or is direct C interop needed?

3. **Paste-at-cursor reliability**: The clipboard-swap + Cmd+V approach is known to fail in some terminal emulators and password fields. Test matrix needed.

4. **Windows LLM latency**: llama.cpp on a typical business laptop CPU (no discrete GPU) with Gemma 3 1B Q4 — is cleanup latency <1s? Needs benchmarking.

5. **WhisperKit iOS model size**: WhisperKit requires models downloaded to device storage. Large-v3-turbo CoreML model is likely 500MB+. Acceptable? Or use smaller model on iOS?

6. **Gemma 3 1B German quality**: No independent German grammar cleanup benchmark found. Must be validated in Phase 1.

---

## Sources

- Parakeet TDT 1.1B model card: https://huggingface.co/nvidia/parakeet-tdt-1.1b (MEDIUM confidence)
- whisper.cpp README + Homebrew formula: https://github.com/ggerganov/whisper.cpp (HIGH confidence)
- distil-whisper large-v3 model card (English-only finding): https://huggingface.co/distil-whisper/distil-large-v3 (HIGH confidence)
- whisper-large-v3-turbo model card: https://huggingface.co/openai/whisper-large-v3-turbo (HIGH confidence)
- GGML pre-converted models list: https://huggingface.co/ggerganov/whisper.cpp (HIGH confidence)
- WhisperKit README: https://github.com/argmaxinc/WhisperKit (HIGH confidence)
- Gemma 3 1B IT QAT GGUF: https://huggingface.co/google/gemma-3-1b-it-qat-q4_0-gguf (HIGH confidence)
- Phi-3 Mini GGUF: https://huggingface.co/microsoft/Phi-3-mini-4k-instruct-gguf (MEDIUM confidence)
- llama.cpp README: https://github.com/ggerganov/llama.cpp (HIGH confidence)
- MLX v0.31.1 release: https://github.com/ml-explore/mlx (HIGH confidence)
- KeyboardShortcuts: https://github.com/sindresorhus/KeyboardShortcuts (HIGH confidence)
- Rectangle (Accessibility requirement verification): https://github.com/rxhanson/Rectangle (HIGH confidence)
- UIInputViewController microphone restriction: General iOS extension documentation (MEDIUM confidence — JS-blocked Apple docs, but cross-verified via known ecosystem constraints)
- RegisterHotKey Win32 API: https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-registerhotkey (HIGH confidence)
- SendInput Win32 API: https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-sendinput (HIGH confidence)
- global-hotkey crate v0.7.0: https://github.com/tauri-apps/global-hotkey (HIGH confidence)
- tray-icon crate v0.22.0: https://github.com/tauri-apps/tray-icon (HIGH confidence)
- Tauri v2.10.1: https://github.com/tauri-apps/tauri (HIGH confidence)
- sherpa-onnx (Parakeet ONNX support): https://github.com/k2-fsa/sherpa-onnx (MEDIUM confidence)
- faster-whisper v1.2.1 (no Apple Silicon GPU): https://github.com/SYSTRAN/faster-whisper (HIGH confidence)
