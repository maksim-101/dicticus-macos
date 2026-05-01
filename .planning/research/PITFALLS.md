# Domain Pitfalls: v2.0 iOS App — Shortcut-Based Dictation with On-Device ML

**Domain:** Adding iOS dictation app (Shortcut activation + FluidAudio/CoreML Parakeet v3) to an existing macOS Swift project
**Researched:** 2026-04-21
**Confidence:** MEDIUM-HIGH — cross-referenced from Apple Developer Forums, FluidAudio documentation, official Apple docs, stable-diffusion iOS post-mortems, and community issue threads. iOS-specific CoreML constraints confirmed from multiple sources; FluidAudio App Groups behavior unconfirmed (not in public docs).

---

## Critical Pitfalls

Mistakes that block the feature entirely, cause crashes on real devices, or fail App Store review.

---

### Pitfall 1: App Intent Cannot Activate the Microphone Without Foregrounding the App

**What goes wrong:** You implement a `DictateIntent: AppIntent` with `openAppWhenRun = false`, expecting the Shortcut to silently record audio and return text in the background. On real devices, `AVAudioSession.activate()` returns an error ("AVAudioSession activation failed") or the session activates but returns silence. No microphone input reaches the app.

**Why it happens:** iOS restricts microphone access to the foreground process. App Intents that run in the background (the default with `openAppWhenRun = false`) run in a sandboxed extension process that cannot acquire a recording audio session. The `.record` or `.playAndRecord` AVAudioSession category requires the app to be visible to the user. Even with the `Audio` background mode enabled in the main app, the App Intent extension process does not inherit that entitlement.

**Confirmed behavior:** Developers have reported "Session activation failed" when attempting to record from a Shortcut-launched intent. The fix is `openAppWhenRun = true`, which brings the full app to the foreground before the intent's `perform()` method runs.

**How to avoid:**
- Set `static var openAppWhenRun: Bool = true` on the dictation intent. This is non-negotiable for any intent that records audio.
- The app will visually appear briefly before returning control to the Shortcut. This is by design — iOS requires the user to see the app when the microphone is active.
- Design the UI so the recording state is immediately visible when the app foregrounds (large, clear "Recording..." indicator). Do not show onboarding or setup screens on foreground triggered by a Shortcut — detect the foreground source and jump directly to recording.
- Note: `openAppWhenRun` cannot be set dynamically. If you need both a "background-runnable" intent (e.g., for checking status) and a "recording" intent, they must be two separate `AppIntent` types.

**Warning signs:**
- During testing, recording works in Simulator (which is more permissive) but fails on device.
- `AVAudioSession.sharedInstance().isOtherAudioPlaying` returns false but recording yields silence.
- Console shows `AVAudioSession: error 560030580` or similar domain error.

**Phase to address:** Phase 1 (Shortcut/App Intent scaffolding). Must be architected correctly before any audio work is attempted.

---

### Pitfall 2: App Intent 30-Second Execution Timeout Kills Long Transcriptions

**What goes wrong:** The App Intents framework enforces a hard 30-second wall-clock timeout on intent execution. For Dicticus, the `perform()` method must: (1) activate audio session, (2) wait for user to record, (3) run CoreML inference, (4) apply dictionary, (5) copy to clipboard, and (6) return a result. If the user records for 25+ seconds, inference alone takes 1–3 seconds, and the total exceeds 30 seconds, the system terminates the intent with no user-visible error — the Shortcut just shows "Intent failed."

**Why it happens:** The 30-second limit is documented by Apple and confirmed in Apple Feedback Assistant reports (FB12016280, FB11697381). It cannot be extended or disabled. It applies from the moment `perform()` is called, including time spent waiting for user input (push-to-talk duration).

**Actual numbers:** On iPhone 13 (from FluidAudio benchmarks): cold ASR load ~5 seconds, warm inference ~162ms encoder. On iPhone 12 and older: inference could be 400–800ms. For a 20-second audio clip at ~110x RTF, transcription is < 1 second warm. The real risk is model cold-load (first use after app restart) + long recording together.

**How to avoid:**
- **Pre-warm the ASR model** in the main app before the user triggers the Shortcut. On app foreground (including foreground from `openAppWhenRun`), immediately start model loading if not already loaded. Use `Task.detached(priority: .userInitiated)` to load in parallel with showing the recording UI.
- **Cap recording duration at 20 seconds** to stay safely under the timeout. Show a countdown indicator at 15 seconds. Auto-stop recording at 20 seconds.
- **Budget allocation:** 3s model warm-up (if cold) + 20s recording + 2s inference + 1s dictionary + 1s clipboard = 27s. This fits within 30 seconds only with warm model.
- **For v1 of iOS: do not support AI cleanup in the App Intent flow.** Adding llama.cpp cleanup adds 1–5 seconds more, which pushes past the budget.
- Future: implement a persistent `AsrManager` that warms during app launch (background) so it's always warm when the Shortcut fires.

**Warning signs:**
- Shortcut shows "DictateIntent failed" or spins indefinitely when the user records for > 20 seconds.
- Console logs show the intent process being killed.
- Works in development (Xcode-attached) but fails in production (debugger adds time budget slack).

**Phase to address:** Phase 1 (Shortcut scaffolding). Record duration cap and model pre-warm architecture must be designed from the start.

---

### Pitfall 3: CoreML Model Memory Limit Causes OOM Crash on Older iPhones

**What goes wrong:** Parakeet TDT v3 CoreML package is ~1.24 GB on disk. At runtime, the model is loaded into memory with additional overhead for activations, buffers, and OS overhead. On iPhones with 4 GB RAM (iPhone 12/13 base), available memory for apps is typically 1.5–2.0 GB before iOS starts killing background processes. Loading the full Parakeet model can push the app over the memory limit, causing a `jetsam` kill (crash without user-visible error).

**Actual risk by device:**
- iPhone 15 Pro / 16 series (8+ GB RAM): No issue. Model loads and runs on ANE.
- iPhone 14 / 15 base (6 GB RAM): Generally fine. Monitor in production.
- iPhone 12 / 13 base (4 GB RAM): High risk. The `increased-memory-limit` entitlement helps but is not guaranteed.
- iPhone 11 and older: Do not support. iOS 17 minimum requirement on FluidAudio already excludes most, but iPhone 11 runs iOS 17 and has 4 GB RAM.

**Why it happens:** CoreML allocates large intermediate buffers during inference on top of the model weights. On ANE, the Neural Engine has dedicated memory but must still coordinate with the CPU heap. The `com.apple.developer.kernel.increased-memory-limit` entitlement tells iOS that the app needs extra memory headroom, but it requires Apple approval for App Store distribution and is not guaranteed on all devices.

**How to avoid:**
- **Request `com.apple.developer.kernel.increased-memory-limit` entitlement** early in development. This requires adding it to your App ID in the Apple Developer Portal. Test whether it helps on 4 GB devices before release.
- **Wrap all CoreML model loading and inference in `@autoreleasepool` blocks.** CoreML allocates Objective-C objects during prediction that are not freed until the autorelease pool drains. Without explicit pool draining, memory spikes during inference can exceed the limit.
- **Unload the model when the app goes to background** (when not recording). The `AsrManager` should expose a `suspend()` method that releases the loaded model, and a `resume()` method triggered on app foreground.
- **Set minimum deployment target to iPhone 13 or newer** for v1 if 4 GB devices cause crashes in testing. This is a pragmatic scope reduction.
- **Monitor with MetricKit** in production. `MXCrashDiagnosticPayload` will show jetsam kills with a memory pressure indicator.

**Warning signs:**
- App crashes silently (no crash log in Console.app) shortly after model loads on older devices.
- `os_log` shows `jetsam` or `memory pressure` entries.
- Xcode's memory gauge shows > 1.5 GB right after model load.
- Works on simulator (no memory limit) but crashes on iPhone 12/13 device.

**Phase to address:** Phase 2 (CoreML model integration on iOS). Must be tested on a real iPhone 12 or 13 device, not only on Simulator or Pro devices.

---

### Pitfall 4: AVAudioSession Category Conflict Interrupts Recording Mid-Utterance

**What goes wrong:** While the user is recording dictation (push-to-hold Shortcut action), an incoming phone call, Siri activation, alarm, or another app's audio session interrupts the recording AVAudioSession. The recording stops abruptly, the app receives an interruption notification, but the interrupt handler is not implemented — so the app hangs waiting for audio that will never come, eventually timing out and producing garbage output or an empty transcript.

**Why it happens:** AVAudioSession uses a category/mode system. The `.record` category cannot mix with other audio sessions — it takes exclusive control of the microphone. When an interruption occurs, iOS deactivates the session and fires an `AVAudioSession.interruptionNotification`. If the app does not handle this notification, the recording machinery (AVAudioEngine or AVAudioRecorder) is left in a broken state.

**Additional conflict:** If the Dicticus macOS app or any other app has an active AVAudioSession at the same time on the same device (e.g., AirPlay mirroring), the iOS session may be downgraded to a lower-quality mode.

**How to avoid:**
- **Register for `AVAudioSession.interruptionNotification` before activating the session.** In the handler:
  - On `.began`: stop recording immediately, save any captured audio, set a "interrupted" state flag
  - On `.ended` with `.shouldResume` option: optionally reactivate and resume (for Dicticus, it's simpler to just discard the recording and show an error)
- **Use `.playAndRecord` category with `.defaultToSpeaker` option** rather than `.record` alone. This provides better interrupt recovery behavior.
- **Set `setAllowHapticsAndSystemSoundsDuringRecording(true)`** to prevent AVAudioSession from blocking haptic feedback during recording.
- **Handle the common case gracefully in the UI:** Show "Recording interrupted — tap to try again" rather than silently failing.
- **Do not leave the AVAudioSession activated after recording completes.** Deactivate with `setActive(false, options: .notifyOthersOnDeactivation)` to be a good audio citizen and allow music apps to resume.

**Warning signs:**
- Recording works in a quiet test environment but fails randomly in real use.
- User reports "sometimes it just doesn't transcribe anything."
- Console shows `AVAudioSession: session interrupted` without a corresponding app response.

**Phase to address:** Phase 2 (audio capture on iOS). Add interruption handling before any user testing begins.

---

### Pitfall 5: Parakeet CoreML Model Not Found After Download — Path Mismatch Between Main App and Extension

**What goes wrong:** You download and cache the Parakeet CoreML model in the main app's `Documents` or `Application Support` directory. When the App Intent (which runs in an extension process separate from the main app) tries to load the model, it resolves a different path — the extension's own container — and the model file is not there. The intent either crashes or falls back silently.

**Why it happens:** Each iOS app and app extension has a separate sandbox container. The main app's container is at `~/Library/Containers/com.yourapp.Dicticus/`. The App Intents extension is at `~/Library/Containers/com.yourapp.Dicticus.DicticusIntents/`. Paths obtained via `FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)` return different directories in each process.

**Critically:** App Intents for iOS 17+ run as extensions within the main app's process space when the main app is foregrounded (`openAppWhenRun = true`), but the file system sandbox still applies. With `openAppWhenRun = true` and a single-process architecture (no separate extension target), this pitfall may not apply — but if you ever add a separate `Intents Extension` target, it will.

**How to avoid:**
- **Use App Groups shared container for all model storage.** Create an App Group identifier (e.g., `group.com.yourname.dicticus`) in Apple Developer Portal and add it to both the main app and any extension targets.
- Access the shared container via:
  ```swift
  FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.yourname.dicticus")
  ```
- Download the model to this shared container path, not to `applicationSupportDirectory`.
- **Pass the model path explicitly** to `AsrModels.load(from:)` rather than relying on FluidAudio's default (HuggingFace download) path, which may default to the process-local container.
- **Document the model path architecture** in the code. A comment like `// Model stored in App Group container, not app container — required for extension access` prevents future developers from "fixing" it back to the wrong location.

**Warning signs:**
- Model loads correctly in Simulator but fails on device.
- `AsrManager` initialization throws a file-not-found error in the extension process.
- Model downloads repeatedly because each process writes to its own container.

**Phase to address:** Phase 2 (model management on iOS). Set up App Groups before writing any model download code.

---

### Pitfall 6: FluidAudio Downloads Model From HuggingFace Without User Consent — 1.24 GB Surprise

**What goes wrong:** FluidAudio's default `AsrModels.downloadAndLoad(version: .v3)` calls HuggingFace's CDN and downloads the full Parakeet v3 CoreML package (~1.24 GB) the first time it runs. If this is called on app first launch without any user indication, the user sees no progress, the app appears frozen for several minutes, and if they're on cellular, they get a 1.24 GB cellular data charge. On slow connections, the download times out and the app crashes.

**Why it happens:** The FluidAudio SDK is designed for simplicity — one call downloads and loads the model. This is appropriate for development but requires wrapping before shipping to users.

**How to avoid:**
- **Never call `downloadAndLoad` without explicit user consent and a visible progress UI.**
- Build a **first-run "Model Setup" screen** that:
  1. Shows the model size (~1.2 GB) upfront
  2. Warns about Wi-Fi requirement (check `NWPathMonitor` for cellular connection, show warning if not on Wi-Fi)
  3. Shows a `URLSession` download progress bar (0–100%)
  4. Handles errors (disk full, network timeout, HuggingFace rate limit) with retry option
  5. Stores a `modelDownloaded: Bool` flag in UserDefaults so the screen never appears again
- **Consider bundling a smaller "starter" model** (e.g., Parakeet EOU 120M, ~150 MB) for the first run, with the full v3 model downloading in the background. But for Dicticus's accuracy requirements, this is a trade-off — Parakeet v3 is the primary model.
- **Check disk space before downloading.** `FileManager.default.volumeAvailableCapacityForImportantUsage` should return > 2 GB before starting download (model + compilation artifacts + headroom).
- **Handle HuggingFace rate limits.** The SDK downloads from HuggingFace's CDN. In geographies with HuggingFace blocks (China) or rate-limited connections, downloads fail. Add a `REGISTRY_URL` override pointing to a self-hosted mirror for production apps.

**Warning signs:**
- TestFlight beta testers report "app froze for 10 minutes" on first launch.
- Crash logs show `NSURLErrorDomain -1001` (timeout) during first run.
- App Store reviews mention surprise cellular charges.

**Phase to address:** Phase 3 (model management UX). Design the download flow before any TestFlight distribution.

---

### Pitfall 7: CoreML Model Compilation Takes 3–5 Seconds on First Load — Blocks UI Thread If Done Synchronously

**What goes wrong:** The first time a CoreML model is loaded on a device, iOS compiles it for the specific device's hardware (specialization). For Parakeet v3 on iPhone 13, this takes ~4.4 seconds (encoder alone). If this compilation is triggered synchronously on the main thread (e.g., in `viewDidLoad` or in the App Intent's `perform()` before showing the UI), the app is completely frozen for 4–5 seconds. The system watchdog may kill the app if it's triggered from a Shortcut foreground with no visible UI activity.

**Actual numbers from FluidAudio benchmarks:**
- iPhone 13 first load: Encoder 4,396ms, full pipeline ~5,200ms
- iPhone 16 Pro Max first load: Encoder 3,361ms, full pipeline ~3,600ms
- Warm load: Encoder 162ms (iPhone 16 Pro Max)

**Why it happens:** CoreML caches compiled model artifacts (`.mlmodelc`) after first load. Subsequent loads use the cache and are fast. But the first load after install, or after an iOS update (which invalidates the cache), requires full recompilation. Developers test with the warm cache and miss this.

**How to avoid:**
- **Always load models off the main thread.** Use `Task.detached(priority: .userInitiated)` or a dedicated dispatch queue.
- **Show a loading state** during model compilation. For the first-run case, show "Preparing speech recognition (first run)..." to set expectations.
- **Trigger first load early** — immediately after the model download completes (not on first use). Cache the compiled `.mlmodelc` in the App Group container so extension processes also benefit from the cached version.
- **After iOS updates**, the compilation cache may be invalidated. Add a `compiledModelVersion` check in UserDefaults keyed to the iOS version, and pre-warm proactively after an iOS update is detected.
- **Do not call model loading inside `perform()` of the App Intent.** Load the model in the main app during foreground, then pass a loaded model reference to the intent via a shared service or singleton.

**Warning signs:**
- App appears frozen for 5 seconds on first use after install.
- Crash reports show watchdog kills (exception type `SIGKILL`, exception code `0x8badf00d`) shortly after app foreground.
- Works fine after the first use but "randomly" hangs on the first use after an iOS update.

**Phase to address:** Phase 2 (CoreML integration). Pre-warm architecture must be a first-class design concern.

---

## Moderate Pitfalls

Mistakes that cause user-visible failures or require significant rework, but don't block the feature entirely.

---

### Pitfall 8: #if os(macOS) / #if os(iOS) Conditional Compilation Misuse in Shared Code

**What goes wrong:** When extracting shared Swift code to `Shared/`, developers instinctively use `#if os(macOS)` and `#if os(iOS)` to conditionally compile platform-specific branches. This works, but creates two problems: (1) the wrong branch gets compiled silently when porting code between platforms, and (2) `#if os(macOS)` does not catch macOS Catalyst (iOS code running on macOS), and vice versa. The subtler issue: `canImport(AppKit)` is the correct check for "macOS API available," not `os(macOS)`.

**How to avoid:**
- Use `#if canImport(AppKit)` to gate AppKit-specific code (macOS only).
- Use `#if canImport(UIKit)` to gate UIKit-specific code (iOS/iPadOS only).
- Use `#if os(macOS)` only when you explicitly need to distinguish macOS from Catalyst (iOS running on macOS).
- Structure shared code to use protocol abstractions rather than `#if` inside business logic. Define a `ClipboardService` protocol with separate `macOSClipboardService` and `iOSClipboardService` implementations. The `#if` only appears at the injection/instantiation site.
- **In xcodegen `project.yml`:** When adding an iOS target, double-check that each Swift file in `Shared/` compiles correctly for both targets. A common mistake is adding a file to only one target's `sources:` list.

**Warning signs:**
- A change to `Shared/` code breaks one platform's build but not the other.
- Code that worked on macOS silently does nothing on iOS because a `#if os(macOS)` block was missed.
- Xcode shows no compilation error but the feature doesn't work on the new platform.

**Phase to address:** Phase 4 (Shared code extraction). Define protocol boundaries before moving any code.

---

### Pitfall 9: xcodegen project.yml iOS Target Missing SPM Dependencies That macOS Target Has

**What goes wrong:** The macOS target in `project.yml` lists `FluidAudio` (and any other SPM packages) in its `dependencies:` section. When adding the iOS target, you copy the target config but miss some dependencies, or list them incorrectly. The iOS target builds in Xcode's incremental build (which may cache the macOS build artifacts) but fails on a clean build. This is particularly tricky for dynamic framework embedding — xcodegen has a known bug where dynamic SPM frameworks are listed as linked but not embedded, causing `dyld: Library not loaded` crashes at runtime.

**How to avoid:**
- After adding the iOS target to `project.yml`, run `xcodegen generate` and then do a **clean build** (`Product > Clean Build Folder`) before testing.
- Verify that all SPM packages used by the iOS target are listed in both `dependencies:` and (for dynamic frameworks) are embedded.
- For each SPM package shared between macOS and iOS targets, verify the package supports both platforms in its `Package.swift` `platforms:` declaration. `FluidAudio` supports iOS 17+ (confirmed from official docs), so this is fine for the primary SDK. Verify any local `Shared/` Swift packages also declare iOS support.
- Add a CI check: `xcodebuild -scheme DicticusIOS -destination 'platform=iOS Simulator,name=iPhone 16' build` should pass on every PR.

**Warning signs:**
- `dyld: Library not loaded: @rpath/FluidAudio.framework/FluidAudio` crash on device launch.
- `xcodegen generate` succeeds but Xcode shows "Missing package product" in the project navigator.
- Tests pass in macOS scheme but fail to even build in iOS scheme.

**Phase to address:** Phase 4 (multi-target project restructure). Run a clean build immediately after setting up the iOS target.

---

### Pitfall 10: Universal App Breaks on iPad Due to Missing `idiom`-Aware Layout

**What goes wrong:** The iOS app is developed and tested only on iPhone. When run on iPad, the layout breaks: a full-screen `VStack` that looks fine on iPhone becomes a tiny centered column on a 12.9-inch iPad screen. The recording button, which is sized for a thumb tap on iPhone, is positioned in the wrong corner on iPad landscape. The Shortcut-driven flow looks reasonable on iPhone but has unused empty space on iPad.

**Why it happens:** SwiftUI adapts some things automatically (text size, safe areas) but does not automatically restructure single-column iPhone layouts into two-column iPad layouts. `HStack { content }` does not become a `NavigationSplitView` automatically.

**How to avoid:**
- At minimum, constrain the main content to a maximum width on iPad: wrap the main `VStack` in a `.frame(maxWidth: 480)` centered on screen. This makes an iPhone-sized layout work acceptably on iPad without full redesign.
- Use `@Environment(\.horizontalSizeClass)` to detect compact (iPhone) vs. regular (iPad) and adjust layout.
- For Dicticus's use case (Shortcut-first, minimal UI): a simple centered card layout works fine on both. The effort of a full iPad-first redesign is not justified for v1.
- Test in iPad Simulator before every TestFlight build. Add iPhone SE (compact) and iPad Pro 13" (regular) to the simulator test matrix.

**Warning signs:**
- UI elements are misaligned or oversized on iPad.
- Tapping the recording button on iPad doesn't work because the tap target hit area is not where the visual button appears.

**Phase to address:** Phase 5 (universal app / iPad support). Budget 1–2 days for layout polish, not a full redesign.

---

### Pitfall 11: App Store Review Requires Microphone Usage Description and Working Demo

**What goes wrong:** The App Store reviewer cannot test the core feature (dictation via Shortcut) without a demonstration method. If the only activation path is through the iOS Action Button or a pre-configured Shortcut, the reviewer may not know how to trigger recording, and reject the app with "we were unable to test core functionality."

**Additional rejection risks:**
- Missing `NSMicrophoneUsageDescription` in the iOS app's `Info.plist` → automatic rejection.
- Unclear privacy disclosure for on-device ASR (even though fully local) → reviewer may request clarification.
- Model download UX that looks like content downloading from a server → may trigger guideline 5.2.2 (downloading code after install review). CoreML models are not "code" but reviewers may not know this.

**How to avoid:**
- Add a clear "Record" button directly in the app's main UI as a second activation path alongside the Shortcut. This gives reviewers a way to test without configuring a Shortcut.
- In `NSMicrophoneUsageDescription`: be specific — "Dicticus records your voice locally on your device to convert speech to text. Audio is never transmitted to any server."
- Add `NSSpeechRecognitionUsageDescription` if using any SFSpeechRecognizer API (even for language detection).
- In the App Review Notes, explicitly state: "All speech processing happens entirely on-device using Apple's Neural Engine. No audio or text leaves the device. The model (~1.2 GB) is downloaded from HuggingFace on first launch."
- Test the review flow by creating a fresh App Store Connect submission with a review account that has no pre-configured Shortcuts.

**Warning signs:**
- Beta testers report difficulty triggering the app without knowing about the Action Button.
- First submission rejected for "unable to access main feature."

**Phase to address:** Phase 5 (App Store submission prep). Design the in-app recording button alongside the Shortcut flow from the beginning.

---

### Pitfall 12: FluidAudio Default Model Download Path Is Not App Groups-Aware

**What goes wrong:** `AsrModels.downloadAndLoad(version: .v3)` uses FluidAudio's internal download path, which defaults to the app's own container. Even if you configure `ModelRegistry.baseURL` for the download source, the *destination* path may still be the app container rather than the App Group shared container. If you later add a keyboard extension (v2.1) or a lock screen widget that needs to read the model path, it cannot access the main app container.

**Why it happens:** FluidAudio is designed for single-app use cases. Its internal storage path logic was not documented to be App Groups-aware as of the research date. The `AsrModels.load(from:)` overload allows specifying a custom path, which is the escape hatch.

**How to avoid:**
- Use `AsrModels.load(from: customPath)` where `customPath` is the App Group container path, rather than `downloadAndLoad` with default path.
- Implement the download separately using `URLSession` (with progress reporting), then point FluidAudio at the downloaded file location.
- **Verify this behavior** by checking `FileManager.default.fileExists(atPath:)` against both the App Group path and the process-local container path after calling `downloadAndLoad`. If the model is in the local container, it confirms the SDK uses local paths.
- File an issue with FluidAudio if App Groups container support is absent — this is a reasonable feature request for an SDK targeting production apps.

**Confidence note:** This pitfall is MEDIUM confidence. The FluidAudio public documentation does not explicitly describe its storage paths. Verify during Phase 2.

**Warning signs:**
- Model appears downloaded but a second process (extension, background task) cannot find it.
- Total disk usage is doubled (model downloaded to both containers).

**Phase to address:** Phase 2 (model management) and Phase 3 (model download UX). Verify storage path behavior on day one of model integration.

---

## Minor Pitfalls

---

### Pitfall 13: AVAudioSession Not Deactivated After Recording Stops Music Playback for the User's Session

**What goes wrong:** The user has music playing (Spotify, Apple Music). They trigger the Dicticus Shortcut to dictate. Recording works. But after dictation completes, Dicticus does not deactivate its AVAudioSession with `.notifyOthersOnDeactivation`. The music never resumes. The user has to manually go back to the music app and hit play.

**How to avoid:**
- After recording ends (and before inference), call:
  ```swift
  try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
  ```
- This signals to other audio apps that they can resume. It is a courtesy but has become expected behavior.
- For `setAllowHapticsAndSystemSoundsDuringRecording`, call this during session setup to avoid blocking haptic feedback from the recording confirmation tap.

**Phase to address:** Phase 2 (audio capture). One-line fix, but easy to forget.

---

### Pitfall 14: Custom Dictionary `UserDefaults` Sync Not Available Across App Group Boundary

**What goes wrong:** The macOS app stores custom dictionary entries in standard `UserDefaults`. You port the `DictionaryService` to iOS and it compiles fine. But if the dictionary entries are read from `UserDefaults.standard` in an extension process, they return empty — `UserDefaults.standard` is not shared across the App Group boundary.

**How to avoid:**
- Replace `UserDefaults.standard` in `DictionaryService` with `UserDefaults(suiteName: "group.com.yourname.dicticus")!` for all dictionary storage.
- This applies to the iOS app's main process as well — use the suite name consistently so the data is accessible from both the main app and any future extensions.
- On macOS, the App Group mechanism also exists but is less commonly used for a menu bar app. If `DictionaryService` is moved to `Shared/`, make the UserDefaults suite name a compile-time constant injected per platform:
  ```swift
  #if os(iOS)
  let suiteName = "group.com.yourname.dicticus"
  #else
  let suiteName = nil // standard on macOS
  #endif
  ```

**Phase to address:** Phase 4 (Shared code extraction / DictionaryService port).

---

### Pitfall 15: Shortcut Output Type Mismatch — Text vs. String in Shortcut Composition

**What goes wrong:** The App Intent's `perform()` returns a result value typed as `String`. The Shortcuts app displays this as a "Text" result. But when the user tries to compose a multi-step Shortcut (Dictate → "Copy to Clipboard" → show notification), the subsequent "Copy to Clipboard" action may show a type mismatch warning because it expects a `Text` content type, not a generic `String`.

**Why it happens:** The Shortcuts type system distinguishes `String` from `Text`. App Intents must conform the output to `StringIntent` result, not just return a raw `String`, to be treated as `Text` in Shortcut composition.

**How to avoid:**
- Return `IntentResult` with a concrete `ReturnsValue<String>` (or `IntentResultContainer` with string) from `perform()`. Use `.result(value: transcribedText)` syntax.
- Test Shortcut composition: create a Shortcut that pipes Dicticus output into "Copy to Clipboard," "Show Result," and "Send Message" actions. Verify type compatibility with each.
- If the intent is also used for Siri ("dictate with Siri"), confirm the spoken output sounds natural — Siri reads the returned String aloud.

**Phase to address:** Phase 1 (App Intent scaffolding). Test Shortcut composition against common use cases before launch.

---

### Pitfall 16: Repeated HuggingFace Download on Every App Delete/Reinstall — Poor UX for Beta Testers

**What goes wrong:** Beta testers frequently delete and reinstall the app. Each reinstall triggers the ~1.24 GB download again (App container is deleted with the app). During a TestFlight beta with 20 testers, this can exhaust HuggingFace's rate limits or result in negative feedback about the onboarding experience.

**How to avoid:**
- iCloud backup can restore the model if the user has iCloud Drive enabled and the model is stored in `Documents` (which is backed up). However, `~1.24 GB` in iCloud backup may upset users. Exclude the model from iCloud backup:
  ```swift
  var resourceValues = URLResourceValues()
  resourceValues.isExcludedFromBackup = true
  try modelURL.setResourceValues(resourceValues)
  ```
- During beta, point `REGISTRY_URL` to a faster CDN (GitHub Releases, Cloudflare R2) rather than HuggingFace directly. This is just the download source; the model itself is identical.
- Show download ETA based on measured download speed. Users tolerate waiting when they can see progress and an estimated time.

**Phase to address:** Phase 3 (model download UX). Also relevant for beta testing logistics.

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| `openAppWhenRun = true` without polish | Recording works immediately | App foregrounds abruptly with no animation or context | Never — add a recording-state initial view |
| Singleton `AsrManager` in AppDelegate | Simple to implement | Blocks keyboard extension in v2.1 from accessing model | Acceptable for v1 if designed as injectable |
| Storing model in app container (not App Group) | Fewer entitlements to configure | Keyboard extension (v2.1) cannot access model without re-download | Never — use App Group from day one |
| Synchronous model load in `perform()` | Simple code | 4–5 second freeze on first use per 30s timeout risk | Never — always async with pre-warm |
| No interruption handling in AVAudioSession | Less code | Silent failures during phone calls, Siri invocations | Never — ship with interrupt handler |
| Skipping `NSMicrophoneUsageDescription` | Saves one line | App Store rejection | Never |
| No disk space check before download | Fewer lines of code | App crash on devices with < 2 GB free space | Never |

---

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| FluidAudio on iOS | Calling `downloadAndLoad` without progress UI | Separate download (URLSession + progress) from load (`AsrModels.load(from:)`) |
| FluidAudio on iOS | Default model path is not App Group-aware | Use `AsrModels.load(from: appGroupModelPath)` with explicit path |
| App Intents + audio | `openAppWhenRun = false` with microphone recording | Always `openAppWhenRun = true` for any intent that records audio |
| App Intents + timeout | Recording > 20 seconds + cold model load | Cap recording at 20s, pre-warm model in foreground before Shortcut fires |
| AVAudioSession | Not handling interruption notifications | Register for `AVAudioSession.interruptionNotification` before activating session |
| AVAudioSession | Not deactivating after recording | Call `setActive(false, options: .notifyOthersOnDeactivation)` after recording ends |
| CoreML compilation | Calling model load on main thread | Always load models with `Task.detached(priority: .userInitiated)` |
| xcodegen multi-target | iOS target missing SPM dependencies | Clean build after `xcodegen generate`, not just incremental |
| UserDefaults + extensions | `UserDefaults.standard` not shared across extension boundary | Use `UserDefaults(suiteName: "group.com.yourname.dicticus")` everywhere |
| App Store review | Only Shortcut activation path, no in-app button | Add a fallback in-app record button for reviewers |

---

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Cold CoreML load in `perform()` | 5-second freeze, possible watchdog kill | Pre-warm model in app foreground, never load in intent execute path | Every first use after install or iOS update |
| Model in per-process container | Double storage consumption, re-download | App Group container from day one | Any v2.1 extension work |
| Large model on 4 GB RAM device | Jetsam kill (silent crash) | `increased-memory-limit` entitlement + `@autoreleasepool` + unload on background | iPhone 12/13 base with other apps open |
| Recording > 20s + cold inference | App Intent 30s timeout, "Intent failed" | Record cap at 20s, warm model before intent runs | Every long dictation on cold start |
| AVAudioSession active after recording | User's music does not resume | Deactivate session with `.notifyOthersOnDeactivation` | Every use when user has music playing |

---

## Security Mistakes

| Mistake | Risk | Prevention |
|---------|------|------------|
| Storing transcribed text in `UserDefaults.standard` without opt-out | iCloud sync exposes voice data to iCloud server | Mark `UserDefaults` values as do-not-sync, or use only local file storage |
| Model files not excluded from iCloud backup | User's iCloud backup grows by 1.24 GB | Set `isExcludedFromBackup = true` on model directory |
| HuggingFace URL hardcoded (no override) | App cannot function in HuggingFace-restricted networks | Support `REGISTRY_URL` environment variable or user-configurable mirror URL |
| Logging transcription text to os_log in production | Voice content visible in Console.app to anyone with device access | Use debug-only logging, `.private` OSLog attribute for any text containing user content |

---

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| No model download progress shown | User sees frozen screen for minutes, force-quits app | Full-screen onboarding with URLSession progress bar |
| Model downloads on cellular without warning | 1.24 GB cellular charge | Detect cellular, warn, require explicit "Download anyway" tap |
| App foregrounds abruptly with blank screen | Startling, confusing for Shortcut users | Show recording-ready state instantly on foreground (UIViewController pre-loaded) |
| Recording ends silently on interruption | User thinks dictation worked, but gets empty output | Show explicit "Recording interrupted" state with retry option |
| No disk space check | App crashes mid-download with cryptic error | Check `volumeAvailableCapacityForImportantUsage > 2 GB` before starting download |
| In-app UI only accessible via Shortcut | App Store reviewer cannot test feature | Always include a visible in-app "Start Dictation" button as a second activation path |

---

## "Looks Done But Isn't" Checklist

- [ ] **Model loading:** Model loads on iPhone 12/13 base (4 GB RAM) without jetsam crash — verify with Xcode memory gauge on a real device
- [ ] **Audio recording:** Recording works when triggered from a Shortcut on a real device, not just from Simulator or direct app launch
- [ ] **Interruption handling:** Recording recovers gracefully from an incoming call mid-recording — tested by calling the device during a recording session
- [ ] **App Groups:** Model file is accessible from both the main app process and any extension process — verified by checking `FileManager` path after download
- [ ] **UserDefaults suiteName:** Custom dictionary entries are readable from extension processes — tested with a dummy extension reading from the shared container
- [ ] **iPad layout:** App layout is usable on 12.9" iPad in both portrait and landscape — tested in iPad Pro Simulator
- [ ] **App Store review path:** An App Store reviewer with no pre-configured Shortcuts can trigger and test dictation using only the in-app UI
- [ ] **NSMicrophoneUsageDescription:** Key is present in the iOS app's `Info.plist` (not only macOS's) and the description explains local-only processing
- [ ] **Session deactivation:** After dictation completes, background music resumes without user intervention — tested with Spotify playing in background
- [ ] **30-second budget:** A 20-second recording on a cold-start iPhone 13 completes within the App Intent timeout — tested with `openAppWhenRun = true` on device
- [ ] **Download UI:** First-run model download shows progress, warns about cellular if not on Wi-Fi, and handles errors gracefully
- [ ] **Clean build:** `xcodebuild clean build` succeeds for the iOS target after `xcodegen generate` — not just incremental rebuild

---

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Wrong App Group container for model | MEDIUM | Move model files to App Group path, update all `FileManager` calls, re-test extension access |
| `openAppWhenRun = false` with audio | LOW | Change one line, but also add recording-ready UI state for foreground case |
| No interruption handling shipped | LOW | Add `NotificationCenter` observer + interrupt state handling, re-submit TestFlight |
| App Store rejection: can't test feature | LOW | Add in-app record button (1 day work), resubmit |
| Jetsam crash on 4 GB devices (memory) | HIGH | Profile memory with Instruments Leaks + Allocations, add `@autoreleasepool`, apply for increased-memory-limit entitlement, possibly restrict to 6 GB+ devices |
| 30-second timeout in production | MEDIUM | Cap recording to 20s + add pre-warm logic in AppDelegate/SceneDelegate, update App Intent architecture |
| Model stored in wrong path (per-process, not App Group) after release | HIGH | Requires migration logic on next update: detect old path, copy to App Group path, delete old copy. Ship as urgent patch. |

---

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| App Intent cannot activate microphone without foreground | Phase 1 — Shortcut scaffolding | `openAppWhenRun = true` set, tested on real device |
| 30-second App Intent timeout | Phase 1 — Shortcut scaffolding | Recording capped at 20s, budget documented |
| CoreML OOM on 4 GB devices | Phase 2 — CoreML integration | Tested on real iPhone 12/13 with Instruments memory profiling |
| AVAudioSession interruption not handled | Phase 2 — audio capture | Interruption tested by calling device during recording |
| Model path not accessible from extension | Phase 2 — model management | App Group configured, extension file access verified |
| Model downloads without user consent or progress | Phase 3 — model download UX | First-run screen complete with progress, Wi-Fi warning |
| CoreML cold-load blocks UI thread | Phase 2 — CoreML integration | Model loaded async, pre-warm on app foreground |
| `#if os()` misuse in shared code | Phase 4 — shared code extraction | `canImport` checks reviewed, iOS target clean-builds |
| xcodegen iOS target missing SPM deps | Phase 4 — project restructure | Clean build passes for iOS target in CI |
| iPad layout broken | Phase 5 — universal app polish | Tested on iPad Pro 13" Simulator portrait + landscape |
| App Store review rejection for missing in-app path | Phase 5 — App Store prep | In-app record button present, reviewer notes written |
| AVAudioSession not deactivated | Phase 2 — audio capture | Background music resumes after dictation in manual test |
| UserDefaults not using App Group suite | Phase 4 — DictionaryService port | Extension process reads dictionary entries correctly |
| Shortcut output type mismatch | Phase 1 — App Intent scaffolding | Shortcut composition tested with Clipboard and Message actions |

---

## Sources

- [FluidAudio GitHub — README and Benchmarks.md](https://github.com/FluidInference/FluidAudio) — HIGH confidence
- [FluidAudio Documentation — ASR Getting Started](https://github.com/FluidInference/FluidAudio/blob/main/Documentation/ASR/GettingStarted.md) — HIGH confidence
- [FluidAudio Benchmarks (iPhone cold/warm load times)](https://github.com/FluidInference/FluidAudio/blob/main/Documentation/Benchmarks.md) — HIGH confidence
- [FluidInference parakeet-tdt-0.6b-v3-coreml HuggingFace model card](https://huggingface.co/FluidInference/parakeet-tdt-0.6b-v3-coreml) — HIGH confidence
- [App Intents framework — Apple Developer Documentation](https://developer.apple.com/documentation/appintents) — HIGH confidence
- [ForegroundContinuableIntent — Apple Developer Documentation](https://developer.apple.com/documentation/appintents/foregroundcontinuableintent) — HIGH confidence
- [openAppWhenRun Apple Developer Forums thread](https://developer.apple.com/forums/thread/723623) — MEDIUM confidence
- [Apple Feedback: App Intents 30-second timeout (FB12016280)](https://github.com/feedback-assistant/reports/issues/386) — HIGH confidence (multiple developer confirmations)
- [Apple Feedback: App Intents should disable timeout (FB11697381)](https://github.com/feedback-assistant/reports/issues/364) — HIGH confidence
- [com.apple.developer.kernel.increased-memory-limit entitlement](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.kernel.increased-memory-limit) — HIGH confidence
- [Memory Issues on 4 GB iOS/iPadOS devices — apple/ml-stable-diffusion #291](https://github.com/apple/ml-stable-diffusion/issues/291) — HIGH confidence (real device OOM data)
- [Microphone recording fails when launched from Shortcuts — Apple Developer Forums #756507](https://developer.apple.com/forums/thread/756507) — MEDIUM confidence (JS-blocked page, but consistent with framework documentation)
- [AVAudioSession handling interruptions — Apple Developer Documentation](https://developer.apple.com/documentation/avfaudio/avaudiosession/responding_to_audio_session_interruptions) — HIGH confidence
- [App Groups Entitlement — Apple Developer Documentation](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.application-groups) — HIGH confidence
- [Background Assets framework — Apple Developer Documentation](https://developer.apple.com/documentation/backgroundassets) — HIGH confidence
- [On-Demand Resources size limits — App Store Connect](https://developer.apple.com/help/app-store-connect/reference/app-uploads/on-demand-resources-size-limits/) — HIGH confidence
- [App Store Review Guidelines — Apple Developer](https://developer.apple.com/app-store/review/guidelines/) — HIGH confidence
- [XcodeGen dynamic SPM framework embedding bug](https://github.com/yonaskolb/XcodeGen/issues/1460) — MEDIUM confidence
- [SwiftUI iPad adaptive layout — fatbobman.com](https://fatbobman.com/en/posts/swiftui-ipad/) — MEDIUM confidence
- [Swift conditional compilation with canImport](https://byby.dev/swift-platform-conditions) — HIGH confidence

---

*Pitfalls research for: iOS dictation app (Shortcut activation, FluidAudio/Parakeet CoreML, App Groups, universal app)*
*Researched: 2026-04-21*
