# Roadmap: Dicticus

## Milestones

- ✅ **v1.0 MVP** — Phases 1-5 (shipped 2026-04-18) — [Archive](milestones/v1.0-ROADMAP.md)
- ✅ **v1.1 Cleanup Intelligence & Distribution** — Phases 6-11 (shipped 2026-04-20)
- ✅ **v2.0 iOS App — Shortcut Dictation** — Phases 12-16 (shipped 2026-04-22)
- ✅ **v2.1 Keyboard Extension & Polish** — Phases 17+ (shipped 2026-04-23)
- ✅ **v2.2 Adaptive Cleanup & Stability** — Phases 21-26 (shipped 2026-05-22)
- ✅ **v2.3 Live-Capture Quality Pass** — Phases 27-30 (shipped 2026-06-06, macOS 1.3.0) — [Archive](milestones/v2.3-ROADMAP.md)
- ✅ **v2.4 Public-Release Readiness + Dictionary as Platform** — Phases 31-35 (shipped 2026-06-09) — [Archive](milestones/v2.4-ROADMAP.md)

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

## Upcoming: v2.5

| Phase | Milestone | Scope | Status |
|-------|-----------|-------|--------|
| 36. iOS Background Dictation Recording | v2.5 (candidate) | Spike-first: background mic recording + Live Activity stop control | Backlog |

Additional v2.5 candidates: public release (notarized `macos-v2.4.0` DMG + Sparkle; `ios-v2.4.0`), menu-bar right-click→Quit (NSStatusItem refactor), Stage Manager ongoing watch.

---

## Phase Details

### Phase 36: iOS Background Dictation Recording (v2.5 candidate — SPIKE-FIRST)
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
**Requirements**: TBD (define at spec/discuss time)
**Plans**: TBD

---

### Phase 19: AI Cleanup iOS
**Goal:** Enable on-device AI cleanup of ASR transcriptions on iOS via llama.cpp with Metal acceleration — improving number/currency/date formatting and enforcing Swiss German orthography (ß→ss) without any network calls.

**Requirements:** CLEAN-01, CLEAN-02

**Plans:** 6 plans (6 / 6 complete — code-complete pending physical-device UAT)
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

*Last updated: 2026-06-09 — v2.4 shipped (Phases 31-35). v2.5 next: Phase 36 (iOS Background Dictation, spike-first) + public release.*
