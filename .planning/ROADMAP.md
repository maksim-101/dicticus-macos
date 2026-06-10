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
| 36. iOS Background Dictation | 1/4 | In Progress|  |
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
**App-Review risk**: HIGH — `UIBackgroundModes: audio` is scrutinized; spike validates the design before implementation commits to it
**Success Criteria** (what must be TRUE):

  1. User starts dictation in Dicticus, switches to another app (or locks screen), and the orange mic indicator stays visible in the iOS status bar throughout
  2. User stops dictation via the Live Activity stop control (Dynamic Island / lock screen) without returning to the Dicticus app
  3. When the user next opens Dicticus (or the transcript completes in background), the full recording is transcribed with no audio data lost
  4. The background-recording design has been reviewed against App Store review guidelines and uses the correct `AVAudioSession` category with a clear user-facing justification documented in the spike

**Plans**: 4 plans (spike-first; plans 02-04 gated on the 36-01 spike GO)

- [x] 36-01-PLAN.md — IOSBG-03 feasibility / App-Review spike (D-04 go/no-go gate)
- [ ] 36-02-PLAN.md — Background audio foundation: .playAndRecord + UIBackgroundModes:audio, no-finalize-on-background, ContentState startedAt
- [ ] 36-03-PLAN.md — Live Activity re-enable + Stop control + soft cap (D-01, D-03)
- [ ] 36-04-PLAN.md — Transcript delivery: notification + clipboard + zero-data-loss safety net (D-02, D-02a)

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

**Spike-first targets**: (1) can an AppIntent/Shortcut start the mic without a jarring app-switch; (2) the background-task transcription tail under real suspension timing.
**Re-enable**: the dormant Live Activity (DictationLiveActivity.swift), `startLiveActivity()`, real elapsed timer, Stop control.
**Requirements**: IOSBG-01, IOSBG-02, IOSBG-03
**Plans**: TBD

---

### Phase 19: AI Cleanup iOS

**Goal:** Enable on-device AI cleanup of ASR transcriptions on iOS via llama.cpp with Metal acceleration — improving number/currency/date formatting and enforcing Swiss German orthography (ß→ss) without any network calls.

**Requirements:** CLEAN-01, CLEAN-02

**Plans:** 1/4 plans executed

- [x] 19-01-PLAN.md — Wave 0 test scaffolding (TDD red targets for Wave 1-4) — completed 2026-04-24
- [x] 19-02-PLAN.md — SPM wiring + CleanupService extraction to Shared/ + Swiss ITN/prompt — completed 2026-04-24
- [x] 19-03-PLAN.md — IOSModelDownloadService (URLSession delegate, pause/resume, backup exclusion) + device eligibility — completed 2026-04-24
- [x] 19-04-PLAN.md — IOSModelWarmupService Step 4 (conditional LLM load, graceful degradation) — completed 2026-04-24
- [x] 19-05-PLAN.md — Settings UI (AiCleanupSection: toggles + inline download panel) — completed 2026-04-24
- [x] 19-06-PLAN.md — DictationViewModel + DicticusApp integration (TextProcessingService wiring + E2E) — completed 2026-04-24

---

### Phase 19.5: AI Cleanup CH-Determinism

**Goal:** Make AI-cleanup output reliably Swiss-correct on iOS and macOS in a deterministic way: ASCII-apostrophe thousands separator, period decimal everywhere when Swiss toggle is ON, Helvetism prompt block, German-locale currency anti-flip pipeline (CHF↔EUR↔USD↔GBP), Swiss default ON migration, macOS toggle UI exposure, and the B2 Parakeet false-re-download hotfix.

**Requirements:** None directly — parent CLEAN-01, CLEAN-02 already met by Phase 19. This phase tightens correctness from B5/B6/S7/S8 UAT findings + B2 regression hotfix.

**Plans:** 5/5 plans complete

- [x] 19.5-01-PLAN.md — B2 Parakeet warmup hotfix (D-D1)
- [x] 19.5-02-PLAN.md — Swiss default migration + iOS default flip + macOS toggle UI (D-A1, D-A2, D-A3)
- [x] 19.5-03-PLAN.md — New Shared utilities: SwissHelvetisms, CurrencyAntiFlip, SwissNumberFormatter (D-D2, D-B1a, D-B1c, D-C1, D-C2, D-C3)
- [x] 19.5-04-PLAN.md — Wire utilities into CleanupPrompt (HELVETISMS + STRICT) and CleanupService (revert + number formatter) (D-B1b, D-B1c, D-D2, D-C2/C3)
- [x] 19.5-05-PLAN.md — Tests + fixtures for migration, utilities, and B5/B6 integration regression

---

### Phase 17: Keyboard Extension

**Goal:** Implement a custom iOS keyboard extension with a QWERTZ layout and an integrated dictation button that bounces to the main app for recording and auto-inserts the result at the cursor.

**Requirements:** KEYB-01, KEYB-02

**Plans:**

- [x] 17-01-PLAN.md — Foundation, Target Setup, and URL Scheme
- [x] 17-02-PLAN.md — Keyboard UI (SwiftUI QWERTZ Layout)
- [x] 17-03-PLAN.md — Dictation Loop and Result Delivery
- [x] 17-04-PLAN.md — Live Activity Stop Button and Polish

---

### Phase 17.5: Darwin IPC Keyboard Dictation (PIVOTED)

**Goal:** Enable the Dicticus keyboard extension's mic button to trigger dictation in the main app via Darwin notification IPC, with transcription inserted directly at the cursor via textDocumentProxy — user never leaves their current app.

**Requirements:** KEYB-02 (text at cursor without app switching — keyboard extension approach)

**Plans:** 3 plans

- [x] 17.5-01-PLAN.md — Intent flag wiring + ViewModel shortcut-launch lifecycle (Action Button fallback)
- [x] 17.5-02-PLAN.md — IPC Bridge (shared) + Host Bridge (main app) + DictationViewModel wiring
- [x] 17.5-03-PLAN.md — Keyboard IPC Manager + Dictation Controller + UI updates

---

### Phase 20: AI Cleanup Demotion + UAT Visibility

**Goal:** Demote the LLM cleanup stage from authoritative rewriter to optional polish layer. Move deterministic cleanup (filler removal, currency-fold, self-correction) into Swift; gate the LLM behind a Levenshtein verification step with a low-creativity prompt; expose raw vs. polished output in the iOS history detail view; replace the App-Group-container `fatalError` in HistoryService with graceful degradation so the app never crashes when entitlements are missing.

**Requirements:** None directly — follow-on from Phase 19.5 UAT findings. Cross-platform parity: ships on macOS and iOS together.

**Plans:** 5/5 plans executed

- [x] 20-01-PLAN.md — Wave 0 RED test scaffolding
- [x] 20-02-PLAN.md — Action 1 (Rein in LLM): temp 0.1, "Lightly edit" prompt, LevenshteinDistance utility, gateLLMOutput helper
- [x] 20-03-PLAN.md — Action 2 (Rules-first deterministic): FillerWordRemover + SelfCorrectionResolver + currency-fold + RulesCleanupService
- [x] 20-04-PLAN.md — Action 4 (Resilience): HistoryService graceful App-Group fallback
- [x] 20-05-PLAN.md — Action 3 (Visibility): iOS HistoryDetailView + macOS inline disclosure

---

### Phase 20.06: AI Cleanup Behavioural Hotfix

**Goal:** Close the gap between Phase 20's artifact-level success and its behavioural goal. Fix HELVETISMS regression, currency-fold idempotency, iOS history UX issues.

**Plans:** 4 plans (+ in-phase fix) — all complete. macOS Release UAT 2026-04-27 ACCEPTED.

---

### Phase 20.08: LLM Swiss-Ification Suppression

**Goal:** Stop the LLM from rewriting clean High German into Swiss German dialect. Two-pronged: dialect-suppression gate + empirical prompt restructure (V19C winner variant g15).

**Plans:** 5/5 plans complete. macOS UAT 2026-05-01 ACCEPTED.

---

### Phase 19.7: macOS Hygiene

**Goal:** Hotkey re-authorization flow, multi-install cleanup, in-app permission status indicator, app icon consistency.

**Plans:** 4 plans (all complete)

---

### Phase 22: Resolver Regression Hotfix

**Goal:** Stop SelfCorrectionResolver from eating user content as substring matches inside unrelated words.

**Plans:** 2 plans — complete.

---

### Phase 25: AI Cleanup Quality v3 — Brand & Acronym Recognition

**Goal:** Reduce isolated-brand mishearing failure rate, eliminate `forty one → 4001` digit-concatenation class, collapse acronym-letter-spacing, fix the `phase ↔ face` homophone class, enable plain-mode JSONL for A/B comparison.
**Plans:** 2/4 plans executed

---

### Phase 25.1: AI Cleanup Quality v3b — paper-driven remediation

**Goal:** Apply research paper recommendations to close 5 defect classes and 2 telemetry gaps from Phase 25's live-capture window.
**Plans:** 4/6 plans executed. V19C shipped 2026-05-22 (90.2% clean rate).

---

### Phase 26: Pipeline Quality Hardening

**Goal:** Fix 4 user-visible quality issues found in V19C live UAT (ITN concatenation, SelfCorrectionResolver doch/oder, dictionary Vercel false positive, point/dash/zero numeric structural words).
**Plans:** 3/3 plans complete.

---

### Phase 27: Dictionary Hallucination Guard + Recorder Enrichment + K7 Brand Adds

**Goal:** Stop DictionaryService fuzzy-pass from mutating valid English/German words into brand names; enrich recorder schema; batch-add K7 brand misses.

**Requirements:** DICT-SAFE-01, DICT-SAFE-02, DICT-EXPAND-01, OBS-DICT-01

**Plans:** 3/3 plans complete (completed 2026-05-27)

---

### Phase 28: V19D Prompt Iteration

**Goal:** Iterate CleanupPrompt.swift V19C → V19D: clause preservation, contraction handling, generalized stutter dedup, principled standalone-number policy, topic-words audit.

**Requirements:** LLM-CLAUSE-01, LLM-CONTR-01, LLM-DEDUP-01, LLM-NUM-01, LLM-PROMPT-AUDIT-01

**Plans:** 4/4 plans complete (completed 2026-05-27; UAT closed 2026-05-29)

---

### Phase 29: ASR Post-Processing: Acronym Collapse, Spoken-Letter Lexicon & Zed Fix

**Goal:** Deterministic post-ASR text-processing: acronym collapse, spoken-letter lexicon (zed/zee→Z), Zed-editor dictionary entry. Cross-platform (Shared/).

**Requirements:** ACRONYM-COLLAPSE-01, SPOKEN-LETTER-01, DICT-ZED-01

**Plans:** 2/2 plans complete (completed 2026-05-29)

---

### Phase 30: PTT Media Auto-Pause (macOS)

**Goal:** Pause media while PTT is held, resume on release. ScriptingBridge for Music/Spotify; CoreAudio/AppleScript mute fallback for non-scriptable sources. macOS-only.

**Requirements:** MEDIA-PAUSE-01, MEDIA-PAUSE-02, MEDIA-PAUSE-03

**Plans:** 3/3 plans complete (completed 2026-06-06; signed-app UAT PASS both tiers)

---

### Phase 31: Dictionary as Platform

**Goal:** Ship a clean public dictionary default (zero personal entries in Release binary) with CSV/JSON import-export, merge strategies, offline starter packs, and documentation for the CSV-author workflow.

**Requirements:** DICT-SPLIT-01..04, DICT-IO-01..04, TECHLEX-01..02

**Plans:** all complete (completed 2026-06-06)

---

### Phase 32: Spoken Punctuation

**Goal:** Deterministic pre-LLM spoken-punctuation collapse in Shared/: unambiguous tokens always collapse; conditional tokens only between identifier-shaped flanks. Cross-platform. In-app reference table.

**Requirements:** PUNCT-01..04

**Plans:** all complete (completed 2026-06-07)

---

### Phase 33: iOS First-Run & Onboarding Polish

**Goal:** Fix cold-launch download flash, untruncated download copy, remove duplicate Action Button entry; add auto-presenting + re-triggerable 3-page onboarding wizard.

**Requirements:** IOS-ONB-01..05

**Plans:** all complete (completed 2026-06-07)

---

### Phase 34: V19E — R8 Over-Promotion Fix

**Goal:** Tighten R8 EXCEPTION prompt wording + add `gateContentWords` set-membership gate to eliminate the kink→K3 / King Four→K4 word-loss class invisible to Levenshtein; full suite GREEN.

**Requirements:** V19E-01..03

**Plans:** all complete (completed 2026-06-08)

---

### Phase 35: UI Reorganization

**Goal:** Decompose macOS popover into a fixed-height tabbed shell (Home/Dictionary/History) + 4-pane Settings window; promote iOS to 3-tab layout; dictionary sort user entries on top; Stage Manager fix; popover Quit button.

**Requirements:** UIORG-01..04

**Plans:** all complete (completed 2026-06-09, UAT approved)

---

## Backlog

### Phase 999.1: Post-ASR / AI-Cleanup Robustness Pass (BACKLOG)

**Goal:** [Captured for future planning]
**Requirements:** TBD
**Plans:** 0 plans
**Source:** 4-day DebugRecorder log sweep (cleanup-2026-06-07 → 06-10, ~160 dictations). All findings are in the Shared/ cleanup pipeline → fix ships macOS + iOS together (cross-platform parity). Related: Phase 29 (acronym collapse), Phase 32 (spoken punctuation), Phase 34 (V19E content-word gate). Memory: `project_acronym_spacing_finding`, `project_ai_cleanup_self_correction_gap`.

Findings to address (priority-ordered):

1. **(HIGH — correctness/meaning-loss) LLM silently deletes content words; the V19E `gateContentWords` backstop passes the result, sometimes inverting meaning.**
   - 2026-06-09 04:30 — "Just create a document, **no** need for you to access my Google Workspace." → "Just **need** for you to access my Google Workspace." (negation/meaning INVERTED — "create a document, no" dropped)
   - 2026-06-10 20:04 — "do it in **a live project, actually,** and not a stale one" → "do it in and not a stale one"
   - 2026-06-08 09:27 — "**plain** dictation" → "dictation"
   - 2026-06-10 04:48 — "an actual **hyphen** between" → "an actual between"
   - Root area: whole-text Levenshtein gate is too coarse for short local clause/word drops; `gateContentWords` not catching deletion-without-restatement. Same family as `project_ai_cleanup_self_correction_gap`.

2. **(MED) Spelled-out single letters only collapse when SPACE-delimited.** User spells continuously; ASR inserts the delimiter, which may be space, comma, or hyphen. 2026-06-10: "M I M E"→"MIME" (good) but "M, I, M, E" (commas) and "H-I-N"/"M-I-M-E" (hyphens) NOT collapsed → "H-I-N1 M-I-M-E-Body". Fix: post-ASR acronym-collapse must normalize single-letter runs regardless of delimiter. Extends `project_acronym_spacing_finding` (space-delimited "N R S N A"→"NRSNA").

3. **(MED) German indefinite article "einen" falsely promoted to numeral "1"** by the v19e identifier-adjacent number-promotion EXCEPTION. 2026-06-10: ASR "...mit H-I-N einen M-I-M-E-Body" → LLM "...mit H-I-N1 M-I-M-E-Body". The promotion rule must not treat German articles (eins/einen/eine) as promotable numbers when functioning as articles.

4. **(MED) Spoken "hyphen" → "-" is produced by the deterministic pre-LLM layer (post_itn: "actual-between") but the LLM pass DROPS it**, so the dash never reaches output. Also a literal-vs-command ambiguity (talking ABOUT the word "hyphen" shouldn't convert). Tension between Phase 32 deterministic spoken-punctuation and the LLM re-processing pass.

_Observation (note only — gate currently catches it): LLM substitutes unfamiliar terms toward its own vocabulary — 2026-06-09 19:59 "schema change" → "Gemma change" (gate REJECTED → fell back to "schema", contained). Watch, not urgent._

Plans:

- [ ] TBD (promote with /gsd-review-backlog when ready)

---

*Last updated: 2026-06-10 — backlog 999.1 added (post-ASR / AI-cleanup robustness, 4 findings from log sweep).*
