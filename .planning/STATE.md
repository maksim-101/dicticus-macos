---
gsd_state_version: 1.0
milestone: v2.2
milestone_name: Adaptive Cleanup & Stability Post-v2.1
status: in_progress
last_updated: "2026-05-19T00:00:00.000Z"
progress:
  total_phases: 14
  completed_phases: 10
  total_plans: 41
  completed_plans: 43
  percent: 73
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

## Phase 25.1 Progress

- [x] `25.1-01-PLAN.md` — SHIPPED 2026-05-17. Telemetry parity (lang_used + emission_counter).
- [x] `25.1-02-PLAN.md` — SHIPPED 2026-05-17. XML output tags (extractEnvelopeOrFallback + unk strip).
- [x] `25.1-03-PLAN.md` — SHIPPED 2026-05-17. Dictionary expansion: 11 Class B entries + applyFuzzyPass (Levenshtein ≤ 2). Commits: 26c9540 (entries + tests), 894976a (fuzzy pass).
- [x] `25.1-04-PLAN.md` — SHIPPED 2026-05-18. V18C: Rule 1 drop + Class C targeted few-shot. SelfCorrectionResolverTests 27/27 PASS. Commits: 0b3308d (CleanupPrompt), cae00d4 (tests).
- [~] `25.1-05-PLAN.md` — T1-T3 SHIPPED 2026-05-19 (commits c8e090e, 62a46a6, c8e7cc8). V19C winner (native German rewrite + V2/compound few-shots). At Task 4 (human-verify checkpoint): user dictating against installed Debug-Recorder build to validate V19C live. SUMMARY.md not yet written — pending "V19 UAT pass" signal.
- [ ] `25.1-06-PLAN.md` — PENDING. NLD/Jaccard deterministic gates.

**Key decision (25.1-03):** Levenshtein ≤ 2 fuzzy second pass added to DictionaryService.apply(to:). Length-prefilter ≥ 6 prevents catastrophic false positives on short tokens. Per CONTEXT.md Parakeet §4: dictionary is the ONLY pre-LLM brand-recognition lever; fuzzy pass closes substring-matching failures deferred from 25-03 Lever 1.

**Key decision (25.1-04):** V18C selected (Rule-1-drop + Class C targeted few-shot). Parakeet TDT v3 emits punctuation natively (paper §1) — Rule 1 was redundant. V18D disqualified despite tying V18C at lev=61: idiom guard broke P25b-idiom-02 (empty output). V15 micro-scalpel contract maintained: SelfCorrectionResolverTests 27/27 PASS pre- and post-ship.

**Key decision (25.1-05):** V19C selected (native German rewrite + explicit V2-positioning + compound-noun few-shots, paper §5.2). Non-Swiss aggregate lev 444 vs V19A baseline 1469 (69% improvement). Gates 1/2/3 PASS (aggregate, V2 lev=0 on P25b-de-v2-01, compound lev=0 on P25b-de-compound-01). Gate 4 (Swiss helvetism lev=0) FAIL — model capability boundary for Gemma 4 E2B Q4_K_M; ß→ss substitution is DictionaryService's responsibility per `feedback_swiss_german_default`, banner remains a model preference signal. V15 micro-scalpel German contract maintained.

**Session hotfixes (2026-05-19, mid-UAT):**

1. **`fix(install-local)` — f443e35.** `scripts/install-local.sh` step 6 codesign re-sign was missing `--options runtime` and `--entitlements`, producing bundles whose Designated Requirement differed from `build-dmg.sh`'s output (no hardened runtime, no entitlements including `com.apple.security.device.audio-input`). macOS treated each install as a different app and re-prompted for Microphone/Accessibility/Input Monitoring on every cycle, *and* silently denied mic data to a process without the audio-input entitlement → transcription failed even when TCC said "Allow". Fix mirrors `build-dmg.sh` signing + adds post-sign verify gate + trash-collision guard for multi-DerivedData scenarios. **Confirmed in live UAT: subsequent install preserved TCC grants — no re-prompt.** Memory `feedback_developer_id_signing_recovery` covered the cert recovery angle; this fix covers the DR-stability angle.

2. **`fix(25.1-02)` — 4578081.** `extractEnvelopeOrFallback` in `Shared/Services/CleanupService.swift` required both `<corrected_text>` AND `</corrected_text>` in the model output. V18C/V19C pre-fill the opening tag in the prompt as a completion anchor (`CleanupPrompt.swift:202` — `Out: <corrected_text>`), so the model emits only content + closing tag. Regex didn't match → fallback returned verbatim → closing tag leaked to the user's cursor on every dictation cycle. Fix handles four envelope shapes explicitly (full / opening-only / closing-only / no-tags); closing-only is now the dominant V18C+/V19C path. Test `testPhase251_StripPreambleFallsBackWhenOpeningTagMissing` was a regression net that pinned a workaround in place; renamed and flipped to `testPhase251_StripPreambleStripsClosingTagWhenOpeningPrefilled`. Three new tests added on macOS + iOS for parity. **Verified live: post_gate now clean, no envelope residue.**

## Next Action

**Resume = collect V19 UAT verdict.** Plan 25.1-05 is at Task 4 (`<task type="checkpoint:human-verify" gate="blocking">`). T1-T3 shipped 2026-05-19; user is dictating against the running Debug-Recorder build (PID at session end: 46440) and accumulating records in `~/Library/Application Support/Dicticus/DebugRecordings/cleanup-2026-05-19.jsonl` (+ subsequent day files).

When resumed, user provides one of:

- **"V19 UAT pass"** → spawn continuation agent to write `25.1-05-language-isolated-prompts-SUMMARY.md` per plan §output (matrix winner, gate verdicts, Swiss disposition, V15 preservation, lang_used=='de' verification from live JSONL), update ROADMAP plan progress, then dispatch Wave 5 (Plan 25.1-06 NLD/Jaccard gates).
- **"V19 re-matrix needed: <reason>"** → revisit harness with reason.
- **"rollback V19: <reason>"** → `git revert c8e7cc8` (Task 3 commit; harness artifacts at c8e090e + 62a46a6 stay since they're gitignored anyway).

**Live verification anchors for the SUMMARY (already confirmed during session):**
- German dictation routes correctly: `lang=="de"`, `lang_used=="de"` (Plan 01 telemetry working in production).
- V19C German block live: `Regeln (auf Deutsch):` appears in `llm_prompt.text` of de records.
- Envelope extractor fix (4578081) verified: `post_gate.text` has no `</corrected_text>` residue.
- TCC grants persisted across the install-local.sh fix rebuild (f443e35) — proof of DR-stability.

**Carried items still open:**

- Phase 25 live-capture analysis (HANDOFF.json original scope) — 25-03/25-04 SUMMARYs still pending. Multi-day capture has been accumulating since 2026-05-16; queue right after Plan 25.1-05 closes, or earlier if regressions force a Phase 25 rollback decision.
- Branch `feature/debug-recording-and-cleanup` is 92 commits ahead of `origin/main`, 5 ahead of `origin/feature/debug-recording-and-cleanup`. Push deferred at session end pending user confirmation.
- Plan 25.1-06 (NLD/Jaccard deterministic gates) blocked on 25.1-05.
- Phase 23 (Decimal Words & Digit Grouping) — backlog, post-v2.2.

Plans:

- [x] `24-PLAN.md` — SHIPPED 2026-05-12. V15 prompt + Idiom Guard + Recorder fix.
- [x] `25-01-PLAN.md` — SHIPPED 2026-05-16. V16 hypothesis matrix.
- [x] `25-02-PLAN.md` — SHIPPED 2026-05-16. Plain-mode logging documentation + parity tests.
- [~] `25-03-PLAN.md` — SHIPPED-TO-LIVE-TEST 2026-05-16. V16-COMPOSITE + dict expansion. Awaiting live-capture analysis to finalize.
- [~] `25-04-PLAN.md` — EXECUTING (de facto). Live-capture window covers the original 25-04 intent.
- [x] `25.1-01-PLAN.md` — SHIPPED 2026-05-17. Telemetry parity (lang_used + emission_counter).
- [x] `25.1-02-PLAN.md` — SHIPPED 2026-05-17. XML output tags.
- [x] `25.1-03-PLAN.md` — SHIPPED 2026-05-17. Dictionary expansion + Levenshtein ≤ 2 fuzzy pass.
- [x] `25.1-04-PLAN.md` — SHIPPED 2026-05-18. V18C disfluency few-shots (Rule-1 drop + Class C targeted).
- [ ] `25.1-05-PLAN.md` — NEXT. Language-isolated German prompt (V19 matrix).
- [ ] `25.1-06-PLAN.md` — PENDING. NLD/Jaccard deterministic gates.
- [ ] `23-PLAN.md` — PENDING. Decimal Words & Digit Grouping.

## Session Continuity

Last session: 2026-05-19 (V19C ship + UAT setup)
Stopped at: Plan 25.1-05 Task 4 — human-verify checkpoint open, user dictating against live Debug-Recorder build to validate V19C. Two hotfixes committed mid-session: f443e35 (install-local.sh DR preservation), 4578081 (envelope extractor case-3 closing-only). Build installed at /Applications/Dicticus.app, TCC grants preserved post-rebuild.
Resume signal: user provides "V19 UAT pass" / "V19 re-matrix needed" / "rollback V19" — then dispatch continuation agent to write 25.1-05-SUMMARY.md and start Wave 5.
Resume file: HANDOFF.json carries the Task 4 checkpoint payload (matrix gates, what user needs to verify, exact signals expected).
