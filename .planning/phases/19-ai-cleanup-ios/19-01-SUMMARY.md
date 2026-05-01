---
phase: 19-ai-cleanup-ios
plan: 01
subsystem: testing
tags: [ios, testing, tdd-scaffold, xctest, wave-0, fixtures, mock-url-protocol]

# Dependency graph
requires:
  - phase: 19-ai-cleanup-ios
    provides: 19-VALIDATION.md Req→Test map (locked 2026-04-24)
provides:
  - Wave 0 XCTest scaffolds for CLEAN-01, CLEAN-02, D-03, D-04, D-06, D-08, D-10, D-13, D-15, D-16, D-17, D-19, D-23, D-28, Q6
  - Swiss German ß/ẞ fixture corpus (8 pairs)
  - Canary prompt fixture (3 DE + 3 EN, fuzzy-equality)
  - Reusable MockURLProtocol helper (chunked progress, Range header 206, failure injection)
affects: [19-02-ai-cleanup-ios, 19-03-ai-cleanup-ios, 19-04-ai-cleanup-ios, 19-05-ai-cleanup-ios, 19-06-ai-cleanup-ios]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "TDD RED scaffolding via isWaveNReady Bool flags + call-shims so target compiles while tests skip pending downstream feature code"
    - "Fixture-driven corpus tests — JSON in Fixtures/ directory auto-bundled by xcodegen into DicticusTests.xctest"
    - "Integration tests gated on DICTICUS_TEST_MODEL_PATH env var via XCTSkipIf"
    - "Canonical UserDefaults keys (aiCleanupEnabled, useSwissGerman) defined in tests so Wave 3 UI code must match"
    - "URLProtocol mock with nonisolated(unsafe) static state + reset() teardown idiom"

key-files:
  created:
    - iOS/DicticusTests/ITNUtilityTests.swift
    - iOS/DicticusTests/CleanupServiceTests.swift
    - iOS/DicticusTests/TextProcessingServiceTests.swift
    - iOS/DicticusTests/SettingsToggleTests.swift
    - iOS/DicticusTests/DeviceEligibilityTests.swift
    - iOS/DicticusTests/IOSModelDownloadServiceTests.swift
    - iOS/DicticusTests/Fixtures/SwissGerman.fixtures.json
    - iOS/DicticusTests/Fixtures/CanaryPrompts.json
    - iOS/DicticusTests/Helpers/MockURLProtocol.swift
  modified: []

key-decisions:
  - "Tests COMPILE today (sole-executor constraint) — RED state achieved via isWaveNReady Bool flags + call-shims instead of referencing undefined symbols. Wave 1/2 flip the flags + replace shim bodies to turn RED→GREEN."
  - "iPhone 17 simulator used as destination — iPhone 15 is not available in the current Xcode; no behavior delta."
  - "TextProcessingServiceTests, SettingsToggleTests, and one sanity test in each other file are CONCRETE (not skipped) — they exercise existing Shared/ code + test infrastructure that already compiles."

patterns-established:
  - "Pattern: isWaveNReady scaffold gate — flip to true when downstream waves land. Each test body begins with XCTSkipIf(!isWaveNReady, \"Pending Wave N: <symbol> not yet implemented\")."
  - "Pattern: callShim methods in test files isolate references to not-yet-existing APIs so the target compiles during scaffolding."
  - "Pattern: MockURLProtocol + URLSessionConfiguration.ephemeral for download-service tests without hitting the network."

requirements-completed: []  # CLEAN-01, CLEAN-02 are NOT complete — test scaffolds created, feature code lands in Waves 1-4.

# Metrics
duration: ~35 min
completed: 2026-04-24
---

# Phase 19 Plan 01: Wave 0 Test Scaffolding Summary

**Nyquist-compliant XCTest scaffolds for all 14 Req→Test rows in 19-VALIDATION.md, with compiling RED state and a reusable MockURLProtocol helper, so Waves 1-4 have concrete green targets.**

## Performance

- **Duration:** ~35 min
- **Started:** 2026-04-24T07:57:00Z
- **Completed:** 2026-04-24T08:32:04Z
- **Tasks:** 3
- **Files created:** 9
- **Files modified:** 0

## Accomplishments

- 6 XCTest scaffolds covering CLEAN-01, CLEAN-02, and 13 decision rows (D-03, D-04, D-06, D-08, D-10, D-13, D-15, D-16, D-17, D-19, D-23, D-28, Q6)
- 2 test fixtures (SwissGerman.fixtures.json: 8 ß/ẞ pairs incl. U+1E9E capital Eszett; CanaryPrompts.json: 3 DE + 3 EN with fuzzy `expected_contains` arrays)
- 1 reusable MockURLProtocol helper supporting chunked progress, Range-header resume (returns 206 Partial Content with Content-Range), and failure-after-N-bytes injection
- Full DicticusTests suite green on iPhone 17 simulator: **58 tests, 18 skipped cleanly, 0 failures**
- Every test-method name from the 19-VALIDATION.md Req→Test map is present and discoverable via `grep -l`

## Task Commits

1. **Task 1: ITNUtility tests + SwissGerman fixtures** — `638973c` (test)
2. **Task 2: CleanupService, TextProcessingService, Settings, Device tests + CanaryPrompts fixture** — `8102c20` (test)
3. **Task 3: IOSModelDownloadServiceTests + MockURLProtocol helper** — `6cab833` (test)

**Plan metadata commit:** added in final step after this summary file is written.

## Files Created

- `iOS/DicticusTests/ITNUtilityTests.swift` — Swiss ß/ẞ tests (D-16, D-17); testSwissGermanEszett, testSwissGermanCapitalEszett, testSwissGermanNoOp, testSwissGermanFixturesCorpus
- `iOS/DicticusTests/CleanupServiceTests.swift` — CLEAN-02 + D-04, D-06, D-19, D-28 scaffolds; testTimeoutFallback, testConcurrentCallGuard, testSwissSafetyNetGating, testBackToBackCallsIndependent, testRealModelInference, testCanaryPromptsFixtureIsBundled
- `iOS/DicticusTests/TextProcessingServiceTests.swift` — CONCRETE D-13 + D-23 tests; testCleanupPath, testPlainModeSkipsCleanup, testBlocksUntilCleaned, testCleanupSkippedWhenProviderNotLoaded (all green)
- `iOS/DicticusTests/SettingsToggleTests.swift` — CONCRETE D-08 + D-15 orthogonality tests; testAiCleanupDefaultOff, testSwissGermanDefaultOff, testTogglesAreOrthogonal, testBothTogglesCanBeOnSimultaneously (all green)
- `iOS/DicticusTests/DeviceEligibilityTests.swift` — D-03 RAM threshold scaffold; testRamThresholdConstantIsFiveGb, testIsAiCleanupSupportedOnCurrentDevice, testPhysicalMemoryIsReadable
- `iOS/DicticusTests/IOSModelDownloadServiceTests.swift` — D-10 + Q6 scaffold; testProgressCallbacks, testPauseResume, testBackupExclusion, testMockURLProtocolHonorsRangeHeader
- `iOS/DicticusTests/Fixtures/SwissGerman.fixtures.json` — 8 input/expected ß pairs
- `iOS/DicticusTests/Fixtures/CanaryPrompts.json` — 6 cleanup canaries (3 DE, 3 EN) with `expected_contains` fuzzy arrays
- `iOS/DicticusTests/Helpers/MockURLProtocol.swift` — URLProtocol mock with chunkCount/chunkDelay/failAfterBytes + Range-header 206 response

## Decisions Made

- **Compile-compatible RED state.** The plan's `<acceptance_criteria>` explicitly states "Files will NOT compile yet against current iOS target … intended RED state." The executor constraint requires "iOS target must still compile and existing test suite must still pass." These are in tension. Resolved by introducing `isWaveNReady` Bool flags and call-shim methods (e.g. `callSwissITN`) so the target compiles today and every assertion is documented in comments for Wave 1/2 to fill in. This preserves the TDD contract (tests are red — skipped with "Pending Wave N") without breaking the build. See Deviations §1.
- **iPhone 17 simulator substitution.** iPhone 15 is not installed in this Xcode; iPhone 17 (iOS 26.3.1) is. No behavior delta — same iOS simulator runtime. Wave 1-4 plans should use `iPhone 17` or update the canonical quick-run command in 19-VALIDATION.md.
- **TextProcessingServiceTests are concrete, not skipped.** `TextProcessingService` and `CleanupProvider` already ship in `Shared/`, so the D-13 / D-23 / CLEAN-01 tests run today against a local `MockCleanupProvider`. Four concrete assertions are green.
- **SettingsToggleTests define canonical UserDefaults keys** — `"aiCleanupEnabled"` and `"useSwissGerman"` with suite `"group.com.dicticus"`. Wave 3 SettingsView must use these exact strings in `@AppStorage`.
- **IOSModelDownloadServiceTests document the required Wave 2 test seams** inline (class-level doc-comment) — `init(sessionConfiguration:)`, `startAndWaitForCompletion()`, `waitForCompletion()`, static `modelURL`/`modelFileName`/`modelPath()`. Wave 2 MUST expose these or the tests cannot turn green.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Replaced "intentionally uncompilable RED tests" with compile-clean scaffolds**
- **Found during:** Task 1 (ITNUtilityTests)
- **Issue:** The plan's `<acceptance_criteria>` state that test files SHOULD fail to compile until Wave 1/2 land (`applySwissITN`, `CleanupService`, `IOSModelDownloadService` not yet added). The executor prompt, however, requires "The iOS target must still compile and the existing test suite must still pass after your changes." These two are mutually exclusive as written.
- **Fix:** Introduced `isWaveNReady: Bool = false` gates + `callSwissITN(_:)` / `makeService()` style call-shims in every scaffold file that references not-yet-existing symbols. Test bodies start with `try XCTSkipIf(!isWaveNReady, "Pending Wave N: …")` and assertions live behind the flag. Wave 1 flips the flag and replaces the shim body with a direct call; no test-name or intent changes needed. Every test-method name from 19-VALIDATION.md Req→Test map is preserved.
- **Files modified:** all 6 test scaffold files
- **Verification:** `xcodebuild test -only-testing:DicticusTests` → 58 tests, 18 skipped, 0 failures on iPhone 17 simulator
- **Committed in:** 638973c (Task 1), 8102c20 (Task 2), 6cab833 (Task 3)

**2. [Rule 3 - Blocking] iPhone 15 simulator unavailable — used iPhone 17**
- **Found during:** Baseline build before Task 1
- **Issue:** Current Xcode install has iPhone 16e, 17, 17 Pro/Max, 17e, and iPhone Air simulators but no iPhone 15. Plan/VALIDATION commands reference `platform=iOS Simulator,name=iPhone 15`.
- **Fix:** Used `iPhone 17` (iOS 26.3.1) for all build + test runs. Same simulator runtime family. Recommend updating 19-VALIDATION.md's quick-run command for downstream waves.
- **Files modified:** none
- **Verification:** All 58 tests run on iPhone 17 with 0 failures.
- **Committed in:** n/a (documentation-only deviation, noted here)

---

**Total deviations:** 2 auto-fixed (2 blocking)
**Impact on plan:** Zero functional scope delta. The scaffolding still serves its Nyquist purpose — every downstream verify hook now points at a named test method that either runs today (existing-symbol tests) or skips with "Pending Wave N: <symbol>" (not-yet-existing-symbol tests). The shim pattern is strictly additive — Wave 1/2 code only needs to (a) add the documented symbol and (b) flip the `isWaveNReady` flag.

## Issues Encountered

- **Simulator preflight failure** during the first full-suite run after Task 3 — `com.dicticus.ios` could not launch (SBMainWorkspace "Busy"). Resolved via `xcrun simctl shutdown all` + reboot of iPhone 17 sim. Second run succeeded. Tracking only; no code change.

## Wave 1 / Wave 2 Handoff — Required Seams

### Wave 1 must add (to turn Swiss ITN tests green)

```swift
// Shared/Utilities/ITNUtility.swift
extension ITNUtility {
    static func applySwissITN(to text: String) -> String { /* … */ }
}
```
Then in `iOS/DicticusTests/ITNUtilityTests.swift`:
- Flip `isWave1Ready = true`
- Replace `callSwissITN` body with `return ITNUtility.applySwissITN(to: text)`

### Wave 1 must add (to turn CleanupService tests green)

- `Shared/Services/CleanupService.swift` conforming to `CleanupProvider` with the D-01/D-02/D-04..D-06/D-19/D-27/D-28 pipeline
- In `CleanupServiceTests.swift`: flip `isCleanupServiceReady = true`, fill in the documented TODO bodies

### Wave 2 must add (to turn download/eligibility tests green)

- `iOS/Dicticus/Services/IOSModelDownloadService.swift` with the documented test seams:
  - `init(sessionConfiguration: URLSessionConfiguration)`
  - `static var modelURL: URL`
  - `static var modelFileName: String = "gemma-4-E2B-it-Q4_K_M.gguf"`
  - `static func modelPath() -> URL`
  - `static func isModelCached() -> Bool`
  - `@Published var state: DownloadState` (`.idle/.downloading/.paused/.completed/.failed`)
  - `@Published var progress: Double`
  - `func start()`, `func pause()`, `func resume()`
  - `func startAndWaitForCompletion() async`, `func waitForCompletion() async` (test-helpers)
- `IOSModelWarmupService.ramThresholdBytes: UInt64` and `static var isAiCleanupSupported: Bool`
- In `IOSModelDownloadServiceTests.swift` + `DeviceEligibilityTests.swift`: flip `isWave2Ready = true`

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- All 6 scaffolds compile against the current iOS target (Swift 6, iOS 17 deployment)
- DicticusTests target includes `Fixtures/*.json` + `Helpers/*.swift` automatically via xcodegen's recursive source path resolution (verified: `SwissGerman.fixtures.json` and `CanaryPrompts.json` both ship inside `DicticusTests.xctest` bundle)
- Wave 1 (Swiss ITN + CleanupService extract) and Wave 2 (Download + RAM eligibility) can begin immediately — verify hooks are already wired
- iPhone 17 simulator runtime confirmed working; recommend updating 19-VALIDATION.md quick-run command

## Self-Check

```
FOUND: iOS/DicticusTests/ITNUtilityTests.swift
FOUND: iOS/DicticusTests/CleanupServiceTests.swift
FOUND: iOS/DicticusTests/TextProcessingServiceTests.swift
FOUND: iOS/DicticusTests/SettingsToggleTests.swift
FOUND: iOS/DicticusTests/DeviceEligibilityTests.swift
FOUND: iOS/DicticusTests/IOSModelDownloadServiceTests.swift
FOUND: iOS/DicticusTests/Fixtures/SwissGerman.fixtures.json
FOUND: iOS/DicticusTests/Fixtures/CanaryPrompts.json
FOUND: iOS/DicticusTests/Helpers/MockURLProtocol.swift
FOUND commit: 638973c
FOUND commit: 8102c20
FOUND commit: 6cab833
```

## Self-Check: PASSED

---
*Phase: 19-ai-cleanup-ios*
*Completed: 2026-04-24*
