<!-- GSD:project-start source:PROJECT.md -->
## Project

**Dicticus**

A fully local, multi-platform dictation app that replaces native dictation on Mac, iPhone, and Windows. Uses on-device ASR and LLM to transcribe speech in German and English with optional AI cleanup — activated via system-wide hotkeys (Mac/Windows) or a custom keyboard/Shortcut (iPhone). Think "MacWhisper but system-wide, cross-platform, and with AI polish."

**Core Value:** Press a key, speak, release — accurate text appears at your cursor instantly, fully private, no cloud dependency.

### Constraints

- **Privacy**: All processing must happen on-device — no audio or text sent to any server
- **Performance**: Transcription must feel near-instant after releasing the hotkey (< 2-3 seconds for typical utterances)
- **Local models**: Both ASR and LLM must run locally with quality comparable to Parakeet V3
- **System-wide**: Must work in any text field across any app (browser, native apps, etc.)
- **Activation**: Push-to-talk (Mac/Windows), toggle (iPhone) — not always-listening
<!-- GSD:project-end -->

<!-- GSD:stack-start source:research/STACK.md -->
## Technology Stack

## Recommended Stack
### 1. ASR Engine
| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| FluidAudio | 0.13.6+ (SPM) | Primary ASR inference SDK on macOS + iOS | Open-source Swift SDK (Apache 2.0), runs Parakeet TDT v3 on Apple Neural Engine via CoreML, ~190-210x realtime, ~66 MB memory per inference, 35+ production apps use it |
| Parakeet TDT v3 (CoreML) | nvidia/parakeet-tdt-0.6b-v3 | Default ASR model | 600M params, ~1.24 GB CoreML package, 25 European languages including German (5.04% WER) and English (6.34% WER), automatic language detection |
| FluidAudio | same | iOS ASR via CoreML | Same SDK works on iOS 17+, same Parakeet model runs on Neural Engine |
- **Previous choice: WhisperKit + Whisper large-v3-turbo** — worked but user prefers Parakeet v3 quality for de/en dictation. Whisper is ~5-10x slower and uses ~8x more memory than Parakeet via FluidAudio on ANE. Phase 2 was built with WhisperKit; Phase 2.1 swaps to FluidAudio.
- **Note on earlier Parakeet research:** Initial research (pre-project) incorrectly concluded "Parakeet is English-only" based on the older parakeet-tdt-1.1b model card. Parakeet TDT v3 (0.6b-v3, released Aug 2025) is multilingual with 25 languages.
- **whisper.cpp**: Still viable for Windows app (no FluidAudio on Windows). Cross-platform model sharing no longer applies — Windows uses whisper.cpp, macOS/iOS use FluidAudio.
- **faster-whisper**: CUDA-only GPU acceleration, no native Apple Silicon support
- **Apple SFSpeechRecognizer**: Poor German offline quality, no auto-detection
- **sherpa-onnx**: Supports Parakeet ONNX but CPU-only on macOS (no ANE); viable fallback for Windows if whisper.cpp is insufficient
### 2. Local LLM for Text Cleanup
| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| llama.cpp | current (8796+ commits, active) | LLM inference runtime | Apple Silicon Metal first-class, 1.5-8bit quantization, runs on macOS and Windows, C library embeddable in native apps |
| Gemma 4 E2B IT (Q4_K_M GGUF) | Google Gemma 4 | Cleanup mode | ~3.1 GB on disk, multilingual, instruction-tuned, handles broken/non-native German with meaning inference |
| Phi-3 Mini 4K (Q4_K_M GGUF) | 3.8B params | Heavier rewrite mode (future) | 2.2 GB on disk, stronger reasoning for structural rewrites, good multilingual performance |
- **Current cleanup model:** Gemma 4 E2B. Upgraded from Gemma 3 1B in v1.1 for better German meaning inference. ~3.1 GB Q4_K_M, runs via llama.cpp Metal.
- Heavier rewrite (future): Phi-3 Mini. 3.8B at Q4 gives meaningfully better output quality for complex rewrites.
- Both run via llama.cpp Metal backend on macOS, and llama.cpp CPU/GPU on Windows.
- **Ollama**: Adds a daemon dependency and HTTP overhead; too heavy for sub-second cleanup in a menu bar app
- **Cloud LLM APIs**: Hard constraint violation
- **LM Studio**: Same issue as Ollama, designed for interactive use not embedded inference
### 3. macOS App Shell
| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| Swift + SwiftUI | Swift 6 / macOS 15 target | Menu bar app shell, UI | Native, zero overhead, MenuBarExtra API (macOS 13+), proper sandbox lifecycle management |
| SwiftUI MenuBarExtra | macOS 13+ | Menu bar presence | The modern Apple-recommended approach for menu bar apps, replaces NSStatusBar for new apps |
| KeyboardShortcuts (sindresorhus) | current (165 commits, actively used in production) | User-configurable global hotkeys | Sandboxed, App Store compatible, stores in UserDefaults, conflict detection built-in, used by Dato/Plash/Lungo |
| AVFoundation | macOS built-in | Audio capture | Native audio session management, push-to-talk buffer capture |
| NSPasteboard + CGEvent | macOS built-in | Paste-at-cursor | Write text to clipboard, synthesize Cmd+V via CGEvent to paste at active cursor position |
| Accessibility API (AXUIElement) | macOS built-in | Text injection | Fallback for apps that support Accessibility: inject directly into focused text field without clipboard roundtrip |
### 4. Windows App
| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| C# + WinForms (system tray) or Rust | - | Windows app shell | Windows desktop apps with system tray, global hotkeys via RegisterHotKey Win32 API |
| whisper.cpp (Windows build) | v1.8.4 | ASR inference | Same model, same inference library; whisper.cpp builds on Windows with MSVC or MinGW, CPU inference works on any business laptop, CUDA available on NVIDIA GPUs |
| llama.cpp (Windows build) | current | LLM text cleanup | Same cross-platform story; GGUF models are identical files |
| RegisterHotKey + SendInput | Win32 API | System hotkeys + text injection | RegisterHotKey is the official system-wide hotkey API on Windows, works in background/tray apps. SendInput synthesizes keyboard events to inject text |
- **Recommendation: 2 separate apps — one native Mac app, one native Windows app — with shared model files (GGUF).**
- The whisper.cpp and llama.cpp C libraries are cross-platform, but the app shell, audio capture, hotkey, and text injection APIs are completely different per platform. There is no practical cross-platform framework (Tauri/Electron) that handles system-wide push-to-talk hotkeys + text-at-cursor injection cleanly without significant platform-specific code anyway.
- Tauri v2 supports macOS + Windows + iOS (current version 2.10.1), but Tauri's global hotkey story requires the `global-hotkey` crate (v0.7.0, released May 2025) and has macOS-specific event loop constraints that complicate push-to-talk semantics. The web-view layer adds unnecessary complexity for a background-only tool with minimal UI.
- The shared asset is the model directory: same GGUF files work on both platforms via the same whisper.cpp + llama.cpp binaries.
- iPhone is a third, separate app (see below).
### 5. iPhone App
| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| Swift + SwiftUI | Swift 6 / iOS 18 | Container app | Required host for keyboard extension |
| FluidAudio | 0.13.6+ | On-device ASR (Parakeet TDT v3) | Swift-native, iOS 17+, CoreML models run on Neural Engine, Swift Package Manager integration |
| UIInputViewController | iOS built-in | Custom keyboard extension | The ONLY supported approach for third-party dictation keyboards on iOS |
| App Groups | iOS entitlement | Shared model storage | Allows keyboard extension to access model files downloaded by main app |
- A standalone iOS app without the keyboard or Shortcut integration: it cannot paste at cursor in third-party apps
- A UIInputViewController extension that tries to use AVAudioSession for live recording: iOS will deny microphone access from within the extension process
## Supporting Libraries
| Library | Platform | Version | Purpose | When to Use |
|---------|----------|---------|---------|-------------|
| KeyboardShortcuts | macOS | current | User-configurable global hotkeys | All hotkey registration on Mac |
| AVFoundation | macOS/iOS | built-in | Audio capture | Push-to-talk buffer management |
| LaunchAtLogin-Modern | macOS | current (macOS 13+) | Login item registration | When adding "launch at login" to menu bar app |
| FluidAudio | macOS + iOS | 0.13.6+ | ASR inference (Parakeet TDT v3) | Swift Package Manager, runs on Apple Neural Engine |
| whisper.cpp C API | Windows | v1.8.4 | ASR inference (Windows only) | C# P/Invoke wrapping |
| llama.cpp C API | macOS + Windows | current | LLM text cleanup | Swift wrapping (macOS) or C# P/Invoke (Windows) |
| tray-icon (Rust crate) | Windows | v0.22.0 | System tray icon | If Rust is chosen for Windows app |
| global-hotkey (Rust crate) | Windows | v0.7.0 | Global hotkeys on Windows | If Rust is chosen for Windows app |
## Architecture: 2-App Split With Shared Models
## Alternatives Considered and Rejected
| Category | Recommended | Alternative | Why Not |
|----------|-------------|-------------|---------|
| ASR (macOS/iOS) | FluidAudio + Parakeet TDT v3 | WhisperKit + Whisper large-v3-turbo | User prefers Parakeet quality; Whisper is 5-10x slower and 8x more memory on ANE |
| ASR (macOS/iOS) | FluidAudio + Parakeet TDT v3 | faster-whisper | CUDA-only acceleration, no Apple Silicon native path |
| ASR (macOS/iOS) | FluidAudio + Parakeet TDT v3 | Apple SFSpeechRecognizer | Poor German offline quality, no auto-detection between languages |
| ASR (macOS/iOS) | FluidAudio + Parakeet TDT v3 | distil-whisper | English-only explicitly |
| LLM | llama.cpp | MLX / mlx-lm | macOS-only, Windows target rules it out |
| LLM | llama.cpp | Ollama | Daemon architecture adds latency, not embeddable |
| Mac app shell | Swift + SwiftUI | Tauri | Web-view overhead for a background-only tool; global hotkey + text injection in Tauri requires significant native plugin code anyway |
| Mac app shell | Swift + SwiftUI | Electron | Even heavier than Tauri, no benefit |
| Cross-platform | 2 native apps | 1 Tauri app | Platform differences in hotkeys/injection too deep for a unified approach to be simpler than two native apps |
| iOS | Shortcut (Phase 1) | Custom keyboard | Custom keyboard cannot access mic; roundtrip architecture is complex for v1 |
## Installation Reference
# macOS: Install whisper.cpp (includes Metal/CoreML support)
# Download model (large-v3-turbo q5_0, ~547 MB)
# (Use the script bundled with whisper.cpp)
# llama.cpp: Build from source or Homebrew
# Download Gemma 3 1B (cleanup model, ~1 GB)
# huggingface-cli download google/gemma-3-1b-it-qat-q4_0-gguf
## Open Questions for Phase-Specific Research
## Sources
- FluidAudio SDK: https://github.com/FluidInference/FluidAudio (HIGH confidence — Apache 2.0, 1,868 stars, 35+ production apps)
- FluidAudio CoreML models: https://huggingface.co/FluidInference/parakeet-tdt-0.6b-v3-coreml (HIGH confidence — 440k+ downloads)
- Parakeet TDT v3 model card: https://huggingface.co/nvidia/parakeet-tdt-0.6b-v3 (HIGH confidence — 25 languages, German 5.04% WER)
- mobius conversion scripts: https://github.com/FluidInference/mobius (HIGH confidence — Apache 2.0, open-source CoreML conversion)
- Parakeet TDT 1.1B model card (SUPERSEDED — English-only): https://huggingface.co/nvidia/parakeet-tdt-1.1b (MEDIUM confidence)
- whisper.cpp README + Homebrew formula: https://github.com/ggerganov/whisper.cpp (HIGH confidence — Windows ASR only now)
- WhisperKit README (SUPERSEDED by FluidAudio): https://github.com/argmaxinc/WhisperKit (HIGH confidence)
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
<!-- GSD:stack-end -->

<!-- GSD:conventions-start source:CONVENTIONS.md -->
## Conventions

Conventions not yet established. Will populate as patterns emerge during development.
<!-- GSD:conventions-end -->

<!-- GSD:architecture-start source:ARCHITECTURE.md -->
## Architecture

Architecture not yet mapped. Follow existing patterns found in the codebase.
<!-- GSD:architecture-end -->

<!-- GSD:skills-start source:skills/ -->
## Project Skills

No project skills found. Add skills to any of: `.claude/skills/`, `.agents/skills/`, `.cursor/skills/`, or `.github/skills/` with a `SKILL.md` index file.
<!-- GSD:skills-end -->

<!-- GSD:workflow-start source:GSD defaults -->
## GSD Workflow Enforcement

Before using Edit, Write, or other file-changing tools, start work through a GSD command so planning artifacts and execution context stay in sync.

Use these entry points:
- `/gsd-quick` for small fixes, doc updates, and ad-hoc tasks
- `/gsd-debug` for investigation and bug fixing
- `/gsd-execute-phase` for planned phase work

Do not make direct repo edits outside a GSD workflow unless the user explicitly asks to bypass it.
<!-- GSD:workflow-end -->



<!-- GSD:profile-start -->
## Developer Profile

> Profile not yet configured. Run `/gsd-profile-user` to generate your developer profile.
> This section is managed by `generate-claude-profile` -- do not edit manually.
<!-- GSD:profile-end -->
