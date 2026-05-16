---
phase: 25-ai-cleanup-quality-v3-brand-acronym-recognition
plan: 03
type: execute
wave: 2
depends_on:
  - 25-01
files_modified:
  - Shared/Services/DictionaryService.swift
  - Shared/Models/CleanupPrompt.swift
  - .planning/debug/harness/run.py
  - .planning/debug/harness/results/v16_matrix.tsv
  - .planning/debug/harness/results/v16_matrix.md
  - macOS/DicticusTests/DictionaryServiceTests.swift
  - macOS/DicticusTests/CleanupPromptTests.swift
  - macOS/DicticusTests/SelfCorrectionResolverTests.swift
  - iOS/DicticusTests/DictionaryServiceTests.swift
  - iOS/DicticusTests/CleanupPromptTests.swift
  - iOS/DicticusTests/SelfCorrectionResolverTests.swift
autonomous: false
requirements: []
must_haves:
  truths:
    - "Shared/Services/DictionaryService.swift `prepopulateWithDefaults` contains the ~16 Phase-25 dictionary entries from v16_matrix.md §5 Lever 1 (H9 dict)."
    - "Shared/Models/CleanupPrompt.swift contains a V16-COMPOSITE build path adopting H3 (domain topic + phase/face few-shot) and H4 (number-integrity rule + few-shot), with H1 explicitly NOT adopted and H5 conditionally adopted per Task 3 V17 verification."
    - "Targeted substring matcher in Shared/Services/TextProcessingService.swift is UNCHANGED — the dictionary expansion (Task 1) is the feeder lever, not the matcher."
    - "A V17 harness variant has been run against phase25_brands.tsv at seed=42 and its results appended to v16_matrix.tsv + a new §6 verification block in v16_matrix.md BEFORE any Swift code is committed."
    - "V17 aggregate < V16E's 50, brand-class ≤ 2 (H9 parity), P25-regress-06-feeding-fitting stays at lev 0, P25-brand-01-cheminiheadless does not recur V16D's brand regression."
    - "Each new test fixture references a real V15-era failure timestamp from 25-CONTEXT.md OR a V15-era win that must not regress."
    - "macOS test suite: 10/10 CleanupPromptTests + 27/27 SelfCorrectionResolverTests still green, plus new DictionaryServiceTests and new Phase 25 CleanupPromptTests fixtures pass."
    - "iOS test files mirror the macOS additions byte-for-byte where possible (per cross-platform parity)."
    - "User checkpoint passes before shipping — V16-COMPOSITE prompt + dictionary expansion is gated on human UAT review of the V17 verification block in v16_matrix.md and the new test fixtures."
  artifacts:
    - path: "Shared/Services/DictionaryService.swift"
      provides: "Phase 25 dictionary expansion (Chemini/Cheminai → Gemini, MPM → NPM, engine eggs → NGINX, Doghand → Dokku, DogChee → Dockge, C Oli → CLI, true Nas → TrueNAS, plus lowercased variants)"
      contains: "Chemini"
    - path: "Shared/Models/CleanupPrompt.swift"
      provides: "V16-COMPOSITE prompt build path with H3 + H4 (and optionally H5) rules + few-shots"
      contains: "V16"
    - path: ".planning/debug/harness/results/v16_matrix.md"
      provides: "Appended §6 V17 verification block with V17 aggregate, brand-class, and regress-06 numbers"
      contains: "V17"
    - path: "macOS/DicticusTests/DictionaryServiceTests.swift"
      provides: "Phase 25 regression-net fixtures for the new dictionary entries"
      contains: "Phase25"
    - path: "macOS/DicticusTests/CleanupPromptTests.swift"
      provides: "Phase 25 V16 regression-net fixtures (number-integrity rule line, phase/face few-shot, optional acronym rule)"
      contains: "Phase25"
  key_links:
    - from: "Shared/Services/DictionaryService.swift"
      to: ".planning/debug/harness/results/v16_matrix.md"
      via: "The ~16 new defaults entries mirror v16_matrix.md §5 Lever 1 (H9 dict that landed brand 35→2 and anchor 28→0)"
      pattern: "Chemini.*Gemini"
    - from: "Shared/Models/CleanupPrompt.swift"
      to: ".planning/debug/harness/results/v16_matrix.md"
      via: "V16-COMPOSITE build path reproduces the §5 recommended H3+H4 rule block + few-shots"
      pattern: "// V16"
    - from: ".planning/debug/harness/run.py"
      to: ".planning/debug/harness/results/v16_matrix.tsv"
      via: "New V17 variant registered alongside V16A-F, output appended to v16_matrix.tsv"
      pattern: "V17"
    - from: "macOS/DicticusTests/DictionaryServiceTests.swift"
      to: ".planning/phases/25-ai-cleanup-quality-v3-brand-acronym-recognition/25-CONTEXT.md"
      via: "Every new fixture's docstring cites the 2026-05-1X timestamp it locks"
      pattern: "2026-05-1"
---

<objective>
Ship the hybrid V16-COMPOSITE + dictionary expansion to production: the highest-ROI Phase 25 levers identified by the 25-01 v16_matrix.md addendum (2026-05-16T05:10 §1b/§2.8/§2.9/§4/§5).

Purpose: The H8/H9 rules-only baselines proved that **the dictionary is the dominant lever for brand+anchor classes** — H9 lands brand 35→2 and anchor 28→0 with zero LLM cost. The LLM's irreplaceable value sits in three categories the dictionary structurally cannot help with: **num** (forty one → 41, H4), **phase_face** (face → phase, H3), and to a lesser extent **acro** (H5, conditional). The original §7 recommendation ("V16-COMPOSITE = H3+H4+H5 + broaden the substring matcher") is **superseded** by §5: dictionary expansion replaces the matcher work AND H1 (always-on canonical), and H5 becomes conditional on V17 verification.

This plan ships:
1. **Lever 1 — dictionary expansion** in `Shared/Services/DictionaryService.swift` (deterministic, zero LLM risk, biggest single win in Phase 25).
2. **Lever 2 — V16-COMPOSITE prompt** in `Shared/Models/CleanupPrompt.swift` adopting H3 + H4 (and conditionally H5), explicitly skipping H1.
3. **Harness V17 verification** appended to `.planning/debug/harness/results/v16_matrix.{tsv,md}` BEFORE the Swift code is committed, confirming the prompt composite does not re-introduce V16F's regression-06 catastrophe or V16D's brand-side regression.
4. **Regression-net tests** locking V15 wins, the new dictionary entries, and the V16 prompt-shape contract on macOS + iOS.
5. **Human UAT checkpoint** against CONTEXT.md `<specifics>` failure cases on a Debug-Recorder build.

The targeted-substring matcher in `Shared/Services/TextProcessingService.swift` is **deliberately NOT modified** in this plan — §5 supersedes the original §7 recommendation to broaden it. Dictionary expansion (Task 1) absorbs that lever, with stronger empirical justification (H9 paired-row evidence, §2.9).

Output: V16-COMPOSITE prompt + expanded dictionary in production, V17 harness verification artifact, regression-net fixtures, on macOS + iOS together. Cross-platform per `feedback_cleanup_cross_platform_parity`.

Depends on plan 25-01 — `v16_matrix.md` (incl. addendum §1b–§5) is the evidentiary input for both levers.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/STATE.md
@.planning/phases/25-ai-cleanup-quality-v3-brand-acronym-recognition/25-CONTEXT.md
@.planning/debug/harness/results/v16_matrix.md
@.planning/debug/harness/results/v16_matrix.tsv
@.planning/phases/25-ai-cleanup-quality-v3-brand-acronym-recognition/25-01-SUMMARY.md

# The files this plan modifies (Swift)
@Shared/Services/DictionaryService.swift
@Shared/Models/CleanupPrompt.swift

# The harness this plan extends (Python)
@.planning/debug/harness/run.py

# Test scaffolding
@macOS/DicticusTests/CleanupPromptTests.swift
@macOS/DicticusTests/SelfCorrectionResolverTests.swift
@iOS/DicticusTests/CleanupPromptTests.swift
@iOS/DicticusTests/SelfCorrectionResolverTests.swift

# Phase 24 ship plan + Phase 22 hotfix — the regression bar this plan must NOT break
@.planning/phases/24-ai-cleanup-quality-v2/

<interfaces>
<!-- Current prod surfaces to integrate against. -->

```swift
// Shared/Services/DictionaryService.swift:85-107 (current `defaults` dict — Task 1 extends in place)
private func prepopulateWithDefaults() {
    let defaults: [String: String] = [
        "true nest": "TrueNAS", ..., "GSD": "GSD", "gst": "GSD", ...
    ]
    for (original, replacement) in defaults {
        if dictionary[original] == nil {
            dictionary[original] = DictionaryMetadata(replacement: replacement, createdAt: Date())
        }
    }
    save()
}

// Shared/Models/CleanupPrompt.swift:60-105 (current V15 prompt body — Task 2 modifies)
struct CleanupPrompt {
    static let customInstructionKey = "cleanupInstruction"
    static let defaultInstruction: String   // <-- update string ref from "V15" to "V16"
    static func build(
        text: String,
        language: String? = nil,
        dictionaryContext: [String: String]? = nil,
        useSwissGerman: Bool? = nil
    ) -> String
}

// .planning/debug/harness/run.py V16_VARIANTS registry — Task 3 adds V17
// Each variant pairs a prompt template with a context-builder function.
```
</interfaces>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Dictionary expansion in Shared/Services/DictionaryService.swift (Lever 1, highest-ROI single change)</name>
  <read_first>
    - .planning/debug/harness/results/v16_matrix.md §2.9 "H9 verdict" + §5 "Lever 1" — the source of truth for the exact entries
    - .planning/debug/harness/results/v16_matrix.md §1b — H8 vs H9 aggregate scoreboard (brand 35→2, anchor 28→0)
    - Shared/Services/DictionaryService.swift lines 85-107 (current `defaults` dict — Task 1's insertion point)
    - .planning/debug/harness/run.py lines 55-84 (DEFAULT_DICT — confirm phonetic variants match)
    - .planning/phases/25-ai-cleanup-quality-v3-brand-acronym-recognition/25-CONTEXT.md `<specifics>` (every failure these entries close)
    - feedback_tests_as_regression_nets memory rule (tests lock real failures, not assertions-on-the-implementation)
    - feedback_cleanup_cross_platform_parity memory rule (macOS + iOS together)
  </read_first>
  <behavior>
    - `DictionaryService.shared.dictionary` contains, after `prepopulateWithDefaults()` runs on a fresh install: `Chemini → Gemini`, `Cheminai → Gemini`, `chemini → Gemini`, `cheminai → Gemini`, `MPM → NPM`, `engine eggs → NGINX`, `Doghand → Dokku`, `Dog Hand → Dokku`, `doghand → Dokku`, `dog hand → Dokku`, `DogChee → Dockge`, `Dog Chee → Dockge`, `dogchee → Dockge`, `dog chee → Dockge`, `C Oli → CLI`, `c oli → CLI`, `true Nas → TrueNAS`.
    - The existing 50+ defaults are preserved unchanged. The new entries are appended to the `defaults` literal; the existing `if dictionary[original] == nil { ... }` guard preserves any prior user overrides on upgrade.
    - The targeted-substring matcher at `Shared/Services/TextProcessingService.swift:159-165` now fires on these new keys whenever a dictation contains them — closing the brand/anchor failure cases listed in CONTEXT.md `<specifics>` "Isolated brand mishearings".
    - `DictionaryServiceTests` (macOS + iOS, new files) lock each new entry as a regression net. Every test cites the V15 capture-window timestamp from CONTEXT.md `<specifics>` that the entry derives from.
  </behavior>
  <action>
**Step A — extend the `defaults` literal at `Shared/Services/DictionaryService.swift:85-107`.**

Append a new Phase-25 block immediately after the existing `"GSD": "GSD", ..., "gsd": "GSD"` line, before the closing `]`. Add an inline `// 2026-05-... — Phase 25 (v16_matrix.md §5 Lever 1)` tag for provenance.

The exact entries (verbatim from `v16_matrix.md` §5 Lever 1 — these are the H9 dict that achieved brand 35→2 and anchor 28→0 in the harness):

```swift
// 2026-05-... — Phase 25 (v16_matrix.md §5 Lever 1, H9 dict; brand 35→2, anchor 28→0)
"Chemini": "Gemini", "Cheminai": "Gemini", "chemini": "Gemini", "cheminai": "Gemini",
"MPM": "NPM",
"engine eggs": "NGINX",
"Doghand": "Dokku", "Dog Hand": "Dokku", "doghand": "Dokku", "dog hand": "Dokku",
"DogChee": "Dockge", "Dog Chee": "Dockge", "dogchee": "Dockge", "dog chee": "Dockge",
"C Oli": "CLI", "c oli": "CLI",
"true Nas": "TrueNAS",
```

Note `true Nas` is already in the existing defaults via `"true NAS": "TrueNAS"`/`"true nest": "TrueNAS"` casing variants — verify before adding to avoid a duplicate literal-key compile error. If it collides, drop the `"true Nas"` line; the existing keys already cover it.

**Step B — create `macOS/DicticusTests/DictionaryServiceTests.swift`** (new file). Header comment block:

```swift
// MARK: - Phase 25 regression net (added 2026-05-...)
//
// Each test below locks a real V15-era brand/anchor mishearing from
// .planning/phases/25-ai-cleanup-quality-v3-brand-acronym-recognition/25-CONTEXT.md <specifics>.
// Format: <test name> — <CONTEXT.md timestamp> — <what it locks>
//
// Evidence: .planning/debug/harness/results/v16_matrix.md §2.9 (H9 dict
// achieved brand 35→2, anchor 28→0 in the harness at seed=42).
```

Add fixtures (one per failure timestamp from CONTEXT.md `<specifics>` "Isolated brand mishearings"):

- `testPhase25_CheminiHeadless_2026_05_15T1502` — asserts `DictionaryService.shared.dictionary["Chemini"]?.replacement == "Gemini"` (locks the 2026-05-15 15:02 failure)
- `testPhase25_CheminiHeadless_2026_05_15T1506` — same, locking 15:06 failure
- `testPhase25_CheminaiCOli_2026_05_16T0417` — asserts both `Cheminai → Gemini` AND `C Oli → CLI` (the 04:17 cascade failure)
- `testPhase25_MPMSupply_2026_05_15T0503` — asserts `MPM → NPM` (the 05:03 failure)
- `testPhase25_EngineEggs_2026_05_15T0504` — asserts `engine eggs → NGINX` (the 05:04 failure)
- `testPhase25_Doghand_2026_05_15T1659` — asserts `Doghand → Dokku` (the 16:59 failure)
- `testPhase25_DogChee_2026_05_15T1659` — asserts `DogChee → Dockge` (the same minute, different fixture)
- `testPhase25_LowercaseVariants` — asserts all four `chemini`/`cheminai`/`doghand`/`dog chee` lowercased keys also exist (so the substring matcher fires regardless of ASR case output)

Each test's doc-comment cites the CONTEXT.md timestamp. Pattern:
```swift
/// Locks 2026-05-15 15:02 V15 failure: "Chemini headless" → "Chemini headless" (kept).
/// After Phase 25: targeted-substring matcher injects `Chemini -> Gemini` into the
/// Known terms block, and Gemma resolves the mishearing. See CONTEXT.md <specifics>
/// "Isolated brand mishearings — NOT fixed by V15".
func testPhase25_CheminiHeadless_2026_05_15T1502() { ... }
```

**Step C — create `iOS/DicticusTests/DictionaryServiceTests.swift`** (new file). Mirror the macOS file byte-for-byte where possible. Same test names, same fixture strings, same docstrings. Per `feedback_cleanup_cross_platform_parity`. The iOS `DictionaryService` is shared from `Shared/Services/DictionaryService.swift` so the assertions are 1:1 identical.

**Step D — verify the existing targeted-substring matcher fires correctly.**

The matcher at `Shared/Services/TextProcessingService.swift:159-165` is **not modified by this task** (or by this plan). After Step A, dictation containing "Chemini" (or any new key) will see `Chemini -> Gemini` injected into `filteredContext` by the existing matcher — no code change needed. Confirm via a manual `xcrun swift test` run that the existing `TextProcessingServiceTests` still pass (no regression on the matcher behavior).

**Anti-pattern to avoid:** Do NOT add tests that just assert "the dict literal contains the string X" by reading the source file. Tests must call `DictionaryService.shared.dictionary[...]?.replacement` against the loaded dictionary — that exercises the prepopulation + persistence path, which is the contract that matters at runtime.
  </action>
  <verify>
    <automated>
      cd /Users/mowehr/code/dicticus && cd macOS && xcodebuild -project Dicticus.xcodeproj -scheme Dicticus -destination 'platform=macOS' -configuration Debug test -only-testing:DicticusTests/DictionaryServiceTests 2>&1 | tail -30 | tee /tmp/p25-03-task1-test-out.txt && \
      grep -E '(Test Suite.*passed|Test Suite.*failed)' /tmp/p25-03-task1-test-out.txt && \
      ! grep -q 'Test Suite.*failed' /tmp/p25-03-task1-test-out.txt && \
      grep -q '"Chemini": "Gemini"' Shared/Services/DictionaryService.swift && \
      grep -q '"engine eggs": "NGINX"' Shared/Services/DictionaryService.swift && \
      grep -q '"Doghand": "Dokku"' Shared/Services/DictionaryService.swift && \
      grep -q '"DogChee": "Dockge"' Shared/Services/DictionaryService.swift && \
      grep -q '"C Oli": "CLI"' Shared/Services/DictionaryService.swift
    </automated>
  </verify>
  <done>
    Shared/Services/DictionaryService.swift `prepopulateWithDefaults` contains the ~16 new Phase 25 entries with a Phase-25 provenance comment. New macOS + iOS DictionaryServiceTests files exist with one test per CONTEXT.md `<specifics>` failure timestamp. macOS DictionaryServiceTests suite green. iOS test file compiles clean.
  </done>
  <acceptance_criteria>
    - All ~16 new dict entries land verbatim from v16_matrix.md §5 Lever 1.
    - Existing 50+ defaults untouched.
    - Tests assert against `DictionaryService.shared.dictionary[...]?.replacement`, not against source-file string contents.
    - Every test method's doc-comment cites a CONTEXT.md `<specifics>` timestamp.
    - macOS + iOS test files exist with identical test method names (parity).
    - No change to `Shared/Services/TextProcessingService.swift` in this task.
  </acceptance_criteria>
</task>

<task type="auto" tdd="true">
  <name>Task 2: V16-COMPOSITE prompt in Shared/Models/CleanupPrompt.swift (H3 + H4, skip H1, conditional H5)</name>
  <read_first>
    - .planning/debug/harness/results/v16_matrix.md §5 (revised recommendation — H3 + H4, skip H1, conditional H5)
    - .planning/debug/harness/results/v16_matrix.md §2.3 (H3 verdict — phase/face homophone fix)
    - .planning/debug/harness/results/v16_matrix.md §2.4 (H4 verdict — number-integrity rule)
    - .planning/debug/harness/results/v16_matrix.md §2.5 (H5 verdict — acronym + enumeration anti-regression)
    - .planning/debug/harness/results/v16_matrix.md §3 (regression check — V16F catastrophe class)
    - .planning/debug/harness/results/v16_matrix.tsv (per-fixture deltas — needed for the historical doc-comment block)
    - .planning/debug/harness/prompts/v16c_*.txt + v16d_*.txt + v16e_*.txt (the actual prompt text for each lever)
    - Shared/Models/CleanupPrompt.swift lines 1-50 (V5/V15 historical comment block pattern this V16 block must match)
    - Shared/Models/CleanupPrompt.swift lines 60-115 (current V15 prompt body to be modified)
  </read_first>
  <behavior>
    - `CleanupPrompt.build(text:..., dictionaryContext: nil, ...)` produces a prompt whose body matches the V16-COMPOSITE structure: H3's "Domain topic words: phase, plan, workflow, framework, dictation, cleanup, prompt." hint line + H3's `discuss this face first → Discuss this phase first.` few-shot, plus H4's number-integrity rule (e.g. "Rule 8: Spelled-out two-digit numbers MUST render as numerals.") + H4's `meeting at forty one Penn` and `two to three minutes` few-shots.
    - **H1 (always-on canonical Known terms) is NOT adopted.** Task 1's dictionary expansion makes H1 redundant per §5; H1 also caused the `Dokploy → Docker` brand-specificity regression in the matrix (§2.1).
    - **H5 (acronym-collapse + enumeration anti-regression) is CONDITIONAL.** If Task 3's V17 verification shows the H3+H4 composite alone regresses `acro_enum` (V15 lev 42 case), add H5's rule + few-shots. If V17 keeps `acro_enum` at lev 0 without H5, omit it. The §4 dictionary-attribution audit shows acro_enum was V15's self-inflicted wound; plain mode at H8/H9 lev 0 has the answer.
    - `CleanupPrompt.build(text:..., dictionaryContext: [...], ...)` injects the Known terms block in the same shape V15 used (lines 75-85). No change to the Known terms block format — Task 1's dictionary expansion does its work through the existing substring matcher.
    - `CleanupPrompt.defaultInstruction` updated to reference V16.
    - V15-era win fixtures (Phase 24 fixtures + V15 win cases from CONTEXT.md `<specifics>` "Brand recognition WINS") STILL produce the same Phase 24 expected outputs — no regression on the existing 10/10 CleanupPromptTests.
  </behavior>
  <action>
**Step A — modify the prompt body at `CleanupPrompt.swift:60-115`.**

1. **Add H4's number-integrity rule** as a new Rule 8 immediately after the existing Rule 7 (`NEVER answer dictated questions.`):

```swift
prompt += "8. Render spelled-out two-digit numbers as numerals (e.g. 'forty one' → '41', 'twenty three' → '23'). Range words like 'two to three' stay as '2 to 3'.\n\n"
```

2. **Add H3's domain topic hint line** immediately before the language banner (Step 3 + 4 block):

```swift
prompt += "Domain topic words: phase, plan, workflow, framework, dictation, cleanup, prompt.\n\n"
```

3. **Add H4's few-shots** to BOTH language branches (en + de) of the few-shot block. English:

```swift
prompt += "In: meeting at forty one Penn\n"
prompt += "Out: Meeting at 41 Penn.\n\n"

prompt += "In: two to three minutes\n"
prompt += "Out: 2 to 3 minutes.\n\n"
```

German equivalents (translate while preserving the digit-integrity contract — confirm against v16d prompt source):

```swift
prompt += "In: meeting um einundvierzig Penn\n"
prompt += "Out: Meeting um 41 Penn.\n\n"
```

(If V16D's harness prompt has a single multilingual few-shot rather than per-language pairs, mirror its structure verbatim.)

4. **Add H3's phase/face few-shot** to the English branch:

```swift
prompt += "In: discuss this face first\n"
prompt += "Out: Discuss this phase first.\n\n"
```

5. **Conditional on Task 3 V17 outcome — H5 acronym rule + enumeration few-shots.** If V17 shows acro_enum regression (lev > 0), add as Rule 9 and few-shots:

```swift
prompt += "9. Collapse letter-spaced acronyms: 'G S D' → 'GSD', 'H D D' → 'HDD', 'T V' → 'TV'. Preserve enumerations: 'options A, B, C, or D' stays 'options A, B, C, or D'.\n\n"
// ... + the two enumeration anti-regression few-shots from v16e prompt
```

If V17 lev = 0 on acro_enum without H5, OMIT H5. The decision branches inside Task 3's verify step.

**Step B — historical doc-comment block at the top of `CleanupPrompt.swift`.**

Add a new `/// 2026-05-... REFACTOR (V16-COMPOSITE): H3 + H4 [+ H5 conditional].` block matching the existing V5 block pattern. Cite the matrix evidence:

```
/// Harness evidence (.planning/debug/harness/results/v16_matrix.md §5 + addendum §1b–§4,
///   .planning/debug/harness/results/v16_matrix.tsv, 2026-05-16 with the production
///   Gemma 4 E2B Q4_K_M GGUF, seed=42):
///     P25-num-01-fortyone:        V15 lev=9 → V16 lev=0  (H4 rule)
///     P25-num-04-...:             V15 lev=11 → V16 lev=0 (H4 rule)
///     P25-phase-face-01:          V15 lev=3 → V16 lev=0  (H3 few-shot)
///     P25-phase-face-02:          V15 lev=4 → V16 lev=1  (H3 few-shot)
///     Brand class (13 fixtures):  V15 lev=2 → V16 lev=2  (preserved; brand wins
///                                                          come from Task 1
///                                                          dictionary expansion,
///                                                          not the prompt)
///     P25-regress-06-feeding-fitting: V15 lev=0 → V16 lev=0 (V17 verification
///                                                            confirmed no
///                                                            regression — §6
///                                                            of v16_matrix.md)
///
/// V16 deliberately does NOT adopt H1 (always-on canonical Known terms): per §5,
/// Task 1's dictionary expansion absorbs the H1 lever, and H1 caused the
/// `Dokploy → Docker` brand-specificity regression in the matrix (§2.1).
///
/// H5 (acronym-collapse + enumeration anti-regression) is [adopted | omitted]
/// based on V17 verification: ... cite the actual decision and §6 evidence.
///
/// V15 wins preserved (CONTEXT.md <specifics> "Brand recognition WINS"):
///   GST→GSD, cloud code→Claude Code, true NAS→TrueNAS, opus four point seven→Opus 4.7,
///   feeding→fitting (suit context). Each locked by a regression-net test in
///   CleanupPromptTests + SelfCorrectionResolverTests.
```

Mirror the V5 block's "trades / structure" prose explaining what V16 buys, what it gives up, why the tradeoff is acceptable.

**Step C — `defaultInstruction` update.**

Change `defaultInstruction` from "Minimal cleanup of dictated speech (V15 smart-verbatim)." to "Minimal cleanup of dictated speech (V16 brand+number+phase composite)."

**Anti-pattern to avoid:** Do NOT add H1 (always-on canonical Known terms) — §5 explicitly recommends against it. Do NOT broaden the targeted-substring matcher in `TextProcessingService.swift` — §5 supersedes that with dictionary expansion (Task 1).

**Cross-platform parity:** `Shared/Models/CleanupPrompt.swift` is shared by both targets — single edit reaches iOS automatically.
  </action>
  <verify>
    <automated>
      cd /Users/mowehr/code/dicticus && cd macOS && xcodebuild -project Dicticus.xcodeproj -scheme Dicticus -destination 'platform=macOS' -configuration Debug build 2>&1 | tail -5 && \
      grep -q 'V16' /Users/mowehr/code/dicticus/Shared/Models/CleanupPrompt.swift && \
      grep -q 'v16_matrix' /Users/mowehr/code/dicticus/Shared/Models/CleanupPrompt.swift && \
      grep -q 'forty one' /Users/mowehr/code/dicticus/Shared/Models/CleanupPrompt.swift && \
      grep -q 'discuss this face first' /Users/mowehr/code/dicticus/Shared/Models/CleanupPrompt.swift && \
      grep -q 'Domain topic words' /Users/mowehr/code/dicticus/Shared/Models/CleanupPrompt.swift && \
      ! grep -q '"V15 smart-verbatim"' /Users/mowehr/code/dicticus/Shared/Models/CleanupPrompt.swift && \
      ! grep -q 'always-on canonical' /Users/mowehr/code/dicticus/Shared/Models/CleanupPrompt.swift
    </automated>
  </verify>
  <done>
    CleanupPrompt.swift contains V16-COMPOSITE prompt body: Rule 8 (number-integrity), Domain topic words hint, phase/face few-shot, two H4 few-shots. The historical doc-comment block at file top cites the matrix evidence with real fixture IDs and lev-distance deltas. `defaultInstruction` references V16. File compiles on macOS. H1 (always-on canonical) NOT present. H5 (acronym rule) adopted or omitted based on Task 3 V17 verification.
  </done>
  <acceptance_criteria>
    - `defaultInstruction` no longer references "V15".
    - Doc-comment block matches the V5 block's prose pattern (purpose, evidence, tradeoffs, structure).
    - Explicit list of V15 wins that V16 must preserve, cited from `<specifics>` "Brand recognition WINS".
    - Builder API signature unchanged — `CleanupPrompt.build(text:language:dictionaryContext:useSwissGerman:)` accepts the same params.
    - Doc-comment block explicitly states why H1 is omitted (cites §5 + the §2.1 brand regression).
    - Doc-comment block states the H5 decision and cites V17 §6 evidence for it.
  </acceptance_criteria>
</task>

<task type="auto">
  <name>Task 3: V17 harness verification — confirm V16-COMPOSITE before committing Swift</name>
  <read_first>
    - .planning/debug/harness/run.py (V16_VARIANTS registry, V16_CONTEXT_FN — how V16A-F are registered)
    - .planning/debug/harness/run_v16_matrix.py (the runner that produced v16_matrix.tsv)
    - .planning/debug/harness/prompts/v16c_*.txt + v16d_*.txt + v16e_*.txt (the lever sources to compose V17 from)
    - .planning/debug/harness/fixtures/phase25_brands.tsv (the 37-row fixture set)
    - .planning/debug/harness/results/v16_matrix.md §5 + §1b (verification gates)
    - .planning/debug/harness/results/v16_matrix.tsv (column schema for appending V17 rows)
  </read_first>
  <behavior>
    - A new V17 variant is registered in the harness's V16_VARIANTS registry, composing H3 (V16C) + H4 (V16D) only (skip H1 always-on canonical Known terms; H5 added in a second pass if V17 acro_enum > 0). The prompt template lives at `.planning/debug/harness/prompts/v17_composite.txt`.
    - The harness runs V17 against `fixtures/phase25_brands.tsv` at seed=42 with the same sampler + stop sequences as the V16A-F runs (TEMP=0.1, TOP_K=40, TOP_P=0.9, n_predict=512).
    - V17 results are appended to `.planning/debug/harness/results/v16_matrix.tsv` as 37 new rows (one per fixture) with `variant=V17`.
    - A new `## 6. V17 verification — V16-COMPOSITE harness gate` section is appended to `.planning/debug/harness/results/v16_matrix.md` reporting V17 aggregate, per-category breakdown, regression check, and pass/fail verdict on the four gates below.
    - If any gate fails, Task 2 commit is BLOCKED (no Swift code is committed). The V17 prompt is iterated and re-verified until all four gates pass, OR the failure is escalated to the human checkpoint in Task 5.
  </behavior>
  <action>
**Step A — author `.planning/debug/harness/prompts/v17_composite.txt`.**

Compose by stacking V16C's domain-topic-line + phase/face few-shot ON TOP OF V16D's number-integrity rule + few-shots. Use V16C's text as the base, splice V16D's Rule 8 + few-shots in at the same position they appear in v16d. **Do NOT include V16A's always-on canonical Known terms layer.** **Do NOT include V16E's acronym rule** in this first V17 pass — that decision branches based on V17 acro_enum results.

**Step B — register V17 in the harness.**

Open `.planning/debug/harness/run.py` (or `run_v16_matrix.py` if the variant registry lives there). Add:
- V17 → `prompts/v17_composite.txt`
- V17 context-fn → same as V16C/V16D (whatever `V16_CONTEXT_FN["V16C"]` is — verify; likely the default targeted-substring builder, NOT `build_always_on_context`).

**Step C — run V17 against `phase25_brands.tsv`.**

Invocation (mirror how V16A-F were invoked — see `run_v16_matrix.py` provenance in §6 of v16_matrix.md):

```bash
cd /Users/mowehr/code/dicticus/.planning/debug/harness
python3 run_v16_matrix.py --variant V17 --seed 42 --fixture-file fixtures/phase25_brands.tsv --append-tsv results/v16_matrix.tsv
```

**Step D — append the §6 verification block to `v16_matrix.md`.**

```markdown
## 6. V17 verification — V16-COMPOSITE harness gate

**Date:** 2026-05-...
**Variant:** V17 = H3 (V16C domain topic + phase/face few-shot) + H4 (V16D number-integrity rule + few-shots). H1 explicitly excluded. H5 omitted in first pass; revisited if acro_enum > 0.
**Runner:** `run_v16_matrix.py --variant V17 --seed 42`
**TSV append:** results/v16_matrix.tsv rows where variant=V17

### Aggregate scoreboard — V17 vs V16E (the prior best) and V15 baseline

| Category    | n  | V15  | V16E    | V17 |
| ----------- | -- | ---- | ------- | --- |
| **ALL**     | 37 | 90   | 50      | ?   |
| brand       | 13 | 2    | 2       | ?   |
| ...         | .. | ..   | ..      | ?   |

### Gate check

| Gate | Threshold | V17 actual | Pass? |
| ---- | --------- | ---------- | ----- |
| 1. Aggregate < V16E (50) | ALL < 50 | ? | ?  |
| 2. Brand class ≤ 2 (H9 parity) | brand ≤ 2 | ? | ? |
| 3. P25-regress-06-feeding-fitting stays at lev 0 (V16F catastrophe avoided) | regress-06 lev == 0 | ? | ? |
| 4. P25-brand-01-cheminiheadless does not recur V16D's regression (V15 lev 0) | brand-01 lev == 0 | ? | ? |

### Verdict

[PASS — proceed to Task 2 commit | FAIL — iterate V17 prompt; if H5 needed (acro_enum > 0), produce V17b with H5 and re-verify | ESCALATE to Task 5 human checkpoint if all iterations fail]
```

**Step E — decision tree.**

- If all 4 gates pass: V17 is the production prompt. Task 2 commits with H5 OMITTED. Doc-comment in Task 2 cites the §6 PASS verdict.
- If gates 1, 3, 4 pass but acro_enum > 0: produce V17b = V17 + H5. Re-run. If V17b passes all gates, Task 2 commits with H5 ADOPTED. Doc-comment cites the §6 V17b verdict.
- If any gate other than acro_enum fails: STOP. Do not commit Task 2's Swift changes. Surface the failure at Task 5 human checkpoint with the V17 TSV rows + §6 verdict.

**Anti-pattern to avoid:** Do NOT modify the V16A-F TSV rows. V17 is APPENDED, not overwriting. Do NOT change sampler params or stop sequences — they must match v16_matrix.md §6 provenance exactly (seed=42, temp=0.1, top_k=40, top_p=0.9, n_predict=512, stop sequences as listed).
  </action>
  <verify>
    <automated>
      cd /Users/mowehr/code/dicticus && \
      test -f .planning/debug/harness/prompts/v17_composite.txt && \
      grep -q 'V17' .planning/debug/harness/results/v16_matrix.tsv && \
      grep -c -E '^V17' .planning/debug/harness/results/v16_matrix.tsv | awk '$1 == 37 {print "37 V17 rows OK"; exit 0} {print "FAIL: expected 37 V17 rows, got " $1; exit 1}' && \
      grep -q '## 6. V17 verification' .planning/debug/harness/results/v16_matrix.md && \
      grep -E 'Verdict:.*(PASS|FAIL|ESCALATE)' .planning/debug/harness/results/v16_matrix.md
    </automated>
  </verify>
  <done>
    `.planning/debug/harness/prompts/v17_composite.txt` exists. V17 rows (37, one per phase25_brands.tsv fixture) appended to `.planning/debug/harness/results/v16_matrix.tsv`. A new `## 6. V17 verification` block exists in `v16_matrix.md` with the four-gate scoreboard, the verdict, and the H5 decision. If verdict is PASS, Task 2 is unblocked. If FAIL, the file documents the failure and Task 2 is blocked pending human review.
  </done>
  <acceptance_criteria>
    - V17 prompt template exists at `.planning/debug/harness/prompts/v17_composite.txt`.
    - 37 new TSV rows with variant=V17.
    - §6 block in v16_matrix.md cites aggregate, brand, regress-06, and brand-01 numbers with PASS/FAIL per gate.
    - The H5 decision (adopt or omit) is recorded in §6 with its evidence.
    - Same sampler + stop-sequence reproducibility as v16_matrix.md §6 provenance.
    - No modification to V15 / V16A-F / H8 / H9 rows.
  </acceptance_criteria>
</task>

<task type="auto" tdd="true">
  <name>Task 4: Regression-net tests in CleanupPromptTests + SelfCorrectionResolverTests (macOS + iOS)</name>
  <read_first>
    - macOS/DicticusTests/CleanupPromptTests.swift (all 10 existing tests — pattern, naming, fixture organization)
    - macOS/DicticusTests/SelfCorrectionResolverTests.swift (all 27 existing tests)
    - iOS/DicticusTests/CleanupPromptTests.swift + iOS/DicticusTests/SelfCorrectionResolverTests.swift (iOS parity scaffolds)
    - .planning/phases/25-ai-cleanup-quality-v3-brand-acronym-recognition/25-CONTEXT.md `<specifics>` (every fixture must cite a timestamp from here)
    - .planning/debug/harness/results/v16_matrix.md §6 (Task 3 verdict + H5 decision — determines whether H5 tests are added)
    - feedback_tests_as_regression_nets memory rule (tests lock real failures, not assertions-on-the-implementation)
  </read_first>
  <behavior>
    - **CleanupPromptTests (macOS + iOS):** New `testPhase25_*` cases each assert a specific `CleanupPrompt.build(...)` output shape that the V16-COMPOSITE prompt requires. These are PROMPT-LEVEL tests — they verify the prompt CONTAINS the right rule lines and the right few-shots.
    - **SelfCorrectionResolverTests (macOS + iOS):** No new tests required unless V16-COMPOSITE rolled changes into the resolver. If purely a prompt-layer change, this file is touched only to confirm existing 27/27 still pass.
    - Per `feedback_tests_as_regression_nets`: tests assert OBSERVABLE properties of the prompt contract, NOT tautologies. Example: "the built prompt contains the phase/face few-shot In/Out pair" tests the behavioral contract for downstream Gemma cleanup; it's not just re-stating the string literal.
    - **Cross-platform:** Every new macOS test gets a parity iOS test with the same name + fixture string + docstring.
  </behavior>
  <action>
**For CleanupPromptTests.swift (macOS + iOS):**

Add the following test methods, each prefixed `testPhase25_`. Decision branches based on Task 3 §6 verdict:

- `testPhase25_V16PromptContainsNumberIntegrityRule` — asserts the built prompt contains "Spelled-out two-digit numbers" or the exact Rule 8 wording from Task 2. Locks H4. Doc-comment cites 2026-05-14 14:40 "What is phase forty one about?" failure from CONTEXT.md `<specifics>`.
- `testPhase25_V16PromptContainsNumberIntegrityFewShot` — asserts the prompt contains "In: meeting at forty one Penn" + "Out: Meeting at 41 Penn." pair. Locks H4 few-shot.
- `testPhase25_V16PromptContainsDomainTopicHint` — asserts the prompt contains "Domain topic words: phase, plan, workflow, framework, dictation, cleanup, prompt." Locks H3 hint line.
- `testPhase25_V16PromptContainsPhaseFaceFewShot` — asserts the prompt contains "In: discuss this face first" + "Out: Discuss this phase first." pair. Locks H3 few-shot. Doc-comment cites 2026-05-14 04:21 "discuss this face first" failure from CONTEXT.md `<specifics>`.
- `testPhase25_V16PromptDoesNOTContainAlwaysOnCanonicalTerms` — asserts that calling `CleanupPrompt.build(text: "hello world", dictionaryContext: nil)` produces a prompt that does NOT contain "Claude" or "Gemini" or "TrueNAS" as a standalone Known terms entry. Locks the §5 decision to skip H1. (Task 1's dictionary expansion still injects these terms when the user dictation triggers a substring match, but the empty-dictionaryContext path must not inject them.)
- `testPhase25_V16DefaultInstructionUpdated` — asserts `CleanupPrompt.defaultInstruction.contains("V16")` and does NOT contain "V15".
- **CONDITIONAL — only if Task 3 §6 verdict adopted H5:** `testPhase25_V16PromptContainsAcronymCollapseRule` + `testPhase25_V16PromptContainsEnumerationAntiRegressionFewShot`. If H5 is omitted, ADD a negative test `testPhase25_V16PromptDoesNOTContainAcronymRule` asserting the rule is absent.

Each test's doc-comment cites the CONTEXT.md timestamp it locks. Pattern from Task 1.

**Per the regression-net memory rule:** Do NOT add a tautological test like `testPhase25_RuleEightSaysSpelledOut` that just asserts the literal Rule 8 wording matches itself. The tests above assert the prompt-shape CONTRACT (downstream Gemma must see this rule line OR this few-shot pair OR this hint) — that's a behavioral contract, not implementation-detail re-statement.

**For SelfCorrectionResolverTests.swift (macOS + iOS):**

Run the existing 27 tests as-is. If any fail under V16-COMPOSITE, the V17 verification missed something — escalate to Task 5 human checkpoint. No new tests added here unless V16 rolled changes into the resolver (it should not).

**Track each fixture's provenance** in a header MARK block in each test file:

```swift
// MARK: - Phase 25 V16-COMPOSITE regression net (added 2026-05-...)
//
// Each test below locks a real V15-era failure or V15-era win from
// .planning/phases/25-ai-cleanup-quality-v3-brand-acronym-recognition/25-CONTEXT.md <specifics>.
// Format: <test name> — <CONTEXT.md timestamp> — <what it locks>
//
// V17 verification: .planning/debug/harness/results/v16_matrix.md §6 (PASS/FAIL + H5 decision).
```

**Cross-platform parity:** Every macOS test method must exist with the same name in `iOS/DicticusTests/CleanupPromptTests.swift`. iOS runtime is desired but iOS compile-clean is the gating bar per Phase 22 precedent (iOS 26.4 SDK runtime may not be locally installed).
  </action>
  <verify>
    <automated>
      cd /Users/mowehr/code/dicticus && cd macOS && xcodebuild -project Dicticus.xcodeproj -scheme Dicticus -destination 'platform=macOS' -configuration Debug test -only-testing:DicticusTests/CleanupPromptTests -only-testing:DicticusTests/SelfCorrectionResolverTests -only-testing:DicticusTests/DictionaryServiceTests 2>&1 | tail -30 | tee /tmp/p25-03-task4-test-out.txt && \
      grep -E '(Test Suite.*passed|Test Suite.*failed)' /tmp/p25-03-task4-test-out.txt && \
      ! grep -q 'Test Suite.*failed' /tmp/p25-03-task4-test-out.txt && \
      grep -c 'testPhase25_' /Users/mowehr/code/dicticus/macOS/DicticusTests/CleanupPromptTests.swift && \
      diff <(grep -oE 'func testPhase25_[A-Za-z0-9_]+' /Users/mowehr/code/dicticus/macOS/DicticusTests/CleanupPromptTests.swift | sort) <(grep -oE 'func testPhase25_[A-Za-z0-9_]+' /Users/mowehr/code/dicticus/iOS/DicticusTests/CleanupPromptTests.swift | sort)
    </automated>
  </verify>
  <done>
    All macOS test suites green (Phase 24's 27/27 + 10/10 baseline + new Phase 25 fixtures across DictionaryServiceTests + CleanupPromptTests). iOS test files mirror the macOS additions and compile clean. Every new test cites a CONTEXT.md `<specifics>` timestamp. The H1-skip decision and H5 decision are both locked by tests.
  </done>
  <acceptance_criteria>
    - Every new test method has a doc-comment citing the CONTEXT.md timestamp(s) it locks.
    - No new test is a tautological assertion against the implementation (per `feedback_tests_as_regression_nets`).
    - macOS test suite — full Phase 24 regression set + new Phase 25 set — green.
    - iOS test files updated in parity, identical test method names.
    - `testPhase25_V16PromptDoesNOTContainAlwaysOnCanonicalTerms` exists on both platforms (locks H1-skip).
    - The H5 decision (adopt or omit) is locked by either a positive or a negative test on both platforms.
  </acceptance_criteria>
</task>

<task type="checkpoint:human-verify" gate="blocking">
  <name>Task 5: Human UAT checkpoint — V16-COMPOSITE + dictionary expansion + plain-mode logging pre-ship review</name>
  <what-built>
    - Shared/Services/DictionaryService.swift: ~16 new Phase 25 dictionary entries from v16_matrix.md §5 Lever 1.
    - Shared/Models/CleanupPrompt.swift: V16-COMPOSITE prompt body (H3 + H4, optionally H5 per V17 verdict). H1 explicitly skipped.
    - .planning/debug/harness/results/v16_matrix.{tsv,md}: V17 verification block + 37 new TSV rows.
    - 6 test files updated/added on macOS + iOS (2 new DictionaryServiceTests + 2 updated CleanupPromptTests + 2 SelfCorrectionResolverTests unchanged), all Phase 24 + Phase 25 regression-net tests green on macOS.
    - No app behavior in plain mode changed by Task 2 (the prompt path is AI-cleanup only). Plain-mode JSONL logging from plan 25-02 should be live in parallel for this UAT — verify both are observable.
  </what-built>
  <how-to-verify>
    1. Read `.planning/debug/harness/results/v16_matrix.md` §5 (recommendation) and §6 (V17 verification) — confirm the V17 verdict is PASS and that what landed in Swift matches.
    2. Read the new doc-comment block at the top of `Shared/Models/CleanupPrompt.swift` — confirm the V16 evidence prose cites real harness fixture IDs and lev-distance deltas, and explicitly states why H1 was omitted and what the H5 decision was.
    3. Run `xcodebuild ... test -only-testing:DicticusTests/CleanupPromptTests -only-testing:DicticusTests/SelfCorrectionResolverTests -only-testing:DicticusTests/DictionaryServiceTests` on macOS — confirm all green.
    4. Spot-check 5 of the new test fixtures — read each test's doc-comment, click through to the CONTEXT.md timestamp it cites, confirm the fixture locks a real failure (not a re-statement of the prompt or dict literal).
    5. Install the Debug-Recorder build via `scripts/install-local.sh`. Verify V16 prompt + dictionary expansion + (plan 25-02) plain-mode logging are all live in the running app.
    6. Smoke-test the failure cases from CONTEXT.md `<specifics>` manually:
       - Dictate "Chemini headless about this" → expect "Gemini headless about this." (Task 1 dictionary fires).
       - Dictate "What is phase forty one about?" → expect "What is phase 41 about?" (Task 2 H4 rule fires).
       - Dictate "discuss this face first" → expect "Discuss this phase first." (Task 2 H3 few-shot fires).
       - Dictate "MPM supply chain attack" → expect "NPM supply chain attack." (Task 1 dictionary fires).
       - Dictate "engine eggs config" → expect "NGINX config." (Task 1 dictionary fires).
    7. Confirm `git diff Shared/` shows ONLY the two intended files (`DictionaryService.swift` + `CleanupPrompt.swift`) — `TextProcessingService.swift` MUST be unchanged in this plan.
    8. Confirm `git diff .planning/debug/harness/` shows V17 prompt + TSV append + §6 markdown block, nothing else.
  </how-to-verify>
  <resume-signal>Type "UAT pass" to authorize plan 25-04 capture-window v2 to start. If issues found, describe them (e.g., "V16 doc-comment cites the wrong fixture IDs", "smoke test X failed: got Y, expected Z", "iOS test parity check failed").</resume-signal>
</task>

</tasks>

<verification>
- `git diff --stat Shared/` — only `Services/DictionaryService.swift` and `Models/CleanupPrompt.swift` modified. `Shared/Services/TextProcessingService.swift` MUST be untouched.
- `git diff --stat .planning/debug/harness/` — V17 prompt + TSV append + §6 markdown block.
- `git diff --stat macOS/DicticusTests/ iOS/DicticusTests/` — DictionaryServiceTests (new on both) + CleanupPromptTests (updated on both) touched, no incidental edits.
- macOS full test suite green: 10/10 CleanupPromptTests + new Phase 25 fixtures + 27/27 SelfCorrectionResolverTests + new DictionaryServiceTests.
- iOS test target compiles under both Debug and Debug-Recorder configurations (runtime green nice-to-have).
- Cross-platform parity: every macOS test addition has an iOS counterpart with the same test name.
- V17 verification: `.planning/debug/harness/results/v16_matrix.md` §6 verdict is PASS.
</verification>

<success_criteria>
- Dictionary expansion (Lever 1) is in production (Shared/Services/DictionaryService.swift).
- V16-COMPOSITE prompt (Lever 2) is in production (Shared/Models/CleanupPrompt.swift).
- TextProcessingService.swift targeted-substring matcher is UNCHANGED (per §5 supersession).
- V17 harness verification shows aggregate < 50, brand ≤ 2, regress-06 lev 0, brand-01 lev 0.
- Phase 24 regression invariants hold (27 SelfCorrectionResolverTests + 10 CleanupPromptTests).
- New Phase 25 regression-net fixtures lock V15 wins, the new dict entries, and the V16 prompt-shape contract — each citing a real CONTEXT.md timestamp.
- Phase 25 goal targets from CONTEXT.md (locked): "Reduce isolated-brand mishearing failure rate (target: ≤ 30% of V15 baseline failure rate on the captured brand corpus), eliminate the `forty one → 4001` digit-concatenation class entirely, collapse acronym-letter-spacing without regressing list-of-letters enumeration, fix the `phase ↔ face` homophone class." — verified via the V17 harness scoreboard AND the Task 5 manual smoke tests.
- macOS + iOS ship together.
- Human UAT checkpoint passed.
- Plan 25-04 capture-window v2 is unblocked.
</success_criteria>

<output>
After completion, create `.planning/phases/25-ai-cleanup-quality-v3-brand-acronym-recognition/25-03-SUMMARY.md` capturing:
- Which dictionary entries shipped (cite v16_matrix.md §5 Lever 1) and the H8→H9 brand/anchor delta they close.
- Which V16-COMPOSITE prompt levers shipped (H3, H4, and the H5 decision with its V17 §6 evidence). Explicit note that H1 was skipped per §5 and that TextProcessingService.swift was deliberately untouched.
- V17 verification scoreboard summary (aggregate, brand, regress-06, brand-01) from §6.
- Diff summary of `Shared/Services/DictionaryService.swift` and `Shared/Models/CleanupPrompt.swift` (line ranges).
- Harness-additions table (V17 prompt path, V17 TSV row count, §6 markdown lines).
- Test additions table (test name → CONTEXT.md timestamp → what it locks → platform parity proof).
- macOS test counts (e.g., 10/10 + 27/27 + N new = all green).
- Human UAT verdict + smoke-test results for each of the 5 dictation cases.
- Explicit handoff to plan 25-04: "Capture-window v2 can begin. With plan 25-02's plain-mode logging live and plan 25-03's dictionary expansion + V16-COMPOSITE prompt live, capture window v2 will produce both plain and aiCleanup JSONL records suitable for the V15→V16 A/B diff methodology, AND the brand-class failure rate should already be measurably lower from day 1."
</output>
