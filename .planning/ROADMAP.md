# Roadmap: Dicticus

## Milestones

- ✅ **v1.0 MVP** — Phases 1-5 (shipped 2026-04-18) — [Archive](milestones/v1.0-ROADMAP.md)
- ✅ **v1.1 Cleanup Intelligence & Distribution** — Phases 6-11 (shipped 2026-04-20)
- ✅ **v2.0 iOS App — Shortcut Dictation** — Phases 12-16 (shipped 2026-04-22)
- ✅ **v2.1 Keyboard Extension & Polish** — Phases 17+ (shipped 2026-04-23)
- ✅ **v2.2 Adaptive Cleanup & Stability** — Phases 21-26 (shipped 2026-05-22)
- ✅ **v2.3 Live-Capture Quality Pass** — Phases 27-30 (shipped 2026-06-06, macOS 1.3.0) — [Archive](milestones/v2.3-ROADMAP.md)
- 🔄 **v2.4 Public-Release Readiness + Dictionary as Platform** — Phases 31-35 (in progress)

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

## Upcoming Phases (v2.3 archive — see ROADMAP.md pre-v2.4 for full detail)

| Phase | Milestone | Scope | Status | Result |
|-------|-----------|-------|--------|--------|
| 27. Dictionary Hallucination Guard | v2.3 | Fuzzy-pass guard, recorder enrichment, K7 brand adds | ✅ Done | 2026-05-27 |
| 28. V19D Prompt Iteration | v2.3 | Clause preservation, contraction, dedup, number policy | ✅ Done | 2026-05-27 |
| 29. ASR Post-Processing | v2.3 | Acronym collapse, spoken-letter lexicon, Zed fix | ✅ Done | 2026-05-29 |
| 30. PTT Media Auto-Pause (macOS) | v2.3 | ScriptingBridge pause/resume + mute fallback | ✅ Done | 2026-06-06 |

---

## Milestone v2.4 — Public-Release Readiness + Dictionary as Platform

**Started:** 2026-06-06
**Goal:** Make Dicticus shippable beyond personal use. Replace the developer-personal default dictionary with a curated public lexicon, add CSV import/export so the minimal default is acceptable, ship spoken punctuation (baseline expectation parity with native dictation), fix the iOS first-run experience, fix the K3/K4 over-promotion quality bug, and (if the IA is agreed) reorganize the macOS/iOS UI.
**Total requirements:** 26 (DICT-SPLIT-01..04, DICT-IO-01..04, PUNCT-01..04, TECHLEX-01..02, IOS-ONB-01..05, UIORG-01..04, V19E-01..03)

### v2.4 Phases

- [x] **Phase 31: Dictionary as Platform** - Split public vs. personal lexicon (public-release BLOCKER), ship CSV/JSON import/export, document the CSV-author workflow as the canonical tech-term recovery path (completed 2026-06-06; plans 3/3 + code-review fixes + UAT-driven polish; Release-binary leak check PASSED, UAT all green — see 31-HUMAN-UAT.md; branch feature/phase-31-dictionary-platform pushed)
- [x] **Phase 32: Spoken Punctuation** - Deterministic pre-LLM punctuation collapse in Shared/, shipping macOS + iOS together (completed 2026-06-07)
- [x] **Phase 33: iOS First-Run & Onboarding Polish** - Fix relaunch flash glitch, download screen truncation, duplicate Action Button entry; add guided onboarding wizard (completed 2026-06-07)
- [ ] **Phase 34: V19E — R8 Over-Promotion Fix** - Tighten R8 EXCEPTION prompt, add content-word-preservation gate; independent quality track
- [ ] **Phase 35: UI Reorganization (discuss-first)** - Declutter macOS popover, promote dictionary editing, consolidate hotkeys, iOS parity audit — IA to be resolved at discuss-phase time; may defer to v2.5

### v2.4 Progress

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 31. Dictionary as Platform | 3/3 | Complete    | 2026-06-06 |
| 32. Spoken Punctuation | 2/2 | Complete    | 2026-06-07 |
| 33. iOS First-Run & Onboarding Polish | 2/2 | Complete    | 2026-06-08 |
| 34. V19E — R8 Over-Promotion Fix | 2/4 | In Progress|  |
| 35. UI Reorganization (discuss-first) | 0/? | Not started | - |

---

## Phase Details

### Phase 31: Dictionary as Platform
**Goal**: Users own their dictionary — the public-release build ships a curated minimal default, developer-personal entries are gated, and any user can grow their lexicon by CSV-importing an AI-generated domain list
**Depends on**: Phase 30 (complete)
**Requirements**: DICT-SPLIT-01, DICT-SPLIT-02, DICT-SPLIT-03, DICT-SPLIT-04, DICT-IO-01, DICT-IO-02, DICT-IO-03, DICT-IO-04, TECHLEX-01, TECHLEX-02
**Success Criteria** (what must be TRUE):
  1. A release build of Dicticus ships a **truly empty** default dictionary — zero personal entries, zero baked-in universal entries; no personal keys appear as strings in the release binary (verified against a Release-config build, including a locally-built DMG)
  2. A dev build (local-only `PERSONAL_LEXICON` flag) loads all ~120 current entries with behavior identical to today — clean-rate baseline preserved, no regression against the V19D 139-record corpus
  3. User can export their full dictionary to CSV or JSON in one action (macOS: NSSavePanel; iOS: document picker)
  4. User can import a CSV or JSON dictionary with a choice of merge strategy; malformed rows are rejected with line-number errors, not silently discarded
  5. User can one-tap import bundled offline starter packs (tech mishearings + brand casing + general/mainstream terms) from Settings; imported entries are tagged `source=.imported` and use "existing wins" merge
  6. Settings and/or onboarding copy explains that the dictionary starts empty by design and walks the user through both the starter packs and the "ask an AI to generate a CSV for your domain" workflow
  7. Entries carry a `source` provenance field (`.default`/`.user`/`.imported`); dev builds reseed cleanly, release builds tag unknown persisted entries as `.user` and never delete them
**Plans**: 3 plans (3 waves)
- [x] 31-01-PLAN.md — Gating + provenance + migration: PERSONAL_LEXICON flag, empty public default, source field, leak-free migration
- [x] 31-02-PLAN.md — Import/export engine + UI: RFC 4180 CSV/JSON, 3 merge strategies, line-numbered validation, native file pickers
- [x] 31-03-PLAN.md — Starter packs + docs: 3 bundled offline packs, one-tap import, empty-by-design + CSV-author help copy

### Phase 32: Spoken Punctuation
**Goal**: Users can speak punctuation symbols reliably in both plain and cleanup modes — unambiguous tokens always collapse, conditional tokens (minus, dot, colon) collapse only between identifier-shaped flanks, matching the baseline expectation set by native macOS dictation
**Depends on**: Phase 31 (preferred; ensures Shared/ is stable after the dictionary refactor)
**Requirements**: PUNCT-01, PUNCT-02, PUNCT-03, PUNCT-04
**Success Criteria** (what must be TRUE):
  1. Speaking "Claude minus ops" produces `Claude-ops`; speaking "five minus three" leaves "five minus three" unchanged — the conditional-collapse heuristic fires only between identifier-shaped tokens
  2. Unambiguous tokens (hyphen, slash, backslash, underscore, asterisk, semicolon, at sign, hash, dollar, caret, tilde, pipe) always collapse to their symbol in both plain and cleanup modes
  3. The supported spoken-punctuation lexicon is listed in onboarding or help copy so users can discover it without trial and error
  4. No prose or arithmetic false positives appear in a replay of the V19D 139-record corpus (the conditional gate preserves "the 60 plus rules", "colon vs. dash", meta-discussion usages)
**Plans**: 2 plans
- [x] 32-01-PLAN.md — collapseSpokenPunctuation step in Shared/ + pipeline wiring + unit tests (PUNCT-01/02/04)
- [x] 32-02-PLAN.md — D-07 reference table UI on macOS + iOS (PUNCT-03)
**UI hint**: yes

### Phase 33: iOS First-Run & Onboarding Polish
**Goal**: A first-time iOS user completes setup without confusion — the download screen is clear and untruncated at any device size, no phantom flash appears when the model is already present, duplicate UI is cleaned up, and a guided wizard orients users to the app after setup
**Depends on**: Phase 30 (complete) — independent of Phases 31, 32, 34, 35
**Requirements**: IOS-ONB-01, IOS-ONB-02, IOS-ONB-03, IOS-ONB-04, IOS-ONB-05
**Success Criteria** (what must be TRUE):
  1. On a device with the model already downloaded, cold-launching the app shows the home screen directly — no download screen flash, even briefly
  2. On first install (model not present), the download screen copy reads clearly with no truncated labels at SE/mini/standard/Pro/Max device widths
  3. After completing mic permission + model download, a guided onboarding wizard appears automatically and can be re-triggered from Settings at any time
  4. Settings → Integration shows exactly one Action Button entry — the duplicate item is gone
**Plans**: 2 plans
  - [x] 33-01-PLAN.md — First-run bug fixes: relaunch flash (IOS-ONB-01), download-screen truncation (IOS-ONB-02), duplicate Action Button removal (IOS-ONB-05)
  - [x] 33-02-PLAN.md — Onboarding wizard: 3-page paged tour + auto-present sequencing (IOS-ONB-03) + Settings re-entry (IOS-ONB-04)
**UI hint**: yes

### Phase 34: V19E — R8 Over-Promotion Fix
**Goal**: AI cleanup no longer promotes real English words adjacent to number-words into identifier stems — "kink three" stays "kink three", "King Four" stays "King four", ordinary prose pairings are untouched — while the V19D 90.2% clean-rate baseline is preserved
**Depends on**: Phase 30 (complete) — independent quality track, can run in any order relative to Phases 31-33
**Requirements**: V19E-01, V19E-02, V19E-03
**Success Criteria** (what must be TRUE):
  1. "kink three", "King Four", "option one is", and "every two weeks" pass through cleanup unchanged (or with correct lowercase normalization) — the `kink→K3`, `King→K4` collapse class no longer occurs
  2. A deterministic content-word-preservation gate rejects LLM output that drops a content word (≥4 chars, non-stop-word) present in the post-ITN input, falling back to post-ITN text
  3. The V19D 139-record corpus clean rate does not drop below 90.2% and the 9.3% dictionary-hit baseline is preserved after shipping
**Plans**: 4 plans (3 waves)
- [x] 34-01-PLAN.md — Wave 0 test infrastructure: negative-case fixture, locate/assemble 139-record corpus + pin scorer, RED content-word-gate tests (both platforms)
- [x] 34-02-PLAN.md — Track A: tighten R8 EXCEPTION (EN+DE) + negative few-shots + v19e version bump + CleanupPromptTests sync (V19E-01)
- [ ] 34-03-PLAN.md — Track B: content-word-preservation gate + stop-word/stem-allowlist + Step 3a wire-in + GREEN tests (V19E-02)
- [ ] 34-04-PLAN.md — Wave 3 regression gate: full-suite parity + SC1 negative matrix + SC3 corpus replay + CHANGELOG (V19E-01/03)

### Phase 35: UI Reorganization (discuss-first; candidate to defer to v2.5)
**Goal**: The macOS popover and iOS app are reorganized by frequency-of-use — dictionary editing is a top-level action, hotkey configuration is consolidated into a single section, and the overall surface feels like a focused tool rather than an accretion of features
**Depends on**: Phase 31 (dictionary import/export UI must already exist before reorganizing the dictionary panel)
**Requirements**: UIORG-01, UIORG-02, UIORG-03, UIORG-04
**Success Criteria** (what must be TRUE):
  1. Opening the macOS popover, a user can reach dictionary management (add, edit, import, export) without scrolling past unrelated controls
  2. All hotkey configuration (standard KeyboardShortcuts + modifier hotkeys + Fn-key note) is in one consolidated section — no duplicate or scattered config blocks
  3. iOS UI has been audited against the same IA principles and brought into parity, with the review findings documented before any changes are made
  4. No existing user-visible behavior regresses: hotkey bindings fire, dictionary contents are preserved, history is accessible, DESIGN.md tokens are respected
**Plans**: TBD

**Note on Phase 35:** The information architecture must be worked out at discuss-phase time, not pre-decided here. If the IA discussion surfaces blocking open questions (popover vs. floating window, tab-bar vs. nested-list on iOS, whether a fresh DESIGN.md pass is needed), Phase 35 may slip to v2.5 without blocking the v2.4 public release — the remaining four phases already satisfy the public-release goal.
**UI hint**: yes

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

*Last updated: 2026-06-06 — v2.4 roadmap created. 5 phases (31-35), 27 requirements, 100% coverage.*
