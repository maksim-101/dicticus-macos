---
gsd_state_version: 1.0
milestone: v2.3
milestone_name: Live-Capture Quality Pass
status: executing
stopped_at: "V19D UAT analyzed — 57 V19D-tagged DebugRecorder records (05-27→05-29), zero cleanup regressions (no degenerate_collapse / very_short / hallucination / large drops); Phase 27 fuzzy guard confirmed firing live (blocked checks→GSD @ 0.33). DECISIONS: (1) V19D PASSES → verify & close Phase 28 via /gsd-verify-work. (2) NFSK acronym-spacing reproduced (record 2026-05-28T03:31:04) but diagnosed as a post-ASR gap — ASR emits "N F S K" spaced, LLM passes through verbatim; NOT a V19D prompt regression → routed to NEW Phase 29 (deterministic acronym-collapse step, ITNUtility sibling; heuristic must handle mixed-case fragments like "Br N A C" and false-positives like "I am O K")."
last_updated: "2026-05-29T09:56:12.167Z"
last_activity: 2026-05-29 -- Phase 29 execution started
progress:
  total_phases: 4
  completed_phases: 3
  total_plans: 9
  completed_plans: 10
  percent: 75
---

# Project State: Dicticus

**Last Updated:** 2026-05-26 (v2.3 roadmap created)
**Milestone:** v2.3 Live-Capture Quality Pass — Roadmap created from `.planning/debug/log-analysis-2026-05-26.md`
**Previous milestone:** v2.2 Adaptive Cleanup & Stability — shipped 2026-05-22 (V19C UAT pass, 90.2% clean rate; Phase 26 ITN hardening)

## Current Position

Phase: 29 (asr-post-processing-acronym-collapse-spoken-letter-lexicon-z) — EXECUTING
Plan: 1 of 2
Status: Executing Phase 29
Last activity: 2026-05-29 -- Phase 29 execution started

### Next Action

Run `/gsd-plan-phase 27` to decompose Phase 27 into plans. Context resume file: `.planning/phases/27-dictionary-hallucination-guard-recorder-enrichment-k7-brand-/27-CONTEXT.md`

**Phase 27 scope:**

- DICT-SAFE-01, DICT-SAFE-02: fuzzy-pass valid-word guard in `Shared/Services/DictionaryService.swift`
- DICT-EXPAND-01: batch-add K7 brand misses (Aqara, Karpathy, Swissfolio, Gemini, cron job, Claude Code variants)
- OBS-DICT-01: enrich recorder JSONL schema with per-replacement `{key, from, to}` array

**Phase 28 (queued, depends on Phase 27):**

- LLM-CLAUSE-01, LLM-CONTR-01, LLM-DEDUP-01, LLM-NUM-01, LLM-PROMPT-AUDIT-01
- Primary file: `Shared/Models/CleanupPrompt.swift` (V19C → V19D)

### Roadmap Evolution

- 2026-05-29: Phases 29 & 30 added to v2.3 from V19D live-UAT findings. Phase 29 = deterministic post-ASR text fixes (acronym collapse, spoken-letter lexicon, `"the set."→"Zed."` dict entry from Spike 001), cross-platform Shared/. Phase 30 = macOS-only PTT media auto-pause (MacWhisper parity), spike-first because macOS 15.4+ entitlement-gated MediaRemote play-state reads; mute-output fallback agreed. K4 prose number-word promotion explicitly deferred to a separate future ITN/prose phase (not 29/30).
- 2026-05-26: Milestone v2.3 opened. Roadmap created from 118-record live-capture analysis (`.planning/debug/log-analysis-2026-05-26.md`). Two phases: Phase 27 (dictionary hallucination guard + recorder enrichment + K7 brand adds) and Phase 28 (V19D prompt iteration). Phase 28 depends on Phase 27 so recorder enrichment gives V19D UAT better per-replacement attribution.

## v2.3 Phase Progress

- [x] Phase 27 — Dictionary Hallucination Guard + Recorder Enrichment + K7 Brand Adds (DICT-SAFE-01, DICT-SAFE-02, DICT-EXPAND-01, OBS-DICT-01) — complete 2026-05-27
- [x] Phase 28 — V19D Prompt Iteration (LLM-CLAUSE-01, LLM-CONTR-01, LLM-DEDUP-01, LLM-NUM-01, LLM-PROMPT-AUDIT-01) — complete; UAT closed 2026-05-29 via debug-log evidence (2 pass, K4 prose = pre-declared follow-on)
- [ ] Phase 29 (proposed) — Acronym-collapse + spoken-letter lexicon + `the set.`→Zed dict entry (NFSK spacing, zed/zee spelling, Spike 001)

## Carried Items (from v2.2)

- Phase 23 (Decimal Words & Digit Grouping) — absorbed into Phase 26, no further action.
- Phase 25.1-06 (NLD/Jaccard deterministic gates) — DEPRIORITIZED (gate at 0.45 never triggered in 153 records; V19C has 0% damage rate).
- Branch `feature/debug-recording-and-cleanup` carrying v2.2 work — confirm sync state before Phase 27 work begins.

## Session Continuity

Last session: 2026-05-29 (V19D live-UAT debug-log review)
Stopped at: V19D UAT analyzed — 57 V19D-tagged DebugRecorder records (05-27→05-29), zero cleanup regressions (no degenerate_collapse / very_short / hallucination / large drops); Phase 27 fuzzy guard confirmed firing live (blocked checks→GSD @ 0.33). DECISIONS: (1) V19D PASSES → verify & close Phase 28 via /gsd-verify-work. (2) NFSK acronym-spacing reproduced (record 2026-05-28T03:31:04) but diagnosed as a post-ASR gap — ASR emits "N F S K" spaced, LLM passes through verbatim; NOT a V19D prompt regression → routed to NEW Phase 29 (deterministic acronym-collapse step, ITNUtility sibling; heuristic must handle mixed-case fragments like "Br N A C" and false-positives like "I am O K").
Previous: 2026-05-27 — Phase 28 context gathered / executed; Debug-Recorder build installed for multi-day live UAT.

### Next Action (2026-05-29)

1. `/gsd-verify-work 28` — formally close Phase 28 (V19D UAT passed per debug-log review).
2. ✅ DONE — Spike 001 (`.planning/spikes/001-zed-set-narrow-fix/`): Zed-IDE→"set" narrow fix VALIDATED ⚠. Ship `"the set." → "Zed."` as a single DictionaryService default entry (period-anchored; 100% prec/recall on corpus, immune to "the set of …" + compound "X set"; no code change). Fold into Phase 29 scope or a tiny dictionary-add.
3. `/gsd-phase add` Phase 29 (acronym-collapse) → `/gsd-plan-phase 29` → execute. Scope now includes THREE: (a) collapse spaced single/short uppercase fragment runs ("N F S K"→"NFSK", handling "Br N A C" + "I am O K" false-positives), (b) spoken-letter-name lexicon (zed/zee→Z, aitch→H, double-u→W) inside spelling runs, (c) DictionaryService default `"the set."→"Zed."` (from Spike 001). See `project_acronym_spacing_finding` memory for full heuristic + reproductions + spike result.

UAT findings from this session (3 total): NFSK acronym-spacing (→Phase 29a), Z-spelling zed/zee (→Phase 29b), Zed-IDE→set acoustic confusion (→spike). V19D cleanup itself: zero regressions across 57 records.

Key constraints carried forward:

- No German-parity gating per `project_usage_pattern_english_dominant` memory — English-only UAT acceptable for v2.3.
- Cross-platform parity per `feedback_cleanup_cross_platform_parity` — all Shared/ changes ship macOS + iOS together.
- `.planning/` is gitignored — no GSD commits target `.planning/*` files.
- Dictionary fuzzy-pass guard must preserve the `~9.3%` dictionary-hit baseline from the 2026-05-23→26 capture window (don't over-block existing exact-match brand fixes).
