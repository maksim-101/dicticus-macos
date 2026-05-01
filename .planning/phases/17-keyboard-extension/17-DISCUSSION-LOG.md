# Phase 17: Keyboard Extension - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-22
**Phase:** 17-keyboard-extension
**Areas discussed:** App-bounce architecture, Keyboard UI & scope, User flow & activation, Text return & insertion

---

## App-Bounce Architecture

**Pre-discussion research:** User asked whether keyboard extensions can access the microphone on iOS 26, and whether Shortcuts could show an overlay without switching apps. Four research agents investigated:

1. **Keyboard mic access:** Blocked since iOS 8, unchanged through iOS 26. All major keyboards (Gboard, SwiftKey, Wispr Flow) use bounce-to-host-app. iOS 26's `SpeechAnalyzer` doesn't help — mic access is the blocker, not the STT engine.
2. **Shortcuts overlay:** No third-party overlay API exists. Live Activities (Dynamic Island) are the closest — and Dicticus already has these. Brief app foreground is unavoidable for mic access.
3. **iOS 26 keyboard updates:** Only Liquid Glass cosmetics. No functional changes to extensions.
4. **iOS 26 overlay/intents:** Interactive Snippets are new but display-only (render in system process, can't record audio). `supportedModes` replaces deprecated `openAppWhenRun`.

| Option | Description | Selected |
|--------|-------------|----------|
| URL scheme bounce | Keyboard opens app via `dicticus://dictate`, app records, writes to App Group, keyboard reads + inserts | ✓ |
| Full-screen extension overlay | Extension tries to record audio in its own view — iOS blocks this | |
| Shortcut-based delegation | Reuse DictateIntent via Shortcuts framework — extra confirmation dialog friction | |

**User's choice:** URL scheme bounce (recommended)
**Notes:** Research confirmed this is the only viable path. Industry standard used by Wispr Flow, Gboard, SwiftKey.

---

## Keyboard UI & Scope

| Option | Description | Selected |
|--------|-------------|----------|
| Dictation-only keyboard | Minimal keyboard with just a dictate button + utility keys | |
| Full QWERTZ + dictate button | Complete keyboard replacement with standard QWERTZ + dictation | ✓ |
| Dictation toolbar | Input accessory view above system keyboard — only works within own app | |

**User's choice:** Full QWERTZ + dictate button
**Notes:** User's default is English + German QWERTZ without Umlauts.

### Typing depth (sub-question)

**Pre-question research:** KeyboardKit investigated. Found: v10 is closed-source binary with LicenseKit telemetry that phones home. Incompatible with privacy constraint. Free tier only supports English. German/emoji/suggestions/dictation all require paid tiers ($50-$1,500/yr).

| Option | Description | Selected |
|--------|-------------|----------|
| KeyboardKit-powered | Use KeyboardKit framework for full keyboard features | |
| Minimal QWERTZ + dictation | Build basic keys yourself, no autocorrect/predictions | |
| Skip suggestions for v1 | Ship with QWERTZ + dictation + emoji, defer word suggestions | ✓ |
| UITextChecker suggestions | Use Apple's built-in API for basic word completions | |
| SpeechAnalyzer + suggestions later | Defer to Apple Intelligence-powered suggestions | |

**User's choice:** Skip suggestions for v1 — build from scratch with UIInputViewController + SwiftUI
**Notes:** KeyboardKit ruled out for privacy. Word suggestions deferred to future phase.

### Language/layout (sub-question)

| Option | Description | Selected |
|--------|-------------|----------|
| Globe key for language + emoji | Two separate keyboards (DE + EN) with globe cycling | |
| Single bilingual keyboard | One QWERTZ layout for both languages, Parakeet auto-detects | ✓ |

**User's choice:** Single bilingual keyboard — always QWERTZ, globe key for emoji only

---

## User Flow & Activation

### Recording start/stop

| Option | Description | Selected |
|--------|-------------|----------|
| Auto-start, auto-stop on silence | Immediate recording, VAD stops it | |
| Auto-start, manual stop via Live Activity | Immediate recording, user taps Stop in Dynamic Island | |
| Both: auto-stop with manual override | Auto-stop default + Stop button in Live Activity | ✓ |

**User's choice:** Both — auto-stop on silence is the default, manual Stop button as override

### Return to original app

| Option | Description | Selected |
|--------|-------------|----------|
| User swipes back themselves | User controls when to return, recording continues in background | ✓ |
| Auto-return to previous app | App tries to navigate back programmatically — no reliable iOS API | |
| Encourage immediate swipe-back | Prominent "swipe back" message after recording starts | |

**User's choice:** User swipes back themselves — same as Wispr Flow

---

## Text Return & Insertion

### Detection mechanism

| Option | Description | Selected |
|--------|-------------|----------|
| App Group + polling | Poll shared UserDefaults every 0.5s | ✓ |
| Darwin notifications | CFNotificationCenter cross-process notification | |
| Both: Darwin + polling fallback | Notification with polling backup | |

**User's choice:** App Group + polling — simple, reliable

### Dictionary corrections timing

| Option | Description | Selected |
|--------|-------------|----------|
| Before insert (in main app) | Full pipeline runs in main app, extension gets corrected text | ✓ |
| After insert (in keyboard extension) | Extension applies corrections after receiving raw text | |

**User's choice:** Before insert — extension stays thin, same pipeline as Shortcut flow

---

## Claude's Discretion

- Key sizing, spacing, visual styling for QWERTZ layout
- Exact polling implementation details
- Keyboard height and safe area handling
- Edge case: user switches keyboard before result arrives
- Number/symbol layer layout
- Dark mode / Liquid Glass styling

## Deferred Ideas

- Word suggestions bar (future phase)
- SpeechAnalyzer benchmarking vs Parakeet v3 for de/en quality
- Interactive Snippets for Siri inline result display
- `supportedModes` migration (replace deprecated `openAppWhenRun`)
- Live Activity interactive Stop button
- `AVInputPickerInteraction` (mic selection)
- Shortcuts "Use Model" for Apple Intelligence cleanup (Phase 19 alt)
