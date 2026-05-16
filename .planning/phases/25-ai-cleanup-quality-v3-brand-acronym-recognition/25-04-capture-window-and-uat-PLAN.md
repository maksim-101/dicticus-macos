---
phase: 25-ai-cleanup-quality-v3-brand-acronym-recognition
plan: 04
type: execute
wave: 3
depends_on:
  - 25-02
  - 25-03
files_modified:
  - .planning/phases/25-ai-cleanup-quality-v3-brand-acronym-recognition/25-04-capture-protocol.md
  - .planning/phases/25-ai-cleanup-quality-v3-brand-acronym-recognition/25-04-UAT.md
  - .planning/phases/25-ai-cleanup-quality-v3-brand-acronym-recognition/25-04-v15-v16-diff.md
  - .planning/STATE.md
  - .planning/ROADMAP.md
autonomous: false
requirements: []
must_haves:
  truths:
    - "A Debug-Recorder build of Dicticus (with V16 prompt + always-on feeder + plain-mode logging all live) is installed and used for ≥3 calendar days of real dictation."
    - "Both plain-mode and aiCleanup-mode JSONL records are collected in ~/Library/Application Support/Dicticus/DebugRecordings/."
    - "Isolated-brand mishearing failure rate on the V16 capture is ≤ 30% of the V15 baseline rate (the headline goal from CONTEXT.md)."
    - "Zero `forty one → 4001` digit-concatenation events appear in V16 records."
    - "Acronym-letter-spacing collapses correctly (H D D → HDD) WITHOUT regressing list-of-letters enumeration (A, B, C, D stays enumerated)."
    - "The `phase ↔ face` homophone fix is observable in the new capture."
    - "All V15 wins (GST→GSD, cloud code→Claude Code, true NAS→TrueNAS, opus four point seven→Opus 4.7) are preserved."
    - "A V15→V16 diff report cites specific record-level wins, losses, and ties using the same methodology that produced 25-CONTEXT.md."
    - "User UAT verdict is recorded — ACCEPTED, CONDITIONAL ACCEPT (with follow-up items), or REJECTED (gap closure required)."
  artifacts:
    - path: ".planning/phases/25-ai-cleanup-quality-v3-brand-acronym-recognition/25-04-capture-protocol.md"
      provides: "3-day capture protocol — installation, dictation diet, daily checkpoint, evidence collection commands"
    - path: ".planning/phases/25-ai-cleanup-quality-v3-brand-acronym-recognition/25-04-v15-v16-diff.md"
      provides: "Quantitative V15→V16 diff on real capture data: per-failure-class deltas vs. CONTEXT.md baseline"
    - path: ".planning/phases/25-ai-cleanup-quality-v3-brand-acronym-recognition/25-04-UAT.md"
      provides: "Human UAT verdict + any gap-closure items"
  key_links:
    - from: ".planning/phases/25-ai-cleanup-quality-v3-brand-acronym-recognition/25-04-v15-v16-diff.md"
      to: ".planning/phases/25-ai-cleanup-quality-v3-brand-acronym-recognition/25-CONTEXT.md"
      via: "Diff cites every failure class from CONTEXT.md <specifics> and reports its V16 outcome"
      pattern: "2026-05-1"
    - from: ".planning/phases/25-ai-cleanup-quality-v3-brand-acronym-recognition/25-04-capture-protocol.md"
      to: "~/Library/Application Support/Dicticus/DebugRecordings/"
      via: "Protocol references the DebugRecordings JSONL output (both plain and aiCleanup records)"
      pattern: "cleanup-\\d{4}-\\d{2}-\\d{2}\\.jsonl"
---

<objective>
Run a 3-day capture window on a Debug-Recorder build with V16 prompt + always-on feeder + plain-mode logging all live. Produce a V15→V16 quantitative diff against the CONTEXT.md baseline and record a user UAT verdict closing Phase 25.

Purpose: The harness (Plan 25-01) is necessary but not sufficient — production audio characteristics differ from harness fixtures. This plan converts harness predictions into real-world evidence and records the human UAT verdict that closes Phase 25.

Output: Three artifacts (capture protocol, V15→V16 diff, UAT verdict) plus STATE.md/ROADMAP.md updates marking Phase 25 closed (or routed to gap closure).

Depends on 25-02 (plain-mode JSONL must be live) AND 25-03 (V16 prompt + feeder must be live). Cannot start before both are merged.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/STATE.md
@.planning/ROADMAP.md
@.planning/phases/25-ai-cleanup-quality-v3-brand-acronym-recognition/25-CONTEXT.md
@.planning/phases/25-ai-cleanup-quality-v3-brand-acronym-recognition/25-01-SUMMARY.md
@.planning/phases/25-ai-cleanup-quality-v3-brand-acronym-recognition/25-02-SUMMARY.md
@.planning/phases/25-ai-cleanup-quality-v3-brand-acronym-recognition/25-03-SUMMARY.md
@.planning/debug/harness/results/v16_matrix.md

# Methodology reference — same diff methodology that produced 25-CONTEXT.md from V15
@.planning/phases/24-ai-cleanup-quality-v2/
</context>

<tasks>

<task type="auto">
  <name>Task 1: Write the 3-day capture protocol</name>
  <read_first>
    - .planning/phases/25-ai-cleanup-quality-v3-brand-acronym-recognition/25-CONTEXT.md (failure classes that must show up in the dictation diet)
    - scripts/install-local.sh (how Debug-Recorder builds get installed)
    - .planning/phases/25-ai-cleanup-quality-v3-brand-acronym-recognition/25-02-SUMMARY.md (confirm plain-mode logging shipped)
    - .planning/phases/25-ai-cleanup-quality-v3-brand-acronym-recognition/25-03-SUMMARY.md (confirm V16 + feeder shipped)
  </read_first>
  <action>
Author `.planning/phases/25-ai-cleanup-quality-v3-brand-acronym-recognition/25-04-capture-protocol.md` containing:

1. **Build & install steps:** `scripts/install-local.sh` with DEBUG_RECORDER active. Verify both V16 prompt and feeder changes shipped (cite `git log` SHAs from 25-03 SUMMARY).
2. **Dictation diet (3 days × ≥30 utterances/day):** must include each failure class from CONTEXT.md <specifics>:
   - Brand mishearings (Chemini → Gemini, MPM → NPM, engine eggs → NGINX, Doghand → Dokku, DogChee → Dockge, Cheminai → Gemini)
   - Number-word integrity (forty one, two three streams, phase forty one)
   - Acronym collapse (H D D, T V, S A B N C D)
   - Enumeration (A, B, C, D — must NOT collapse)
   - phase ↔ face homophone (discuss this phase first, GSD phases)
   - V15 wins (GST, cloud code, true NAS, opus four point seven, Versal) — must NOT regress
   - Plain mode: dictate ≥10 utterances/day in plain mode for A/B
3. **Daily checkpoint:** end-of-day, run `wc -l ~/Library/Application\ Support/Dicticus/DebugRecordings/cleanup-$(date +%Y-%m-%d).jsonl` and confirm both `"mode":"plain"` and `"mode":"aiCleanup"` records present (`grep -c`, with `grep -v '^#'` hygiene).
4. **Evidence collection commands:** explicit jq queries to extract per-failure-class records, e.g.:
   ```bash
   jq -c 'select(.steps.raw.text | test("forty one"; "i"))' cleanup-2026-05-*.jsonl
   ```
   List one query per failure class.
5. **Stop conditions:** ≥3 calendar days AND ≥90 total utterances AND ≥1 record from each failure class.
  </action>
  <verify>
    <automated>
      test -f .planning/phases/25-ai-cleanup-quality-v3-brand-acronym-recognition/25-04-capture-protocol.md && \
      grep -q 'DEBUG_RECORDER' .planning/phases/25-ai-cleanup-quality-v3-brand-acronym-recognition/25-04-capture-protocol.md && \
      grep -q 'jq' .planning/phases/25-ai-cleanup-quality-v3-brand-acronym-recognition/25-04-capture-protocol.md && \
      grep -q 'plain' .planning/phases/25-ai-cleanup-quality-v3-brand-acronym-recognition/25-04-capture-protocol.md
    </automated>
  </verify>
  <done>Capture protocol document exists and covers all failure classes from CONTEXT.md plus plain-mode A/B.</done>
</task>

<task type="checkpoint:human-verify" gate="blocking">
  <name>Task 2: Human runs the capture window (3 calendar days of real dictation)</name>
  <what-built>
    A Debug-Recorder build of Dicticus is installed locally with V16 prompt + always-on canonical-term feeder + plain-mode JSONL logging all live. The capture-protocol document (Task 1) lists the dictation diet and daily checkpoints.
  </what-built>
  <how-to-verify>
    1. Install the build via `scripts/install-local.sh` (DEBUG_RECORDER active).
    2. Follow `25-04-capture-protocol.md` for 3 calendar days.
    3. End of each day: confirm JSONL records contain both `"mode":"plain"` and `"mode":"aiCleanup"`. Confirm `dictionary_context_keys` is no longer empty/GSD-only (Phase 25-03 feeder fix observable).
    4. End of day 3: total ≥90 utterances captured, ≥1 record per failure class from CONTEXT.md <specifics>.
    5. Confirm the user's daily workflow is not regressed — if Dicticus quality dropped on any front, capture specific failures for the diff.
  </how-to-verify>
  <resume-signal>Type "capture complete" after day 3. If issues found mid-capture (severe regression on V15 wins, app crash, etc.), type "abort" with description — escalates to gap-closure planning before V16 ships beyond local debug.</resume-signal>
</task>

<task type="auto">
  <name>Task 3: Produce the V15→V16 diff report</name>
  <read_first>
    - .planning/phases/25-ai-cleanup-quality-v3-brand-acronym-recognition/25-CONTEXT.md <specifics> (the V15 baseline per failure class)
    - ~/Library/Application Support/Dicticus/DebugRecordings/cleanup-2026-05-*.jsonl (the V16 capture, days from Task 2)
    - .planning/debug/harness/results/v16_matrix.md (the harness predictions to compare against reality)
  </read_first>
  <action>
Author `.planning/phases/25-ai-cleanup-quality-v3-brand-acronym-recognition/25-04-v15-v16-diff.md` with the SAME methodology that produced 25-CONTEXT.md's empirical scoreboard:

1. **Per-failure-class table:** column 1 class name, column 2 V15 baseline (from CONTEXT.md), column 3 V16 observed (from new capture), column 4 delta, column 5 verdict (PASS / FAIL / REGRESSION).
2. **Headline goal check:** isolated-brand mishearing failure rate — V16 must be ≤ 30% of V15 rate. State the rate explicitly.
3. **Hard goals:** zero `forty one → 4001` events, zero collapsed enumeration (A,B,C,D stays enumerated), zero regression on V15 wins.
4. **Plain vs. aiCleanup A/B:** for the plain-mode records collected, compare raw text quality against aiCleanup text quality on matched utterances (where the user dictated the same phrase in both modes).
5. **Surprises section:** any failure class that emerged in V16 but wasn't in CONTEXT.md.
6. **Harness-vs-reality reconciliation:** for each prediction in `v16_matrix.md`, did production match? Cite specific record IDs.
  </action>
  <verify>
    <automated>
      test -f .planning/phases/25-ai-cleanup-quality-v3-brand-acronym-recognition/25-04-v15-v16-diff.md && \
      grep -q 'V15' .planning/phases/25-ai-cleanup-quality-v3-brand-acronym-recognition/25-04-v15-v16-diff.md && \
      grep -q 'V16' .planning/phases/25-ai-cleanup-quality-v3-brand-acronym-recognition/25-04-v15-v16-diff.md && \
      grep -E -q '(PASS|FAIL|REGRESSION)' .planning/phases/25-ai-cleanup-quality-v3-brand-acronym-recognition/25-04-v15-v16-diff.md
    </automated>
  </verify>
  <done>Diff document exists, every CONTEXT.md failure class has a row, headline goal verdict is stated, harness predictions are reconciled with production reality.</done>
</task>

<task type="checkpoint:decision" gate="blocking">
  <name>Task 4: User UAT verdict — ACCEPTED / CONDITIONAL / REJECTED</name>
  <decision>Does V16 ship to production (macOS-vX.Y + iOS-vX.Y), or does Phase 25 enter gap closure?</decision>
  <context>
    The V15→V16 diff (Task 3) is the input. The headline goal is ≤ 30% V15 brand-mishearing rate, zero digit-concat events, no regression on V15 wins. The user is the only judge of whether the dictation experience improved.
  </context>
  <options>
    <option id="accepted">
      <name>ACCEPTED</name>
      <pros>V16 ships in next macOS + iOS release. Phase 25 closes. STATE.md + ROADMAP.md updated.</pros>
      <cons>None if metrics are met.</cons>
    </option>
    <option id="conditional">
      <name>CONDITIONAL ACCEPT</name>
      <pros>V16 ships with documented follow-up items (e.g., specific brand still missed, deferred to Phase 26 backlog).</pros>
      <cons>Phase 25 closes with explicit follow-ons logged; roadmap grows.</cons>
    </option>
    <option id="rejected">
      <name>REJECTED — gap closure required</name>
      <pros>Surfaces problems before they hit users. Triggers `/gsd-plan-phase --gaps` for a 25.x follow-on plan set.</pros>
      <cons>Phase 25 stays open; V16 does not ship yet.</cons>
    </option>
  </options>
  <resume-signal>Select: accepted, conditional, or rejected. If conditional or rejected, describe the gaps in `25-04-UAT.md`.</resume-signal>
</task>

<task type="auto">
  <name>Task 5: Write UAT verdict and close Phase 25 state</name>
  <read_first>
    - Task 4's resume-signal (the verdict)
    - .planning/STATE.md
    - .planning/ROADMAP.md
  </read_first>
  <action>
1. Author `.planning/phases/25-ai-cleanup-quality-v3-brand-acronym-recognition/25-04-UAT.md` capturing the verdict from Task 4, the diff summary, and any follow-up items.
2. Update `.planning/STATE.md` — mark Phase 25 status:
   - ACCEPTED or CONDITIONAL → status: `complete` (with follow-ups noted under CONDITIONAL).
   - REJECTED → status: `gap-closure` (with next-step pointer to `/gsd-plan-phase --gaps`).
3. Update `.planning/ROADMAP.md` Phase 25 entry similarly. Mark plan checkboxes complete:
   - `[x] 25-01-PLAN.md`
   - `[x] 25-02-PLAN.md`
   - `[x] 25-03-PLAN.md`
   - `[x] 25-04-PLAN.md`
4. Commit message (when user runs the commit): `docs(gsd): close Phase 25 — V16 brand-anchored cleanup [VERDICT]`.
  </action>
  <verify>
    <automated>
      test -f .planning/phases/25-ai-cleanup-quality-v3-brand-acronym-recognition/25-04-UAT.md && \
      grep -E -q '(ACCEPTED|CONDITIONAL|REJECTED)' .planning/phases/25-ai-cleanup-quality-v3-brand-acronym-recognition/25-04-UAT.md && \
      grep -q 'Phase 25' .planning/STATE.md && \
      grep -q '25-04-PLAN.md' .planning/ROADMAP.md
    </automated>
  </verify>
  <done>UAT document written, STATE.md + ROADMAP.md reflect Phase 25's closing status, all four plan checkboxes are flipped.</done>
</task>

</tasks>

<verification>
- All three artifacts (capture-protocol.md, v15-v16-diff.md, UAT.md) exist.
- STATE.md and ROADMAP.md updated to reflect Phase 25's closing status.
- The capture window happened on a real Debug-Recorder build (verifiable via `git log` SHAs cited in capture-protocol.md and ≥3 days of JSONL files in DebugRecordings/).
- The diff report uses the same methodology that produced 25-CONTEXT.md and includes a harness-vs-reality reconciliation.
- User UAT verdict recorded; if REJECTED, gap-closure plan pointer is logged.
</verification>

<success_criteria>
- 3-day capture window completed on V16 + plain-mode-logging build.
- V15→V16 diff produced with per-failure-class verdicts.
- Headline goal verdict explicitly stated (≤ 30% brand-mishearing rate vs. V15).
- User UAT verdict captured and reflected in STATE.md + ROADMAP.md.
- Phase 25 is either CLOSED (ACCEPTED/CONDITIONAL) or routed to gap closure (REJECTED).
</success_criteria>

<output>
After completion, create `.planning/phases/25-ai-cleanup-quality-v3-brand-acronym-recognition/25-04-SUMMARY.md` capturing:
- Capture-window stats (days, total utterances, per-class counts).
- Headline V15→V16 deltas (brand-mishearing rate, digit-concat count, enumeration preservation, V15-wins preservation).
- Harness-vs-reality reconciliation summary (predictions that matched, predictions that missed).
- UAT verdict and any follow-up items routed to backlog or gap closure.
- Phase 25 closing handoff: next milestone or next phase to start.
</output>
