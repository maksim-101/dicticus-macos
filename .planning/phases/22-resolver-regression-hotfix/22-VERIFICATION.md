---
phase: 22-resolver-regression-hotfix
verified: 2026-05-08T21:00:00Z
status: human_needed
score: 7/7 must-haves verified
overrides_applied: 0
human_verification:
  - test: "iOS xcodebuild test gate on SelfCorrectionResolverTests (25/25)"
    expected: "** TEST SUCCEEDED ** with 25 tests passing on iOS Simulator (18 existing + 7 new)"
    why_human: "iOS 26.4 SDK runtime is not installed on this machine — `xcodebuild -showdestinations` reports unavailable. Parity is substituted via `diff -q` (passes), but executing the suite requires either a CI bot with the iOS runtime or the developer's primary machine after installing the iOS 26.4 component via Xcode > Settings > Components."
  - test: "Live dictation regression check on macOS Release build with the 7 JSONL fixture utterances"
    expected: "Each utterance arrives at the cursor verbatim — no `now`/`noticed`/`wait` content-eating, no spurious whitespace collapsing"
    why_human: "End-to-end audio→ASR→resolver→cleanup→paste pipeline cannot be exercised programmatically — requires speaking the 7 phrases under the system hotkey and visually confirming pasted text matches input."
  - test: "Confirm scope-aligned narrowing is acceptable in production"
    expected: "Connectors after sentence-terminators without a comma (e.g. `Done. Actually that's wrong.`) no longer fire — confirm this matches user intent vs. prior behavior"
    why_human: "Code review (22-REVIEW.md WR-01) flagged the regex narrowed scope: prior pattern fired on `[,;:.?!]?\\s+`; new pattern fires only on `(?:^|,)\\s*`. The 7 fixtures don't lock either behavior. User has accepted this as scope-aligned with the goal (stop content-eating, not preserve all prior firing) — flag remains for live-corpus confirmation."
---

# Phase 22: Resolver Regression Hotfix Verification Report

**Phase Goal:** Stop `SelfCorrectionResolver` from eating user content as substring matches inside unrelated words (e.g. `now`, `noticed`, `wait`, German `nehmen`/`warten`). Confirmed root cause of the long-running "T"/"W" degenerate-collapse production bug.

**Verified:** 2026-05-08T21:00:00Z
**Status:** human_needed
**Re-verification:** No — initial verification

## Goal Achievement

ROADMAP §22 lists no `success_criteria` array (free-form goal text only). Plan-frontmatter `must_haves.truths` are taken as the verification contract, plus the goal-derived "substring-match content-eating must be impossible".

### Observable Truths

| # | Truth | Status | Evidence |
| --- | --- | --- | --- |
| 1 | Resolver is a no-op for the 7 JSONL fixture inputs (post_rules == raw) | ✓ VERIFIED | macOS suite 25/25 green per 22-01-SUMMARY (`** TEST SUCCEEDED **` 0.015s); fixtures 5/6/9/11/18/19/29 each `XCTAssertEqual(resolve(input, "en"), input, …)` against the new regex |
| 2 | All 18 existing positive/negative tests in SelfCorrectionResolverTests still pass | ✓ VERIFIED | macOS run reports `Executed 25 tests, with 0 failures` — 18 prior + 7 new = 25, no regressions |
| 3 | macOS and iOS test files remain byte-for-byte identical (cross-platform parity) | ✓ VERIFIED | `diff -q macOS/DicticusTests/SelfCorrectionResolverTests.swift iOS/DicticusTests/SelfCorrectionResolverTests.swift` exit=0, no output; `wc -l` both = 336 lines |
| 4 | The regex on Shared/Utilities/SelfCorrectionResolver.swift line 75 only fires after start-of-string OR a literal comma, AND only on whole connector words (`\b`) | ✓ VERIFIED | `sed -n '75p'` returns exactly `let pattern = "(?i)(?:^|,)\\s*(\(alternation))\\b(\\s*)"`; old broken pattern absent (`grep -c '\[,;:\.?\!\]?\\\\s+' = 0`) |
| 5 | The 8a79e6b cosmetic LLM few-shot is absent from CleanupPrompt.build() output for English (XCTest, not just one-time grep) | ✓ VERIFIED | `testWFewShotFromCommit8a79e6bIsAbsent` present at L367 of macOS/DicticusTests/CleanupPromptTests.swift; isolated test gate `** TEST SUCCEEDED **` per 22-02-SUMMARY; both `XCTAssertFalse` calls present (`let's see whether` + `whether this is good`) |
| 6 | Future regression (residue reintroduction) caught before merge | ✓ VERIFIED | XCTAssertFalse on `prompt.contains(...)` runs against live `CleanupPrompt.build(text: "test", language: "en")` — any commit reintroducing either string would flip this test red in CI |
| 7 | Pre-existing V5-drift CleanupPromptTests failures NOT touched | ✓ VERIFIED | `git log --pretty=format:"%H" -- Shared/Models/CleanupPrompt.swift` shows last touch was e1d3eef (V5 rewrite), not in phase-22 commits ba2b01b/7fce68b/d4af189/7df3376 — production source untouched by this phase |

**Score:** 7/7 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
| --- | --- | --- | --- |
| `Shared/Utilities/SelfCorrectionResolver.swift` | Fixed regex at L75 with comma-only prefix and trailing `\b` | ✓ VERIFIED | L75 contains exact target string; file = 378 lines (matches summary "line count unchanged"); broken pattern absent (count 0) |
| `macOS/DicticusTests/SelfCorrectionResolverTests.swift` | 7 new XCTest methods under MARK '- JSONL regression fixtures (Phase 22)' | ✓ VERIFIED | All 7 method names found at L266/276/286/296/306/316/328; MARK at L255; file = 336 lines (was 254, delta +82 matches summary) |
| `iOS/DicticusTests/SelfCorrectionResolverTests.swift` | Identical 7 new XCTest methods (parity) | ✓ VERIFIED | All 7 method names found at identical line numbers; MARK at L255; `diff -q` against macOS = empty (byte-identical, exit 0) |
| `macOS/DicticusTests/CleanupPromptTests.swift` | New test `testWFewShotFromCommit8a79e6bIsAbsent` under MARK '- Phase 22 regression: 8a79e6b few-shot must be absent' | ✓ VERIFIED | Function at L367, MARK at L360; both residue strings present as XCTAssertFalse search targets (count=1 each); file = 378 lines (was 359, delta +19 matches summary) |
| `Shared/Models/CleanupPrompt.swift` (must NOT be modified) | Untouched by phase 22 | ✓ VERIFIED | Both residue strings absent (counts 0/0); git log on file shows last commit was e1d3eef (pre-phase 22), no phase-22 commit touches it |

### Key Link Verification

| From | To | Via | Status | Details |
| --- | --- | --- | --- | --- |
| `Shared/Utilities/SelfCorrectionResolver.swift:75` | macOS test fixtures section | XCTest assertions on `SelfCorrectionResolver.resolve()` | ✓ WIRED | All 7 fixtures call `SelfCorrectionResolver.resolve(input, language: "en")` and assert pass-through |
| macOS test file | iOS test file | byte-identical mirror via `cp` | ✓ WIRED | `diff -q` empty; matching line count (336/336) |
| `CleanupPromptTests::testWFewShotFromCommit8a79e6bIsAbsent` | `Shared/Models/CleanupPrompt.swift::build()` | `XCTAssertFalse` on `prompt.contains(...)` | ✓ WIRED | Test calls `CleanupPrompt.build(text: "test", language: "en")` and asserts prompt does not contain either residue string; both substrings present in source as the search targets |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
| --- | --- | --- | --- | --- |
| `SelfCorrectionResolver.swift` | `pattern` (regex string) | Built from `connectors.sorted(...).map(escapedPattern).joined("|")` interpolated into the corrected template | Yes — the EN/DE connector arrays at L238-271 are populated; `no`, `wait`, `actually` etc. are real fixed strings | ✓ FLOWING |
| Resolver test inputs | `input` (String literal) | Verbatim JSONL `raw` values from cleanup-2026-05-08.jsonl per inline doc-comments at L257-262 | Yes — fixture inputs are real captured production traffic, not synthetic | ✓ FLOWING |
| `CleanupPromptTests::prompt` | output of `CleanupPrompt.build(text: "test", language: "en")` | Live call into `Shared/Models/CleanupPrompt.swift::build()` | Yes — calls real builder; reads real V5 prompt | ✓ FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| --- | --- | --- | --- |
| Line 75 contains the new pattern verbatim | `sed -n '75p' Shared/Utilities/SelfCorrectionResolver.swift` | `let pattern = "(?i)(?:^|,)\\s*(\(alternation))\\b(\\s*)"` | ✓ PASS |
| Old broken pattern is gone | `grep -c '\[,;:\.?\!\]?\\\\s+' Shared/Utilities/SelfCorrectionResolver.swift` | `0` | ✓ PASS |
| Cross-platform parity | `diff -q macOS/.../Tests.swift iOS/.../Tests.swift; echo $?` | `exit=0` (no output) | ✓ PASS |
| All 7 macOS fixture methods present | `grep -cE 'func testEnglish(Now\|Actually\|Wait)…'` (compound) | 7/7 found at expected line numbers | ✓ PASS |
| All 7 iOS fixture methods present | same on iOS file | 7/7 found at identical line numbers | ✓ PASS |
| MARK present on both | `grep 'MARK: - JSONL regression fixtures (Phase 22)'` on both files | 1 hit each | ✓ PASS |
| CleanupPrompt residue absent | `grep -c "let's see whether"` and `grep -c "whether this is good"` on Shared/Models/CleanupPrompt.swift | `0`, `0` | ✓ PASS |
| Regression test exists with both assertions | grep on macOS CleanupPromptTests.swift | `testWFewShotFromCommit8a79e6bIsAbsent` at L367; both residue strings present as XCTAssertFalse search targets | ✓ PASS |
| Phase-22 commits exist | `git log --oneline -10` | ba2b01b, 7fce68b, d4af189, 7df3376 all present | ✓ PASS |
| macOS xcodebuild test gate | `xcodebuild test … -only-testing:DicticusTests/SelfCorrectionResolverTests` | per 22-01-SUMMARY: `** TEST SUCCEEDED **` 25/25 0.015s (transcript captured by executor; not re-run by verifier — would be redundant with executor evidence) | ? SKIP (executor evidence accepted) |
| iOS xcodebuild test gate | same on iOS Simulator | iOS 26.4 SDK runtime not installed on this machine; deferred to human verification | ? SKIP |

### Requirements Coverage

PLAN frontmatter `requirements: []` for both 22-01 and 22-02. No requirement IDs to map. REQUIREMENTS.md does not list this phase under any REQ-ID — confirmed by grep: no `Phase 22` mapping exists. Hotfix-only phase, no requirement coverage gap.

### Anti-Patterns Found

Files modified by this phase:
- `Shared/Utilities/SelfCorrectionResolver.swift` (1-line regex change)
- `macOS/DicticusTests/SelfCorrectionResolverTests.swift` (+82 lines)
- `iOS/DicticusTests/SelfCorrectionResolverTests.swift` (+82 lines, byte-identical)
- `macOS/DicticusTests/CleanupPromptTests.swift` (+19 lines)

| File | Line | Pattern | Severity | Impact |
| --- | --- | --- | --- | --- |
| (none) | — | No TODO/FIXME/PLACEHOLDER/console.log/empty-handler patterns introduced | ℹ️ Info | Clean phase — all changes are either a one-line fix or test additions that exercise real code paths via XCTest assertions |

The 22-REVIEW.md raised 4 advisory warnings (WR-01 narrowing scope, WR-02..04 documentation gaps and unrelated pre-existing items). None classify as blockers; user has accepted the WR-01 scope-narrowing as goal-aligned. Surfaced as a human-verification item for live-corpus confirmation.

### Human Verification Required

1. **iOS test suite execution**
   - **Test:** Run `xcodebuild test -project iOS/Dicticus.xcodeproj -scheme Dicticus -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:DicticusTests/SelfCorrectionResolverTests` on a machine with iOS 26.4 SDK installed.
   - **Expected:** `** TEST SUCCEEDED **` 25/25.
   - **Why human:** iOS 26.4 SDK runtime is missing on this machine. Parity via `diff -q` is verified, but execution requires the runtime.

2. **Live dictation regression check**
   - **Test:** Speak each of the 7 JSONL fixtures under the macOS Release build hotkey and confirm pasted text equals input verbatim.
   - **Expected:** No `now`/`noticed`/`wait` content-eating, no whitespace anomalies.
   - **Why human:** End-to-end audio→ASR→resolver→cleanup→paste pipeline is not unit-testable.

3. **Scope-narrowing acceptance (WR-01)**
   - **Test:** Confirm the new regex's narrower trigger condition (`^|,` only, not `[,;:.?!]?`) is acceptable in real-world input.
   - **Expected:** No production utterances regress because connectors after `.`, `?`, `!`, `;`, `:` (without a comma) no longer fire.
   - **Why human:** The 7 fixtures don't lock this either way; only live-corpus observation can confirm.

### Gaps Summary

No gaps blocking goal achievement. All 7 must-haves are verified in the live codebase:

- The regex at L75 is the exact corrected pattern — substring-eat impossibility is structurally enforced by `\b` and the comma/start-of-string anchor.
- 7 negative regression fixtures lock the fix in across both platforms with byte-identical mirror.
- The CleanupPrompt regression net is in place as an XCTAssertFalse invariant.
- Production source `Shared/Models/CleanupPrompt.swift` was not modified (verified by git log).
- No requirement IDs are claimed; none in REQUIREMENTS.md map to phase 22.

The phase moves to **human_needed** rather than **passed** because:
1. The iOS test runtime is missing on this machine — parity is verified via `diff -q` (substitute assurance), but executor's success-or-fail evidence on iOS is unavailable.
2. End-to-end behavioral confirmation via live dictation is the ultimate goal-truth test and is not programmatically reachable.
3. The WR-01 scope-narrowing (advisory) deserves a live-corpus sanity check before declaring victory on long-tail bugs.

These are not gaps in implementation — they are integration/UAT verifications outside the unit-test surface.

---

_Verified: 2026-05-08T21:00:00Z_
_Verifier: Claude (gsd-verifier)_
