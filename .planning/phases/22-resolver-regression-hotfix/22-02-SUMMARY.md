---
phase: 22-resolver-regression-hotfix
plan: 02
subsystem: cleanup-pipeline
tags: [cleanup-prompt, regression-net, llama-cpp, xctest]

requires:
  - phase: 22-resolver-regression-hotfix
    provides: SelfCorrectionResolver L75 regex hotfix (Plan 01) — once the resolver no longer emits residue, the LLM never sees the broken phrase, so the cosmetic 8a79e6b few-shot becomes dead weight or a misdirection trap. This plan makes its absence an enforced invariant.
provides:
  - "XCTAssertFalse regression net guarding against silent reintroduction of the 8a79e6b 'let's see whether' / 'whether this is good' few-shot strings into CleanupPrompt.build() output"
  - "1 new XCTest method `testWFewShotFromCommit8a79e6bIsAbsent` under MARK `// MARK: - Phase 22 regression: 8a79e6b few-shot must be absent`"
affects: [future-cleanup-prompt-changes]

tech-stack:
  added: []
  patterns:
    - "Verification-by-test (XCTAssertFalse on prompt content) instead of revert when the offending lines were already removed by an unrelated rewrite (e1d3eef V5 prompt)"
    - "Regression-net testing per memory feedback_tests_as_regression_nets — locks the absence of a known-bad pattern as a CI invariant"

key-files:
  created: []
  modified:
    - "macOS/DicticusTests/CleanupPromptTests.swift (+19 lines: 1 MARK + 1 XCTest method)"

key-decisions:
  - "No production source touched — Shared/Models/CleanupPrompt.swift was NOT modified. Pre-flight grep (Task 1) confirmed both residue strings ('let's see whether', 'whether this is good') are already absent from the file (overwritten by the V5 rewrite at e1d3eef on 2026-05-05, after 8a79e6b on 2026-05-03)."
  - "Insert location: just before the final closing `}` of the `CleanupPromptTests` class (between line 358 and the prior line 359 in the pre-edit file). Indentation matches existing methods (4 spaces inside the class)."
  - "No iOS counterpart added — `CleanupPromptTests` exists only in the macOS test target by 20.06-01 precedent (per RESEARCH.md Architectural Responsibility Map)."
  - "Test gate run with `-only-testing:DicticusTests/CleanupPromptTests/testWFewShotFromCommit8a79e6bIsAbsent` to bypass pre-existing V5-drift failures in other CleanupPromptTests methods (out of scope per .planning/.continue-here lines 18–19)."

patterns-established:
  - "When a 'revert this past commit' task arrives but the offending lines are already gone via an unrelated rewrite, the deliverable is a test that asserts absence — not a re-revert."

requirements-completed: []

duration: 7min
completed: 2026-05-08
---

# Phase 22 Plan 02: CleanupPrompt 8a79e6b Few-Shot Regression Net Summary

**XCTAssertFalse regression net locks in the absence of the cosmetic `8a79e6b` LLM few-shot ("let's see whether" / "whether this is good") from `CleanupPrompt.build()` output — verification-by-test, no production source touched.**

## Performance

- **Duration:** ~7 min
- **Started:** 2026-05-08T20:13:00Z
- **Completed:** 2026-05-08T20:20:00Z
- **Tasks:** 2 (Task 1 read-only gate + Task 2 test addition)
- **Files modified:** 1
- **Lines added:** +19

## Accomplishments

- **Task 1 (pre-flight gate):** `grep -c "let's see whether" Shared/Models/CleanupPrompt.swift` returned `0`; `grep -c "whether this is good" Shared/Models/CleanupPrompt.swift` returned `0`. The 8a79e6b residue strings are CONFIRMED ABSENT in the current source. RESEARCH.md Pitfall 2 (assuming the few-shot still exists) avoided. Plan stays in regression-net mode, not actual-revert mode.
- **Task 2 (regression net):** Added one new XCTest method `testWFewShotFromCommit8a79e6bIsAbsent` to `macOS/DicticusTests/CleanupPromptTests.swift` under a new MARK `// MARK: - Phase 22 regression: 8a79e6b few-shot must be absent`. The test calls `CleanupPrompt.build(text: "test", language: "en")` and asserts the returned prompt does NOT contain `"let's see whether"` or `"whether this is good"`.
- **Test gate:** `xcodebuild test -project macOS/Dicticus.xcodeproj -scheme Dicticus -destination 'platform=macOS' -only-testing:DicticusTests/CleanupPromptTests/testWFewShotFromCommit8a79e6bIsAbsent CODE_SIGNING_ALLOWED=NO` reports `** TEST SUCCEEDED **` with `Executed 1 test, with 0 failures (0 unexpected) in 0.001 seconds`.
- **Production source untouched:** `git diff Shared/Models/CleanupPrompt.swift` produces no output. The plan delivered without modifying any production code, exactly as scoped.
- **Out-of-scope tests untouched:** Pre-existing V5-prompt-drift failures in other `CleanupPromptTests` methods (documented in `.planning/.continue-here` lines 18–19) remain in their pre-Phase-22 state. The targeted `-only-testing` test name avoided them entirely.

## Task Commits

Each task was committed atomically (Task 1 was read-only, no commit):

1. **Task 1: Pre-flight grep — 8a79e6b residue absent in CleanupPrompt.swift** — read-only, no commit (no file changes)
2. **Task 2: Add `testWFewShotFromCommit8a79e6bIsAbsent` to macOS/DicticusTests/CleanupPromptTests.swift** — `7df3376` (test)

**Plan metadata commit (with SUMMARY.md, STATE.md, ROADMAP.md):** added at end of plan.

## Files Created/Modified

- `macOS/DicticusTests/CleanupPromptTests.swift` — +19 lines: 1 new MARK section + 1 XCTest method `testWFewShotFromCommit8a79e6bIsAbsent`. Inserted just before the final closing `}` of the `CleanupPromptTests` class (after the existing `testCurrencyExemplarFollowsTenseExemplarSwiss` method). Total file length 359 → 378 lines.

## Decisions Made

The plan was prescriptive (verbatim MARK text, verbatim method name, verbatim test body), so the only "decision" was honoring it literally. Notable design choices already locked in by the planner and re-affirmed in execution:

- **Verification-by-test, not revert.** RESEARCH.md and CONTEXT.md confirmed the 8a79e6b lines were already removed by the V5 rewrite (`e1d3eef`, 2026-05-05). Task 1's pre-flight grep re-confirmed this immediately before editing. The deliverable is therefore a regression net (`XCTAssertFalse`), not a hunk revert.
- **macOS-only.** No iOS counterpart added — `CleanupPromptTests` is macOS-exclusive by 20.06-01 precedent. The cross-platform parity rule (memory `feedback_cleanup_cross_platform_parity`) does NOT apply here because there is no iOS analog test class to mirror to.
- **Targeted test gate.** Used `-only-testing:DicticusTests/CleanupPromptTests/testWFewShotFromCommit8a79e6bIsAbsent` to avoid being blocked by pre-existing V5-drift failures in the rest of `CleanupPromptTests` (out of scope per RESEARCH.md and `.planning/.continue-here`).
- **CODE_SIGNING_ALLOWED=NO override.** Same flag used by Plan 01 — required because the local Dicticus.xcodeproj target requires a provisioning profile but tests do not need signed binaries.

## Deviations from Plan

None — plan executed exactly as written.

The plan's MARK text, method name, indentation conventions, test body, and acceptance-criteria greps were all followed verbatim. No code-quality issues triggered Rule 1/2/3 auto-fixes.

---

**Total deviations:** 0
**Impact on plan:** Plan executed atomically in 1 commit (Task 1 was read-only, no commit needed) with all acceptance criteria met. The targeted xcodebuild test reports `** TEST SUCCEEDED **` (1/1 in 0.001s).

## Issues Encountered

- **macOS xcodebuild initially failed with provisioning-profile error** — same root cause and same fix as Plan 01: pass `CODE_SIGNING_ALLOWED=NO` to xcodebuild test (test runs do not need signed binaries). Final macOS run reports `** TEST SUCCEEDED **`.

No other issues. No deferred items. No followups.

## Self-Check: PASSED

- Created file: `.planning/phases/22-resolver-regression-hotfix/22-02-SUMMARY.md` — written via Write tool (this file).
- Modified file: `macOS/DicticusTests/CleanupPromptTests.swift` — verified via `grep -c "func testWFewShotFromCommit8a79e6bIsAbsent"` returns `1` and `grep -c "MARK: - Phase 22 regression: 8a79e6b few-shot must be absent"` returns `1`.
- Production source untouched: `git diff Shared/Models/CleanupPrompt.swift` produces no output.
- Commit: `7df3376` — verified via `git log --oneline -3` shows `7df3376 test(cleanup-prompt): lock 8a79e6b few-shot absence as regression net`.
- Test gate: `** TEST SUCCEEDED **` with 1/1 passing in 0.001 seconds (transcript captured during execution).
