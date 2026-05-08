---
phase: 22-resolver-regression-hotfix
plan: 01
subsystem: cleanup-pipeline
tags: [resolver, regex, hotfix, xctest, cross-platform-parity, self-correction]

requires:
  - phase: 21-adaptive-cleanup-stability
    provides: SelfCorrectionResolver re-enabled in AI mode (commit 55f6b73, bffe1ad); DEBUG_RECORDER scheme that captured the JSONL fixtures (4080462)
provides:
  - "Comma-prefix + word-boundary regex at SelfCorrectionResolver.swift:75"
  - "7 negative-fixture XCTest methods on macOS and iOS (byte-identical)"
  - "Regression net for the 'now/noticed/wait substring-eat' bug class"
affects: [phase-23-decimal-words-digit-grouping, future-cleanup-pipeline-changes]

tech-stack:
  added: []
  patterns:
    - "Negative-fixture XCTests as regression net for regex hot-spots (per memory feedback_tests_as_regression_nets)"
    - "Cross-platform test parity via direct cp instead of manual mirror (per memory feedback_cleanup_cross_platform_parity)"

key-files:
  created: []
  modified:
    - "Shared/Utilities/SelfCorrectionResolver.swift (1-line regex fix at L75)"
    - "macOS/DicticusTests/SelfCorrectionResolverTests.swift (+82 lines: 1 MARK + 7 XCTest methods)"
    - "iOS/DicticusTests/SelfCorrectionResolverTests.swift (+82 lines: byte-identical mirror)"

key-decisions:
  - "Regex prefix narrowed from '(?:[,;:.?!]?\\\\s+|,\\\\s*)' to '(?:^|,)\\\\s*' — only fire at start-of-string OR after a literal comma; the broken optional-punctuation alternative fired on plain whitespace"
  - "Trailing '\\\\b' added so connector '\\\\b' before the trailing whitespace group anchors connectors to whole words; blocks 'no' eating 'now'/'noticed' and 'wait' eating 'waitress'"
  - "No connector partition needed: existing 'guard !backwardTokens.isEmpty' at L160 already handles ambiguous start-of-string matches"
  - "iOS parity via direct 'cp' (not retype) so whitespace can never drift"

patterns-established:
  - "JSONL regression fixtures live under MARK '- JSONL regression fixtures (Phase 22)' at the bottom of the resolver test class"
  - "Resolver pass-through pattern: XCTAssertEqual(SelfCorrectionResolver.resolve(input, language: 'en'), input, ...)"

requirements-completed: []

duration: 12min
completed: 2026-05-08
---

# Phase 22 Plan 01: Resolver Regression Hotfix Summary

**Comma-prefix + `\b` word-boundary regex at SelfCorrectionResolver.swift:75 with 7 verbatim JSONL regression fixtures locked in across both macOS and iOS test targets.**

## Performance

- **Duration:** ~12 min
- **Started:** 2026-05-08T18:00:00Z
- **Completed:** 2026-05-08T18:12:25Z
- **Tasks:** 3
- **Files modified:** 3

## Accomplishments
- Replaced the broken `(?i)(?:[,;:.?!]?\s+|,\s*)(connector)(\s*)` regex with the corrected `(?i)(?:^|,)\s*(connector)\b(\s*)` — eliminates the optional-punctuation prefix that fired on plain whitespace, and adds a trailing `\b` that blocks substring matches inside `now`/`noticed`/`waitress` etc.
- Added 7 verbatim JSONL fixtures (records 5/6/9/11/18/19/29 from `cleanup-2026-05-08.jsonl` captured by `Dicticus-Debug-Recorder`) as XCTest methods under a new MARK section.
- Maintained cross-platform parity: macOS and iOS test files remain byte-for-byte identical (`diff -q` produces no output).
- Full `SelfCorrectionResolverTests` suite expanded from 18 → 25 tests on macOS, all green (`** TEST SUCCEEDED **` in 0.015s).

## Task Commits

Each task was committed atomically:

1. **Task 1: Replace the broken regex on line 75 of SelfCorrectionResolver.swift** — `ba2b01b` (fix)
2. **Task 2: Add 7 JSONL regression fixture tests to macOS/DicticusTests/SelfCorrectionResolverTests.swift** — `7fce68b` (test)
3. **Task 3: Mirror the 7 new tests into iOS/DicticusTests/SelfCorrectionResolverTests.swift (cross-platform parity)** — `d4af189` (test)

**Plan metadata commit (with SUMMARY.md, STATE.md, ROADMAP.md):** added at end of plan.

## Files Created/Modified
- `Shared/Utilities/SelfCorrectionResolver.swift` — single-line regex change at L75; line count unchanged (378 lines).
- `macOS/DicticusTests/SelfCorrectionResolverTests.swift` — added MARK `// MARK: - JSONL regression fixtures (Phase 22)` and 7 XCTest methods (254 → 336 lines).
- `iOS/DicticusTests/SelfCorrectionResolverTests.swift` — direct `cp` mirror of macOS file (parity guaranteed by `diff -q`).

## Decisions Made

The plan was highly prescriptive (verbatim regex string, verbatim test method names, verbatim MARK text), so the only "decision" was honoring the plan literally. Notable design choices made during planning and re-affirmed during execution:

- **Use `cp` for the iOS mirror, not manual retyping.** This guarantees byte-identical parity (a hard gate in this plan) without any whitespace-drift risk. The `@testable import Dicticus` line works on both targets because each Xcode target compiles its own `Dicticus` module name.
- **No connector partition.** The existing `guard !backwardTokens.isEmpty else { continue }` at L160 already handles the ambiguous start-of-string case where `^` matches but there's no preceding context to validate. Adding a partition would be over-engineering.

## Deviations from Plan

None - plan executed exactly as written.

The plan's regex string, 7 method names, MARK text, indentation conventions, and `cp` command for the iOS mirror were all followed verbatim. No code-quality issues triggered Rule 1/2/3 auto-fixes.

---

**Total deviations:** 0
**Impact on plan:** Plan was executed atomically across 3 commits with all acceptance criteria met on macOS. iOS test execution was blocked by a missing iOS Simulator runtime on this machine (see "Issues Encountered"); however, the iOS test file is byte-identical to the macOS file which is verified green at 25/25.

## Issues Encountered

- **macOS xcodebuild initially failed with provisioning-profile error** — resolved by passing `CODE_SIGNING_ALLOWED=NO` (test runs do not need signed binaries). Final macOS run reports `** TEST SUCCEEDED **` with `Executed 25 tests, with 0 failures (0 unexpected) in 0.015 seconds`.
- **iOS Simulator runtime unavailable on this machine** — `xcrun simctl list devices available` shows iOS 18.0/18.5/26.3/26.4 all marked Unavailable; `xcodebuild -showdestinations` reports `iOS 26.4 is not installed`. The iOS test file is byte-identical to the macOS file (`diff -q` produces no output), and the same `SelfCorrectionResolver` source is compiled into both targets, so the macOS green run is equivalent verification of the test logic. iOS execution will run cleanly in a CI / build-bot environment with iOS Simulator runtimes installed, or on the developer's primary machine when the iOS 26.4 SDK component is downloaded via Xcode > Settings > Components. Documented in commit `d4af189` body.

## Self-Check: PASSED

Files exist:
- ✓ `Shared/Utilities/SelfCorrectionResolver.swift` (line 75 contains `let pattern = "(?i)(?:^|,)\\s*(\(alternation))\\b(\\s*)"`)
- ✓ `macOS/DicticusTests/SelfCorrectionResolverTests.swift` (7 new methods + MARK present, grep verified)
- ✓ `iOS/DicticusTests/SelfCorrectionResolverTests.swift` (byte-identical to macOS counterpart, `diff -q` empty)

Commits exist (verified via `git log --oneline -4`):
- ✓ `ba2b01b` — fix(resolver): tighten regex to comma-prefix + word-boundary suffix
- ✓ `7fce68b` — test(resolver): add 7 JSONL regression fixtures (Phase 22, macOS)
- ✓ `d4af189` — test(resolver): mirror 7 JSONL regression fixtures to iOS (parity)

Tests:
- ✓ macOS: `** TEST SUCCEEDED **` (25 tests = 18 existing + 7 new, all green, 0.015s)
- ⚠ iOS: not executed locally (iOS 26.4 SDK not installed); parity-verified instead via `diff -q`

## Next Phase Readiness

- **Plan 22-02 ready to execute.** Wave 2 (`8a79e6b` CleanupPrompt regression net: pre-flight grep + one `XCTAssertFalse` test; no production source touched). No dependencies on this plan beyond the test infrastructure already in place.
- **Phase 23 (Decimal Words & Digit Grouping)** — backlog ITN regression class. Resolver hotfix unblocks Phase 22 from shipping clean.
- **iOS Simulator runtime gap** — flag for the developer to install iOS 26.4 components via Xcode > Settings > Components before the next iOS-targeted phase, so iOS xcodebuild gates can run locally.

---
*Phase: 22-resolver-regression-hotfix*
*Completed: 2026-05-08*
