# Phase 20: AI Cleanup Demotion + UAT Visibility — Context

**Gathered:** 2026-04-26
**Status:** Ready for planning
**Source:** In-conversation decisions following Phase 19.5 UAT findings + strategic research (Option C: Hybrid rules-first deterministic + optional LLM polish).

<domain>
## Phase Boundary

This phase changes the role of the LLM in the cleanup pipeline from authoritative rewriter to optional polish layer. It addresses three classes of UAT findings from Phase 19.5:

1. **Quality** — Gemma 4 E2B hallucinates ("ausgeflogen" → "ausgezogen"), produces literal artifacts ("110.90 Franken Rappen"), and ignores in-stream self-corrections ("Franken... ich meine Euro").
2. **Visibility** — iOS history rows are truncated; users cannot inspect raw vs. polished output to verify what the cleanup did.
3. **Robustness** — `HistoryService.swift:61` calls `fatalError` when the App Group container is unavailable, crashing the iOS simulator on misconfigured signing.

In scope: rules-first cleanup pipeline in Swift (Shared/), LLM gate (low temperature + verification + edit-not-rewrite prompt), raw/polished toggle UI, iOS history detail view, HistoryService graceful degradation.

Out of scope: Phase 19.6 (iOS UX polish — depends on DESIGN.md), Phase 18 (iCloud Sync — deferred), DESIGN.md generation, ASR-side improvements (acronym spacing, Parakeet model swaps), keyboard-extension changes.

</domain>

<decisions>
## Implementation Decisions

### Strategy — Option C (Hybrid)

- **LOCKED:** LLM is demoted from "authoritative rewriter" to "optional polish layer." The deterministic Swift pipeline is the primary path; LLM output is opt-in and Levenshtein-gated.
- **LOCKED:** Cross-platform parity — every change ships on macOS and iOS together (per `feedback_cleanup_cross_platform_parity` memory).
- **LOCKED:** Industry alignment — pattern matches Superwhisper's documented architecture (rules-first deterministic + LLM-optional).

### Action 1 — Rein in the LLM

- **LOCKED:** Lower Gemma 4 inference temperature from current default to **0.1** (or equivalent low-creativity setting available in LlamaSwift).
- **LOCKED:** Replace prompt verb "Rewrite" with **"Lightly edit"** in `CleanupPrompt.defaultInstruction`. Same for any per-language variants.
- **LOCKED:** Add **Levenshtein verification gate**: after the LLM returns, compare normalized-Levenshtein distance between LLM output and the rules-cleaned input. If distance exceeds a threshold (TBD during planning, target ~30%), discard the LLM output and use the rules-cleaned text instead. Threshold tuning is a planning concern.
- The user-customizable instruction (UserDefaults `cleanupInstruction`) keeps its existing override path; the *default* instruction text changes only.

### Action 2 — Move deterministic cleanup into Swift

- **LOCKED:** Filler-word removal moves from LLM responsibility to Swift (e.g. "äh", "ähm", "um", "uh", "halt", "also" — exact list to be enumerated during planning, gated by language).
- **PHASE-20 SCOPE NOTE (added 2026-04-26 after planning):** The Phase 20 ship list is narrowed to the disambiguation-safe core: `{äh, ähm, ehm, hmm}` (de) + `{uh, um, umm, er, erm}` (en). The originally-named tokens **`halt`** and **`also`** are **deliberately deferred** to a future phase — both have semantic meaning in German (`also` = "therefore"; `halt` = the "just / simply" particle), and stripping them blindly will damage non-filler usage. Plans 20-01 and 20-03 ship adversarial fixtures (`"also gut"`, `"halt mal"`) that assert preservation. A future phase will reintroduce them with sentence-position heuristics (comma-bounded, sentence-initial standalone) — re-evaluate after Phase 20 UAT.
- **LOCKED:** Currency-fold rule: `"X Franken Y Rappen"` collapses to `"CHF X.Y0"` (and analogous EUR/Cent fold). This complements — not replaces — the existing `SwissNumberFormatter` cross-token bridge for split cents (B3-original).
- **LOCKED:** Self-correction handling: when the speaker says "ich meine Y" (or English "I mean Y") immediately after token X, drop X and keep Y. Specific connector patterns to be enumerated during planning ("ich meine", "I mean", "genauer gesagt", "rather", "or rather"). Bounded by safe windows (max N preceding tokens).
- **LOCKED:** All of these live in `Shared/Services/` (cross-platform). `TextProcessingService` orchestrates: rules pass → optional LLM pass → SwissNumberFormatter post-pass.

### Action 3 — Visibility

- **LOCKED:** iOS history detail view exposes both raw and polished text for the same entry. The `text` and `rawText` columns are already populated by Phase 19 (D-38).
- **LOCKED:** Cross-platform raw/polished toggle: a per-entry control (and/or global default) lets the user choose which version is copied to the clipboard. Default is **Raw** until UAT confirms LLM trust.
- The toggle's exact UI shape (per-row chevron, segmented control, settings flag, etc.) is a planning concern — but the data plumbing is already in place via the GRDB schema.

### Action 4 — HistoryService graceful degradation

- **LOCKED:** Replace `fatalError("App Group container not found")` at `Shared/Services/HistoryService.swift:61` with a per-app fallback container path (e.g. `FileManager.default.urls(for: .applicationSupportDirectory, ...)`).
- **LOCKED:** Log the missing-App-Group condition once via `os.Logger` (warn-level), and surface a non-blocking warning state the iOS Settings UI can read for diagnostics.
- **LOCKED:** History writes in fallback mode are *not* shared with future keyboard extensions; that is acceptable degradation — the keyboard extension already gracefully no-ops when history is unavailable.

### Claude's Discretion

- Exact Levenshtein threshold value (start ~30%, tune during planning/execution).
- Exact filler-word lists per language.
- Exact connector pattern list for self-correction handling.
- File-decomposition (one new `Shared/Services/RulesCleanupService.swift` vs. extension methods on existing `TextProcessingService`).
- UI shape of raw/polished toggle (planning will propose, then verify against design conventions in code).
- Test split (unit fixtures for each rule, integration for pipeline order, snapshot for history detail view).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### UAT findings driving this phase
- `.planning/phases/19-ai-cleanup-ios/19-UAT-FINDINGS.md` — original UAT inventory split into 19.5/19.6/19.7
- `.planning/STATE.md` — Phase 19.5 closure notes + Phase 20 entry-point summary

### Pipeline files this phase will modify
- `Shared/Services/TextProcessingService.swift` — orchestrator; needs new pre-LLM rules pass + Levenshtein gate
- `Shared/Services/CleanupService.swift` — LLM call site; needs temperature lowering + verification gate hook
- `Shared/Models/CleanupPrompt.swift` — `defaultInstruction` text + verb change
- `Shared/Utilities/SwissNumberFormatter.swift` — currency-fold may live alongside split-cents bridge
- `Shared/Services/HistoryService.swift` — graceful-degradation fallback (line 61)

### History detail-view scaffolding (iOS)
- `iOS/Dicticus/Views/HistoryView*.swift` (and any row-detail views) — raw/polished display
- `Shared/Models/TranscriptionEntry.swift` (or equivalent GRDB record) — already exposes `text` + `rawText`

### Phase 19.5 hotfix commits (do not regress)
- 6268f11 — Gemma chat-template fragment strip in CleanupService
- e8c665e — Foundation Decimal guards + cross-token bridges in SwissNumberFormatter

### Cross-platform parity convention
- Memory: `feedback_cleanup_cross_platform_parity.md` — every cleanup pipeline change ships on macOS + iOS together

### External patterns
- Superwhisper docs: https://superwhisper.com/docs/get-started/introduction (rules-first deterministic + optional LLM polish)
- Vectara hallucination leaderboard, RLLM-CF (arXiv 2505.24347) — context for LLM verification-gate pattern

</canonical_refs>

<specifics>
## Specific Ideas

- The Levenshtein gate is a **fail-safe**, not a quality metric — its job is to reject hallucinated rewrites, not to score outputs. Threshold should be permissive enough to allow normal cleanup edits.
- "Lightly edit" prompt language is a standard mitigation for small-LLM over-rewriting; analogous to Superwhisper's "polish" framing.
- Currency-fold and self-correction rules are deterministic and culturally specific (Swiss German), so they belong in Swift where they can be tested with fixtures — never sent to the LLM as a hint.
- The raw/polished toggle is also a UAT instrument: it lets the user see exactly what the LLM did so this team can decide later (post Phase 20) whether to keep, replace, or retire the LLM stage.
- `HistoryService` graceful degradation is a robustness fix — not a behavior change for the production app where App Group is correctly provisioned. It only affects misconfigured signing (simulator + dev builds).

</specifics>

<deferred>
## Deferred Ideas

- Phase 19.6 — iOS UX polish (dynamic home screen, bigger mic icon, scrollable dictation pane, auto-stop, search-match highlight) — blocked on DESIGN.md, separate phase.
- Replacing Gemma with a larger/different LLM — out of scope; this phase reframes the LLM, not retrains the choice.
- ASR-side improvements (acronym spacing collapse, Parakeet swap) — different layer, separate roadmap items.
- Background download of GGUF model on iOS — accepted scope deferral from Phase 19 (D-35).
- iCloud Sync (Phase 18) — explicitly deferred at milestone level.

</deferred>

---

*Phase: 20-ai-cleanup-demotion-uat-visibility*
*Context gathered: 2026-04-26 from in-conversation Option C decisions*
