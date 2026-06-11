# Roadmap: Dicticus

## Milestones

- ✅ **v1.0 MVP** — Phases 1-5 (shipped 2026-04-18) — [Archive](milestones/v1.0-ROADMAP.md)
- ✅ **v1.1 Cleanup Intelligence & Distribution** — Phases 6-11 (shipped 2026-04-20)
- ✅ **v2.0 iOS App — Shortcut Dictation** — Phases 12-16 (shipped 2026-04-22)
- ✅ **v2.1 Keyboard Extension & Polish** — Phases 17+ (shipped 2026-04-23)
- ✅ **v2.2 Adaptive Cleanup & Stability** — Phases 21-26 (shipped 2026-05-22)
- ✅ **v2.3 Live-Capture Quality Pass** — Phases 27-30 (shipped 2026-06-06, macOS 1.3.0) — [Archive](milestones/v2.3-ROADMAP.md)
- ✅ **v2.4 Public-Release Readiness + Dictionary as Platform** — Phases 31-35 (shipped 2026-06-09) — [Archive](milestones/v2.4-ROADMAP.md)
- 🔄 **v2.5 iOS Release & Context-Aware Dictation** — Phases 36-40 (in progress)

---

## Completed Phases

| Phase | Milestone | Scope | Status | Result |
|-------|-----------|-------|--------|--------|
| 12. Shared Code | v2.0 | Shared pipeline, ITN, Dictionary, GRDB | ✅ Done | Success |
| 13. iOS Pipeline | v2.0 | FluidAudio iOS, App Intent, Live Activity | ✅ Done | Success |
| 14. Model Mgmt | v2.0 | Onboarding, Model Provisioning (2.7GB) | ✅ Done | Success |
| 15. History & Dict | v2.0 | History View, Dictionary UI, FTS5 | ✅ Done | Success |
| 16. Universal App | v2.0 | iPad Layout, WhatsNew, Launch Screen | ✅ Done | Success |
| 17. Keyboard Extension | v2.1 | Custom iOS Keyboard with in-app dictation — text at cursor without app switching | ✅ Done | Success |
| 27. Dictionary Hallucination Guard | v2.3 | Fuzzy-pass guard, recorder enrichment, K7 brand adds | ✅ Done | 2026-05-27 |
| 28. V19D Prompt Iteration | v2.3 | Clause preservation, contraction, dedup, number policy | ✅ Done | 2026-05-27 |
| 29. ASR Post-Processing | v2.3 | Acronym collapse, spoken-letter lexicon, Zed fix | ✅ Done | 2026-05-29 |
| 30. PTT Media Auto-Pause (macOS) | v2.3 | ScriptingBridge pause/resume + mute fallback | ✅ Done | 2026-06-06 |
| 31. Dictionary as Platform | v2.4 | Public default split + CSV import/export + starter packs + docs | ✅ Done | 2026-06-06 |
| 32. Spoken Punctuation | v2.4 | Deterministic pre-LLM punctuation collapse (Shared/) | ✅ Done | 2026-06-07 |
| 33. iOS First-Run & Onboarding Polish | v2.4 | Fix flash, truncation, duplicate UI; guided wizard | ✅ Done | 2026-06-07 |
| 34. V19E — R8 Over-Promotion Fix | v2.4 | Tighten R8, content-word preservation gate | ✅ Done | 2026-06-08 |
| 35. UI Reorganization | v2.4 | macOS tabbed popover + 4-pane Settings; iOS 3-tab | ✅ Done | 2026-06-09 |

---

## Phases: v2.5 iOS Release & Context-Aware Dictation

- [ ] **Phase 36: iOS Background Dictation** — Spike-first: validate App Review design, then implement background mic recording with Live Activity stop control
- [ ] **Phase 37: iOS Distribution** — Background Assets model download, privacy labels, TestFlight + App Store submission
- [ ] **Phase 38: Context-Aware Formatting** — Active-app detection → AI-cleanup prompt adaptation (macOS-primary, cross-platform via Shared/)
- [ ] **Phase 39: Voice Edit Commands** — Deterministic pre-LLM spoken edit commands ("scratch that", "new paragraph", "capitalize X")
- [ ] **Phase 40: Windows Feasibility Spike** — Written feasibility report for Windows port; no shipping code

---

## Progress: v2.5

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 36. iOS Background Dictation | 4/4 | In Progress (awaiting verification) |  |
| 37. iOS Distribution | 0/TBD | Not started | - |
| 38. Context-Aware Formatting | 0/TBD | Not started | - |
| 39. Voice Edit Commands | 0/TBD | Not started | - |
| 40. Windows Feasibility Spike | 0/TBD | Not started | - |

---

## Phase Details

### Phase 36: iOS Background Dictation

**Goal**: User can start dictating on iOS, switch apps or lock the screen mid-dictation, and receive a complete accurate transcript when they stop — without data loss and without keeping Dicticus in the foreground
**Depends on**: Phase 35 (v2.4 shipped)
**Requirements**: IOSBG-01, IOSBG-02, IOSBG-03
**App-Review risk**: HIGH — `UIBackgroundModes: audio` is scrutinized; spike validated the design (CONDITIONAL-GO → deferred-delivery re-scope) before implementation
**Success Criteria** (what must be TRUE):

  1. User starts dictation in Dicticus, switches to another app (or locks screen), and the orange mic indicator stays visible in the iOS status bar throughout
  2. User stops dictation via the Live Activity stop control (Dynamic Island / lock screen) without returning to the Dicticus app
  3. When the user next opens Dicticus, the full recording is transcribed with no audio data lost; cleanup + clipboard + on-screen delivery happen on foreground (iOS blocks background GPU/clipboard — spike-proven)
  4. The background-recording design has been reviewed against App Store review guidelines and uses the correct `AVAudioSession` category with a clear user-facing justification documented in the spike

**Architecture (re-scoped 2026-06-10 after the 36-01 spike)**: capture-in-background, finish-on-foreground. Background audio + ASR work; LLM cleanup (GPU/Metal) and `UIPasteboard` are iOS-blocked backgrounded, so delivery defers to the next foreground with an away-stop local notification. See `36-CONTEXT.md` / `36-SPIKE-FINDINGS.md`.

**Plans**: 4 plans (spike done; implementation in 3 sequential waves, each gated on a device human-verify)

- [x] 36-01-PLAN.md — IOSBG-03 feasibility / App-Review spike (CONDITIONAL-GO → deferred-delivery re-scope)
- [x] 36-02-PLAN.md — Background-capture foundation: supersede spike scaffolding, no-finalize-on-background, ContentState `startedAt` + `Text(timerInterval:)`, restore silence auto-stop + toggle cleanup (IOSBG-01)
- [x] 36-03-PLAN.md — No-reopen stop controls: fix expanded/lock-screen Live Activity Stop, Action-Button toggle-to-stop, ~5-min soft cap (IOSBG-01 / D-01, D-01a, D-03)
- [x] 36-04-PLAN.md — Deferred delivery: background-aware persist (zero data loss), foreground auto-cleanup+copy+show, away-stop notification, multiple-pending queue (IOSBG-02 / D-02, D-02a, D-05)

**UI hint**: yes

### Phase 37: iOS Distribution

**Goal**: Any iOS user can install Dicticus from TestFlight (then the App Store), download the ASR model post-install with clear progress and consent, and trust that the app accurately represents its data practices to Apple and to them
**Depends on**: Phase 36
**Requirements**: IOSDIST-01, IOSDIST-02, IOSDIST-03
**App-Review risk**: MEDIUM — privacy labels and microphone/background justifications must be accurate and specific to avoid rejection
**Success Criteria** (what must be TRUE):

  1. A user with no Xcode or developer tools can install Dicticus on their iPhone by accepting a TestFlight invite (or App Store link)
  2. On first launch, the app presents the ~2.7 GB model download with its size stated, a progress indicator, and a consent step — the user is never surprised by a large download
  3. The app's App Store privacy label correctly states "Data Not Collected" (no audio/transcripts leave the device) and specifies microphone and background-audio usage in terms App Review accepts
  4. The app passes at least one complete App Review cycle (TestFlight or App Store) without rejection on privacy or background-mode grounds

**Plans**: TBD
**UI hint**: yes

### Phase 38: Context-Aware Formatting

**Goal**: AI cleanup adapts its tone and formatting to whatever app the user is dictating into — a code editor gets different output than an email client — without any network calls, and the user can override or disable this behaviour
**Depends on**: Phase 35 (v2.4 shipped)
**Requirements**: CTXFMT-01, CTXFMT-02, CTXFMT-03
**Success Criteria** (what must be TRUE):

  1. When the user dictates into a code editor (e.g., Xcode, VS Code), AI cleanup preserves identifiers, avoids sentence-capitalizing code tokens, and omits filler reformatting that would break code context
  2. When the user dictates into a chat app or email client, AI cleanup formats the output as natural prose appropriate to that context
  3. Active-app detection happens entirely on-device: no app name, window title, or text is sent to any network endpoint
  4. A Settings toggle lets the user disable context-aware formatting entirely; a separate control lets them pin a specific context (overriding auto-detection) for the current session

**Plans**: TBD

### Phase 39: Voice Edit Commands

**Goal**: User can dictate correction commands ("scratch that", "new paragraph", "capitalize last word") that are applied deterministically to the transcript — without the LLM being involved in command recognition
**Depends on**: Phase 35 (v2.4 shipped)
**Requirements**: VEDIT-01, VEDIT-02
**Success Criteria** (what must be TRUE):

  1. User says "scratch that" immediately after a dictation and the most-recent pasted text is removed from the active text field
  2. User says "new paragraph" and a paragraph break is inserted at the insertion point
  3. Edit commands are matched by a deterministic rule layer (not sent to the LLM), so command recognition has zero latency beyond the normal dictation transcription time
  4. If the user dictates text that happens to contain command-like phrases as literal content, the distinction between command and literal is clear and documented (e.g., commands only trigger when spoken as a standalone utterance)

**Plans**: TBD

### Phase 40: Windows Feasibility Spike

**Goal**: A written report exists that scopes a Windows port — covering ASR (whisper.cpp), LLM (llama.cpp), app shell, global hotkeys, text injection, and model sharing — with a recommendation and rough effort estimate; no production code is written
**Depends on**: Nothing (fully independent research phase)
**Requirements**: WIN-01
**Success Criteria** (what must be TRUE):

  1. The report answers: can the same GGUF model files be used on Windows without conversion?
  2. The report specifies the minimum Windows API surface needed for push-to-talk + text-at-cursor injection and identifies any showstoppers
  3. The report gives a rough effort estimate (e.g., person-weeks) and a clear go/no-go recommendation for a v3.0 Windows port

**Plans**: TBD

---

### Phase 36 (archive — v2.5 candidate stub from v2.4): iOS Background Dictation Recording (v2.5 candidate — SPIKE-FIRST)

**Goal**: A user can trigger dictation, leave Dicticus (or lock the screen), keep speaking while looking at what they're answering, stop from the Live Activity, and paste the result — all without reopening the app
**Origin**: Found during Phase 33 UAT (2026-06-08). The dictation Live Activity implied background recording but iOS suspended the app and recording stopped (no `audio` background mode; elapsed ticker hardcoded to 0). Interim fix (commit 82f2860) removed the misleading Live Activity and finalizes-on-background; this phase builds the real feature.
**Not public-release-blocking** — deferred to v2.5.
**Technical feasibility (established in discussion)**:

  - Background mic recording IS possible for the main app via `UIBackgroundModes: audio` + a keep-alive `AVAudioSession` — recording must be STARTED in the foreground, then continues into background/lock. (The keyboard-extension mic restriction is a separate, unrelated constraint.)
  - Stop without returning: Live Activity Stop control (Dynamic Island / lock screen) — `StopDictationIntent` already wired. Optional VAD silence auto-stop (`onSilenceDetected` already exists).
  - Clipboard without returning: `UIPasteboard` write is programmatic; wrap the post-stop transcribe tail in `beginBackgroundTask` so it completes while backgrounded.
  - Known friction: iOS has no API to auto-return the user to their previous app (Messages, etc.) — "return" is a manual swipe; and App Store review scrutinizes the `audio` background mode (defensible for a dictation app, not a rubber stamp).

---

## Backlog

Unsequenced parking lot (999.x). Promote with `/gsd-review-backlog` when ready.

### Phase 999.1: Post-ASR / AI-Cleanup Robustness (BACKLOG)

**Goal:** [Captured for future planning] — harden ASR/LLM-cleanup output quality (scaffolding-tag leakage, self-correction dropping, number/ITN oddities).
**Requirements:** TBD
**Plans:** 0 plans — see `.planning/phases/999.1-post-asr-cleanup-robustness/999.1-BACKLOG.md` for accumulated items.

Plans:
- [ ] TBD (promote with /gsd-review-backlog when ready)
