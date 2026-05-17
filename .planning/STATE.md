---
gsd_state_version: 1.0
milestone: v2.2
milestone_name: Adaptive Cleanup & Stability Post-v2.1
status: in_progress
last_updated: "2026-05-17T15:49:53.705Z"
progress:
  total_phases: 14
  completed_phases: 10
  total_plans: 41
  completed_plans: 42
  percent: 71
---

# Project State: Dicticus

**Last Updated:** 2026-05-16 (live-capture pause)
**Milestone:** v2.2 Adaptive Cleanup & Stability — Phase 24 SHIPPED 2026-05-12 (Micro-Scalpel V15 + Idiom Guard)
**Next milestone:** v2.3 (TBD — likely iCloud Sync + TestFlight)

## Current Position

Phase: 25 (ai-cleanup-quality-v3-brand-acronym-recognition) — PAUSED in LIVE-CAPTURE
Plan: 3 of 4 shipped to live-test (25-01 matrix, 25-02 logging, 25-03 V16-COMPOSITE + dict). 25-04 capture window is what's running now.

**Wave 1 outcome (2026-05-16):**

- 25-01 SHIPPED: V16 matrix run (259 inferences, seed=42, 53s wall-clock).
- 25-02 SHIPPED with discovery-driven pivot: plain-mode JSONL emission was already live (TextProcessingService.swift:224 OUTER-scope #if DEBUG_RECORDER block). Plan pivoted to "document + lock with parity tests".
- 25-01 H8/H9 follow-up (commit 4b93acc): rules-only matrix showed dictionary does ~90% of brand fixing. H9 (rules+expanded dict) aggregate 72, second-best of 9 variants, brand 35→2 and anchor 28→0 with zero LLM cost. Memory: `project_dictionary_dominates_brand_fixing`.

**Wave 2 pivot (2026-05-16):**

- Original plan: 5 tasks (dict expand → V16-COMPOSITE prompt → V17 harness verify → regression tests → formal UAT).
- User direction: skip harness-verify / tests / formal-UAT. Ship V16-COMPOSITE + dict expansion directly to the running Debug-Recorder app and validate via live capture. Quote: "implement the changes or new prompts directly into the app and we keep the debugging log running and I just test it live".
- Shipped commits: `0fc3198` (V16-COMPOSITE + Lever 1 dictionary, both files in Shared/), `b17ed32` (pre-existing install-local.sh syntax bug fix).
- Installed: `/Applications/Dicticus.app`, Debug-Recorder configuration, Developer ID signed (VTWHBCCP36). Verified V16-COMPOSITE prompt live in cleanup-2026-05-16.jsonl at 16:54:03Z.

**Live-capture pause (resume in a few days):**

- Branch: feature/debug-recording-and-cleanup, 13 commits ahead of origin (push deferred by user).
- Log location: `~/Library/Application Support/Dicticus/DebugRecordings/cleanup-2026-05-DD.jsonl` (one per day). Both plain-mode and AI-mode records interleave; AI-mode records carry full LLM prompt/raw/post-gate alongside the raw ASR.
- Resume = analyze accumulated logs, decide ship-vs-iterate, write 25-03 + 25-04 SUMMARYs.
- See `.continue-here` for the detailed resume checklist and `.planning/HANDOFF.json` for structured task state.

**Bonus this session (now memorized):**
Developer ID signing identity (VTWHBCCP36) was missing from login keychain (cert present, private key gone post-wipe). Recovered from 1Password TrueNAS vault item `sqn2j6zeygtpewb2v66expqxva` (Certificates.p12). New memory `feedback_developer_id_signing_recovery` documents the recovery so future sessions don't fall back to ad-hoc signing and break TCC permissions.
**Milestone v2.2:** Phase 22 SHIPPED 2026-05-08. Phase 24 (AI Cleanup Quality v2) SHIPPED 2026-05-12.
Remediation for Phase 22 UAT Gap G-01 (self-correction not dropped) implemented via **V15 "Micro-Scalpel"** 
prompt in `Shared/Models/CleanupPrompt.swift`. V15 moves to a "rules-first" instructions structure
that explicitly permits dropping stutters and abandoned fragments while preserving substantive 
repair-chains verbatim.

Phase 24 is officially synchronized across macOS and iOS. Both platforms are 100% green.
A persistent 'permissions not sticking' issue on macOS was identified and fixed through
Developer ID signing and build artifact cleanup; this workflow is now mandated in `GEMINI.md`
and automated in `install-local.sh`.

Rules layer hardened via **Abort 3c: Idiom Guard** in `SelfCorrectionResolver.swift`. The guard
prevents over-correction on idiomatic comma-terminated phrases identified in weekend logs 
(e.g., "by the way", "wie gesagt"). Unit test suite `SelfCorrectionResolverTests` reports 27/27 green.
`CleanupPromptTests` reports 10/10 green.

DebugRecorder state bleed bug fixed in `TextProcessingService.swift` (clearing `lastDebugTrace`
at start of cycle).

**Phase inventory:**

- ... (Phases 12-20.08 preserved in history)
- 21 — Adaptive Cleanup & Stability — SHIPPED 2026-05-03
- 22 — Resolver Regression Hotfix — SHIPPED 2026-05-08
- 23 — Decimal Words & Digit Grouping — BACKLOG (ITN regression class)
- 24 — AI Cleanup Quality v2 — SHIPPED 2026-05-12
- 25 — AI Cleanup Quality v3 — Brand & Acronym Recognition — ADDED 2026-05-16 (planning pending)

### Roadmap Evolution

- 2026-05-16: Phase 25 added — AI Cleanup Quality v3 (Brand & Acronym Recognition). Scoped from V15 capture-window analysis (see `project_v15_capture_findings` memory). Four-plan structure proposed: 25-01 offline hypothesis matrix in harness, 25-02 plain-mode logging, 25-03 V16 prompt + dictionary feeder, 25-04 capture window v2 + UAT.
- 2026-05-16 (session pause): Phase 25 Wave 2 deviated from the planned 5-task gating path. V16-COMPOSITE + Lever 1 dictionary shipped directly to /Applications via Debug-Recorder build per user direction. V17 harness verification (T3), regression tests (T4), and formal UAT (T5) skipped; live capture is now the validation path. 25-04 "capture window v2" is what's executing during the multi-day pause.
- Phase 25.1 inserted after Phase 25: Paper-driven remediation: telemetry parity (lang_used null fix + dual-emission verification), XML output tags, dictionary expansion (own brands), language-isolated prompts, Reparandum/Interregnum/Repair few-shots. Source: research paper + Phase 25-03 defect classes A-E. (URGENT)

## Next Action

After multi-day pause, resume via /gsd-resume-work. The current capture window is Phase 25 Wave 2 + 25-04 collapsed into one live test against /Applications/Dicticus.app (Debug-Recorder build, V16-COMPOSITE + expanded dictionary) to gather production-like JSONL logs.

1. Locate accumulated logs: `ls ~/Library/Application\ Support/Dicticus/DebugRecordings/cleanup-2026-05-*.jsonl`
2. Sanity-check V16-COMPOSITE still in the live prompt (one-liner in `.continue-here`).
3. Run analysis: per-category lev deltas vs V15 baselines + dictionary-vs-LLM attribution + regression check against `.planning/debug/harness/fixtures/phase25_brands.tsv`.
4. Conclude Phase 25: 25-03-SUMMARY.md + 25-04-SUMMARY.md, mark SHIPPED if clean (or open 25-03b if regressions).
5. Push the branch (13+ commits ahead, deferred this session).
6. Next: Phase 23 (Decimal Words & Digit Grouping) or plan Milestone v2.3.

Plans:

- [x] `24-PLAN.md` — SHIPPED 2026-05-12. V15 prompt + Idiom Guard + Recorder fix.
- [x] `25-01-PLAN.md` — SHIPPED 2026-05-16. V16 hypothesis matrix.
- [x] `25-02-PLAN.md` — SHIPPED 2026-05-16. Plain-mode logging documentation + parity tests.
- [~] `25-03-PLAN.md` — SHIPPED-TO-LIVE-TEST 2026-05-16. V16-COMPOSITE + dict expansion. Awaiting live-capture analysis to finalize.
- [~] `25-04-PLAN.md` — EXECUTING (de facto). Live-capture window covers the original 25-04 intent.
- [ ] `23-PLAN.md` — PENDING. Decimal Words & Digit Grouping.
