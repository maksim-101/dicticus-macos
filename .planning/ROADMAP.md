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
| 20.08. LLM Swiss-Ification Suppression | v2.1 | 5/5 | Shipped 2026-05-01 | Wave-A (Plans 01–03) shipped variant (e); Plan 04 pivoted to variant (g15) (see `20.08-VARIANT-G-RATIONALE.md`); Plan 05 gap closure (R-G15-01 currency-digit truncation) shipped via 3 UAT iterations: drop §3 priming-trap directive, add `naja` filler, add 6th tense exemplar, reorder so currency-preservation exemplar holds the recency-anchor slot. macOS Release UAT 2026-05-01 ACCEPTED with sentence-stitching note. See `20.08-05-UAT-RESULTS.md` |
| 21. Adaptive Cleanup & Stability | v2.2 | — | Shipped 2026-05-03 | Debounce fix, Surgical Completion, 6-token repair window — UAT ACCEPTED |
| 22. Resolver Regression Hotfix | v2.2 | 2/2 | Shipped 2026-05-08 | Plan 22-01: regex L75 comma-prefix + word-boundary fix; 7 JSONL fixtures locked in cross-platform; macOS resolver suite 25/25 green. Plan 22-02: pre-flight grep + 1 XCTAssertFalse test in macOS CleanupPromptTests confirming the 8a79e6b cosmetic LLM few-shot is absent (verification-by-test, no production source touched). macOS targeted test green (1/1 in 0.001s). |
| 23. Decimal Words & Digit Grouping | v2.2 | 0/? | Absorbed → Phase 26 | ITN doesn't fold spoken decimal markers (`Punkt`/`Komma`/`point`) and English ITN concatenates comma-separated digit words (`three, five` → `35`). Scope absorbed into Phase 26 (Pipeline Quality Hardening) |
| 24. AI Cleanup Quality v2 | v2.2 | 0/? | Blocked on capture window (until 2026-05-12) | Self-correction handling + speech disfluency removal + structured eval refresh. Triggered by Phase 22 UAT G-01 (Gemma 4 E2B passed `"persist now or will is not or will it not"` through verbatim instead of dropping the abandoned fragment). Capture window 2026-05-09 → 2026-05-12 via Dicticus-Debug-Recorder build at /Applications/Dicticus.app, then `/gsd-plan-phase 24` |
| 26. Pipeline Quality Hardening | v2.2 | 0/3 | Planned | P0 ITN number concatenation, P1 SelfCorrectionResolver German clause drops, P2 dictionary false positive, P3 numeric structural words. Absorbs Phase 23 scope. Source: V19C live UAT (153 records) |

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

**Requirements:** R1, R2, R3, R4, R5, R6, R7, R8, R9 (locally defined in `20.08-RESEARCH.md` §6 + `20.08-VALIDATION.md`).

**Approach:** Two-pronged structural fix —
1. **Dialect-suppression gate** (`CleanupService.gateLLMDialect`) inserted in `TextProcessingService.swift` BEFORE the existing Levenshtein gate. Demotes to `rulesCleanedText` if the LLM injects any token from `SwissDialectForms.tokens` that was not present in the raw ASR (speaker-said exception preserved).
2. **Empirical prompt restructure** via debug-only macOS spike harness (`CleanupSpikeView`) running 5 fixtures × 4 candidate prompt variants with pinned sampler seed (0xDEADBEEF). Winning variant ships in `CleanupPrompt.swift` HELVETISMS block, pivoting from "preserve speaker's register" (D-05 pivot) to "Standard High German output".

**Cross-platform parity rule:** dialect gate + SwissDialectForms data + integration tests ship on iOS AND macOS together (per memory: feedback_cleanup_cross_platform_parity). `CleanupPromptTests.swift` remains macOS-only by 20.06-01 precedent.

**Plans:** 5/5 plans complete; Wave-B variant pivot 2026-04-29 (variant e → variant g15); Plan 05 gap closure shipped 2026-05-01 across 3 UAT iterations (macOS Release ACCEPTED with sentence-stitching note)

Plans:
- [x] 20.08-01-PLAN.md — Wave 1: `Shared/Models/SwissDialectForms.swift` (curated 38-token list, homographs `de`/`sind`/`müesli` excluded, CC BY-SA 4.0 attribution) + iOS + macOS parity tests (R4, R5)
- [x] 20.08-02-PLAN.md — Wave 2: `CleanupService.gateLLMDialect` + `tokenizeForDialectGate` + integration call at `TextProcessingService.swift` ~line 97 (BEFORE existing `gateLLMOutput`) + R1/R2/R3 unit tests + R7 stacking-safe integration test on both platforms (depends on 20.08-01)
- [x] 20.08-03-PLAN.md — Wave 3 (CHECKPOINT): macOS Debug-only spike harness `CleanupSpikeView` — runs 5 fixtures × 4 prompt variants with seed 0xDEADBEEF; user picked variant (e), recorded in `20.08-SPIKE-RESULTS.md`. **SUPERSEDED:** post-checkpoint UAT exposed identity-preservation failures (lowercase nouns, `und Und`, `Würdigten` mishear scar) → Wave-B re-spike → variant (g15) ships instead. See `20.08-VARIANT-G-RATIONALE.md` §1.5 + §10.
- [x] 20.08-04-PLAN.md — Wave 4 (CHECKPOINT): Tasks A+B SHIPPED on `0c6e883` (variant g15 prompt restructure under two-layer German conditional + R6 tests, 14/14 green); Task C UAT 2026-05-01 FAILED with R-G15-01 currency-digit truncation reproduced cross-platform → triggered Plan 05 gap closure. Primary anti-Swiss-ification contract HELD on both platforms.
- [x] 20.08-05-PLAN.md — Wave 5 (gap closure): R-G15-01 closed via 3 UAT iterations on macOS Release. Final shipped state: drop §3 priming-trap directive, keep 5th currency exemplar, add 6th past-tense exemplar (one slot earlier than anchor), add `naja` to FillerWordRemover.germanFillers (5-token ship list), R6 order-lock test guards recency-bias arrangement. macOS UAT 2026-05-01 ACCEPTED with sentence-stitching note. See `20.08-05-UAT-RESULTS.md`.

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

### Phase 22: Resolver Regression Hotfix
**Goal:** Stop `SelfCorrectionResolver` from eating user content as substring matches inside unrelated words (e.g. `now`, `noticed`, `wait`, German `nehmen`/`warten`). Confirmed root cause of the long-running "T"/"W" degenerate-collapse production bug.

**Trigger:** DebugRecorder live capture 2026-05-08 produced 30 JSONL records under the `Dicticus-Debug-Recorder` scheme. Records 5, 6, 9, 11, 18, 19, 29 show `post_rules` text drift caused by the regex at `Shared/Utilities/SelfCorrectionResolver.swift:75`. Pattern flaws: optional punctuation prefix (`[,;:.?!]?`) fires on naked whitespace, and missing trailing `\b` matches connectors as word substrings.

**Companion:** Revert commit `8a79e6b`'s cosmetic LLM few-shot ("W → 'this is good'") in `Shared/Models/CleanupPrompt.swift` once the regex is fixed — the few-shot was treating a downstream symptom of this bug.

**Cross-platform:** Both files live in `Shared/`; ships on macOS + iOS together (per memory `feedback_cleanup_cross_platform_parity`).

**Evidence:** `~/Library/Application Support/Dicticus/DebugRecordings/cleanup-2026-05-08.jsonl` + `.planning/phases/22-resolver-regression-hotfix/22-CONTEXT.md`

**Plans:** 2 plans (1/2 complete)
- [x] 22-01-PLAN.md — Regex one-liner fix at SelfCorrectionResolver.swift:75 + 7 JSONL regression-net fixtures on macOS and iOS test targets (cross-platform parity) — **completed 2026-05-08** (commits ba2b01b, 7fce68b, d4af189; macOS suite 25/25 green; iOS file byte-identical via `diff -q`; iOS xcodebuild gate deferred — iOS 26.4 SDK runtime not installed locally)
- [ ] 22-02-PLAN.md — Verify 8a79e6b cosmetic LLM few-shot is absent from CleanupPrompt.swift; lock in via XCTAssertFalse regression-net test

---

### Phase 23: Decimal Words & Digit Grouping
**Goal:** ITN should fold spoken decimal markers (`Punkt`, `Komma`, `point`) when they sit between digit groups, and English ITN should respect comma boundaries instead of fusing `three, five` → `35`. Discovered alongside Phase 22 in records 24-28 of the 2026-05-08 capture; deferred so the resolver fix ships first without scope creep.

**Plans:** TBD — opens after Phase 22 is in production.

---

### Phase 24: AI Cleanup Quality v2
**Goal:** Improve AI Cleanup (Gemma 4 E2B) quality across three axes that current prompt under-serves: (1) self-correction handling — drop abandoned/restated phrases mid-sentence; (2) speech disfluency removal — fillers, false starts, stuttered word-restarts; (3) structured eval refresh — labelled JSONL corpus + baseline + variant-comparison tooling so future prompt changes are measured, not assumed.

**Trigger:** Phase 22 UAT 2026-05-09 finding G-01. Input `"And what you did will persist now or will is not or will it not?"` was passed through verbatim by AI Cleanup; expected `"...persist now or will it not?"`. Documented in `.planning/phases/22-resolver-regression-hotfix/22-HUMAN-UAT.md` Gaps section and auto-memory `project_ai_cleanup_self_correction_gap`.

**Status:** Blocked on capture window (2026-05-09 → 2026-05-12). Dicticus-Debug-Recorder build installed at `/Applications/Dicticus.app` 2026-05-09 (Developer ID re-signed, TeamIdentifier `VTWHBCCP36`). After window closes, run `/gsd-plan-phase 24` against the captured JSONL corpus.

**Plans:** TBD — opens after capture window + corpus catalog.

**Cross-platform:** Per `feedback_cleanup_cross_platform_parity`, all plans ship on macOS AND iOS together.

**Context file:** `.planning/phases/24-ai-cleanup-quality-v2/24-CONTEXT.md`

### Phase 25: AI Cleanup Quality v3 — Brand & Acronym Recognition

**Goal:** Reduce isolated-brand mishearing failure rate (target: ≤ 30% of V15 baseline on the captured brand corpus), eliminate the `forty one → 4001` digit-concatenation class entirely, collapse acronym-letter-spacing without regressing list-of-letters enumeration, fix the `phase ↔ face` homophone class, enable plain-mode JSONL for production A/B comparison.
**Requirements**: N/A (quality phase — measured against capture-window scoreboard, not requirement IDs)
**Depends on:** Phase 24
**Plans:** 2/4 plans executed

Plans:
- [x] 25-01-hypothesis-matrix-PLAN.md — Offline hypothesis matrix in `.planning/debug/harness/` (Wave 1, no app code). Tests H1–H7 against prod GGUF at seed=42, produces `results/v16_matrix.md` naming the winning V16 variant.
- [x] 25-02-plain-mode-logging-PLAN.md — Plain-mode DebugRecorder logging in `Shared/Services/TextProcessingService.swift` (Wave 1, ships in parallel with 25-01). macOS + iOS parity. Enables plain-vs-AI A/B from production capture.
- [ ] 25-03-v16-prompt-and-dictionary-feeder-PLAN.md — V16 prompt + always-on canonical-term injector (Wave 2, depends on 25-01). macOS + iOS parity. Phase 24 regression-net (27 SelfCorrectionResolverTests + 10 CleanupPromptTests) preserved; new Phase 25 fixtures cite real CONTEXT.md timestamps.
- [ ] 25-04-capture-window-and-uat-PLAN.md — 3-day V16 capture + V15→V16 diff + human UAT verdict (Wave 3, depends on 25-02 AND 25-03). Closes Phase 25 with ACCEPTED / CONDITIONAL ACCEPT / REJECTED.

**Wave structure:** {25-01, 25-02} → {25-03} → {25-04}. Plans 25-01 and 25-02 are file-disjoint (harness vs. Swift); 25-03 consumes 25-01's matrix; 25-04 consumes both 25-02 (logging) and 25-03 (V16 code).

**Cross-platform:** Per `feedback_cleanup_cross_platform_parity` memory, 25-02 and 25-03 each ship macOS + iOS in the same plan. 25-01 is harness-only.

**Context file:** `.planning/phases/25-ai-cleanup-quality-v3-brand-acronym-recognition/25-CONTEXT.md`

---

*Last updated: 2026-05-16 — Phase 25 planned. Four-plan structure locked per CONTEXT.md user mandate (hypothesis-first methodology).*

*Last updated: 2026-05-09 — Phase 22 production UAT 2/3 PASSED + 1 deferred (iOS sim runtime). Phase 24 (AI Cleanup Quality v2) scaffolded as blocked on data capture (window 2026-05-09 → 2026-05-12).*

### Phase 25.1: AI Cleanup Quality v3b — paper-driven remediation (telemetry parity, XML output tags, dictionary expansion, language-isolated prompts, disfluency taxonomy) (INSERTED)

**Goal:** Apply the "Enhancing Local Dictation AI Cleanup" research paper's recommendations to close the 5 defect classes (A–E) and 2 telemetry gaps surfaced by Phase 25's live-capture window. Foundation-first dependency order: telemetry parity → XML envelope → dictionary expansion → English disfluency few-shots → German language-isolated prompt → NLD/Jaccard safety-net gates. Plans 04 + 05 use mandatory pre-build hypothesis matrices (`.planning/debug/harness/`) before shipping; Plans 01/02/03/06 are deterministic regression-net work.
**Requirements**: telemetry parity (paper §1.1), XML output tags (paper §6.2), dictionary expansion (paper §2.2), disfluency taxonomy (paper §3), language-isolated prompts (paper §5), NLD/Jaccard gates (paper §7)
**Depends on:** Phase 25
**Plans:** 4/6 plans executed

Plans:
- [x] 25.1-01-PLAN.md — Telemetry parity: add `lang_used` + `emission_counter` to DebugCleanupRecord; close 25-04 telemetry gaps (paper §1.1) **SHIPPED**
- [x] 25.1-02-PLAN.md — XML output tags: V16-COMPOSITE prompt instructs `<corrected_text>` envelope; CleanupService.stripPreamble extracts + falls back; Class D `<unk>` strip (paper §6.2) **SHIPPED**
- [x] 25.1-03-PLAN.md — Dictionary expansion: 11 Class B entries + applyFuzzyPass (Levenshtein ≤ 2 for keys ≥ 6 chars); 255/255 macOS tests green (paper §2.2, Parakeet implication §4) **SHIPPED**
- [x] 25.1-04-PLAN.md — Disfluency few-shots: V18C winner via 2-iteration matrix (V18C drops Rule 1 per Parakeet §1 hypothesis + adds Class C targeted few-shot). 80/80 tests pass including resolver gate 27/27 (paper §3 Reparandum/Interregnum/Repair) **SHIPPED**
- [x] 25.1-05-PLAN.md — Language-isolated prompts: V19C winner (native German rewrite + V2/compound few-shots). UAT pass: 90.2% clean rate, 39.3% improvement rate, 0% damage rate across 153 records. **SHIPPED 2026-05-22**
- [ ] 25.1-06-PLAN.md — NLD/Jaccard deterministic gates: DEPRIORITIZED — gate at 0.45 threshold never triggered in 153 records; V19C has 0% damage rate. Gate is working well as-is. Remaining quality issues are in pre-LLM pipeline (→ Phase 26).

---

### Phase 26: Pipeline Quality Hardening

**Goal:** Fix the 4 user-visible quality issues found in the V19C live UAT (153 records, May 19-22): P0 ITN number concatenation ("twenty five" → "2005"), P1 SelfCorrectionResolver drops German "doch"/"oder" clauses (3 content-drop records), P2 dictionary "versus"→"Vercel" false positive, P3 "point"/"dash"/"zero" not converted to symbols in numeric contexts. Absorbs Phase 23 (Decimal Words & Digit Grouping) scope.
**Requirements**: None (bug fixes driven by live UAT evidence)
**Depends on:** Phase 25.1
**Source:** `v19c-corrected-analysis-may19-22.md`

**Plans:** 3 plans

Plans:
- [ ] 26-01-PLAN.md — P0 ITN number concatenation fix + P3 numeric structural words (point/dash/zero/Punkt/Komma)
- [ ] 26-02-PLAN.md — P1 SelfCorrectionResolver doch/oder false-positive removal
- [ ] 26-03-PLAN.md — P2 Dictionary versus->Vercel false-positive retirement

**Wave structure:** {26-01, 26-02, 26-03} — all Wave 1, file-disjoint (ITNUtility vs SelfCorrectionResolver vs DictionaryService).

**Cross-platform:** All 3 plans modify Shared/ code + macOS tests + iOS tests (byte-identical copy). Per feedback_cleanup_cross_platform_parity.
