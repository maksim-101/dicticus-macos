# Project Research Summary

**Project:** Dicticus v2.0 — iOS App (iPhone + iPad)
**Domain:** Native iOS dictation app with on-device ML, App Intents/Shortcuts activation, and clipboard text delivery
**Researched:** 2026-04-21
**Confidence:** HIGH

## Executive Summary

Dicticus v2.0 is an iOS companion to the existing macOS menu bar app, delivering fully private, on-device speech-to-text via Apple's Shortcuts framework and Action Button. The technical foundation is already proven on macOS: FluidAudio 0.13.6+ running Parakeet TDT v3 (CoreML, Neural Engine) for ASR, GRDB for history storage, and Swift 6 / SwiftUI throughout. The iOS port reuses this stack directly — FluidAudio is officially iOS 17+ compatible and runs the same CoreML model on the Neural Engine. The activation model is fundamentally different from macOS: iOS has no global hotkeys, so the canonical solution is `AudioRecordingIntent` (App Intents framework, iOS 16+) surfaced via Shortcuts, Action Button (iPhone 15 Pro+), Siri, and Back Tap. Text is delivered via `UIPasteboard`, with the transcript also returned as a Shortcut output string for automation chaining.

The recommended architecture is a phased extraction strategy: first move platform-agnostic services (`DictionaryService`, `HistoryService`, `TextProcessingService`, `ITNUtility`, shared models) from `macOS/` to a new `Shared/` directory that both targets compile directly (not as a local SPM package — App Intents metadata extraction requires intent types in the main target's compilation unit). The iOS target then adds thin platform adapters: `iOSAudioCaptureService`, `iOSModelWarmupService`, `iOSPermissionManager`, `ClipboardOutputService`, and the `DictateIntent` AppIntent entry point. AI cleanup (llama.cpp + Gemma 4 E2B) is explicitly deferred to iOS v2.x — the ~3.1 GB GGUF model is too large for typical iPhone RAM budgets and the inference path has no CoreML acceleration.

The dominant risks are iOS-specific and non-obvious: `AudioRecordingIntent` requires a Live Activity to be started before recording begins or iOS silently terminates the audio session; the App Intents framework enforces a hard 30-second execution timeout that constrains recording duration to ~20 seconds on a pre-warmed model; Parakeet TDT v3's CoreML model can cause jetsam OOM kills on 4 GB iPhones (iPhone 12/13 base) without the `increased-memory-limit` entitlement; and the model's 2.69 GB download must be wrapped in a consent-and-progress UI before any production release. All of these are avoidable with correct architecture choices made upfront, but retrofitting them later is costly.

## Key Findings

### Recommended Stack

The iOS app reuses the macOS stack wherever possible. FluidAudio 0.13.6+ (same SPM package) runs Parakeet TDT v3 via CoreML on the Neural Engine with identical API patterns on iOS 17+. GRDB 7.x handles transcription history via SQLite/FTS5. The new iOS-specific additions are the App Intents framework (first-party, no third-party dependency) for Shortcuts/Action Button/Siri activation, ActivityKit for Live Activities (mandatory for `AudioRecordingIntent`), UIPasteboard for text delivery, and AVAudioSession with `.record` category for audio capture. The xcodegen `project.yml` pattern already established for macOS is extended to add a separate `iOS/project.yml` with an `iOS 17.0` deployment target. No llama.cpp, no Sparkle, no KeyboardShortcuts, no LaunchAtLogin on iOS v2.0.

**Core technologies:**
- **FluidAudio 0.13.6+**: ASR inference via Parakeet TDT v3 on Neural Engine — same SDK as macOS, iOS 17+ confirmed, 190-210x realtime, ~66 MB RAM per inference
- **App Intents framework (Apple built-in)**: Shortcut/Action Button/Siri activation — `AudioRecordingIntent` conformance, `openAppWhenRun = true` is mandatory for microphone access
- **ActivityKit (Apple built-in)**: Live Activity for recording indicator — mandatory requirement of `AudioRecordingIntent`, Dynamic Island compact view
- **AVFoundation / AVAudioSession**: Audio capture with `.record` category — iOS requires explicit session category and `setActive(true)`, unlike macOS
- **UIPasteboard (Apple built-in)**: Text delivery to clipboard plus Shortcut return value — both paths needed simultaneously
- **GRDB 7.x**: Transcription history and dictionary storage — shared from macOS, placed in App Groups container (`group.com.dicticus`)
- **xcodegen**: iOS target added to existing project via separate `iOS/project.yml`

### Expected Features

**Must have (table stakes):**
- FluidAudio + Parakeet TDT v3 ASR on iOS — core feature without which nothing works
- Model download on first launch (2.69 GB / ~1.24 GB compressed) — cannot be bundled, must have progress UI with consent and Wi-Fi warning
- Microphone permission priming with contextual explanation before system prompt
- `DictateIntent` conforming to `AudioRecordingIntent` — enables Shortcut, Action Button, and Siri activation
- Live Activity with Dynamic Island waveform — mandatory for `AudioRecordingIntent`, not optional
- Clipboard output (`UIPasteboard.general.string`) plus Shortcut return value (`String`)
- Custom dictionary (find-replace via `DictionaryService` from `Shared/`) — already ships on macOS, expected by iOS users
- Onboarding covering mic permission, model download, and Action Button setup guide
- Universal app (iPhone + iPad) — low incremental cost with SwiftUI size-class adaptation

**Should have (competitive):**
- iCloud custom dictionary sync (`NSUbiquitousKeyValueStore`) — no competitor offers cross-device local-dictionary sync
- Action Button guided setup wizard — Wispr Flow's wizard shows high activation rates; required for discoverability
- Transcription history (port `HistoryService` from `Shared/`) — Google Eloquent offers this; clipboard overwrites happen
- Siri phrase activation via `AppShortcutsProvider` — hands-free use case, low implementation cost
- Control Center widget (`ControlWidget`, iOS 18+) — covers users without Action Button hardware
- Back Tap setup instructions — no code required, just onboarding guidance

**Defer (v2+):**
- AI cleanup on iOS — llama.cpp GGUF has no CoreML acceleration path; 3.1 GB model is impractical for iPhone RAM
- Custom keyboard extension (text-at-cursor) — iOS blocks microphone in `UIInputViewController`; complex IPC bounce architecture (v2.1 milestone)
- Cloud sync of transcription history — privacy constraint; CloudKit private database is viable v2.x path
- Swiss German ASR — separate milestone

### Architecture Approach

The iOS app follows a three-layer architecture: a thin `DictateIntent` AppIntent entry point in `iOS/`, platform-agnostic service logic in the new `Shared/` directory (compiled directly into both targets, not as an SPM package), and iOS-specific platform adapters in `iOS/`. The primary data flow is: Shortcut triggers `DictateIntent.perform()` → app foregrounds → Live Activity starts → `iOSAudioCaptureService` records → `TranscriptionService` runs Parakeet TDT v3 → `TextProcessingService` applies dictionary and ITN → text written to `UIPasteboard` and returned as Shortcut output. Dictionary data uses `UserDefaults(suiteName: "group.com.dicticus")` (App Groups) so it is accessible to future extensions. Model files are stored in the main app container (not App Groups — model is too large and not shared across platforms).

**Major components:**
1. `DictateIntent` (`iOS/`) — `AudioRecordingIntent` conformance, orchestrates full dictation pipeline, `openAppWhenRun = true`
2. `iOSAudioCaptureService` (`iOS/`) — AVAudioSession `.record` category, AVAudioEngine tap, interruption handling
3. `iOSModelWarmupService` (`iOS/`) — async model download and CoreML compilation on first launch, pre-warm on app foreground
4. `TranscriptionService` (`Shared/`) — FluidAudio ASR pipeline, extracted from macOS target
5. `TextProcessingService` + `DictionaryService` + `ITNUtility` (`Shared/`) — post-processing chain, UserDefaults suite migrated to App Groups
6. `DictationAttributes` + Live Activity (`iOS/`) — ActivityKit recording indicator for `AudioRecordingIntent` compliance
7. `ClipboardOutputService` (`iOS/`) — `UIPasteboard.general` write plus Shortcut result return

### Critical Pitfalls

1. **`AudioRecordingIntent` without Live Activity silently kills the audio session** — Start a Live Activity via ActivityKit at the top of `perform()` before any AVAudioSession activation. Simulator is more permissive and will mislead you.

2. **App Intents 30-second execution timeout** — Cap recording at 20 seconds maximum. Pre-warm ASR model in main app on foreground so inference is ~200ms warm, not 4-5 seconds cold. Never load the model inside `perform()`.

3. **Parakeet TDT v3 OOM jetsam on 4 GB iPhones (iPhone 12/13 base)** — Request `com.apple.developer.kernel.increased-memory-limit` entitlement early. Wrap CoreML inference in `@autoreleasepool`. Unload model when app backgrounds. Test on real 4 GB hardware.

4. **`openAppWhenRun = false` with microphone recording** — Set `static var openAppWhenRun: Bool = true` unconditionally on `DictateIntent`. Background App Intents cannot acquire AVAudioSession with `.record` category. Works in Simulator, fails on device.

5. **2.69 GB model download without consent or progress UI** — Never call `downloadAndLoad` without a dedicated onboarding screen showing size, Wi-Fi check, URLSession progress, and retry on error.

## Implications for Roadmap

Based on research, the natural phase structure follows the dependency chain: infrastructure and shared code first, then core recording/ASR pipeline, then model management UX, then full feature integration, then polish and distribution.

### Phase 1: App Intent Scaffolding + Shared Code Extraction

**Rationale:** The AppIntent architecture decisions must be made first — `openAppWhenRun = true`, `AudioRecordingIntent` conformance, Live Activity requirement, and Shortcut return type. Getting these wrong requires rearchitecting later. Shared code extraction must happen before any iOS code can compile. These have no dependencies on ASR or model management.

**Delivers:** A working iOS target in Xcode that compiles. A bare `DictateIntent` that foregrounds the app and returns a hardcoded string. `Shared/` extracted and both macOS + iOS targets building cleanly.

**Addresses:** Shortcut activation, Siri activation, Action Button activation (all table stakes)
**Avoids:** Pitfall 1 (Live Activity mandate), Pitfall 4 (`openAppWhenRun`), App Intents + SPM static library issue, Shortcut output type mismatch

### Phase 2: CoreML + Audio Pipeline

**Rationale:** The ASR pipeline is core value. This phase wires `iOSAudioCaptureService` (AVAudioSession, interruption handling), `iOSModelWarmupService` (async CoreML load), and `TranscriptionService` together. Memory management for 4 GB devices and the 30-second App Intent timeout budget must both be verified on real hardware here.

**Delivers:** End-to-end dictation working on real iPhone via Shortcut: Action Button → app foregrounds → records → Parakeet transcribes → clipboard output.

**Uses:** FluidAudio 0.13.6+, AVFoundation, ActivityKit, App Groups entitlement
**Avoids:** Pitfall 2 (30s timeout, 20s recording cap), Pitfall 3 (OOM on 4 GB devices), AVAudioSession interruption handling, CoreML cold load on main thread, session deactivation, FluidAudio App Groups path (verify on day 1)

### Phase 3: Model Download UX + Onboarding

**Rationale:** Cannot ship to TestFlight without this. The 2.69 GB download without progress UI is the most likely beta abandonment trigger. Must be informed by real timing data measured in Phase 2.

**Delivers:** Complete first-run onboarding — mic permission priming, model download screen with URLSession progress + Wi-Fi warning + retry, Action Button setup guide, model compilation feedback.

**Addresses:** Model download (table stakes), microphone permission priming (table stakes), Action Button setup wizard (differentiator)
**Avoids:** Surprise download without consent, HuggingFace re-download on reinstall

### Phase 4: Post-Processing + Dictionary + History

**Rationale:** DictionaryService and TextProcessingService are extracted to `Shared/` in Phase 1, but need UserDefaults suite migration to App Groups and iOS wiring. History follows the same pattern. Completes the dictation quality story.

**Delivers:** Custom dictionary working on iOS (find-replace corrections applied to every transcription). Transcription history view. UserDefaults suiteName correctly set for future extension access.

**Addresses:** Custom dictionary (table stakes), transcription history (differentiator), ITN number normalization
**Avoids:** `#if os()` misuse in shared code, xcodegen iOS target missing SPM deps, UserDefaults not using App Group suite

### Phase 5: Universal App + App Store Submission Prep

**Rationale:** iPad layout adaptation is low-effort but must be tested before distribution. App Store review rejection for "can't test core feature" requires an in-app Record button proactively, not after rejection.

**Delivers:** Usable layout on iPad (centered card, `.frame(maxWidth: 480)` minimum). In-app "Start Dictation" button as fallback activation path. Complete `Info.plist` with all required usage descriptions. TestFlight-ready build via `scripts/build-ipa.sh`.

**Addresses:** Universal app (table stakes), App Store distribution
**Avoids:** iPad layout breakage, App Store rejection for missing in-app activation path

### Phase Ordering Rationale

- Phase 1 before Phase 2: Xcode target structure and App Intent architecture must compile before ASR code is added. Shared code extraction is a prerequisite for the iOS target.
- Phase 2 before Phase 3: Cannot design onboarding experience without knowing actual model load times on real devices. Onboarding UI must be informed by measured latency.
- Phase 4 after Phase 2: DictionaryService and HistoryService require the transcription pipeline to exist before end-to-end wiring and testing.
- Phase 5 last: iPad polish and App Store prep are finishing work that requires the full feature set to be stable.
- macOS app remains unchanged throughout: all shared code extraction is additive. macOS must pass its 158 tests after each extraction step.

### Research Flags

Phases likely needing deeper research during planning:
- **Phase 2:** CoreML memory management on 4 GB iPhones — `increased-memory-limit` entitlement approval process is not fully documented. FluidAudio's App Groups storage path behavior is MEDIUM confidence (not in public docs — verify on day 1).
- **Phase 3:** HuggingFace rate limits in production and geographic restrictions — consider CDN mirror strategy for beta distribution.
- **Phase 5:** App Store review for CoreML model download apps — reviewer guidance for "model is not code" clarification.

Phases with standard patterns (skip deep research):
- **Phase 1:** App Intents scaffolding is well-documented in official Apple docs and confirmed via Context7. `AudioRecordingIntent` pattern is clear.
- **Phase 4:** GRDB shared code extraction follows established patterns already used on macOS. UserDefaults suite migration is a one-line change per file.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | FluidAudio iOS requirements confirmed via Context7 + official docs. App Intents confirmed via Apple docs + WWDC. Model size verified via HuggingFace file listing. |
| Features | HIGH (table stakes), MEDIUM (UX specifics) | Competitor analysis based on live Wispr Flow + Google Eloquent docs. Permission priming research is industry studies. |
| Architecture | HIGH | Derived from existing macOS codebase (directly inspected) + official Apple docs. App Intents SPM pitfall confirmed via Apple Developer Forums. |
| Pitfalls | HIGH (critical), MEDIUM (two) | 30s timeout confirmed via Apple Feedback Assistant reports. FluidAudio App Groups path (Pitfall 12) is MEDIUM — needs Phase 2 verification. |

**Overall confidence:** HIGH

### Gaps to Address

- **FluidAudio storage path with App Groups:** `AsrModels.downloadAndLoad(to:)` custom path API exists but App Groups container interaction is not documented. Verify file paths on day 1 of Phase 2; file an issue with FluidAudio if override doesn't work.
- **`increased-memory-limit` entitlement approval:** Requires Apple Developer Portal configuration. Initiate the request at project start, not when OOM crashes appear in production.
- **App Intent 30-second budget on iPhone 13 cold start:** FluidAudio benchmarks show 5.2s cold load on iPhone 13. With 20s recording cap + 2s inference + overhead, the budget is tight. Measure actual end-to-end timing on real iPhone 13 in Phase 2.
- **iOS 26 audio recording enhancements (WWDC25):** If iOS 26 relaxes `AudioRecordingIntent` constraints or the 30-second timeout, Phase 2 architecture may have more flexibility. Monitor Apple fall 2025 release notes.

## Sources

### Primary (HIGH confidence)
- FluidAudio GitHub + Context7 `/fluidinference/fluidaudio` — iOS 17+ requirements, `downloadAndLoad(to:)` API, cold/warm load benchmarks
- HuggingFace `FluidInference/parakeet-tdt-0.6b-v3-coreml` — model size (2.69 GB total, ~1.24 GB compressed)
- Apple Developer Documentation — App Intents, `AudioRecordingIntent`, `openAppWhenRun`, `ForegroundContinuableIntent`, ActivityKit, App Groups entitlement
- Apple Feedback Assistant FB12016280, FB11697381 — 30-second App Intent timeout (multiple developer confirmations)
- Wispr Flow product documentation — Action Button setup, Shortcut activation, clipboard/return value patterns
- apple/ml-stable-diffusion issue #291 — CoreML OOM on 4 GB iOS devices (real device data)
- XcodeGen documentation (Context7) — multi-target project.yml, entitlements, App Groups
- macOS Dicticus codebase (directly inspected) — existing service patterns, 158 tests, shared code candidates

### Secondary (MEDIUM confidence)
- Apple Developer Forums thread #756507 — microphone recording fails from Shortcuts (consistent with framework docs)
- Apple Developer Forums thread #723623 — `openAppWhenRun` behavior confirmation
- Apple Developer Forums thread #759160 — App Intents + SPM static library metadata extraction issue
- XcodeGen GitHub issue #1460 — dynamic SPM framework embedding bug
- appcues.com + NN/g — 81% lift with contextual mic permission request (industry studies)

### Tertiary (LOW confidence)
- WWDC25 session on audio recording (iOS 26) — referenced in FEATURES.md sources; iOS 26 release not yet confirmed; monitor Apple fall 2025

---
*Research completed: 2026-04-21*
*Ready for roadmap: yes*
