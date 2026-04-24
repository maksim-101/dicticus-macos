# Phase 19 Deferred Items

Out-of-scope findings logged during Wave 1 execution. Do not fix inside this phase — they are pre-existing and unrelated to Phase 19 scope.

## macOS `DicticusTests/ITNUtilityTests/testMixedText` pre-existing failure

**Status:** FAILING on `feature/phase-19-ai-cleanup-ios` before Wave 1 began.
**Confirmed pre-existing:** Verified via `git stash` + re-test on commit `c3ee521` (Wave 1 Task 2b) — same failure reproduces.

**Symptom:**
```
XCTAssertEqual failed: ("There are five birds and one cat")
  is not equal to ("There are 5 birds and 1 cat")
```

**Root cause:** The English ITN in `Shared/Utilities/ITNUtility.swift` intentionally
gates on `minDigitThreshold = 10` — standalone digits < 10 are left spelled out
per the style guide ("spell out one through nine"). The macOS test
`testMixedText` asserts the opposite.

**Why not fixed:** Pre-existing test/code divergence outside Wave 1 scope.
Either the test expectation is wrong, or the threshold is wrong — decision
belongs to a dedicated ITN-review pass, not this phase.

**Recommendation:** Fix the test expectation to `"There are five birds and one cat"`
(preserving style-guide intent), or lower the threshold to 1 and accept
digit-rendering for all numeric tokens. A separate trivial PR.

---

*Logged: 2026-04-24 during Wave 1 execution (Plan 19-02 Task 3).*
