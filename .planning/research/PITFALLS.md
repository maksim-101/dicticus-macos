# Domain Pitfalls: Local Multi-Platform Dictation App

**Domain:** Fully local ASR + LLM dictation with system-wide text injection
**Researched:** 2026-04-14
**Confidence:** MEDIUM — Apple documentation pages require JavaScript and couldn't be fully rendered; findings cross-validated from GitHub issue trackers, official API docs (SendInput), and project READMEs.

---

## Critical Pitfalls

Mistakes that cause rewrites, blocked distribution, or fundamentally broken UX.

---

### Pitfall 1: App Sandbox Prevents Global Hotkeys and Text Injection

**What goes wrong:** If you build the macOS app as a sandboxed app (required for Mac App Store distribution), the App Sandbox blocks: (a) posting CGEvents to other processes, (b) global input monitoring via `NSEvent.addGlobalMonitorForEventsMatchingMask`, and (c) the `AXUIElement` accessibility APIs that allow injecting text into foreign windows. The app silently fails to paste or receive hotkey events in many scenarios.

**Why it happens:** App Sandbox was designed to prevent exactly what a dictation app needs to do — read your keystrokes globally and write text into another app's text field. These capabilities require entitlements (`com.apple.security.automation.apple-events`, `com.apple.security.temporary-exception.mach-lookup.global-name`) that Apple does not approve for standard App Store submissions.

**Consequences:** If you start with sandboxing enabled, you will build the entire app before discovering that core features don't work. Stripping sandboxing later affects notarization workflow and requires redistribution outside the App Store.

**Prevention:** Build as an **unsigned or notarized-but-not-sandboxed** app distributed directly (DMG/Sparkle), not via the Mac App Store. Decide this on day one. Apps like Rectangle, Ice, and Loop all operate as unsandboxed utilities for exactly this reason.

**Detection:** Test CGEventPost to another app's window in a sandboxed build during scaffolding. If the paste silently does nothing, sandboxing is the culprit.

**Phase:** Scaffolding / Phase 1 architecture decision.

---

### Pitfall 2: Accessibility Permission Is Per-User, Can Be Revoked, and Requires Re-grant After App Update

**What goes wrong:** macOS Accessibility permission (System Settings → Privacy & Security → Accessibility) is granted to a specific binary path and code signature. When you update the app (new build, new code signature), macOS may silently revoke the permission, causing text injection to stop working with no error to the user.

**Why it happens:** macOS ties accessibility grants to the app's code identity. Developer builds (debug) and release builds have different signatures. A macOS update can also reset the ACL.

**Consequences:** Users report "it stopped working after the update" — a UX disaster for a dictation tool that must work reliably every time.

**Prevention:**
- Show a clear "Accessibility permission required" onboarding step with a direct link to the System Settings pane.
- On every app launch, check `AXIsProcessTrustedWithOptions` and surface a persistent warning if the grant is missing.
- Use a consistent bundle identifier and signing identity across releases.
- Do NOT silently swallow accessibility errors — surface them immediately.

**Detection:** Ship to one test machine, update the app binary, verify the permission is still granted. If not, you've confirmed the issue.

**Phase:** Phase 1 (macOS core) — implement permission checks before any other feature.

---

### Pitfall 3: Paste-at-Cursor via Cmd+V Simulation Fails in Specific Apps and Secure Fields

**What goes wrong:** The paste-at-cursor strategy (write text to NSPasteboard, simulate Cmd+V via CGEventPost) is NOT universally reliable. Known failure modes:
- Password fields and secure text fields: macOS blocks programmatic paste into `NSSecureTextField` and similar.
- Terminal.app and some Electron apps intercept keyboard events differently.
- Some apps use a delay between receiving the clipboard change and processing the paste, causing a race condition where the old clipboard content is pasted instead.
- Games and full-screen apps that capture the entire event stream may not receive the synthetic Cmd+V.

**Why it happens:** CGEventPost injects into the system event stream but requires the target app to have focus and properly handle the event. Secure text fields explicitly block programmatic paste. Electron apps run a Chromium event loop that can desync with macOS event timing.

**Consequences:** Users will report "dictation pastes the wrong text" or "nothing happens in [specific app]." This is a long tail of per-app bugs.

**Prevention:**
- Primary strategy: simulate Cmd+V via CGEventPost after a short delay (50–100ms) to allow clipboard to settle.
- Add a configurable delay option for users with slower machines or problematic apps.
- Accept that secure fields will never work and document this clearly.
- For apps where Cmd+V simulation fails, offer a fallback: AXUIElement `kAXValueAttribute` write (direct text insert via accessibility, works in many native AppKit text fields without clipboard involvement).

**Detection:** Test in Terminal, Chrome, Firefox, Electron apps (e.g., VS Code, Slack), and password fields during development.

**Phase:** Phase 1 (macOS core) — design the paste mechanism with fallback from day one.

---

### Pitfall 4: Whisper Hallucinates Text During Silence and Short Recordings

**What goes wrong:** Whisper (and whisper.cpp) generates confabulated text when given silence, background noise, or very short audio clips. For a push-to-talk dictation tool, this is particularly dangerous: if the user holds the hotkey for a fraction of a second, Whisper may return a long hallucinated sentence rather than nothing. Known patterns include repeating the last transcription, generating common phrases, or producing gibberish.

**Sources:** whisper.cpp issues #2629 (hallucinations during silence — merged fix), #3744 (repetition hallucinations), #3729 (infinite sentence duplication), #2901 (text disappearing at clip endings).

**Why it happens:** Whisper is an encoder-decoder architecture trained to always produce output. It was designed for complete audio files, not short push-to-talk clips with potential silence. Without VAD (Voice Activity Detection), it attempts to transcribe silence.

**Consequences:** Users get random text injected at their cursor. This is the single most user-visible bug category for a dictation app.

**Prevention:**
- Implement VAD before passing audio to the ASR model. Silero VAD is a common lightweight option. Only pass audio chunks that contain detected speech.
- Set a minimum audio duration threshold (e.g., discard clips under 0.3 seconds).
- Implement a no-speech probability threshold — Whisper outputs this internally. Discard results where `no_speech_prob > 0.6`.
- Do not use raw audio below a volume threshold.

**Detection:** Record 0.5 seconds of silence, run through the model, check output. If you get any text, hallucination is live in your pipeline.

**Phase:** Phase 1 (ASR pipeline) — implement VAD as a required component, not an optional enhancement.

---

### Pitfall 5: Core ML First-Run Compilation Causes Multi-Second Freeze

**What goes wrong:** When using WhisperKit or whisper.cpp with Core ML backend on Apple Silicon, the first inference run triggers on-device model compilation by the ANE service. This compilation can take 10–60 seconds and blocks the main thread if not handled asynchronously. From the user's perspective, the app appears frozen.

**Sources:** whisper.cpp README: "the first run on a device is slow, since the ANE service compiles the Core ML model to some device-specific format." WhisperKit issues #264 (crash on startup), #300 (duplicate bundle files loaded per call).

**Why it happens:** Core ML's device-specific blob compilation is a one-time cost per device, but happens on first use after installation or model updates. It is not cached across app reinstalls.

**Consequences:** After installation, the first dictation attempt stalls for up to a minute. Users assume the app is broken.

**Prevention:**
- Trigger model warm-up explicitly in the background immediately after app launch (not on first hotkey press).
- Show a "Warming up model..." indicator in the menu bar on first launch.
- Cache the compiled Core ML blob and check for it on startup.
- WhisperKit loads models in the background by default — use this, do not fight it.

**Detection:** Fresh install → immediately press the dictation hotkey → measure time to first response.

**Phase:** Phase 1 (model integration) — warm-up logic must be part of the initial architecture.

---

### Pitfall 6: Language Auto-Detection Is Unreliable for Short Clips

**What goes wrong:** Whisper's language detection runs on the first 30 seconds of audio. For short push-to-talk clips (3–10 seconds), the detection window is the entire clip. For bilingual speakers doing short utterances, detection accuracy degrades significantly — especially when the clip starts with a filler word or pause. German and English can be misidentified (particularly short utterances like "Okay, weiter" or "Yes, danke").

**Sources:** whisper.cpp issue #1800: "the language used at first leads to a translation despite another idiom being dominant." Issue #3317: language auto-detection bug. Issue #1242: feature request to limit detection to a subset of languages.

**Why it happens:** Language detection is based on the distribution of first-token probabilities. Short clips give insufficient signal. Code-switching (German/English within one sentence) is particularly hard.

**Consequences:** A German sentence gets transcribed into English (or translated rather than transcribed). Users lose trust in the tool within minutes.

**Prevention:**
- Restrict language detection to only German and English (pass `language_tokens: ["de", "en"]` or equivalent). This dramatically improves accuracy by eliminating competition from 98 other languages.
- For Parakeet V3 (NVIDIA's model), verify language detection behavior separately — it may behave differently from OpenAI Whisper.
- Consider adding a manual language toggle in the menu bar for cases where auto-detection fails.
- Normalize audio before detection to ensure consistent volume levels.

**Detection:** Record 5-second clips of common short phrases in both languages. Check detection accuracy, especially for phrases that contain words common in both languages.

**Phase:** Phase 1 (ASR pipeline) — language restriction should be set during initial model configuration.

---

### Pitfall 7: Windows UIPI Blocks Text Injection into Elevated Processes

**What goes wrong:** On Windows, `SendInput` is blocked by User Interface Privilege Isolation (UIPI) when the target application is running at a higher integrity level than the dictation app. This means text injection fails silently in UAC-elevated apps (admin command prompts, system utilities, Task Manager, many corporate IT tools). The SendInput documentation states explicitly: "This function fails when it is blocked by UIPI. Note that neither GetLastError nor the return value will indicate the failure was caused by UIPI blocking."

**Sources:** Microsoft official SendInput docs (winuser.h): "Applications are permitted to inject input only into applications that are at an equal or lesser integrity level."

**Why it happens:** UIPI is a Windows security boundary. Normal user-level apps run at "medium" integrity. Elevated (administrator) apps run at "high" integrity. Input injection from medium to high is prohibited.

**Consequences:** The dictation tool does nothing in a large class of common developer/admin scenarios. The failure is completely silent — no error, no log.

**Prevention:**
- Document this as a known limitation: dictation will not work in UAC-elevated applications unless the app itself is elevated.
- Optionally: provide a "Run as Administrator" mode for the dictation service, but warn users this is a security tradeoff.
- Test on Windows against: elevated PowerShell, elevated Command Prompt, Windows Terminal (elevated), and corporate apps.

**Detection:** Open an elevated command prompt, trigger dictation — if nothing is injected, UIPI is blocking.

**Phase:** Windows phase — document this before committing to Windows support to set user expectations.

---

### Pitfall 8: iOS Custom Keyboard Has a 48MB Memory Hard Limit

**What goes wrong:** iOS keyboard extensions are capped at 48MB of RAM. Loading a Whisper model or any neural ASR model locally inside a keyboard extension is impossible — even the smallest Whisper Tiny model requires ~273MB RAM. The OS will silently kill the extension process when it exceeds the limit.

**Sources:** Apple developer documentation (confirmed via community knowledge, documented in multiple iOS extension programming guides). The keyboard extension memory limit is hard and cannot be appealed.

**Why it happens:** iOS keyboard extensions run in a highly constrained process separate from the host app. Apple enforces strict memory limits to prevent keyboard extensions from slowing down the system.

**Consequences:** The "iOS custom keyboard with on-device ASR" approach is fundamentally infeasible for models of the required quality. Any implementation will crash or be killed by the OS.

**Prevention:** Do not attempt to run ASR inside the keyboard extension process. The viable architectures for iOS dictation are:
  1. **App Group / XPC**: Keyboard extension communicates with the main app container via App Group shared storage or XPC. The main app process runs the ASR model (full memory budget). The keyboard extension sends audio, receives text.
  2. **iOS Shortcut**: A Shortcut action can invoke an app extension that runs in the main app process, avoiding the keyboard extension constraint entirely.
  3. **Keyboard + audio file handoff**: Record audio in the keyboard extension (audio capture itself is lightweight), save to App Group container, signal the main app to transcribe.

**Detection:** Attempt to load any ML model inside a keyboard extension target. Watch Xcode memory gauge — it will crash at ~48MB.

**Phase:** iOS phase design — resolve the architecture before writing a line of iOS code.

---

### Pitfall 9: iOS Custom Keyboard Cannot Access Network (Unless User Grants Full Access)

**What goes wrong:** Custom keyboard extensions by default have no network access. Microphone access also requires explicit user permission ("Allow Full Access" toggle in iOS Settings for the keyboard). If Full Access is not granted, the keyboard cannot capture audio or communicate with the host app via XPC in some configurations.

**Sources:** Apple App Extensions programming guide (confirmed from developer community knowledge).

**Why it happens:** Apple's security model treats keyboard extensions as high-risk components (they see everything the user types). Network access is opt-in for privacy reasons.

**Consequences:** Even if you solve the memory problem via XPC, the keyboard extension may not be able to communicate with the main app if the user hasn't granted Full Access. Many users refuse to enable Full Access due to perceived privacy risk (even if the app is fully local).

**Prevention:**
- Design the iOS architecture to be fully functional with local-only operation (no network calls from the keyboard extension).
- Use App Group shared file containers for keyboard → main app communication rather than network-based IPC.
- In the keyboard extension's onboarding, explicitly explain why Full Access is needed and that no data leaves the device.

**Detection:** Install the keyboard extension, do NOT enable Full Access, attempt to trigger dictation — verify failure mode and error handling.

**Phase:** iOS phase — architecture decision before implementation.

---

## Moderate Pitfalls

---

### Pitfall 10: Global Hotkey Registration Relies on Deprecated Carbon APIs

**What goes wrong:** macOS global hotkey registration for arbitrary key combinations still relies on Carbon's `RegisterEventHotKey` API (or libraries like KeyboardShortcuts that wrap it). Apple has deprecated Carbon but not replaced it with a modern equivalent for this use case. This API may break in a future macOS release without warning.

**Sources:** KeyboardShortcuts README: "relies on deprecated Carbon APIs... Apple will presumably provide alternatives before deprecating these further." KeyboardShortcuts is sandboxed-compatible and handles Caps Lock and media key exclusions.

**Why it happens:** The Carbon event hotkey API predates macOS and was never fully modernized. Apple has not shipped a replacement in NSEvent or SwiftUI.

**Prevention:**
- Use a maintained library (KeyboardShortcuts by sindresorhus) rather than calling Carbon directly — this abstracts the API and can be updated when Apple eventually provides a modern replacement.
- Avoid Caps Lock, media keys, and Function keys (F1–F12) as primary hotkey modifiers — these have restrictions in sandboxed and non-sandboxed apps alike.
- Test hotkey registration on every macOS major version beta.

**Phase:** Phase 1 (macOS core) — select the hotkey library before implementing activation.

---

### Pitfall 11: Hotkey Conflicts with Common Developer Tools

**What goes wrong:** Common modifier+key combinations are already claimed by apps the target user (a developer) uses constantly: Cmd+Shift+Space (macOS Spotlight variants), Option+Space (Alfred, Raycast), F5 (browser DevTools), Ctrl+Space (IDEs for autocomplete). Registering a conflicting hotkey silently wins the race most of the time, but may fail intermittently or cause unexpected behavior in the conflicted app.

**Prevention:**
- Use uncommon modifier combinations for defaults: e.g., Fn+key, Hyper key (Caps Lock remapped via Karabiner), or Ctrl+Option+Cmd combinations.
- Make hotkeys fully user-configurable from day one — do not hardcode.
- The KeyboardShortcuts library warns users when a conflict is detected with system shortcuts.

**Phase:** Phase 1 — set configurable hotkeys as a requirement, not a post-MVP feature.

---

### Pitfall 12: WhisperKit Memory Leak When Loading Models Repeatedly

**What goes wrong:** WhisperKit has a documented bug where calling `.loadModels()` multiple times loads duplicate bundle files into memory, causing cumulative memory growth. On a system with other memory-intensive processes (Xcode, Chrome), this can trigger memory pressure and degrade performance.

**Sources:** WhisperKit GitHub issue #300 ("Duplicating .bundle files in memory with each .loadModels() call"), #393 ("CoreML Audio Resource Leak").

**Prevention:**
- Load the ASR model once at startup and keep it warm in memory for the app lifetime. Do not unload/reload between dictation sessions.
- Monitor memory usage in Instruments during a 30-minute usage session with multiple dictation invocations.

**Phase:** Phase 1 (model lifecycle) — design model loading as a singleton that initializes once.

---

### Pitfall 13: Audio Sample Rate Mismatch Degrades Transcription Quality

**What goes wrong:** Whisper expects 16kHz mono audio. Microphones on Apple Silicon Macs typically capture at 44.1kHz or 48kHz. If resampling is not done correctly (or skipped), Whisper transcription quality degrades — it can still produce output but with significantly higher error rates, especially for German.

**Why it happens:** The model's internal feature extraction (mel spectrogram) is calibrated for 16kHz. Feeding it higher sample rate audio without proper resampling is equivalent to feeding it sped-up speech.

**Prevention:**
- Always resample to 16kHz mono before passing to the ASR model.
- Use AVAudioEngine's `installTap` with explicit format conversion, or use `AVAudioConverter` with the target format specified.
- Confirm the format in test output: log the actual sample rate of captured audio before passing to the model.

**Phase:** Phase 1 (audio capture) — set up the audio pipeline with explicit format targeting.

---

### Pitfall 14: Latency Stacking in the ASR → LLM Cleanup Pipeline

**What goes wrong:** The project targets < 2–3 seconds total latency. Each step adds latency that compounds:
- Audio capture buffer flush: 50–200ms
- VAD processing: 20–50ms
- ASR inference (Whisper large on Apple Silicon): 500ms–2s for typical utterance
- LLM cleanup inference (local model): 500ms–3s depending on model size and utterance length
- Clipboard write + paste simulation: 50–100ms

If ASR and LLM are run sequentially on the same GPU/ANE hardware, total latency can easily exceed 4–5 seconds for the "AI cleanup" mode.

**Prevention:**
- Benchmark each step independently before integrating.
- Keep "plain transcription" mode (ASR only, no LLM) as the default hotkey — this eliminates LLM latency entirely.
- For LLM cleanup, use a quantized small model (e.g., Phi-3 Mini 4-bit, Gemma 2B 4-bit) via llama.cpp or MLX. These can process a 50-word sentence in under 1 second on Apple Silicon.
- Run ASR and LLM on separate inference engines if they can use different hardware resources (e.g., ANE for ASR, CPU for small LLM).
- Consider streaming: paste the ASR output immediately, then optionally replace with cleaned-up text when LLM finishes.

**Phase:** Phase 2 (AI cleanup) — establish latency budget before choosing the LLM.

---

### Pitfall 15: macOS 26 Requires Explicit Menu Bar Permission

**What goes wrong:** macOS 26 introduced a new privacy control (System Settings → Menu Bar) that requires apps to be explicitly allowed to display menu bar items. Without this permission, the app runs but its menu bar icon is invisible, making the entire app inaccessible to the user.

**Sources:** stats app README: "macOS 26 introduced a new privacy control under System Settings → Menu Bar. Apps must be explicitly allowed there to display menu bar items."

**Prevention:**
- Add a first-launch onboarding checklist that includes granting Menu Bar permission alongside Microphone and Accessibility permissions.
- If the menu bar icon is not visible, detect this state and notify the user via a notification or popup.

**Phase:** Phase 1 — include in the permissions/onboarding flow.

---

## Minor Pitfalls

---

### Pitfall 16: App Store Distribution Incompatible with Bundled ML Models

**What goes wrong:** Bundling large ML model files (Whisper large-v3 is ~1.6GB as GGUF) inside the app bundle creates a multi-gigabyte download on the Mac App Store. App Store asset delivery limits and review times become significant friction. Additionally, the App Store sandbox requirements (see Pitfall 1) prevent the app from functioning as intended.

**Prevention:** For this project (personal use developer tool), distribute outside the App Store via GitHub Releases or a direct download with Sparkle for auto-updates. This sidesteps both the sandbox and the model size problem. Models can be downloaded post-install (avoiding the huge initial download), stored in `~/Library/Application Support/Dicticus/`.

**Phase:** Phase 1 architecture decision — use Sparkle + direct distribution from the start.

---

### Pitfall 17: iOS Shortcut Approach Has Activation Latency

**What goes wrong:** Triggering dictation on iOS via a Shortcut (Shortcut action → run in background → return text) adds significant activation overhead (1–3 seconds to launch the Shortcut engine) compared to a native keyboard extension. For a tool where speed is the primary UX value, this is noticeable.

**Prevention:** Benchmark the Shortcut activation time on the target device before committing to this approach. If unacceptable, the XPC/App Group architecture (keyboard extension delegates to main app) may feel faster because the main app can be kept warm in memory.

**Phase:** iOS feasibility phase — test before implementation, not after.

---

### Pitfall 18: Windows App Requires Different Text Injection Strategy Per App Type

**What goes wrong:** Windows has multiple application frameworks (Win32, WPF, WinUI, Electron, UWP) each with different text injection reliability. `SendInput` with `VK_PASTE` simulation works in most apps, but UWP apps (Microsoft Store apps) and some WPF apps may require `WM_SETTEXT` or UI Automation's `ValuePattern.SetValue()` instead.

**Prevention:** Design the Windows text injection layer as a strategy chain: try `SendInput` first, fall back to `WM_SETTEXT`, fall back to UI Automation `ValuePattern`. Test across Win32 (Notepad), WPF (one IDE), Electron (VS Code), and UWP (Calculator or a Store app).

**Phase:** Windows phase — accept this as inherent complexity and budget time for per-app-type testing.

---

### Pitfall 19: German Compound Words Cause Whisper Hallucination Cascades

**What goes wrong:** German-specific: long compound words (e.g., "Bundeswirtschaftsministerium") or domain-specific German terminology can cause Whisper to enter a repetition loop where it regenerates the same word or phrase multiple times. This is compounded in the `large-v3-turbo` model variant which has known issues with language detection returning 0 segments.

**Sources:** whisper.cpp issues #3642 (large-v3-turbo returns 0 segments with detect_language), #3729 (infinite duplication for longer recordings).

**Prevention:**
- Use the standard `large-v3` or Parakeet V3 (the model the user already trusts) rather than the turbo variant for German.
- Set `max_initial_timestamp` and `no_speech_threshold` parameters to reduce hallucination likelihood.
- Validate specifically with German compound-heavy speech before considering the ASR component done.

**Phase:** Phase 1 (ASR validation) — German-specific test suite is required.

---

## Phase-Specific Warnings

| Phase Topic | Likely Pitfall | Mitigation |
|---|---|---|
| macOS scaffolding | Sandboxing blocks all core features | Decide on unsandboxed distribution before writing code |
| macOS permissions onboarding | Users skip permission grants; app silently fails | Check all 3 permissions on launch (Accessibility, Microphone, Menu Bar); block until granted |
| Audio capture setup | Wrong sample rate silently degrades quality | Explicitly configure 16kHz mono; log actual format in dev builds |
| ASR pipeline | Silence hallucinations on short clips | Implement VAD and no_speech_prob threshold before first demo |
| ASR pipeline | German language mis-detected | Restrict to {de, en} language set; validate with compound words |
| Model loading | Core ML first-run freeze | Warm up model at app launch in background; show status indicator |
| Model lifecycle | Memory leak from repeated model loads | Load model once, keep warm; instrument with Xcode memory profiler |
| Hotkey system | Carbon API deprecation risk | Use KeyboardShortcuts library; make hotkeys fully configurable |
| Hotkey system | Conflicts with Raycast/Alfred/Spotlight | Default to uncommon modifier combos; warn on conflicts |
| Paste-at-cursor | Clipboard race conditions | Add 50–100ms delay after clipboard write; test in 5+ apps |
| AI cleanup mode | Latency stacking exceeds 3s budget | Benchmark ASR and LLM independently; use quantized small LLM |
| iOS architecture | Keyboard extension memory limit | Resolve architecture (App Group XPC vs Shortcut) before any iOS code |
| iOS permissions | Full Access requirement alarming to users | Explain local-only in onboarding; design to work without Full Access where possible |
| Windows text injection | UIPI blocks elevated processes | Document as known limitation; test against elevated terminal early |
| Windows text injection | Different APIs per app framework | Implement strategy chain: SendInput → WM_SETTEXT → UI Automation |
| Distribution | Bundled model size makes App Store impractical | Commit to direct distribution + Sparkle on day one |

---

## Sources

- whisper.cpp GitHub issues: https://github.com/ggml-org/whisper.cpp/issues (hallucinations #2629, #3729, #3744; language detection #1800, #3317; VAD #3278; large-v3-turbo #3642) — MEDIUM confidence
- WhisperKit GitHub issues: https://github.com/argmaxinc/WhisperKit/issues (memory leak #300, Core ML resource leak #393, startup crash #264) — MEDIUM confidence
- whisper.cpp README memory table (tiny ~273MB, small ~852MB, large ~3.9GB) — HIGH confidence
- Whisper VRAM requirements discussion: https://github.com/openai/whisper/discussions/5 — MEDIUM confidence
- SendInput UIPI documentation: https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-sendinput — HIGH confidence
- KeyboardShortcuts README (Carbon API note, Caps Lock limitation, sandboxing compatibility): https://github.com/sindresorhus/KeyboardShortcuts — HIGH confidence
- Whisper speculative decoding blog (latency data, architecture): https://huggingface.co/blog/whisper-speculative-decoding — MEDIUM confidence
- stats app README (macOS 26 Menu Bar permission gate): https://github.com/exelban/stats — MEDIUM confidence
- Rectangle README (Accessibility permission reset procedures): https://github.com/rxhanson/Rectangle — MEDIUM confidence
- iOS keyboard extension memory limit (48MB): community-confirmed, developer knowledge — MEDIUM confidence (official Apple docs require JavaScript to render)
- iOS Full Access requirement for network/IPC in keyboard extensions: Apple developer documentation — MEDIUM confidence
