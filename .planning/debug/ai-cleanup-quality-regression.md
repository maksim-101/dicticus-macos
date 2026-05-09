---
status: partially-resolved
trigger: "AI Cleanup paraphrasing, hallucinating, dropping self-corrections, and mishandling number ranges (post-v2.2 regression). Goal: cleanup should ONLY touch up grammar/sentence structure/obvious ASR mishearings — never paraphrase, never delete content, never invent words."
created: 2026-05-04
updated: 2026-05-09
resolution_trail:
  - "Symptoms (B) self-correction dropping, (C) hallucination, (D) time-loss — substring-based artifacts of the resolver bug — RESOLVED by Phase 22 (regex hotfix at SelfCorrectionResolver.swift:75). Production UAT 2026-05-09 confirmed."
  - "Symptom (B) RESIDUAL — true LLM-side self-correction handling (where the LLM, not the resolver, must drop abandoned phrases) is NOT addressed by Phase 22 and was re-observed in production UAT 2026-05-09 (input 'persist now or will is not or will it not?' passed verbatim). Carried forward as Phase 24 (AI Cleanup Quality v2). Capture window 2026-05-09 → 2026-05-12 in progress; see `.planning/phases/24-ai-cleanup-quality-v2/24-CONTEXT.md`."
symptoms:
  expected: |
    AI cleanup is a SURGICAL touch-up:
    - Fix grammar (capitalization, punctuation, agreement)
    - Fix obvious ASR mishearings of known terms (via dictionary anchor)
    - Preserve user's words, content, and self-corrections verbatim
    - Never invent text; never collapse content; never paraphrase
  actual: |
    Four distinct failure modes observed:

    (A) PARAPHRASING — invents filler tokens.
        ~~Input:  "That is satisfactory with the quality."~~
        ~~Output: "That is if it is satisfactory with the quality."  (added "if it is")~~
        RETRACTED 2026-05-04 (user clarification): "That is if it is satisfactory
        with the quality" was the user's actual dictated phrase, not a paraphrase
        introduced by cleanup. Symptom (A) is no longer a confirmed failure mode.
        Remaining failure modes (B), (C), (D), (E) are unaffected — V0 still has
        documented catastrophic failures on F01/F16/F23/F24/F31/F32 etc.

    (B) SELF-CORRECTION DROPPING / TIME-LOSS —
        Input:  "the first meeting I think is at six o'clock? No, it's at five 30 PM."
        Output: time correction at end not preserved cleanly.

    (C) HALLUCINATION — fabricates content not in source.
        User reports invented names/days appearing in output that were not dictated.

    (D) NUMBER-RANGE HOMOPHONE — "one to four" → "102, four"
        ASR hears "to" as homophone "two", ITN normalizes "1 2 4",
        downstream produces "phases 102, four" instead of "phases 1–4".

    (E) SHORT-INPUT FAILURE / NO TRANSCRIPTION (added 2026-05-04, secondary —
        possibly different root cause from A-D, may be ASR-side):
        Dictating very short utterances ("A plus B") produced (1) an
        ASR mishearing → "AppLite B" the first time, then (2) on retry
        of just "A plus B" twice in a row: error notification popped up,
        NO text was injected at all. CleanupService catch path normally
        returns raw text on error (Shared/Services/CleanupService.swift:290-294,
        documented as D-19 fallback). User reports raw text was NOT pasted —
        suggests this is upstream of cleanup (ASR returned empty? recording
        too short? minimum-duration guard? notification path that suppresses
        injection). Track separately; do not let it derail the cleanup
        investigation but verify before closing the session.
  error_messages: "None — silent quality degradation. No crashes, no logs surface the paraphrasing."
  timeline: |
    Regressed during v2.2 milestone iterations. Suspect commits:
    - c04dde5 (2026-05-03): "disable safety gates to unblock short-sentence repairs"
      → removed Levenshtein/Dialect gates, no backstop for paraphrase.
    - 8a79e6b (2026-05-03): "resolve 'W' hallucination" added few-shot in
      CleanupPrompt teaching expansion of "w" → "this is good" — paraphrase
      training signal.
    - 21b714a (2026-05-03): "Surgical Completion" architecture refactor of
      CleanupPrompt structure.
    Worked acceptably in macos-v1.2.0 production UAT (2026-05-01) per
    project_phase20_uat_findings memory.
  reproduction: |
    1. Run macOS app from /Applications (current Dicticus.dmg build).
    2. Enable AI cleanup mode.
    3. Dictate any of these test inputs (or paste raw text into a test harness
       that calls CleanupService.cleanup directly):
       - "Let's see whether this is good"
       - "This looks good, and I think we can continue with GSD housekeeping.
          That is satisfactory with the quality."
       - "the first meeting I think is at six o'clock? No, it's at five 30 PM."
       - "Claude Code should verify phases one to four."
    4. Compare output to input — flag any insertion, deletion, or
       paraphrase beyond capitalization/punctuation/known-term correction.
---

# Current Focus
- hypothesis: "Production 'T'/'W' degenerate-collapse bug is real but does NOT reproduce in offline harness with V5 prompt + production sampler + production GGUF (any seed). Root cause must be runtime-only state (KV-cache bleed, sampler-seed drift, mid-call config flip, or a bug in the deployed app that diverges from harness invocation). Need live capture from the running app to surface what the harness can't."
- test: "Reproduce in production by enabling DebugRecorder (Dicticus-Debug-Recorder scheme, committed 2026-05-08) and dictating until a collapse anomaly fires. Inspect the JSONL record's llm_prompt + llm_raw to see exactly what the model received and emitted at the failure moment."
- expecting: "Recorder JSONL with anomaly.degenerate_collapse=true on at least one capture. Fields will reveal whether the prompt was malformed, the dictionary context contaminated, the sampler in a bad state, or the model output is genuinely degenerate from a clean prompt."
- next_action: "User runs Dicticus-Debug-Recorder scheme locally, dictates real workloads for a session, then we inspect ~/Library/Application Support/Dicticus/DebugRecordings/cleanup-YYYY-MM-DD.jsonl together. No further code changes pending until we have live data."

# Evidence
- timestamp: 2026-05-04
  details: "Static analysis of Shared/Models/CleanupPrompt.swift confirms three problematic few-shot examples — lines 52-53 (de self-correction collapse), 58-59 (en 'w'→'this is good' expansion), 64-65 (en self-correction collapse to single number)."
- timestamp: 2026-05-04
  details: "TextProcessingService.swift:107-120 — gateLLMDialect and gateLLMOutput calls are commented out (commit c04dde5). No remaining defense against LLM content drift."
- timestamp: 2026-05-04
  details: "User UAT 2026-05-04 reports paraphrase ('That is' → 'That is if it is'), content dropping, and 'Mira'/'Wednesday' hallucinations on real dictation."
- timestamp: 2026-05-04
  details: "User reports separate failure mode: 'Claude Code should verify phases 102, four.' instead of '1 to 4' — homophone 'to'/'two' collision in ITN layer, predates LLM."
- timestamp: 2026-05-04
  details: "RulesCleanupService.clean runs SelfCorrectionResolver in AI mode (TextProcessingService.swift:70-72). English connectors include 'no', 'actually', 'wait' with comma-prefix guard. The user's 'six o'clock? No, it's at five 30 PM' would trigger this resolver, dropping 'six o'clock' before LLM input — this competes with the LLM's own self-correction handling."
- timestamp: 2026-05-04
  details: |
    Pre-flight discovery for offline harness (gsd-debug-session-manager pre-flight):
    - llama-cli binary: /opt/homebrew/bin/llama-cli
    - llama-server binary: /opt/homebrew/bin/llama-server
    - Active model (Gemma 4 E2B Q4_K_M): /Users/mowehr/Library/Application Support/Dicticus/Models/gemma-4-E2B-it-Q4_K_M.gguf
    - Legacy model (Gemma 3 1B Q4_0): /Users/mowehr/Library/Application Support/Dicticus/Models/gemma-3-1b-it-Q4_0.gguf  (available for A/B regression testing)
    - Model wiring: macOS/Dicticus/Services/ModelDownloadService.swift (modelFileName="gemma-4-E2B-it-Q4_K_M.gguf"), loaded at ModelWarmupService.swift:146-155.
    - Existing test infra to extend: macOS/DicticusTests/{CleanupServiceTests,ModelWarmupServiceTests,ModelDownloadServiceTests}.swift

# Eliminated
- "Stochastic LLM sampling causes paraphrase" — at temp=0.1 the model is deterministic across seeds 1, 2, 3, 42, 99. V0 fails the same way every run. Bug is structural (prompt-induced), not sampling-related.
- "Removing the bad few-shots is sufficient" — V1 (V0 minus the 3 dropping/expansion few-shots) STILL fails F01 ("first meeting...six o'clock? No, it's at 5:30 PM" → "first meeting is at five thirty PM"). The model has its own bias toward fluent collapse; explicit "preserve every word" instruction is required to override it.
- "User's exact paraphrase ('That is' → 'That is if it is') reproduces in offline harness" — does NOT reproduce on F02 across any variant or seed. User's actual ASR input was likely different from the cleaned text they retyped. V0's other failures are reproducible and ample to explain user dissatisfaction.

# Empirical Results (offline harness, 35 fixtures × 4 variants, deterministic seed=42)
- Harness: .planning/debug/harness/run.py (Python stdlib + llama-server HTTP, exact sampler parity to CleanupService.swift:147-156).
- Variants tested:
  - V0: exact mirror of current Shared/Models/CleanupPrompt.swift (baseline)
  - V1: V0 minus the 3 bad few-shots
  - V2: instruction-led + minimal safe few-shots
  - V3: V2 + explicit disfluency-removal carve-out (recommended)

## V0 catastrophic failures (reproducible at any seed):
- F01 self-correction collapse: "first meeting I think is at six o'clock? No, it's at five 30 PM" → "The first meeting is at 5:30 PM" (drops "I think", "six o'clock", "No, it's at")
- F11 long-form mangling: comma-to-period restructuring, drops "And so"
- F12 short fragment + ellipsis hallucination: "I would say" → "I would say..."
- F13 prefix drop: "and so in between" → "In between."
- F16 (de) self-correction collapse: "...dienstag um 9 uhr...montag um 8 uhr" → "Mein erstes Meeting wohl am Montag um 8 Uhr sei." (drops the entire reparandum)
- F23 unprompted German→English translation: "Phasen eins bis vier sollten wir prüfen." → "We should check phases one through four."
- F24 question-to-fabricated-answer: "When is the first meeting tomorrow?" → "The first meeting tomorrow is at nine." (HALLUCINATES)
- F27/F28 multi-correction collapse: "demo is on tuesday, no actually wednesday, at three pm wait four pm" → "The demo is on Wednesday at four pm."
- F31 destruction: "the App Lite version was wrong i meant A plus B" → "The App Plus B." (loses entire correction context — this is the user's reported "AppLite B" experience)
- F32 affirmative→negative inversion: "Did Mira mention which day..." → "Mira didn't mention which day..." (DANGEROUS — inverts factual meaning)
- F35 inversion drop: "wont we need to ship by friday otherwise the demo wont work" → "We need to ship by Friday, otherwise the demo won't work." (drops "Won't we" inversion)

## V3 verdict (recommended for production):
- ✓ Fixes ALL V0 failures listed above (F01, F11, F12, F13, F14, F16, F23, F24, F27, F28, F31, F32, F35)
- ✓ Removes pure disfluencies as expected (F14: "uh I think we should um you know like maybe..." → "I think we should maybe try the new approach"; F25 (de): drops "äh"/"ähm")
- ✓ Preserves substantive self-corrections introduced by no/wait/actually/I mean/nein/moment/eigentlich
- ✓ Doesn't regress dictionary fixes (F07/F17 GSD/TrueNAS still mapped) or grammar/punctuation (F15/F35 punctuation still added)
- ✗ Number-range bug F09/F10 ("phases 102, four") still present — confirms this MUST be fixed in ITNUtility, not LLM
- = same speed as V0 (~0.2-1.1s per call, prompt-cache friendly)

# Resolution (proposed — pending approval)

## Fix 1: Replace CleanupPrompt with V3 structure
- File: Shared/Models/CleanupPrompt.swift
- Replace flat-glossary + Term:/In:/Out: minimalist structure with:
  - Short imperative task instruction ("Light cleanup of dictated speech...")
  - Explicit "preserve substantive content, including self-corrections introduced by no/wait/actually/I mean/nein/moment/eigentlich"
  - Explicit "Never add words. Never paraphrase. Never answer questions."
  - Two safe few-shots per language (dictionary fix + disfluency removal example) — NO dropping examples
- iOS parity: Shared/ — change ships on both platforms automatically.

## Fix 2: Re-enable Levenshtein safety gate as backstop
- File: Shared/Services/TextProcessingService.swift:107-120
- Re-enable gateLLMOutput with calibrated threshold derived from harness (V3 max word-Levenshtein observed = 6 on 35 fixtures, mostly punctuation; threshold = max(input_word_count * 0.5, 8) gives headroom).
- Reason: harness covers known cases but real ASR will produce inputs we don't have fixtures for. Gate is cheap insurance.

## Fix 3: ITN homophone fix for number ranges
- File: Shared/Utilities/ITNUtility.swift
- Detect pattern: range-implying noun ("phases", "chapters", "steps", "items", "Phasen", "Kapitel", "Schritte") followed by `\d+ \d+ \d+` or `\d+, \d+` and rewrite to `\d–\d`.
- Pre-empt the homophone collision before it reaches LLM.
- Edge case: don't compress lists ("phases one, two, four" — keep as list, only compress contiguous "1 to N").

## Fix 4 (separate, lower priority): SelfCorrectionResolver in AI mode
- File: Shared/Services/TextProcessingService.swift:70-72
- Currently runs SelfCorrectionResolver before LLM in AI mode. With V3 prompt the LLM handles self-corrections correctly; the rules layer competes and can drop content.
- Decision needed: gate SelfCorrectionResolver to plain mode only OR keep it as a safety net.
- Recommendation: keep it but tighten — only fire when confidence high (multi-token reparandum); let LLM handle ambiguous cases.

# Remaining open questions
1. Should disfluencies actually be removed (V3 behavior) or preserved verbatim (V2 behavior)? V3 matches typical user expectation but loses fidelity. Get user vote.
2. Does V3 hold up against the actual app's full default dictionary (~75 entries) — the harness uses a trimmed set. Worth verifying with full dict before commit.
3. Failure mode (E) "A plus B" → no transcription / error notification — separate investigation needed; F06 fixture in offline harness shows V0/V2/V3 all handle "A plus B" fine, suggesting the issue is upstream in ASR or the recording-duration guard, not cleanup.

# 2026-05-05 Iteration 2 — V4 retraction → V5 strict-verbatim

## V4 retracted
V4 ("resolve self-corrections, preserve structural negations") shipped earlier
on 2026-05-05 (commit 17dc2bd). User UAT same day reported V4 still:
  - dropped substantive content on long-form ("I would say, and the first
    meeting" → vanished)
  - eats sentence connectors ("And so", "and so in between" → "in between")
  - over-generalizes "drop original phrase before connector" rule

Mechanism: telling the LLM "drop the original phrase before no/wait/actually"
generalized to "drop preamble before any connector," eating legitimate filler-y
intros like "I would say, and...".

## V5 (committed, e1d3eef) — strict verbatim
Added 4 new prompt variants to harness (V4 prod-mirror, V5 strict-verbatim,
V6 minimalist-no-fewshot, V7 strict + compact fewshot). Added 10 new fixtures
covering the 2026-05-05 user-reported failure modes (F36-F45). Ran 4-way
comparison on 18 regression-prone fixtures (results/v4_vs_v5_v6_v7_keyset.tsv,
seed=42, production GGUF).

Verdict: V5 wins on every reported failure case.
  F11 long-form:           V4 lev=11  V5 lev=0
  F36 filler-prefix drop:  V4 catastrophic  V5 lev=1
  F38 short self-correct:  V4 collapses  V5 preserves
  F43 "and so":            V4 strips  V5 preserves
  F16/F27/F28 multi:       V4 collapses  V5 preserves
  F44 Mira-question:       V4 OK   V5 OK (no hallucination either)

V5 full-suite run (results/v5_full.tsv) confirms no new regressions:
all 45 fixtures lev ≤ 6 (longest German), preservation fixtures lev ≤ 1.

Tradeoff accepted: explicit time-corrections like "9 Uhr, ach ich meine
8 Uhr" are now preserved verbatim (lev=2) instead of resolving to "8 Uhr".
ASR-faithful output > niche auto-resolve.

Code change: Shared/Models/CleanupPrompt.swift rewritten with V5
instruction-led + 2 safe few-shots per language. Updated
TextProcessingService.swift comment to point at V5 (was still V3).

Status: V5 installed to /Applications, awaiting UAT.

# 2026-05-06 Iteration 3 — V5 holds, V8 family rejected

V8 (WRONG/CORRECT contrastive) and 65-fixture stress run (results/v8_stress_REPORT.md):
V5 produces zero true MAJORs across all 65 fixtures including F55-F65 stress
cases. V8 introduces 5 new MAJORs from the WRONG/CORRECT framing (the model
mimics the WRONG examples). V8a (V8 minus contrastive) ties V5 but doesn't
improve on it. Verdict: SHIP NOTHING. V5 stays.

DictionaryService cleanup committed 8a79e6b: removed brittle "1m"/"1 m"/"I m"/
"one m"/"One m" → "I'm" mappings + added purgeRetiredDefaults() to drop them
from existing UserDefaults installs.

# 2026-05-07/08 Iteration 4 — model/prompt search exhausted, switching to live capture

Live UAT after V5+SelfCorrectionResolver abort-3a deploy still showed
production "T"/"W" degenerate-collapse and broken-German cases. Investigated:

1. Q5_K_M / Q6_K Gemma 4 E2B quantization (.planning/debug/harness/results/
   q5_languagetool_REPORT.md): the collapse bug DOES NOT REPRODUCE in the
   offline harness on any of Q4/Q5/Q6 against the F66/F67/F68 fixtures
   (broken-German + collapse traps). Q5/Q6 are not the fix.

2. LanguageTool 6.8 post-pass: corrupts Swiss orthography (forces ß over ss)
   and mangles brand names. Net-harmful. Rejected.

3. Phi-3 Mini superiority claim from initial research: RETRACTED after
   external evidence — Microsoft's own Phi-3 card says English-skewed; Gemma 3
   4B beats Phi-3.5 on IFEval. Don't switch on that basis.

4. Polish/Heavy-rewrite mode design: ON HOLD. Adding a more aggressive prompt
   on top of the same Q4 model would amplify the very degenerate-collapse
   behavior we can't currently characterize.

The harness path is exhausted without live production data. Built and shipped
the DebugRecorder instead (commit pending, this iteration):

- Shared/Diagnostics/DebugRecorder.swift — JSONL appender, daily rotation,
  14-day retention, anomaly auto-flag for raw>30 chars && llm_raw<5 chars.
- Shared/Services/CleanupService.swift — captures full assembled prompt,
  raw pre-strip llama output, latency, model name into nonisolated lastDebugTrace.
- Shared/Services/TextProcessingService.swift — measures per-step (raw →
  post_dict → post_itn → post_swiss → post_rules → llm_prompt → llm_raw →
  post_gate → post_swiss_num) and writes one JSONL record per cleanup.
- All recorder code fenced under `#if DEBUG_RECORDER` — compiled out of the
  public Release build. Verified: 0 recorder symbols in default Debug build,
  107 in Debug-Recorder build.
- macOS/project.yml — new Debug-Recorder config (inherits Debug) + new
  Dicticus-Debug-Recorder scheme. Public scripts/build-dmg.sh untouched.
- iOS NOT yet wired (parity TBD once macOS data confirms recorder design).

Output path: ~/Library/Application Support/Dicticus/DebugRecordings/cleanup-YYYY-MM-DD.jsonl
Filter for collapse: `jq 'select(.anomaly.degenerate_collapse)' cleanup-*.jsonl`

Status: BLOCKED on user collecting live recorder data. Resume from here once
the user has dictated under Dicticus-Debug-Recorder long enough to capture
at least one anomaly.

---

## RESOLVED 2026-05-08 — Live capture, root cause identified, Phase 22 queued

**Capture:** Two dictation batches under `Dicticus-Debug-Recorder` produced 30 JSONL
records at `~/Library/Application Support/Dicticus/DebugRecordings/cleanup-2026-05-08.jsonl`.
TCC permissions inherited from prod build via re-signing with Developer ID Application
cert `B9CA1FF8209D9B1BD4940F2D39C327EF836FD3C0` (DR matches prod byte-for-byte).

**Root cause:** `Shared/Utilities/SelfCorrectionResolver.swift:75`

```swift
let pattern = "(?i)(?:[,;:.?!]?\\s+|,\\s*)(\(alternation))(\\s*)"
```

Two flaws in the regex:

1. `[,;:.?!]?` — punctuation prefix is OPTIONAL, so plain whitespace before any connector
   token fires the match. The function name implies "comma-prefixed self-correction"
   but the regex accepts any word boundary.
2. No `\b` after the alternation capture. With `connectors` containing bare tokens like
   `no`, `wait`, `ne`, `wart`, `actually`, the regex matches inside `now`, `noticed`,
   `nowadays`, `waitress`, `nehmen`, `neben`, `warten`, `wartest`. The trailing characters
   are consumed because the regex doesn't re-anchor.

**Verbatim evidence (raw → post_rules in JSONL):**

| Record | raw | post_rules | Bug |
|---|---|---|---|
| 5 | `go ahead now please` | `go ahead w please` | `now` matched `no`; `w` is residue |
| 6 | `actually is, what` | `is, what` | `actually` fired without comma prefix |
| 9 | `in home assistant now` | `in home assistant w` | same as #5 |
| 11 | `oh wait, I just noticed` | `oh w, I just w` | `wait` and `noticed` both eaten |
| 18 | `did will persist now` | `did will persist w` | same as #5 |
| 19 | `push the branch now` | `push the branch w` | same |
| 29 | `you noticed as well` | `you w as well` | `noticed` → `no` ate it |

The corruption happens BEFORE the LLM stage. Commit `8a79e6b` (CleanupPrompt
"W → 'this is good'" few-shot) was treating a downstream symptom — the LLM never
invented "w"; the resolver created the residue and the LLM either echoed or
hallucinated a recovery.

**Proposed fix (planner will detail):**

```swift
let pattern = "(?i)(?:^|,)\\s+(\(alternation))\\b(\\s*)"
```

Open question: should `^` fire for all connectors, or only the high-signal ones
(`I mean`, `I meant`, `scratch that`, `or rather`)? Phase 22 planner decides.

**Out of scope (Phase 23 backlog):** records 24-28 also showed two ITN bugs:
spoken decimal markers (`Punkt`/`Komma`/`point`) not folded between digit
groups, and English ITN concatenating `three, five` → `35` ignoring the comma.
NOT a regression caused by the resolver and shouldn't block Phase 22.

**Wrong-microphone diagnostic:** the original symptom that opened this debug
session ("recording symbol but no transcript") turned out to be a wrong-mic
selection by the user, not a code bug. The DebugRecorder shipped during that
investigation gave us the data to find the actual production regression.

**Next:** `/gsd-plan-phase 22` — see `.planning/phases/22-resolver-regression-hotfix/22-CONTEXT.md`.

Status: ROOT CAUSE CONFIRMED. Remediation queued as Phase 22.
