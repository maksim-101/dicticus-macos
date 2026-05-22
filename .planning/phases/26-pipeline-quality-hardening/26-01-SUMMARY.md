---
phase: 26-pipeline-quality-hardening
plan: "01"
subsystem: itn-pipeline
tags: [itn, number-normalization, structural-words, bug-fix, tdd, regression-tests]
dependency_graph:
  requires: []
  provides: [fixed-english-itn, numeric-structural-words-post-pass]
  affects: [Shared/Utilities/ITNUtility.swift, macOS/DicticusTests/ITNUtilityTests.swift, iOS/DicticusTests/ITNUtilityTests.swift]
tech_stack:
  added: []
  patterns: [tdd-red-green, reverse-order-regex-replacement, candidate-order-priority]
key_files:
  created: []
  modified:
    - Shared/Utilities/ITNUtility.swift
    - macOS/DicticusTests/ITNUtilityTests.swift
    - iOS/DicticusTests/ITNUtilityTests.swift
decisions:
  - "P0: Try hyphenated candidate before space-separated in applyEnglishITN — NSNumberFormatter parses 'twenty-five' correctly as 25 but 'twenty five' as 2005 (concatenation artifact)"
  - "P0 guard: skip ITN merge for length-2 'zero X' pairs — 'zero' is a structural prefix in version-number contexts and must survive to the structural-word post-pass"
  - "P3 transform order: point/Punkt before zero-prefix-dash before plain dash — ensures 'twenty five point one dash zero six' traces correctly to '25.1-06'"
  - "P3 single-digit word resolution: enDigitWords alternation + enWordMap in structural patterns — allows 'point one' and 'dash zero six' to resolve without requiring ITN to emit digit tokens for sub-10 words"
metrics:
  duration_seconds: 512
  completed_date: "2026-05-22"
  tasks_completed: 1
  tasks_total: 1
  files_modified: 3
  tests_added: 11
  tests_total_after: 273
---

# Phase 26 Plan 01: ITN P0 Candidate Order Fix + P3 Structural Word Post-Pass Summary

Fixed P0 English ITN number concatenation bug (NSNumberFormatter parsed "twenty five" as 2005 instead of 25) by swapping candidate order to try hyphenated form first, and added P3 `applyNumericStructuralWords` post-pass that converts "point"/"Punkt"/"Komma"/"dash"/"zero" to symbols in numeric contexts.

## Tasks Completed

| # | Task | Commit | Files |
|---|------|--------|-------|
| 1 (RED) | Add failing tests for P0 + P3 | 2f63ec8 | macOS/DicticusTests/ITNUtilityTests.swift |
| 1 (GREEN) | Fix ITNUtility + copy iOS tests | cda406d | Shared/Utilities/ITNUtility.swift, iOS/DicticusTests/ITNUtilityTests.swift |

## What Was Built

**P0 Fix — candidate order swap in `applyEnglishITN`:**
- Line ~434: `candidates = [subTextAllHyphens.lowercased(), subText.lowercased()] + mixed`
- Previous order tried space-separated form first → NSNumberFormatter parsed "twenty five" as 2005 (20 × 100 + 05). Hyphenated form "twenty-five" parses correctly as 25.
- Root cause confirmed by UAT record 134: "twenty five point one dash zero six" → "2005 point one dash 6".

**P0 guard — skip "zero X" length-2 ITN merges:**
- Added to the existing length==2 over-merge guard block.
- NSNumberFormatter can parse "zero-six" as 6 (drops the leading zero), which would swallow the structural "zero" before the P3 post-pass could expand it. Guard prevents this.

**P3 Addition — `applyNumericStructuralWords(to:language:)`:**
- New `static func` wired as the last transform in `applyITN`, after `applyRangeHomophoneFix`.
- Four-step transform (order-dependent):
  1. `point`/`Punkt` between digit and digit-or-word → decimal dot
  2. `Komma` between digits → German decimal comma
  3. `dash zero X` after digit → digit prefix `-0X`
  4. plain `dash` between digits → hyphen
- `enDigitWords` alternation (`zero|one|...|nine|\d+`) allows single-digit English words as right operands — required for "point one" → ".1" before ITN emits a digit token.
- `replaceStructural` helper: processes matches in reverse order, supports custom replacement closures.

**Threat model compliance (T-26-01):** All structural word patterns require `\d+` on the left side — "the point is clear" (no preceding digit) never matches. Verified by `testEnglishPointNoFalsePositive` and `testGermanPunktNoFalsePositive`.

## Test Results

- macOS ITNUtilityTests: 17/17 PASS (6 existing + 11 new)
- Full macOS suite: 273/273 PASS (0 regressions)
- iOS ITNUtilityTests.swift: byte-identical to macOS (verified by `diff -q`)

### New Tests Added (11)

**P0 regression:**
- `testEnglishTwentyFiveNotConcatenated` — "twenty five" → "25"
- `testEnglishFortyOneNotConcatenated` — "forty one" → "41"
- `testEnglishThirtySevenNotConcatenated` — "thirty seven" → "37"

**P3 structural words:**
- `testEnglishPointBetweenDigits` — "Version 25 point 1" → "Version 25.1"
- `testEnglishDashBetweenDigits` — "25 dash 06" → "25-06"
- `testEnglishPointAndDashVersionString` — "twenty five point one dash zero six" contains "25.1-06"
- `testGermanPunktBetweenDigits` — "25 Punkt 1" → "25.1"
- `testGermanKommaBetweenDigits` — "25 Komma 5" → "25,5"
- `testEnglishZeroCollapseAfterDash` — "1 dash zero 6" → "1-06"

**P3 false-positive guards:**
- `testEnglishPointNoFalsePositive` — "the point is clear" unchanged
- `testGermanPunktNoFalsePositive` — "Punkt eins" unchanged

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Added zero-X ITN merge guard**
- **Found during:** GREEN phase — test `testEnglishPointAndDashVersionString` produced "25.1-6" instead of "25.1-06"
- **Issue:** With P0 fix in place (hyphenated form tried first), `NumberFormatter.spellOut` parsed "zero-six" as 6 (treating it as just "six"), consuming the structural "zero" before the P3 post-pass could use it for zero-prefixing. This left the structural word pass without a "zero" to expand, producing "-6" instead of "-06".
- **Fix:** Added length==2 guard for "zero X" pairs (where X is a unit digit word) to skip ITN merging. "zero" as a number constituent is only valid at larger scales (e.g. "zero hundred" is not natural speech); in practice "zero X" is always a positional/structural context.
- **Files modified:** Shared/Utilities/ITNUtility.swift
- **Commit:** cda406d

## TDD Gate Compliance

- RED gate: commit 2f63ec8 (`test(26-01): add failing tests...`) — all 11 new tests failed, 6 existing passed
- GREEN gate: commit cda406d (`feat(26-01): fix P0 ITN...`) — all 17 tests passed

## Known Stubs

None.

## Threat Flags

None. The structural word post-pass operates entirely on already-transcribed text (post-ASR). No new network endpoints, auth paths, or schema changes introduced.

## Self-Check: PASSED

| Check | Result |
|-------|--------|
| Shared/Utilities/ITNUtility.swift exists | FOUND |
| macOS/DicticusTests/ITNUtilityTests.swift exists | FOUND |
| iOS/DicticusTests/ITNUtilityTests.swift exists | FOUND |
| RED commit 2f63ec8 in git log | FOUND |
| GREEN commit cda406d in git log | FOUND |
| iOS and macOS test files byte-identical | IDENTICAL |
| macOS full test suite | 273/273 PASS |
