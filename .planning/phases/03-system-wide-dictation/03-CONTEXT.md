# Phase 3: System-Wide Dictation - Context

**Gathered:** 2026-04-17
**Status:** Ready for planning

<domain>
## Phase Boundary

Deliver the core user-facing dictation workflow: user holds a configurable hotkey, speaks, releases, and transcribed text appears at the cursor in any app. This phase wires the existing ASR pipeline (Phase 2/2.1 TranscriptionService) to system-wide hotkeys, text injection via clipboard+paste, and visual recording feedback in the menu bar. It also registers the AI cleanup hotkey as a stub for Phase 4.

</domain>

<decisions>
## Implementation Decisions

### Push-to-Talk Mechanics
- **D-01:** Hold-to-record activation — hold hotkey starts recording, release triggers transcription and paste. Walkie-talkie mental model.
- **D-02:** Silent discard on short presses (< 0.3s) — TranscriptionService already rejects via .tooShort, just reset state silently. No error, no beep.
- **D-03:** Suppress key repeat at the hotkey handler level — track keyDown flag, ignore subsequent keyDown events until keyUp fires. Prevents multiple startRecording() calls.
- **D-04:** Default hotkey for plain dictation: **Fn+Shift** (left-hand combo). Note: Fn key is handled specially on macOS — researcher must verify KeyboardShortcuts support or determine if lower-level approach (CGEventTap, IOKit) is needed.
- **D-05:** Default hotkey for AI cleanup mode: **Fn+Control** (left-hand combo). Same Fn caveat as D-04.

### Text Injection
- **D-06:** Clipboard + Cmd+V paste strategy — save NSPasteboard contents, write transcription text, synthesize Cmd+V via CGEvent, restore original clipboard. Most reliable cross-app method.
- **D-07:** Clipboard save and restore — original clipboard contents preserved after injection. Small (~50ms) delay acceptable.
- **D-08:** Cmd+V for all apps including terminal emulators — single code path. Terminal.app and iTerm2 support Cmd+V by default on macOS.

### Recording Indicator
- **D-09:** Filled red mic icon (`mic.fill` with red tint) while recording — universally understood "recording" signal. Reverts to normal mic on release.
- **D-10:** No audio feedback on record start/stop — silent operation. Visual indicator is sufficient; audio cues could be picked up by the microphone.
- **D-11:** Spinner/hourglass icon during transcribing state (`ellipsis.circle` or similar) — shows app is processing after key release. Acceptable if brief on short clips; helpful for longer utterances.

### Hotkey Routing
- **D-12:** Register both hotkeys in Phase 3 — plain dictation (Fn+Shift) works end-to-end, AI cleanup (Fn+Control) is registered but stubbed.
- **D-13:** AI cleanup hotkey ignores silently in Phase 3 — no recording, no notification, no action. Phase 4 wires it to the LLM pipeline.
- **D-14:** Hotkeys are user-configurable from the start — use KeyboardShortcuts library's built-in preferences UI with recorder views in the menu bar dropdown. Conflict detection and UserDefaults persistence handled by the library.

### Error Handling
- **D-15:** macOS notification for real errors — post system notification for transcription failures (model error, mic unavailable). Brief, non-intrusive, doesn't steal focus.
- **D-16:** No notification for silence-only recordings — these are expected (accidental holds, thinking pauses). Silent return to idle.
- **D-17:** "Model loading..." notification if hotkey pressed before warm-up completes — informative, user can retry in a few seconds.

### Edge Cases
- **D-18:** Continue recording across app switches — recording doesn't stop when frontmost app changes. Text pastes into whatever app is frontmost on key release. Natural for system-wide dictation.
- **D-19:** Reject second hotkey press while transcribing — TranscriptionService throws .busy, show "Still processing..." notification. No queuing, no cancellation of in-progress work.

### Menu Bar Dropdown
- **D-20:** Add hotkey configuration section — KeyboardShortcuts recorder views for both hotkeys (plain dictation + AI cleanup).
- **D-21:** Add last transcription preview with copy button — shows truncated text of last successful transcription. Copy button as fallback if paste-at-cursor failed or user wants the text again.
- **D-22:** Existing permission rows and warmup row remain. Warmup row auto-hides when models are ready (existing behavior).

### Claude's Discretion
- Specific SF Symbol choice for transcribing state indicator
- Clipboard restore timing and delay values
- Notification content wording and category identifiers
- KeyboardShortcuts recorder view layout within dropdown
- Last transcription text truncation length
- CGEvent keystroke synthesis implementation details

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project Context
- `.planning/PROJECT.md` — Core value, constraints, key decisions
- `.planning/REQUIREMENTS.md` — TRNS-01, TRNS-05, APP-03, APP-04 are this phase's requirements
- `.planning/ROADMAP.md` — Phase 3 success criteria and dependency chain

### Technology Decisions
- `CLAUDE.md` §Technology Stack §macOS App Shell — KeyboardShortcuts (sindresorhus), AVFoundation, NSPasteboard + CGEvent, Accessibility API decisions
- `CLAUDE.md` §ASR Engine — FluidAudio SDK, Parakeet TDT v3

### Prior Phase Context
- `.planning/phases/01-foundation-app-shell/01-CONTEXT.md` — Menu bar design (D-05, D-06), permissions onboarding, SF Symbol icon pattern
- `.planning/phases/02-asr-pipeline/02-CONTEXT.md` — TranscriptionService architecture (D-13, D-14, D-15), VAD defense layers
- `.planning/phases/02.1-asr-engine-swap-whisperkit-to-fluidaudio-parakeet-tdt-v3/02.1-CONTEXT.md` — FluidAudio migration, service API preservation (D-04, D-05, D-06)

### Existing Code (Phase 3 integration points)
- `Dicticus/Dicticus/Services/TranscriptionService.swift` — `startRecording()`, `stopRecordingAndTranscribe()`, State enum (.idle, .recording, .transcribing)
- `Dicticus/Dicticus/DicticusApp.swift` — `transcriptionService` @State, warmup→service wiring via onChange
- `Dicticus/Dicticus/Views/MenuBarView.swift` — Current dropdown layout (permissions, warmup, quit)
- `Dicticus/Dicticus/Services/ModelWarmupService.swift` — `isReady`, `isWarming` published properties
- `Dicticus/Dicticus/Services/PermissionManager.swift` — Permission state checking

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `TranscriptionService` — Full ASR pipeline with `startRecording()` / `stopRecordingAndTranscribe()` API, ready for hotkey wiring
- `TranscriptionService.State` enum — `.idle`, `.recording`, `.transcribing` states that map directly to icon states (normal mic, red mic, spinner)
- `DicticusTranscriptionResult` — Engine-agnostic result with `.text`, `.language`, `.confidence`
- `ModelWarmupService.isReady` — Boolean to gate hotkey activation
- Menu bar icon pulse animation pattern (`.symbolEffect(.pulse)`) — established in Phase 1 for warm-up
- `PermissionManager.allGranted` — Can gate hotkey registration on required permissions

### Established Patterns
- `@MainActor` ObservableObject services with `@Published` state
- `.environmentObject()` injection from DicticusApp into MenuBarView
- `.onChange(of:)` for reactive wiring (warmup → transcription service creation)
- SF Symbol monochrome template icons with `.symbolEffect()` for animations

### Integration Points
- `DicticusApp.transcriptionService` already held as `@State` — hotkey handler can call `.startRecording()` / `.stopRecordingAndTranscribe()` on it
- `DicticusApp.body` MenuBarExtra label — icon state computation already exists, extend with recording/transcribing states
- `MenuBarView` — add hotkey config section and last transcription preview below existing content
- CGEvent for Cmd+V synthesis requires Accessibility permission — already checked in PermissionManager

</code_context>

<specifics>
## Specific Ideas

- User chose Fn+Shift and Fn+Control as hotkey defaults — both are left-hand ergonomic combos using Fn as anchor. Fn key is special on macOS (not a standard NSEvent modifier) — research whether KeyboardShortcuts supports it or if lower-level event handling is needed.
- Last transcription in dropdown serves as a safety net — if paste-at-cursor fails, user can still copy text manually.
- The three-state icon progression (normal mic → red filled mic → spinner → normal mic) maps cleanly to TranscriptionService.State enum.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 03-system-wide-dictation*
*Context gathered: 2026-04-17*
