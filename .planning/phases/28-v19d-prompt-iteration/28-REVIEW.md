---
phase: 28-v19d-prompt-iteration
reviewed: 2026-05-27T14:55:00Z
depth: standard
files_reviewed: 14
files_reviewed_list:
  - Shared/Diagnostics/DebugRecorder.swift
  - Shared/Models/CleanupPrompt.swift
  - Shared/Services/CleanupService.swift
  - Shared/Services/TextProcessingService.swift
  - Shared/Utilities/ITNUtility.swift
  - iOS/DicticusTests/CleanupPromptTests.swift
  - iOS/DicticusTests/CleanupServiceTests.swift
  - iOS/DicticusTests/DicticusTests.swift
  - iOS/DicticusTests/ITNUtilityTests.swift
  - macOS/DicticusTests/CleanupPromptTests.swift
  - macOS/DicticusTests/CleanupServiceTests.swift
  - macOS/DicticusTests/DicticusTests.swift
  - macOS/DicticusTests/ITNUtilityTests.swift
  - macOS/Dicticus.xcodeproj/project.pbxproj
findings:
  critical: 1
  warning: 4
  info: 3
  total: 8
  resolved: 4
  deferred: 4
status: partially_fixed
---

## Fixes Applied (2026-05-27)

| Finding | Commit | Status |
|---|---|---|
| CR-01 (ITN Pattern A mangles prose bigrams) | `c443283` | fixed — regex tightened + 5 regression tests |
| WR-01 (DE Regel 8 prefix mismatch) | `ef3d30e` | fixed — `8.` → `- ` bullet to match siblings |
| WR-02 (prompt_version hardcoded default) | `2b24f8c` | fixed — `CleanupPrompt.currentVersion` threaded |
| WR-03 (Rule 8 locks in ITN false positives) | — | deferred — design choice per plan W-01 dual-defense; CR-01 fix eliminates the practical risk surface |
| WR-04 (`levenshteinGateThreshold` doc drift) | `cabb005` | fixed — doc updated to 0.45 |
| IN-01, IN-02, IN-03 | — | deferred — informational; defer to backlog |

xcodebuild test GREEN for `ITNUtilityTests` + `ITNUtilitySingleDigitTests` (38 tests) and `CleanupPromptTests` (36 tests).


# Phase 28: Code Review Report

**Reviewed:** 2026-05-27T14:55:00Z
**Depth:** standard
**Files Reviewed:** 14
**Status:** partially_fixed (CR-01 + WR-01/02/04 fixed; WR-03 deferred as design; IN-* deferred)

## Summary

Phase 28 (v19d-prompt-iteration) adds K2/K4/K5 prompt few-shots, a `prompt_version`
field with backward-compatible decode, and a new deterministic ITN pass that promotes
single-digit number-words to digits when they sit next to "identifier-like" tokens.

The Codable backward-compat path (`decodeIfPresent ?? "v19c"`) is implemented
cleanly and well-tested. Cross-platform parity is intact — all four test files are
byte-identical between `macOS/DicticusTests/` and `iOS/DicticusTests/` (verified via
`diff -q`). Test coverage of the prompt content additions and the Codable round-trips
is thorough.

However, the new ITN regex Pattern A in `applyEnglishSingleDigitIdentifier` contains
a classification bug that silently mangles extremely common English prose bigrams
(see CR-01). The bug runs deterministically **before** the LLM and is then explicitly
locked-in by the new Rule 8 ("Preserve digits already present"), so the LLM cannot
unwind it. There is no existing test that exercises 1- or 2-character Title-Case
prose prefixes — the only "negative" fixture (`testEnglishProsePrefix_Cat_one_preserved`)
exercises a 3-character stem, which the regex correctly excludes.

The German Regeln list mixes bullet ("- ") and numeric ("8.") prefixes in a single
block (WR-01). Other findings are smaller maintainability concerns around
`prompt_version` plumbing (WR-02), the EN Rule 8 instruction-vs-implementation gap
introduced by ITN running pre-LLM (WR-03), and a `static let levenshteinGateThreshold`
doc-comment that disagrees with its own initializer (WR-04, pre-existing but
re-surfaced by the file diff).

The Xcode `project.pbxproj` change is the expected auto-add of the new test files
and is consistent in shape with prior Xcode auto-edits.

## Critical Issues

### CR-01: ITN Pattern A silently mangles common English prose bigrams ("No one" → "No1")

**File:** `Shared/Utilities/ITNUtility.swift:407-412`
**Issue:**
The new R1-LOCKED stem regex
```
(?:[A-Z][a-z]?|[A-Z]{2,5}|[a-z][A-Z][a-zA-Z]{0,3})
```
documents itself (line 394) as: "Excludes 3+ char Title-Case prose words (Cat, One, The)."
But the first alternation `[A-Z][a-z]?` accepts **1- or 2-character** Title-Case
stems — exactly the class of stop-words that appear immediately before a digit-word
in normal English prose. This causes deterministic ASR mangling for every common
bigram of the form `<short Title-Case word> <one|two|...|nine>`:

| Input                              | Pipeline output (post-ITN)           |
|------------------------------------|---------------------------------------|
| `No one knows that.`               | `No1 knows that.`                     |
| `At one point`                     | `At1 point`                           |
| `In one hour`                      | `In1 hour`                            |
| `On one of the days`               | `On1 of the days`                     |
| `So one day`                       | `So1 day`                             |
| `Do one thing well`                | `Do1 thing well`                      |
| `Be one with the universe`         | `Be1 with the universe`               |
| `My one true love`                 | `My1 true love`                       |
| `He one shotted it`                | `He1 shotted it`                      |
| `Go five steps forward`            | `Go5 steps forward`                   |

Verified via a faithful Python port of the regex (`\b(stem)\s+(digit)\b`,
case-sensitive stem, case-insensitive digit). The 16 enumerated EN test fixtures
in `ITNUtilityTests.swift:122-195` never exercise a 1- or 2-char Title-Case prose
prefix — the only negative case (`Cat one`) uses a 3-char stem that the regex
correctly rejects, so the existing suite gives a false sense of safety.

This is **worse** than a "noisy output" bug: in AI-cleanup mode the new EN Rule 8
explicitly instructs the LLM to "Preserve digits and number-formats already present
in the input — do not re-spell them as words" (`CleanupPrompt.swift:122`), so the
LLM is told NOT to unwind the ITN's mistake. The mangled output reaches the user's
cursor verbatim.

The DE variant (`applyGermanSingleDigitIdentifier`, line 443) inherits the same
shape via `[A-Z][a-zäöüß]?` and the same trap applies to common German bigrams
(`Da eins`, `So ein`, `Wo eins`, `Er eins`, `Am eins`). The DE digit word list
is much larger (includes `ein`/`eine`/`einen`/`einer`/`einem`/`eines`/`zehn`/`elf`/`zwölf`),
so the false-positive surface is larger than in English.

**Fix:**
Either (a) tighten the stem regex so 1- and 2-char Title-Case stems require an
explicit non-prose signal, or (b) add a sentence-context guard. Minimal-change
option (a):
```swift
// EN: drop the `[A-Z][a-z]?` alternative — require either 2-5 all-caps
// (E, GSD, NRSNA) or a camelCase shape (iOS, eBook).
let stemPattern = "(?:[A-Z]{2,5}|[a-z][A-Z][a-zA-Z]{0,3})"
```
This still accepts `E` (the LLM-NUM-01 / D-02 `E one → E1` fixture) iff `E` is
treated as the 1-char member of the all-caps class — which requires changing
`[A-Z]{2,5}` to `[A-Z]{1,5}` AND adding an explicit "not followed by `[a-z]`"
guard so prose words like `No`, `At`, `In`, `Be`, `Go`, `My` (which all match
`[A-Z][a-z]`) do not slip through.

A defensible regex:
```swift
// 1-char ALLCAPS that's not followed by a lowercase letter ('E one' ✅, 'Eone' ✗),
// or 2-5 char ALLCAPS, or camelCase.
let stemPattern = "(?:[A-Z](?![a-zäöüß])|[A-Z]{2,5}|[a-z][A-Z][a-zA-Z]{0,3})"
```
Then add regression tests that lock the bigrams above (`No one`, `At one`, `In one`,
`Be one`, `Go five`, `Do one`, `So one`, `My one`, `He one`, `On one`) AND keep
the `iOS seven`, `E one`, `M three`, `Modell einer` positives green.

---

## Warnings

### WR-01: German Regeln block mixes bullet ("- ") and numeric ("8.") prefixes

**File:** `Shared/Models/CleanupPrompt.swift:178-186`
**Issue:**
The DE rules block was written as a bulleted list in V19C (lines 178-184 use `"- "`
prefix for rules 1-7). The Phase 28 addition appends rule 8 using a numeric prefix
(`"8. Einzelne Zahlwörter..."`, line 186) instead of `"- Einzelne Zahlwörter..."`.
Result: the LLM sees a heterogeneous list where the final item is visually distinct
from the rest. This may cause the model to weight rule 8 differently from rules 1-7
(emphasis bias on numbered items) or, conversely, to treat it as a list-terminator
and de-prioritize it.

The EN rules block (lines 110-122) uses `"1."`..."`8.`" consistently, so the
inconsistency is DE-only. The author comment at line 176 ("Phase 28 D-10: Regel 8
added as an ADDITIVE extension only — existing 1-7 byte-identical") acknowledges
the constraint of not touching V19C bytes, but the chosen workaround introduces a
formatting discontinuity rather than preserving the bullet shape.

**Fix:**
Either reformat the new rule with the bullet prefix to match its siblings:
```swift
prompt += "- Einzelne Zahlwörter ('eins'..'zwölf'): im Prosa-Text ausschreiben. AUSNAHME: ...\n"
```
Or, if the bullet-vs-number choice was deliberate evidence-driven (the matrix
harness should show this), document the rationale inline so a future reviewer
doesn't "fix" it.

---

### WR-02: `prompt_version` is hardcoded in init default, never threaded from prompt builder

**File:** `Shared/Services/TextProcessingService.swift:331-367` (record assembly), `Shared/Diagnostics/DebugRecorder.swift:65` (init default)
**Issue:**
The `DebugCleanupRecord` initializer defaults `prompt_version: String = "v19d"`.
`TextProcessingService.process(...)` never passes this argument explicitly when
constructing the record (lines 331-367 — `prompt_version` is absent from the call
site), so every record encoded today carries "v19d" by virtue of the default.

This is functionally correct *for Phase 28*, but the field's purpose (per the
comment at `DebugRecorder.swift:37`: "prompt variant tag for JSONL analysis") is to
discriminate between prompt versions in collected logs. If a future phase adds a
v19e variant — or runs a A/B test where two prompt versions ship simultaneously —
nothing in the existing code will propagate the actual prompt version into the
record. The author would have to remember to update both the prompt builder AND
the init default in lockstep, which is exactly the kind of synchronization invariant
that gets missed.

**Fix:**
Make the prompt builder return its version alongside the prompt string, and thread
it into the record:
```swift
// CleanupPrompt
static let currentVersion = "v19d"

// CleanupServiceTrace gains a `promptVersion: String` field, populated by
// CleanupService.cleanup at the same site that builds the prompt.

// TextProcessingService.process(...) passes:
//     prompt_version: cleanupTrace?.promptVersion ?? CleanupPrompt.currentVersion
```
Or, minimally, add a unit test that asserts `record.prompt_version == "v19d"`
after a full pipeline run so a future drift trips CI.

---

### WR-03: New Rule 8 "Preserve digits" clause locks in any ITN false positive

**File:** `Shared/Models/CleanupPrompt.swift:122` (EN), `Shared/Models/CleanupPrompt.swift:186` (DE)
**Issue:**
EN Rule 8 ends with: *"Preserve digits and number-formats already present in the
input — do not re-spell them as words."* This is the "W-01 dual-defense" idea
(documented at lines 119-121): the deterministic ITN runs first, and the LLM is
told not to undo it.

The problem: this transforms ITN bugs from "noisy" (LLM can repair) into "fatal"
(LLM is forbidden from repairing). Every false positive from the new
`applySingleDigitIdentifier` pass (see CR-01) becomes a permanent, user-visible
mangling.

This is a defense-in-depth design that only works if the ITN side is more conservative
than the LLM side. Today the ITN is more aggressive (CR-01), so the dual-defense
is asymmetric and harmful.

**Fix:**
Soften Rule 8 to allow the LLM to repair obviously wrong ITN outputs:
> "Preserve digits already present in the input UNLESS they appear in clearly
> prose contexts (e.g. 'No1 knows' → 'No one knows'). Do not re-spell legitimate
> identifiers like 'E1', 'iOS7', 'Version 2'."

This is a band-aid; CR-01 is the real fix. Both should ship together.

---

### WR-04: `levenshteinGateThreshold` documentation contradicts its initializer

**File:** `Shared/Services/CleanupService.swift:646, 665`
**Issue:**
Line 646 declares `public static let levenshteinGateThreshold: Double = 0.45`. The
doc comment on the `threshold` parameter of `gateLLMOutput` (line 665) says:
*"Defaults to `levenshteinGateThreshold` (0.30) — pass an explicit value only for
calibration / testing."*

The literal value is 0.45 but the documentation claims 0.30. Either the constant
was tuned upward without updating the doc, or the doc was copy-pasted from an
earlier revision. Reviewer/operator confusion is the real cost — anyone reading
the doc to understand the gate's strictness will form the wrong mental model and
make wrong calibration decisions.

This is pre-existing (not introduced in Phase 28), but the CleanupService.swift
file is in the diff for Phase 28 (the VARIANT-A-WINNER comment additions at lines
323-326), so it's in-scope for this review.

**Fix:**
Update the doc comment to match the actual constant:
```swift
///   - threshold: normalized-distance ceiling. Defaults to
///     `levenshteinGateThreshold` (0.45) — pass an explicit value only for
///     calibration / testing.
```

---

## Info

### IN-01: "Variant A no-op" test method is decorative and trips a lint

**File:** `macOS/DicticusTests/CleanupServiceTests.swift:395-401` (and iOS parity copy)
**Issue:**
`testVariantA_NoNormalizeContractionsMethod` asserts `XCTAssertTrue(true)`. This is
intentional per the comment ("documentation-as-test methods") but contributes nothing
to safety — if a future phase adds a `normalizeContractions` method, this test will
not fail; the test simply documents the current design choice.

Phase 27 closed `WR-04 — rewrite testK7_DoesNotOverrideUserCustomization as real
regression net` for exactly this category of "decorative test" issue. The same
critique applies here.

**Fix:**
Either drop the test or convert it to a real regression net:
```swift
func testVariantA_NoNormalizeContractionsMethod() {
    // Reflect on the type — fail if a normalizeContractions method is added
    // without the design-doc anchor being updated.
    let mirror = Mirror(reflecting: CleanupService.self)
    XCTAssertFalse(
        mirror.children.contains(where: { $0.label == "normalizeContractions" }),
        "Variant B/D promotion path: update this test if a normalizeContractions method is added."
    )
}
```
Reflection alone won't catch nonisolated static methods, so a more direct option
is to grep the source via `Bundle` resources during the test. Either way is more
useful than `XCTAssertTrue(true)`.

---

### IN-02: `applyEnglishSingleDigitIdentifier` Pattern B accepts prose contexts ("step one of the recipe" → "step 1 of the recipe")

**File:** `Shared/Utilities/ITNUtility.swift:415-419`
**Issue:**
Pattern B uses a case-insensitive set of "version-class" words: `version|model|item|option|chapter|step|phase|task|level|stage|track|round|tier|grade`. This is intentionally permissive (the test fixture at `ITNUtilityTests.swift:146` exercises `version two and option one → version 2 and option 1`), but several entries on this list are highly polysemous:

- `step one of the recipe is to chop onions` → `step 1 of the recipe is to chop onions` (prose)
- `I lost the round one` → `I lost the round 1` (prose)
- `a step one rebuild` → `a step 1 rebuild` (ambiguous)
- `On stage two appeared` → `On stage 2 appeared` (prose)

The current test suite includes no negative cases for Pattern B — every Pattern-B
test is a true positive. The user's accepted contract appears to be "always promote
in these contexts" so this may be by design, but it's worth a fixture or two that
documents the boundary explicitly.

**Fix:**
Add an explicit test that locks the current intentional permissiveness:
```swift
func testEnglishPatternB_StepRecipeIsPromoted_DocumentsPermissiveDesign() {
    // Pattern B intentionally promotes 'step <digit>' even in prose contexts.
    // See Plan 28-02 D-02. Update fixture if behavior changes.
    XCTAssertEqual(
        ITNUtility.applyITN(to: "step one of the recipe", language: "en"),
        "step 1 of the recipe"
    )
}
```
Or, if the prose cases are NOT intended, scope down the list (drop `step`, `round`,
`stage`) and add negative tests.

---

### IN-03: `extractEnvelopeOrFallback` doc comment references a wrong line number

**File:** `Shared/Services/CleanupService.swift:580-581`
**Issue:**
The doc comment in `extractEnvelopeOrFallback` (case 3 explanation) says:
*"the V18C/V19C pattern — opening tag pre-filled in the prompt as a completion
anchor at `CleanupPrompt.swift:202`"*. The actual location of the opening-tag
pre-fill is now `CleanupPrompt.swift:289` (`prompt += "Out: <corrected_text>"`).

Phase 28 added enough lines to `CleanupPrompt.swift` (rule 8, K2/K4/K5 few-shots,
removal of topic-words) that the line reference in the doc comment is now off by
~87 lines. Stale doc references aren't functional bugs but they slowly poison the
"trust the comment" instinct that makes future maintenance cheap.

**Fix:**
Use a symbolic reference rather than a line number:
```swift
///   3. Closing only:   `X</corrected_text>`                   → `X`
///      (V18C/V19C pattern — opening tag pre-filled in the prompt as a
///      completion anchor in `CleanupPrompt.build()`'s final "Out: ..." line)
```

---

_Reviewed: 2026-05-27T14:55:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
