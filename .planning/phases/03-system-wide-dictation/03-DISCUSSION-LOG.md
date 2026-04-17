# Phase 3: System-Wide Dictation - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-17
**Phase:** 03-system-wide-dictation
**Areas discussed:** Push-to-talk mechanics, Text injection strategy, Recording indicator, Hotkey routing for modes, Error handling UX, Edge cases during recording, Menu bar dropdown updates

---

## Push-to-Talk Mechanics

| Option | Description | Selected |
|--------|-------------|----------|
| Hold-to-record | Hold hotkey = recording, release = transcribe. Walkie-talkie model. | ✓ |
| Toggle on/off | Press once to start, press again to stop. | |
| Both modes | Hold-to-record default + separate toggle hotkey for long dictations. | |

**User's choice:** Hold-to-record
**Notes:** None — straightforward selection.

---

| Option | Description | Selected |
|--------|-------------|----------|
| Silent discard | TranscriptionService already rejects < 0.3s. Reset silently. | ✓ |
| Brief visual flash | Flash menu bar icon briefly on short tap. | |
| Ignore at hotkey level | Don't start recording until key held 0.3s. | |

**User's choice:** Silent discard
**Notes:** None.

---

| Option | Description | Selected |
|--------|-------------|----------|
| Suppress repeats | Track keyDown flag, ignore subsequent keyDown until keyUp. | ✓ |
| Let KeyboardShortcuts handle it | Trust library to deduplicate held keys. | |

**User's choice:** Suppress repeats
**Notes:** None.

---

| Option | Description | Selected |
|--------|-------------|----------|
| Fn+D | Fn + D for dictation. Mnemonic. | |
| Ctrl+Shift+Space | Three-key combo, similar to macOS native dictation. | |
| Option+Space | Two-key combo, may conflict with Spotlight alternatives. | |

**User's choice:** Fn+Shift (custom, via free text)
**Notes:** User specified Fn+Shift as left-hand combo. Also specified Fn+Control for AI cleanup mode in the same response.

---

## Text Injection Strategy

| Option | Description | Selected |
|--------|-------------|----------|
| Clipboard + Cmd+V | Save clipboard, write text, synthesize Cmd+V, restore clipboard. | ✓ |
| Accessibility API first | Try AXUIElement.setValue() first, fallback to clipboard+paste. | |
| Clipboard only, no restore | Overwrite clipboard, paste. Loses previous clipboard contents. | |

**User's choice:** Clipboard + Cmd+V (after clarification of how it works)
**Notes:** User initially wasn't sure about the mechanism. After explanation of save→put→paste→restore flow, confirmed this approach.

---

| Option | Description | Selected |
|--------|-------------|----------|
| Save and restore | Save clipboard before paste, restore after. ~50ms overhead. | ✓ |
| Overwrite clipboard | Replace clipboard with transcription. Simpler but lossy. | |

**User's choice:** Save and restore
**Notes:** None.

---

| Option | Description | Selected |
|--------|-------------|----------|
| Cmd+V for all apps | Single code path. macOS terminals support Cmd+V. | ✓ |
| Detect terminal, use Cmd+Shift+V | Detect frontmost app and adjust paste shortcut. | |
| You decide | Let Claude choose. | |

**User's choice:** Cmd+V for all apps
**Notes:** None.

---

## Recording Indicator

| Option | Description | Selected |
|--------|-------------|----------|
| Filled red mic | mic.fill with red tint while recording. | ✓ |
| Pulsing animation | Reuse pulse from warm-up in different color. | |
| Different SF Symbol | Switch to waveform or mic.circle.fill. | |

**User's choice:** Filled red mic
**Notes:** None.

---

| Option | Description | Selected |
|--------|-------------|----------|
| No audio feedback | Silent operation. Visual indicator sufficient. | ✓ |
| Subtle system sound | Short system sound on start/stop. | |
| You decide | Let Claude choose. | |

**User's choice:** No audio feedback
**Notes:** None.

---

| Option | Description | Selected |
|--------|-------------|----------|
| Spinner/hourglass icon | Show processing indicator during transcription. | ✓ |
| Keep red mic until done | Red stays until text is pasted. | |
| No indicator | Go straight back to idle on release. | |

**User's choice:** Spinner/hourglass icon
**Notes:** User noted concern about animation speed for short clips — acknowledged that brief flash is acceptable for short transcriptions, while longer utterances benefit from visible spinner.

---

## Hotkey Routing for Modes

| Option | Description | Selected |
|--------|-------------|----------|
| Register both now | Register plain + cleanup hotkeys. Cleanup is stubbed. | ✓ |
| Only plain dictation hotkey | Add cleanup hotkey in Phase 4. | |
| Register both, cleanup does plain | Both work but cleanup also does plain until Phase 4. | |

**User's choice:** Register both now
**Notes:** None.

---

| Option | Description | Selected |
|--------|-------------|----------|
| Ignore silently | Hotkey registered but does nothing. | ✓ |
| Brief menu bar flash | Flash icon to acknowledge press. | |
| Do plain dictation instead | Both hotkeys do same thing until Phase 4. | |

**User's choice:** Ignore silently
**Notes:** None.

---

| Option | Description | Selected |
|--------|-------------|----------|
| Configurable from start | KeyboardShortcuts recorder UI in dropdown. | ✓ |
| Hardcoded defaults for now | Fixed combos, config in Phase 5. | |
| You decide | Let Claude choose. | |

**User's choice:** Configurable from start
**Notes:** None.

---

## Error Handling UX

| Option | Description | Selected |
|--------|-------------|----------|
| macOS notification | Post system notification for failures. | ✓ |
| Menu bar icon flash | Brief error icon in menu bar. | |
| Silent failure | Return to idle with no feedback. | |

**User's choice:** macOS notification
**Notes:** None.

---

| Option | Description | Selected |
|--------|-------------|----------|
| No notification for silence | Silence is expected — silent return to idle. | ✓ |
| Notify for silence too | Always notify on any failed transcription. | |
| Configurable | Default silent, add debug/verbose mode. | |

**User's choice:** No notification for silence
**Notes:** None.

---

| Option | Description | Selected |
|--------|-------------|----------|
| Notification: 'Model loading...' | Inform user models aren't ready yet. | ✓ |
| Queue and record anyway | Record audio, transcribe when model loads. | |
| Block hotkey until ready | Don't register hotkeys until ready. | |

**User's choice:** Notification: 'Model loading...'
**Notes:** None.

---

## Edge Cases During Recording

| Option | Description | Selected |
|--------|-------------|----------|
| Continue recording | Recording persists across app switches. Text pastes into frontmost app on release. | ✓ |
| Cancel recording on app switch | Stop recording if frontmost app changes. | |

**User's choice:** Continue recording
**Notes:** Natural for system-wide dictation — user might switch to target app while speaking.

---

| Option | Description | Selected |
|--------|-------------|----------|
| Reject with notification | Show 'Still processing...' and ignore second press. | ✓ |
| Queue the second request | Accept second recording, queue behind first. | |
| Cancel first, start second | Abort in-progress, start new recording. | |

**User's choice:** Reject with notification
**Notes:** None.

---

## Menu Bar Dropdown Updates

| Option | Description | Selected |
|--------|-------------|----------|
| Add hotkey config only | Shortcuts section with recorder views. | |
| Hotkey config + last transcription | Shortcuts + last transcription preview. | ✓ |
| Full status dashboard | Comprehensive dashboard with all states. | |

**User's choice:** Hotkey config + last transcription with copy button (custom, via free text)
**Notes:** User specified the last transcription should include a copy icon as a fallback — if paste-at-cursor failed or user wants the text again.

---

## Claude's Discretion

- SF Symbol choice for transcribing state indicator
- Clipboard restore timing and delay values
- Notification content wording and category identifiers
- KeyboardShortcuts recorder view layout
- Last transcription text truncation length
- CGEvent keystroke synthesis details

## Deferred Ideas

None — all discussion stayed within Phase 3 scope.
