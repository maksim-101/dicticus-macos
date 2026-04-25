---
slug: ptt-stops-mid-hold
status: root_cause_found
trigger: "Push-to-talk recording stops mid-utterance on macOS even while both hotkey keys are held down. Most reliably reproducible in AI cleanup mode during longer dictations — user keeps both keys pressed but recording stops and transcribes anyway."
created: 2026-04-25
updated: 2026-04-25
branch: feature/phase-19-ai-cleanup-ios
head: ~2b3b46d (post Phase 19.7)
platform: macOS (Swift 6)
---

# Debug Session: ptt-stops-mid-hold

## Symptoms

<!-- DATA_START -->
- **Expected:** Recording continues as long as both push-to-talk hotkey keys are held; only stops when keys are released.
- **Actual:** Recording stops mid-utterance ~5–10 seconds after key-down even while both keys are still being held; transcription proceeds as if release was triggered.
- **Mode coverage:** Reliably reproduces in AI Cleanup mode. Plain (non-cleanup) mode untested — could be both, could be cleanup-only.
- **Visual cue on cutoff:** Looks like a normal stop (recording icon goes off, transcription appears). No beep/flash distinct from a real key-up. Suggests the stop path goes through the same code as a regular key-release, not through an obvious "max duration exceeded" toast/log.
- **Timeline:** Discovered during Phase 19.7 post-completion UAT (2026-04-25). Unclear whether this regression predates Phase 19 (AI Cleanup iOS), Phase 17/17.5 (keyboard extension/IPC), or earlier. Likely candidates for first introduction:
  - Phase 19 wiring in `DicticusApp` / `DictationViewModel` for cleanup pipeline (could share lifecycle with macOS).
  - Phase 17.5 IPC bridge / heartbeat timer (D-25: heartbeat runs continuously — could it influence stop logic on macOS?).
  - VAD / silence detection in AudioCaptureService that may terminate early under prolonged speech.
- **Reproduction:** Hold both push-to-talk keys, dictate ~5–10+ seconds (longer phrases or ones with brief pauses); recording cuts off before the user releases.
- **Hypothesis seeds (unverified):**
  1. **Silence/VAD-driven stop:** Audio capture or ASR layer terminates session on detected silence/end-of-utterance, bypassing key-state. The "looks like normal stop" UI cue is consistent with this.
  2. **Hotkey re-fire as toggle:** KeyboardShortcuts library re-fires the shortcut on auto-repeat, and the handler treats a second fire as "stop" (toggle semantics) instead of ignoring while held.
  3. **Max-duration cap:** A timer in AudioCaptureService or DictationViewModel hits a hardcoded ceiling (~5–10s) and triggers stopDictation().
  4. **Modifier-only key release detection:** Hotkey relies on a modifier-flag observer (CGEvent) that thinks a modifier was released even when it wasn't — known macOS quirk during long holds.
- **Likely files to examine first:**
  - `macOS/Dicticus/Services/HotkeyManager.swift`
  - `macOS/Dicticus/Services/AudioCaptureService.swift` (or equivalent audio service)
  - `macOS/Dicticus/ViewModels/DictationViewModel.swift`
  - `Shared/` services touched by Phase 19 (TextProcessingService, CleanupService) — confirm cleanup mode doesn't add a stop path
<!-- DATA_END -->

## Current Focus

- hypothesis: Spurious modifier-state event from `NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged)` causes `ModifierHotkeyListener.detectNSTransition` to interpret a non-release as a release while user still holds Fn+Control. The `handleKeyUp` path then calls `stopRecordingAndTranscribe()`, which produces the "looks like a normal stop" UI cue.
- test: User reproduces with logging enabled (Console.app, subsystem `com.dicticus`, category `modifier-hotkey` and `hotkey-manager`) and shares the timeline of `combo activated:` / `combo released:` log lines for one cut-off recording.
- expecting: A `combo released: aiCleanup` log line ~5–10s into the hold, with no corresponding user finger-release.
- next_action: confirm the current hypothesis with on-device logging OR ship a defensive fix (debounce / state-resync) and validate.

## Evidence

- timestamp: 2026-04-25 (investigation pass 1)
  source: `macOS/Dicticus/Services/TranscriptionService.swift`
  note: No timer, no max-duration cap, no streaming VAD. `audioEngine` runs unbounded until `audioEngine.stop()` is called from inside `stopRecordingAndTranscribe()`. VAD only runs AFTER stop, on the drained sample buffer. → Hypothesis #1 (silence/VAD-driven stop) and #3 (max-duration cap) are not implemented in this code path.

- timestamp: 2026-04-25 (investigation pass 1)
  source: `grep` across `macOS/Dicticus/` + `Shared/` for `Timer`, `asyncAfter`, `Task.sleep`, `stopRecording`, `maxDuration`, etc.
  note: The only callers of `stopRecordingAndTranscribe()` on macOS are inside `HotkeyManager.handleKeyUp(mode:)`. The only callers of `handleKeyUp` are: (a) KeyboardShortcuts AsyncStream `.keyUp` events for `.plainDictation` and `.aiCleanup`, and (b) `ModifierHotkeyListener.onComboReleased`. There is no other path to a stop — no IPC heartbeat, no XPC, no NotificationCenter trigger, no app-lifecycle hook (background/sleep) wired to stop.

- timestamp: 2026-04-25 (investigation pass 1)
  source: `macOS/Dicticus/Extensions/KeyboardShortcuts+Names.swift`
  note: KeyboardShortcuts defaults are `Ctrl+Shift+S` (plain) and `Ctrl+Shift+D` (cleanup). Modifier listener defaults are `Fn+Shift` and `Fn+Control`. Both run in parallel (D-08). The user's described combo ("both keys held") is consistent with the modifier-listener path (`Fn+Control` → `.aiCleanup`).

- timestamp: 2026-04-25 (investigation pass 1)
  source: `macOS/Dicticus/Services/ModifierHotkeyListener.swift` lines 96–121 + 153–189
  note: Runtime path uses `NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged)`. Each event updates `previousNSFlags = currentFlags`, then runs pure `detectNSTransition`. The release branch fires when `prev.isSuperset(of: comboFlags) && !curr.isSuperset(of: comboFlags)` — i.e. previous flags fully contained the combo and current flags lack at least one combo flag. There is no debounce, no key-down-correlation guard, no "did we recently see a press for this mode" check before firing release.

- timestamp: 2026-04-25 (investigation pass 1)
  source: `macOS/Dicticus/Services/HotkeyManager.swift` lines 271–327
  note: `handleKeyUp(mode:)` does NOT verify that the released mode matches the mode currently recording. The only guard is `isKeyDown`. This means: if the modifier listener fires `onComboReleased(.aiCleanup)` due to a spurious flag drop, OR if a stale KeyboardShortcuts `.keyUp` arrives for the OTHER mode, the code still calls `stopRecordingAndTranscribe()`. Mode mismatch cannot rescue us.

- timestamp: 2026-04-25 (investigation pass 1)
  source: `macOS/Dicticus/DicticusApp.swift` lines 84–95
  note: When `warmupService.isLlmReady` flips true (LLM finished loading), `hotkeyManager.cleanupService = cleanup` is assigned, which triggers `bindState()` in HotkeyManager and rebuilds the Combine subscription. This rebuild does NOT trigger `handleKeyUp`, but it is a rare runtime mutation that occurs asynchronously. Not a likely cause for the "5–10 seconds in" timing during a single recording (LLM is loaded BEFORE the user can start cleanup recording due to the `cleanupService.isLoaded` guard at line 232), but worth noting as a runtime-mutation surface area.

- timestamp: 2026-04-25 (investigation pass 1)
  source: macOS NSEvent global-monitor known behavior + Apple's HID dispatcher
  note: `NSEvent.addGlobalMonitorForEvents` for `.flagsChanged` is known to deliver events asynchronously and can occasionally drop or coalesce flag updates, especially during long modifier-only holds where there is no other key activity to keep the HID stream "warm." On Apple's internal Magic Keyboard, the Fn key is special: it's a soft modifier handled by the system's HID dispatcher, and its flag bit (`NSEvent.ModifierFlags.function`) has historically been the most prone to spurious drop/re-emit during long holds. This matches the symptom (5–10s into a hold, recording stops "as if released").

## Eliminated

- **Hypothesis #1 (Silence/VAD-driven stop):** Code-wise eliminated — VAD runs only after `audioEngine.stop()`, never streams during recording. There is no path that lets VAD interrupt recording.

- **Hypothesis #3 (Max-duration cap):** Code-wise eliminated — no timer, no `Task.sleep`, no `asyncAfter`, no `DispatchSourceTimer`, no `Timer.scheduledTimer` anywhere in the recording or hotkey path. The only timers in the app are: `PermissionManager.pollTimer` (only active while permission popover is open), `ModelWarmupService.watchdogTask` (only active during warmup), and a few UI-only `asyncAfter` calls in views (history flash, etc.). None can call `stopRecordingAndTranscribe()`.

- **Hypothesis #2 (Hotkey auto-repeat re-fire as toggle):** Eliminated for the modifier-listener path — there is no "toggle" semantics anywhere. `handleKeyUp` requires `isKeyDown == true` and unconditionally stops; it doesn't toggle. For the KeyboardShortcuts path: the AsyncStream emits explicit `.keyDown` and `.keyUp` events, not a single "fire" event, so auto-repeat would surface as repeated `.keyDown` (already filtered by the `isKeyDown` guard), not as a `.keyUp`.

- **Phase 17.5 IPC heartbeat:** Eliminated — grep for `heartbeat`, `IPC`, `XPC`, `distributedNotification` across `macOS/Dicticus/` + `Shared/` returns zero hits. The IPC bridge / heartbeat timer mentioned in orchestrator notes is iOS-side only.

- **TextInjector synthetic Cmd+V loopback:** Eliminated — `TextInjector.synthesizePaste()` uses a private `CGEventSource(stateID: .privateState)` and posts only `.maskCommand` flags, and runs only AFTER recording stop. Cannot trigger a mid-recording stop and cannot loop back into the global modifier monitor.

## Resolution

### Root Cause (proposed, high-confidence)

`ModifierHotkeyListener` uses `NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged)` and trusts every flag-state delta as ground truth. During long modifier-only holds — especially Fn+Control on Apple internal keyboards, where Fn is a soft modifier with known dispatcher quirks — the system can emit a spurious `flagsChanged` event in which the previously-held combo is no longer a superset, even though the user's fingers are still on both keys. `detectNSTransition` then returns `(mode: .aiCleanup, isPress: false)`, the listener fires `onComboReleased`, and `HotkeyManager.handleKeyUp` calls `stopRecordingAndTranscribe()`.

The 5–10 second timing is consistent with HID dispatcher idle behavior on long modifier-only holds without intervening keystrokes. AI cleanup mode reproduces more reliably because users tend to dictate longer utterances when they expect cleanup polishing — i.e. they hold the key longer.

Three independent code-side weaknesses make this manifest as a real bug rather than just a rare hiccup:

1. **No state resync.** The listener only knows what `flagsChanged` told it. There is no periodic verification against `NSEvent.modifierFlags` (the actual current state).
2. **No release debounce / confirmation.** A single suspect event triggers an immediate release.
3. **No mode-correlation guard in `handleKeyUp`.** Even if the released mode doesn't match the active recording mode, the stop fires.

### Suggested Fix

Layered defense (smallest change first; use whichever subset the user agrees to):

**Fix A — Mode-correlation guard in `handleKeyUp` (macOS only, ~5 lines):**
Track which `mode` started the active recording in `HotkeyManager`, and ignore `handleKeyUp(mode:)` calls whose `mode` doesn't match. This blocks any cross-talk between the two listener paths and any spurious release for a mode that isn't currently recording. Cheap and safe.

**Fix B — Release debounce in `ModifierHotkeyListener` (~15 lines):**
When `detectNSTransition` says "release," do NOT immediately fire `onComboReleased`. Instead, schedule a 50–80 ms `Task.sleep` and re-check `NSEvent.modifierFlags` (the live system state, not the cached `previousNSFlags`). If the live flags STILL don't contain the combo, fire release. If they do contain the combo, treat the original event as a transient and discard it (also reset `previousNSFlags` to the live value). This eliminates spurious-drop false-positives without affecting real releases (50–80 ms is below human key-release perception).

**Fix C — Periodic state resync (~10 lines):**
While a recording is active, poll `NSEvent.modifierFlags` every ~250 ms on the main thread and reconcile with `previousNSFlags`. Real releases would be caught by the existing `flagsChanged` path within ~1 frame; the poll only catches the failure mode where `flagsChanged` itself didn't fire when it should have. (This is the inverse failure mode — a real release missed — and may not be needed for the reported bug, but is cheap insurance.)

**Recommendation:** Apply Fix A + Fix B together. A is a sanity check that prevents whole classes of cross-talk bugs, and B directly addresses the most likely root cause. Skip C unless the user reports the inverse failure mode (recording stuck on after real release).

### Validation Plan

1. Land Fix A + B behind logging:
   - Log every `flagsChanged` event with previous + current flag bits.
   - Log every release-debounce decision (kept vs. discarded).
   - Log when `handleKeyUp` is rejected by the mode-correlation guard.
2. User reproduces by dictating a long sentence (~15 seconds) in cleanup mode while watching `Console.app` filtered to `com.dicticus`.
3. Success: zero "release discarded by debounce" events for real holds, zero `handleKeyUp rejected by mode guard` events for normal releases. Bug fixed if recording no longer cuts mid-hold.
4. Also test plain mode (Fn+Shift) for the same duration — confirm or eliminate that the bug is mode-agnostic.

### specialist_hint

swift
