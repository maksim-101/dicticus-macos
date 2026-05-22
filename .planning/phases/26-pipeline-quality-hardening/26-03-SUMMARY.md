---
phase: 26-pipeline-quality-hardening
plan: "03"
subsystem: DictionaryService
tags: [dictionary, fuzzy-match, false-positive, regression-test, cross-platform]
dependency_graph:
  requires: []
  provides: [dictionary-versus-vercel-fix]
  affects: [DictionaryService, DictionaryServiceTests]
tech_stack:
  added: []
  patterns: [TDD-red-green, purge-retired-defaults]
key_files:
  created: []
  modified:
    - Shared/Services/DictionaryService.swift
    - macOS/DicticusTests/DictionaryServiceTests.swift
    - iOS/DicticusTests/DictionaryServiceTests.swift
decisions:
  - Retire Versal entry via purgeRetiredDefaults pattern (existing mechanism) rather than ad-hoc removal
  - Add lowercase vercel key for case-insensitive exact-match normalization
  - Test class seeds only the post-fix state to lock invariant going forward
metrics:
  duration: "~6 minutes"
  completed: "2026-05-22"
  tasks_completed: 1
  files_changed: 3
---

# Phase 26 Plan 03: P2 Dictionary versus→Vercel False Positive Fix Summary

Retired the "Versal" -> "Vercel" dictionary entry that fuzzy-matched every spoken "versus" (Levenshtein distance 2) and replaced it with a "vercel" exact-match-only entry (distance 3 from "versus", outside the fuzzy threshold).

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 (RED) | Failing regression test for versus→Vercel | b06c13c | macOS/DicticusTests/DictionaryServiceTests.swift |
| 1 (GREEN) | Retire Versal + add vercel exact-match + iOS parity | 2a31f23 | Shared/Services/DictionaryService.swift, macOS/DicticusTests/DictionaryServiceTests.swift, iOS/DicticusTests/DictionaryServiceTests.swift |

## What Was Built

**DictionaryService.swift changes:**

1. `purgeRetiredDefaults()` — Added "Versal" to the retired array. On every launch this removes the key from any existing user install's persisted UserDefaults, converging to the corrected behavior without a manual reset.

2. `prepopulateWithDefaults()` — Removed the `"Versal": "Vercel"` entry. Added `"vercel": "Vercel"` as the replacement: lowercase key triggers the case-insensitive regex pass for any capitalization of "vercel", while having distance 3 from "versus" (outside the fuzzy threshold of ≤ 2).

**Test changes (macOS and iOS, byte-identical):**

- Added `DictionaryServicePhase26RegressionTests` class with:
  - `testPhase26_VersusNotReplacedWithVercel` — regression lock: "the approach of A versus B is clear" passes through unchanged
  - `testPhase26_VercelExactMatchWorks` — verifies the new "vercel" entry normalises to "Vercel"

## TDD Gate Compliance

- RED commit `b06c13c`: test seeded "Versal" and asserted no change → FAIL confirmed (`"the approach of A Vercel B is clear"`)
- GREEN commit `2a31f23`: DictionaryService fix + test updated to post-fix invariant → all 21 tests PASS

## Verification Results

```
xcodebuild ... -only-testing:DicticusTests/DictionaryServiceTests
              -only-testing:DicticusTests/DictionaryServiceClassBTests
              -only-testing:DicticusTests/DictionaryServiceFuzzyMatchTests
** TEST SUCCEEDED ** (21 tests, 0 failures)

diff -q macOS/.../DictionaryServiceTests.swift iOS/.../DictionaryServiceTests.swift
(no output — byte-identical)
```

## Acceptance Criteria Check

- [x] `purgeRetiredDefaults()` retired array contains "Versal"
- [x] `prepopulateWithDefaults()` does NOT contain "Versal" as a dict key
- [x] `prepopulateWithDefaults()` contains `"vercel": "Vercel"` (lowercase key)
- [x] `grep -c '"Versal"' Shared/Services/DictionaryService.swift` returns 2 (one in retired array, one in doc comment)
- [x] All existing dictionary tests pass + 2 new regression tests pass
- [x] "versus" passes through unchanged with post-fix dictionary state
- [x] iOS DictionaryServiceTests.swift is byte-identical to macOS version

## Deviations from Plan

None — plan executed exactly as written.

The only minor nuance: the TDD RED test initially seeded "Versal" to demonstrate the failure. The GREEN test revision updated the setUp to seed only "vercel" (the post-fix production state). This is standard TDD test evolution and was expected by the plan's STEP 3 ("run macOS tests — MUST now pass").

## Threat Surface Scan

No new network endpoints, auth paths, file access patterns, or schema changes introduced. This change removes a harmful entry from the dictionary defaults and adds an innocuous exact-match entry — no new trust boundary exposure.

## Self-Check: PASSED

- `Shared/Services/DictionaryService.swift` exists and contains "Versal" in retired array + "vercel" in defaults
- `macOS/DicticusTests/DictionaryServiceTests.swift` contains `testPhase26_VersusNotReplacedWithVercel`
- `iOS/DicticusTests/DictionaryServiceTests.swift` is byte-identical to macOS version
- Commits b06c13c and 2a31f23 verified in git log
