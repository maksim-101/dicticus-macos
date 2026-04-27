# Roadmap: Dicticus

## Milestones

- ✅ **v1.0 MVP** — Phases 1-5 (shipped 2026-04-18) — [Archive](milestones/v1.0-ROADMAP.md)
- ✅ **v1.1 Cleanup Intelligence & Distribution** — Phases 6-11 (shipped 2026-04-20)
- ✅ **v2.0 iOS App — Shortcut Dictation** — Phases 12-16 (shipped 2026-04-22)
- ✅ **v2.1 Keyboard Extension & Polish** — Phases 17+ (shipped 2026-04-23)

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

## Upcoming Phases

| Phase | Milestone | Scope | Status | Result |
|-------|-----------|-------|--------|--------|
| 17.5. Inline Shortcut Dictation | v2.1 | Darwin IPC keyboard dictation — mic button on Dicticus keyboard triggers recording in main app via Darwin notifications, transcription inserts at cursor via textDocumentProxy (PIVOTED from shortcut UI) | Done | Success |
| 18. iCloud Sync | v2.1 | CloudKit integration for Dictionary & History | Deferred | - |
| 19. AI Cleanup iOS | v2.1 | llama.cpp Metal for on-device AI cleanup | Code Complete | Pending physical-device UAT (findings → 19.5/19.6) |
| **DESIGN.md** | v2.1 | Cross-platform design tokens (brand, color, typography, spacing, motion) + per-platform sections (iOS/macOS/Windows) + asset inventory | Next | Prerequisite for 19.6 |
| 19.5. AI Cleanup CH-Determinism | v2.1 | 5/5 | Complete   | 2026-04-26 |
| 19.6. iOS UX Polish | v2.1 | Dynamic home screen (clipboard-aware), bigger mic icon, scrollable dictation pane, auto-stop toggle, history-row expand + search-match highlight, restart-trigger button after model download, toggle→download visual cue | Planned | Depends on DESIGN.md |
| 19.7. macOS Hygiene | v2.1 | Hotkey re-authorization flow, multi-install cleanup (build script + uninstaller), in-app permission status indicator, app icon consistency macOS↔iOS | Done 2026-04-25 | M1/M2/M3/D1 resolved — D1 confirmed by Finder UAT |
| 20. AI Cleanup Demotion + UAT Visibility | v2.1 | 5/5 | Shipped 2026-04-27 | UAT findings closed via Phase 20.06; AI-cleanup path GREEN on the test sentence |
| 20.06. AI Cleanup Behavioural Hotfix | v2.1 | 4/4 | Shipped 2026-04-27 | HELVETISMS dialect preserved + currency idempotency + iOS history gestures + Settings-toggle reactivity (UAT GREEN on AI-cleanup path) |
| 20.07. Rules-only ASR-Mishearing Recovery | v2.1 | 0/? | Planned | Rules-only Swiss path produces unrecoverable shapes when ASR drifts (e.g. `4, Franken50 Euro`) — needs an aggressive split-rule with false-positive guards |
| 20.08. LLM Swiss-Ification Suppression | v2.1 | 0/? | Planned | AI-cleanup ON + Swiss ON path: LLM still translates clean High German into Swiss dialect (`auf der anderen Seite` → `uf de andere Siite`, `wahrscheinlich` → `wahrschiinli`) despite 20.06's preservation-first prompt. Likely fix: drop the helvetisms reference list and/or add a helvetism-delta demotion gate |

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

**Requirements:** None directly — follow-on from Phase 19.5 UAT findings (Gemma hallucination "ausgeflogen"→"ausgezogen", currency literal "Franken Rappen", missed self-corrections, iOS history truncation, simulator crash at HistoryService.swift:61). Cross-platform parity: ships on macOS and iOS together (per cross-platform parity convention).

**Plans:** 5/5 plans executed
- [x] 20-01-PLAN.md — Wave 0 RED test scaffolding (Levenshtein, Filler, SelfCorrection, RulesCleanup fixtures, gate + fallback test stubs)
- [x] 20-02-PLAN.md — Action 1 (Rein in LLM): temp 0.1, "Lightly edit" prompt, LevenshteinDistance utility, gateLLMOutput helper
- [x] 20-03-PLAN.md — Action 2 (Rules-first deterministic): FillerWordRemover + SelfCorrectionResolver + currency-fold + RulesCleanupService + Step 2c/3a wiring in TextProcessingService
- [x] 20-04-PLAN.md — Action 4 (Resilience): HistoryService graceful App-Group fallback + appGroupAvailable flag + Settings warning rows (iOS + macOS)
- [x] 20-05-PLAN.md — Action 3 (Visibility): iOS HistoryDetailView + macOS inline disclosure + CleanupCopyMode UserDefault + Settings parity row

**Out of scope:** Phase 19.6 (iOS UX polish, depends on DESIGN.md), Phase 18 (iCloud Sync, deferred).

---

### Phase 20.06: AI Cleanup Behavioural Hotfix
**Goal:** Close the gap between Phase 20's *artifact-level success* (12/12 must-haves verified) and its *behavioural goal* ("demote the LLM"). UAT 2026-04-27 surfaced four real regressions that the Phase 20 test matrix did not cover. Fix them, re-run UAT, then declare Phase 20 done.

**Requirements:** None directly — corrective follow-on to Phase 20 + Phase 19.5 HELVETISMS.

**Findings to address** (full triage in `.planning/phases/20-ai-cleanup-demotion-uat-visibility/20-UAT-FINDINGS.md`):
- F-20-UAT-01 🔴 HELVETISMS prompt block reworded so LLM preserves speaker dialect (no HG→Swiss German translation). Add NEGATIVE list of common traps (auf→uf, ausgeflogen→usgfloge, gekostet→choschtet, ...).
- F-20-UAT-02 🔴 Currency-fold idempotency + speaker-explicit-currency-wins. Fix "110.57 €" → "110.57 Euro Euro" duplication and "4.50 Franken" → "4.50 Euro" wrong-direction flip. Audit `SwissNumberFormatter.foldCurrencyUnits` + `CurrencyAntiFlip`.
- F-20-UAT-03 🟡 iOS long-press on history row: replace SwiftUI Text auto-detection (showing path/link preview) with explicit `.contextMenu { Copy }`.
- F-20-UAT-04 🟡 iOS row chevron + verify NavigationLink fires (parity with macOS chevron from 20.05). HistoryDetailView shipped but tap not discoverable.
- F-20-UAT-05 🟢 Re-test number-drift "110.57"→"100.57" after F-20-UAT-01 (likely no separate fix needed).

**Cross-platform parity rule:** HELVETISMS prompt + currency formatter changes must ship on iOS AND macOS together (per memory: feedback_cleanup_cross_platform_parity).

**Plans:** 4 plans

Plans:
- [x] 20.06-01-PLAN.md — Wave 1: HELVETISMS prompt rework — preservation-first wording + NEGATIVE list of HG→CH-G traps + tests (F-20-UAT-01, F-20-UAT-05)
- [x] 20.06-02-PLAN.md — Wave 2: Currency idempotency + speaker-explicit anchor + STRICT prompt extension (F-20-UAT-02) — depends on 20.06-01 (shared CleanupPrompt.swift)
- [x] 20.06-03-PLAN.md — Wave 1: iOS HistoryRow .contextMenu Copy + trailing chevron (F-20-UAT-03, F-20-UAT-04)
- [x] 20.06-04-PLAN.md — Wave 3: Manual UAT re-run gate; flips Phase 20 + 20.06 to Shipped on GREEN (F-20-UAT-01..05) — depends on 20.06-01, 02, 03
- [x] 20.06-05-FIX (in-phase) — iOS warmup hang + fake progress UI + Settings AI-cleanup-toggle reactivity (real FluidAudio progressHandler + CleanupService nonisolated load + @AppStorage in AiCleanupSection)

**UAT outcome (2026-04-27):**
- Configuration B (iOS, AI cleanup ON, Swiss ON — the critical case): ✅ GREEN. Output `Das hat mich dann ca. 4.50 Franken gekostet.` — currency preserved, dialect preserved, no hang.
- Configuration A (iOS, AI cleanup OFF, Swiss ON): ⚠️ deferred to 20.07. ASR drift on this run produced `4, Franken50 Euro` — an unrecoverable shape for the rules-only path. Not a 20.06-introduced regression in `SwissNumberFormatter`; the formatter's bridge regex cannot rescue tokens with letters glued to digits without a more aggressive split-rule.
- Settings UX bug (AI Cleanup toggle → Download Required panel reveal lag): ✅ fixed in-phase via `@AppStorage` refactor.

---

### Phase 20.07: Rules-only ASR-Mishearing Recovery
**Goal:** Recover currency phrases on the rules-only path (Swiss ON, AI cleanup OFF) when ASR drifts to shapes like `4, Franken50 Euro` (comma after the digit, currency-word concatenated to the cents). Today's `SwissNumberFormatter.bridgeCrossTokenDecimal` requires whitespace-separated tokens and bails on any token containing letters; the rules-only path therefore emits the corrupted ASR verbatim.

**Requirements:** None directly — follow-on to Phase 20.06 UAT findings.

**Tentative scope:**
- Add a pre-tokenization regex to split `<currency-word><digits>` patterns (`Franken50` → `Franken 50`).
- Strip leading punctuation from the integer side of the currency phrase (`4,` → `4`) before bridging.
- False-positive guards: only fire when the trailing digit run is exactly 2 digits AND the currency-word matches the strict alternation already used by Bridge 2.
- Fixtures: a UAT replay table covering the 2 known mishearings (`4 Franken 50 Euro`, `4, Franken50 Euro`) plus a deliberately-not-currency adjacency case (e.g. `Frankreich50` should NOT split).

**Plans:** TBD — opens after a fresh round of rules-only UAT to widen the failure-mode catalog.

---

### Phase 20.08: LLM Swiss-Ification Suppression
**Goal:** Stop the LLM from rewriting clean High German into Swiss German dialect on the AI-cleanup ON + Swiss ON path. UAT 2026-04-27 (post-20.06 ship): user dictated standard High German and the LLM produced `uf de andere Siite, wahrschiinli, alli mini, wuer ich denn, het, hie usfiltere`. Phase 20.06's preservation-first prompt (`HELVETISMS: Preserve the speaker's dialect register exactly. Do NOT replace High German words with Swiss German equivalents.`) is being ignored by Gemma 4 E2B because the appended `SwissHelvetisms.words` reference list is interpreted as a preferred vocabulary.

**Requirements:** None directly — follow-on to Phase 20.06 UAT findings (post-ship).

**Tentative scope:**
- Drop the `SwissHelvetisms.words` reference list from the prompt entirely — keep only the negative instruction.
- Add a "helvetism-delta" demotion gate: if cleaned output contains ≥N helvetism tokens not present in the raw ASR, fall back to rules-only (mirrors 20.06's Levenshtein gate but content-aware).
- Few-shot examples in the prompt: input `auf der anderen Seite` → output `auf der anderen Seite` (NOT `uf de andere Siite`).
- Fixtures: UAT replay table covering 5+ Swiss-ification traps (`auf de`, `wahrschiinli`, `alli mini`, `het`, `wuer`).

**Plans:** TBD — opens via `/gsd-discuss-phase 20.08`.

---

### Phase 19.7: macOS Hygiene
**Goal:** Hotkey re-authorization flow, multi-install cleanup (build script + uninstaller), in-app permission status indicator, app icon consistency macOS↔iOS — Unblocks daily macOS dictation.

**Requirements:** M1, M2, M3, D1 (UAT row IDs from `19-UAT-FINDINGS.md`); D-01..D-18 (CONTEXT.md decisions)

**Plans:** 4 plans (all complete)
- [x] 19.7-01-PLAN.md — M2 dev install/uninstall scripts (D-01..D-03) + README "Manual uninstall"
- [x] 19.7-02-PLAN.md — M3 Input Monitoring permission row + per-row Repair label + hide-when-all-granted (D-08..D-12)
- [x] 19.7-03-PLAN.md — M1 Hotkey re-authorization flow: Repair banner + Re-register button + multi-copy warning (D-04..D-07)
- [x] 19.7-04-PLAN.md — D1 Icon canonicalization: assets/icon-master.png + scripts/generate-icons.sh + regenerated PNGs + README (D-13..D-17)

---

*Last updated: 2026-04-25 — Phase 19.7 (macOS Hygiene) complete: all 4 plans shipped, verifier passed 22/22 must-haves, D1 Finder UAT user-approved. Phase 18 iCloud Sync deferred. Code review surfaced 11 advisory findings (0 critical, 5 warnings, 6 info) in 19.7-REVIEW.md — suitable for follow-up cleanup.*
