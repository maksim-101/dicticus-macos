---
phase: 26-pipeline-quality-hardening
plan: "02"
subsystem: SelfCorrectionResolver
tags: [bug-fix, tdd, german-nlp, resolver, regression-tests]
dependency_graph:
  requires: []
  provides: [SelfCorrectionResolver-doch-oder-fix]
  affects: [macOS/Dicticus, iOS/Dicticus, Shared/Utilities]
tech_stack:
  added: []
  patterns: [TDD RED/GREEN, cross-platform test parity]
key_files:
  created:
    - .planning/phases/26-pipeline-quality-hardening/26-02-SUMMARY.md
  modified:
    - Shared/Utilities/SelfCorrectionResolver.swift
    - macOS/DicticusTests/SelfCorrectionResolverTests.swift
    - iOS/DicticusTests/SelfCorrectionResolverTests.swift
decisions:
  - Remove standalone "doch" and "oder" from germanConnectors — too ambiguous as German discourse particles to be reliable self-correction markers
  - Remove "doch" from pureCorrectionConnectors — follows from germanConnectors removal
  - Keep "oder vielmehr" and "oder besser" — multi-word connectors where "oder" serves a legitimate correction role (longest-first sort ensures they still match)
metrics:
  duration: "~10 minutes"
  completed: "2026-05-22T14:57:41Z"
  tasks_completed: 1
  files_modified: 3
---

# Phase 26 Plan 02: SelfCorrectionResolver doch/oder false-positive fix Summary

Remove standalone "doch" and "oder" from SelfCorrectionResolver connector lists, eliminating P1 false-positive content drops on German tag questions and subordinate clause markers, locked by 3 UAT regression fixtures (records 102, 117, 132).

## Tasks Completed

| # | Task | Commit | Files |
|---|------|--------|-------|
| 1 (RED) | Add 3 failing UAT regression fixtures | 4a0dcb6 | macOS/DicticusTests/SelfCorrectionResolverTests.swift |
| 1 (GREEN) | Remove doch/oder + sync iOS test parity | 4337952 | Shared/Utilities/SelfCorrectionResolver.swift, iOS/DicticusTests/SelfCorrectionResolverTests.swift |

## What Was Built

The `SelfCorrectionResolver` was treating German discourse particles "doch" and "oder" as
self-correction connectors. This caused legitimate clause content to be dropped:

- UAT record 102: `"wir sind in dieser Stadt Zürich, oder wäre das auch schon einschränkend"` → dropped to `"wir sind in wäre das auch schon einschränkend"` (before fix)
- UAT record 117: `"gefällt mir eigentlich ganz gut, doch dieser eine Teilsatz"` → dropped to `"gefällt mir dieser eine Teilsatz"` (before fix)
- UAT record 132: `"das Ganze ankurbelt, doch wenn noch tun"` → was already passing due to "wenn" abort pronoun, but locked as regression fixture

**Fix applied (3 lines removed from SelfCorrectionResolver.swift):**
- `"doch"` removed from `germanConnectors` array (was line 257)
- `"oder"` standalone removed from `germanConnectors` array (was line 268)
- `"doch"` removed from `pureCorrectionConnectors` set (was line 299)

**Preserved (multi-word connectors unaffected):**
- `"oder vielmehr"` and `"oder besser"` remain in `germanConnectors` — these use "oder" as part of a longer correction phrase and are matched longest-first, so standalone "oder" removal has no impact on them.

## Test Results

- macOS SelfCorrectionResolverTests: **30 tests passed, 0 failures** (27 existing + 3 new UAT fixtures)
- iOS SelfCorrectionResolverTests.swift: byte-identical to macOS (`diff -q` returns clean)
- Verified: `testGermanOderVielmehr` still passes (multi-word connector works)
- Verified: `testGermanOderBesser` still passes (multi-word connector works)

## TDD Gate Compliance

- RED commit: `4a0dcb6` — `test(26-02)`: 3 failing fixtures (2 failed, 1 coincidentally passed via abort pronoun path)
- GREEN commit: `4337952` — `feat(26-02)`: implementation fix; all 30 tests pass

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None.

## Threat Flags

None — this change reduces trust-boundary surface (T-26-03 mitigated: ambiguous connectors that caused false-positive content deletion are removed).

## Self-Check: PASSED

- [x] `Shared/Utilities/SelfCorrectionResolver.swift` — modified, committed in 4337952
- [x] `macOS/DicticusTests/SelfCorrectionResolverTests.swift` — modified, committed in 4a0dcb6
- [x] `iOS/DicticusTests/SelfCorrectionResolverTests.swift` — modified, committed in 4337952
- [x] RED commit `4a0dcb6` exists: `git log --oneline | grep 4a0dcb6`
- [x] GREEN commit `4337952` exists: `git log --oneline | grep 4337952`
- [x] 30 tests pass, 0 failures (verified via `xcodebuild test`)
- [x] iOS file byte-identical to macOS (`diff -q` clean)
- [x] `grep -c '"doch"' Shared/Utilities/SelfCorrectionResolver.swift` → 0
- [x] `grep -c '"oder",' Shared/Utilities/SelfCorrectionResolver.swift` → 0
