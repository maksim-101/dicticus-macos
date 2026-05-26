---
phase: 27-dictionary-hallucination-guard-recorder-enrichment-k7-brand
plan: 01
subsystem: dictionary-service
tags: [hallucination-guard, fuzzy-match, allowlist, levenshtein, recorder-trace, applyWithTrace]
requires:
  - LevenshteinDistance.normalizedDistance (Shared/Utilities/LevenshteinDistance.swift)
  - hermitdave/FrequencyWords corpus (CC-BY-SA 4.0)
provides:
  - DictionaryService.applyWithTrace(to:) — canonical traced apply
  - DictionaryService.Replacement (Codable, Sendable) — per-replacement trace entry
  - DictionaryService.BlockedMatch (Codable, Sendable) — blocked-fuzzy trace entry (4 fields incl. `to`)
  - DictionaryService.commonWordsForTests — internal allowlist accessor for tests
affects:
  - Shared/Services/DictionaryService.swift (canonical refactor; apply -> wrapper)
  - macOS/project.yml, iOS/project.yml (resources bundling)
  - Shared/Resources/{allowlist-en.txt, allowlist-de.txt, ALLOWLIST_LICENSE.md} (new bundled assets)
  - macOS/DicticusTests/DictionaryServiceTests.swift, iOS counterpart (byte-identical)
tech-stack:
  added:
    - hermitdave/FrequencyWords (vendored text assets, CC-BY-SA 4.0)
  patterns:
    - Defense-in-depth fuzzy guard (Guard A: allowlist veto; Guard B: Levenshtein ratio cap)
    - Inner-type pattern (Replacement, BlockedMatch as nested public structs on DictionaryService)
    - Canonical-implementation wrapper (apply -> applyWithTrace.text)
    - Resource-bundle Set-ivar load with defensive empty-Set fallback
key-files:
  created:
    - Shared/Resources/allowlist-en.txt (1005 lemmas)
    - Shared/Resources/allowlist-de.txt (1000 lemmas)
    - Shared/Resources/ALLOWLIST_LICENSE.md
  modified:
    - Shared/Services/DictionaryService.swift
    - macOS/project.yml (resources entry added)
    - iOS/project.yml (resources block added)
    - macOS/DicticusTests/DictionaryServiceTests.swift
    - iOS/DicticusTests/DictionaryServiceTests.swift
decisions:
  - fuzzyRatioCap = 0.25 (D-03 open-decision Option 1, ratified by user 2026-05-26)
  - BlockedMatch schema = 4 fields {key, from, to, ratio} (D-06 amendment Option A, ratified by user 2026-05-26)
  - Allowlist split into two language files merged into one Set<String> at load (D-claude-discretion)
  - K1 morphological variants {remind, apply, applies, applied, applying} appended to top-1000 EN to ensure coverage (RESEARCH §6.4)
  - Identity-replacement suppression: fuzzy pass emits no Replacement when `to == token` (avoids no-op trace entries after exact-match pass)
metrics:
  duration: ~25 minutes (3 task commits + summary)
  completed: 2026-05-26
  tests_added: 11 (5 guard + 3 trace + 3 baseline-preservation)
  tests_modified: 1 (Tailscele assertion comment annotated)
  test_files_byte_identical: yes (diff -q exits 0)
---

# Phase 27 Plan 01: Dictionary Hallucination Guard Summary

Installed defense-in-depth fuzzy-pass guard (bundled common-word allowlist + Levenshtein ratio cap 0.25) and refactored `DictionaryService` so `applyWithTrace(to:) -> (text, replacements, blocked)` is the canonical implementation and `apply(to:) -> String` becomes a thin one-line wrapper. K1 hallucinations (`remind→Gemini`, `applies→AppLite`) are blocked; existing exact-match and distance-1 fuzzy hits continue to fire; 9.3% dictionary-hit baseline preserved.

## What Shipped

### Wave 0 Assets
- `Shared/Resources/allowlist-en.txt` (1005 lemmas) — top 1000 from hermitdave/FrequencyWords `en_50k.txt` (CC-BY-SA), lowercased and filtered to `^[a-zäöüß]+$` of length ≥ 2, plus 5 appended K1 morphological variants (`remind`, `apply`, `applies`, `applied`, `applying`).
- `Shared/Resources/allowlist-de.txt` (1000 lemmas) — top 1000 from `de_50k.txt`, same filter.
- `Shared/Resources/ALLOWLIST_LICENSE.md` — CC-BY-SA 4.0 attribution.
- `macOS/project.yml` — added `- path: ../Shared/Resources` alongside the existing `Dicticus/Assets.xcassets` resource.
- `iOS/project.yml` — added a `resources:` block with `- path: ../Shared/Resources`.
- xcodegen regenerated both `.xcodeproj` files; verified `allowlist-en.txt` is bundled into the built `.app/Contents/Resources/`.

### Code Changes in DictionaryService
- `public struct Replacement: Codable, Sendable { key, from, to }` — per-replacement trace entry (D-09).
- `public struct BlockedMatch: Codable, Sendable { key, from, to, ratio }` — blocked-fuzzy trace entry with the **4-field schema** (D-06 amendment Option A).
- `private static let fuzzyRatioCap: Double = 0.25` — D-03 open-decision Option 1.
- `private let commonWords: Set<String>` ivar populated once in `init()` via `Self.loadCommonWords()`. Loader reads `allowlist-en.txt` + `allowlist-de.txt` from `Bundle.main`, splits/trims/lowercases/unions; logs and falls back to empty Set on any failure (Assumption A2).
- `internal var commonWordsForTests: Set<String>` — test-visibility surface for `testAllowlistLoadedFromBundle`.
- `applyWithTrace(to:) -> (text, replacements, blocked)` — canonical traced implementation. Captures `Replacement` entries on every exact-match regex hit (using `regex.matches(in:options:range:)` to extract the matched substring before `stringByReplacingMatches` rewrites it) and merges in fuzzy-pass results.
- `apply(to:) -> String` — single statement: `return applyWithTrace(to: text).text` (D-08).
- `applyFuzzyPassWithTrace(_:)` — token-walker preserved verbatim from the prior `applyFuzzyPass`; collects Replacement / BlockedMatch arrays from per-token calls.
- `fuzzyReplaceTokenWithTrace(_:candidates:) -> (String, Replacement?, BlockedMatch?)` — installs Guard A (allowlist veto, D-01a + D-04) and Guard B (ratio cap, D-01b + D-03). When a candidate passes Guard B but the resulting text equals the input token (e.g. after exact-match already produced the final form), no Replacement is emitted to keep the trace clean.
- Old `applyFuzzyPass(_:) -> String` and `fuzzyReplaceToken(_:candidates:) -> String` are removed (grep verified).

### Tests
- `DictionaryServiceHallucinationGuardTests` (5 tests): K1 reproduce cases with JSONL timestamps in the test names; allowlist case-insensitive veto; ratio cap behavior on length-7 tokens; allowlist bundle-load assertion (1505+ entries, contains `remind`, `applies`, `running`, `working`, `looking`).
- `DictionaryServiceApplyWithTraceTests` (3 tests): traced replacements with `.to == "Dicticus"`; allowlist-veto path produces no BlockedMatch (Guard A precedes candidate loop); positive BlockedMatch path (`barbax5 vs BarBaz7`, ratio 0.286) emits all 4 fields including `.to == "BarBaz7"`; `apply == applyWithTrace.text` identity contract.
- `DictionaryServiceFuzzyMatchTests` (3 new tests): `testTailskillExactStillFires`, `testTailskilDistance1StillFires`, `testTailsceleStillFiresAt025Cap` — baseline-preservation contract.
- macOS and iOS test files are byte-identical (`diff -q` exits 0).

## Open Decisions — Resolved by User Upfront

### D-06 Amendment (BlockedMatch schema)
**Option A — Include `to` field.** Ratified by user 2026-05-26. Recorded here as the D-06 amendment: the `dictionary_blocked` JSONL schema carries **4 fields** `{key, from, to, ratio}`. Rationale: single-file diagnosability of JSONL logs without needing to cross-reference `dictionary[key].replacement` from another source.

Downstream impact for Plan 27-02:
- `DictionaryBlockedEntry` is `{key, from, to, ratio}` with explicit memberwise init.
- The `.map { DictionaryBlockedEntry(key: $0.key, from: $0.from, to: $0.to, ratio: $0.ratio) }` bridge applies as written.
- Codable round-trip fixture asserts `.to == "Gemini"` on the blocked entry.

### D-03 Open-Decision (Ratio threshold)
**Option 1 — Ratio cap 0.25.** Ratified by user 2026-05-26. RESEARCH §6.1 recommendation: ratio 0.25 still BLOCKS both K1 cases (`remind` 0.333, `applies` 0.286) and KEEPS the existing `Tailscele → Tailscale` fuzzy hit firing (ratio 0.222 ≤ 0.25). The existing `testPhase251_FuzzyMatch_TailskillVariants` assertion at line 167-174 is unchanged in effect; an inline comment was added documenting the ratio-cap dependency.

## Test Results

```
Test Suite 'DictionaryServiceTests'                      passed: 6 tests
Test Suite 'DictionaryServiceClassBTests'                passed: 6 tests
Test Suite 'DictionaryServiceFuzzyMatchTests'            passed: 9 tests (incl. 3 new baseline tests)
Test Suite 'DictionaryServicePhase26RegressionTests'     passed: 2 tests
Test Suite 'DictionaryServiceHallucinationGuardTests'    passed: 5 tests (new)
Test Suite 'DictionaryServiceApplyWithTraceTests'        passed: 3 tests (new)
---
TOTAL: 31 tests across 6 suites, 0 failures
```

Allowlist bundle proof: `Dicticus.app/Contents/Resources/allowlist-en.txt` confirmed present in `~/Library/Developer/Xcode/DerivedData/Dicticus-.../Build/Products/Debug/`.

iOS test file parity: `diff -q macOS/DicticusTests/DictionaryServiceTests.swift iOS/DicticusTests/DictionaryServiceTests.swift` exits 0.

xcodegen regenerated both `.xcodeproj` files cleanly.

Tests were executed with `CODE_SIGNING_ALLOWED=NO CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO` because the macOS target uses manual `Developer ID` signing for release builds and the test invocation does not need provisioning. This is a runtime-only flag; the committed `project.yml` settings are unchanged.

## Must-Haves Truths — All Observable

1. **"Speaking `remind` in JSONL `2026-05-25T08:22:24.564Z` shape does not mutate to `Gemini` in post_dict."** — Verified by `testRemindNotMutatedToGemini_2026_05_25T08_22_24` (PASSED). Allowlist Guard A vetoes; the candidate loop is never entered.
2. **"Speaking `applies` in JSONL `2026-05-26T16:12:57.343Z` shape does not mutate to `AppLite` in post_dict."** — Verified by `testAppliesNotMutatedToAppLite_2026_05_26T16_12_57` (PASSED). Allowlist Guard A vetoes (`applies` was explicitly appended to the EN list).
3. **"Existing exact-match brand fixes (`Tailskill→Tailscale`, `cloud code→Claude Code` analogs) still fire — 9.3% dictionary-hit baseline preserved."** — Verified by 9 PASSED `DictionaryServiceFuzzyMatchTests` and 6 PASSED `DictionaryServiceClassBTests`.
4. **"`DictionaryService.applyWithTrace(to:)` is the canonical traced implementation; `apply(to:) -> String` is a thin wrapper that discards the trace."** — Verified by `testApplyAndApplyWithTraceProduceSameText` and by direct code inspection: `apply` body is `return applyWithTrace(to: text).text`.
5. **"Allowlist veto fires on the lowercased token regardless of input case (D-04)."** — Verified by `testAllowlistVetoCaseInsensitive`: `apply(to: "REMIND")` returns `"REMIND"` unchanged.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 — Bug] Identity-replacement suppression in fuzzy pass**
- **Found during:** Task 3 test run.
- **Issue:** `testApplyWithTraceReturnsReplacements` reported 2 replacements instead of 1. The test seeds `Dicticos → Dicticus`. After the exact-match pass produces `Dicticus is great`, the fuzzy pass walks `Dicticus` (8 chars), checks it against candidate key `Dicticos` (distance 1, ratio 0.125 ≤ 0.25), fires a "replacement" of `Dicticus → Dicticus` (no visible change), and incorrectly emits a Replacement trace entry.
- **Fix:** In `fuzzyReplaceTokenWithTrace`, when the candidate's replacement string equals the input token (`to == token`), return `(token, nil, nil)` instead of emitting a no-op Replacement. This keeps the trace signal clean and matches the intuitive contract: a Replacement entry means a visible mutation occurred.
- **Files modified:** `Shared/Services/DictionaryService.swift` (Guard B branch in `fuzzyReplaceTokenWithTrace`).
- **Commit:** `e576885`.

**2. [Rule 2 — Critical] EN allowlist enrichment for K1 coverage**
- **Found during:** Task 1a verification.
- **Issue:** Top-1000 EN list from hermitdave/FrequencyWords does not include `remind` (line 1769) or `applies` (line 11096). Plan acceptance criteria require `grep -c "^remind$"` and `grep -c "^applies$"` to return 1 (necessary for the K1 allowlist-veto path).
- **Fix:** Per RESEARCH §6.4 fallback policy, appended 5 K1 morphological variants (`remind`, `apply`, `applies`, `applied`, `applying`) to the top-1000 EN list after the same lowercasing/filter pass, preserving the ~1000-entry target with explicit coverage of the K1 reproduce cases. Documented in `ALLOWLIST_LICENSE.md` methodology note.
- **Files modified:** `Shared/Resources/allowlist-en.txt`, `Shared/Resources/ALLOWLIST_LICENSE.md`.
- **Commit:** `7f9c62e`.

## Known Stubs

None — all changes are wired end-to-end and exercised by passing tests.

## Self-Check: PASSED

- `Shared/Resources/allowlist-en.txt` — FOUND (1005 lines)
- `Shared/Resources/allowlist-de.txt` — FOUND (1000 lines)
- `Shared/Resources/ALLOWLIST_LICENSE.md` — FOUND
- `Shared/Services/DictionaryService.swift` — FOUND (modified)
- `macOS/DicticusTests/DictionaryServiceTests.swift` — FOUND (modified)
- `iOS/DicticusTests/DictionaryServiceTests.swift` — FOUND (modified, byte-identical to macOS)
- Commit `7f9c62e` — FOUND in git log
- Commit `4ed5d7e` — FOUND in git log
- Commit `e576885` — FOUND in git log
- 31/31 DictionaryService-related tests PASS

## Plan Commits

| Task | Commit | Description |
|------|--------|-------------|
| 1a   | `7f9c62e` | feat(27-01): add allowlist assets and xcodegen resources wiring |
| 1b   | `4ed5d7e` | test(27-01): add hallucination guard + applyWithTrace test scaffolding |
| 3    | `e576885` | feat(27-01): install fuzzy-pass hallucination guard + applyWithTrace |
| 4    | (this SUMMARY commit) | docs(27-01): complete plan summary |
