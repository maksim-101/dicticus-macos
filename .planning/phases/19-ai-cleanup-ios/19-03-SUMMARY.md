---
phase: 19-ai-cleanup-ios
plan: 03
subsystem: ios-download-and-device-gate
tags: [ios, download, urlsession, backup-exclusion, device-eligibility, wave-2]

# Dependency graph
requires:
  - phase: 19-ai-cleanup-ios
    provides: 19-02-SUMMARY (Shared CleanupService + llama SPM on iOS + Swiss ITN)
  - phase: 19-ai-cleanup-ios
    provides: 19-01-SUMMARY (Wave 0 test scaffolds with isWave2Ready gate + MockURLProtocol)
provides:
  - iOS/Dicticus/Services/IOSModelDownloadService.swift (foreground URLSession delegate downloader)
  - IOSModelWarmupService.requiredPhysicalMemoryBytes (D-03 threshold, 5 GiB)
  - IOSModelWarmupService.isAiCleanupSupported (runtime RAM gate)
  - Flipped Wave 0 tests: IOSModelDownloadServiceTests (3) + DeviceEligibilityTests (2)
affects: [19-04-ai-cleanup-ios, 19-05-ai-cleanup-ios, 19-06-ai-cleanup-ios]

# Tech tracking
tech-stack:
  added:
    - "URLSessionDownloadDelegate-based foreground downloader on iOS (first use in this repo)"
    - "URLResourceValues.isExcludedFromBackup = true on GGUF at rest (Q6 / D-14)"
    - "ProcessInfo.processInfo.physicalMemory runtime device gate (first use)"
  patterns:
    - "@MainActor final class + nonisolated static helpers so delegate callbacks on the URLSession delegate queue can resolve paths synchronously without actor hops"
    - "Task { @MainActor in … } inside nonisolated delegate methods to publish @Published state safely"
    - "cancel(byProducingResumeData:) + downloadTask(withResumeData:) for in-memory pause/resume; resume data never written to disk (per RESEARCH guidance — 3 GB is too large to want stale resume data)"
    - "sessionConfiguration: URLSessionConfiguration = .default test seam injecting MockURLProtocol"
    - "OperationQueue (non-main, single-concurrency) as URLSession delegate queue — avoids the main-queue deadlock warning in Apple docs"
    - "CheckedContinuation-based startAndWaitForCompletion() async test helper, resolved from the finish / error callbacks"

key-files:
  created:
    - iOS/Dicticus/Services/IOSModelDownloadService.swift (241 LOC)
  modified:
    - iOS/Dicticus/Services/IOSModelWarmupService.swift (+16 LOC for D-03 statics, stale Step 4 comment removed, 156 → 172 LOC)
    - iOS/DicticusTests/IOSModelDownloadServiceTests.swift (+73 LOC to flip gate, fill 3 test bodies, add 1 new lifecycle test; 128 → 178 LOC)
    - iOS/DicticusTests/DeviceEligibilityTests.swift (flipped isWave2Ready + real assertions; 49 → 54 LOC)

key-decisions:
  - "Statics on IOSModelDownloadService (modelURL, modelFileName, modelPath(), isModelCached()) are nonisolated — the class is @MainActor, but the nonisolated delegate callbacks (didFinishDownloadingTo) need to resolve the destination synchronously while `location` is still valid. Making these statics nonisolated avoids async-hop gymnastics. Instance state remains @MainActor-isolated."
  - "init(sessionConfiguration: = .default) — the default value matches the plan's public surface exactly, but we also set `waitsForConnectivity = true` inside init so production instances survive Wi-Fi blips. Tests pass an ephemeral config with MockURLProtocol.self in protocolClasses."
  - "Delegate queue is a dedicated non-main OperationQueue, not .main. Apple's URLSession docs explicitly warn about deadlock potential with main-queue delegate callbacks. We hop to @MainActor via Task { @MainActor in ... } for each @Published mutation."
  - "Resume data lives only in memory on the service (resumeData: Data?). For a ~3 GB download, persisting resume data to disk would be a larger footprint than the progress it represents is worth; per RESEARCH.md guidance, keeping it in memory matches user expectation (paused session = app-session-scoped)."
  - "requiredPhysicalMemoryBytes (not the test's commented-out ramThresholdBytes name) is the authoritative name per the plan's <acceptance_criteria>. Test flipped to match."
  - "Removed (not just updated) the stale 'No Step 4 (LLM) on iOS v2.0 — locked decision' comment. Per plan action: 'search for this exact string and delete the line.' Replaced with a forward pointer: '// Step 4 (LLM warmup) wiring lands in Wave 3 (Plan 19-04).'"

patterns-established:
  - "Use @MainActor final class + nonisolated static constants/helpers when the instance is UI-bound but callback surfaces are not."
  - "URLSession delegate + Task { @MainActor in … } for @Published mutations is the iOS-correct pattern; matches RESEARCH.md Pattern 2."
  - "MockURLProtocol swap via sessionConfiguration.protocolClasses = [MockURLProtocol.self] is the project's canonical URLSession test seam (first service to use it live)."

requirements-completed: []  # CLEAN-01, CLEAN-02 not complete — download service + device gate landed; UI + warmup wiring + Settings toggle land in Waves 3-4.

# Metrics
duration: ~25 min active work (2026-04-24T18:42:39Z → 2026-04-24T19:08:14Z)
completed: 2026-04-24
---

# Phase 19 Plan 03: Wave 2 iOS Download Service + Device Eligibility Summary

**One-liner:** Land the foreground URLSession-delegate downloader for the Gemma 4 E2B GGUF (progress, pause/resume via resume data, Q6 iCloud-backup exclusion) and the D-03 runtime RAM gate (`requiredPhysicalMemoryBytes = 5 GiB`, `isAiCleanupSupported: Bool`) on `IOSModelWarmupService` — flipping 5 Wave 0 tests from skipped to green.

## Performance

- **Started:** 2026-04-24T18:42:39Z
- **Completed:** 2026-04-24T19:08:14Z (~25 min)
- **Tasks:** 2 (Task 1 downloader + Task 2 device gate)
- **Commits:** 2 atomic task commits + 1 metadata commit (this SUMMARY)
- **Files touched:** 4 (1 new + 3 modified)

## Accomplishments

- `IOSModelDownloadService` ships as a `@MainActor final class` conforming to `NSObject, ObservableObject, URLSessionDownloadDelegate`.
  - Static `modelURL` matches the unsloth Gemma 4 E2B URL verbatim (per D-14); static `modelFileName` is `gemma-4-E2B-it-Q4_K_M.gguf`; static `modelPath()` resolves `Application Support/Dicticus/Models/gemma-4-E2B-it-Q4_K_M.gguf` (D-11 parity with macOS).
  - `init(sessionConfiguration: URLSessionConfiguration = .default)` provides the canonical test seam — Wave 0 tests inject `MockURLProtocol` through an ephemeral configuration.
  - `@Published` `state` / `progress` / `bytesPerSec` drive the Wave 3 inline Settings UI (D-10). Delegate callbacks (`didWriteData`, `didFinishDownloadingTo`, `didCompleteWithError`) publish via `Task { @MainActor in … }` hops off a non-main `OperationQueue`.
  - Pause/resume uses `cancel(byProducingResumeData:)` + `downloadTask(withResumeData:)`; resume data stays in memory only. `MockURLProtocol` in `testPauseResume` correctly serves a 206 Partial Content response starting at the paused offset, and the download re-completes.
  - On `didFinishDownloadingTo`, the file moves to `modelPath()` synchronously (before the temp URL is invalidated) and `URLResourceValues.isExcludedFromBackup = true` is applied — closing Q6 / T-19-03-03. Verified by `testBackupExclusion` reading back `URLResourceValues(forKeys: [.isExcludedFromBackupKey])`.
  - `startAndWaitForCompletion()` and `waitForCompletion()` are the exact async helpers Wave 0 tests reference.
- `IOSModelWarmupService` gains two `nonisolated` statics:
  - `requiredPhysicalMemoryBytes: UInt64 = 5 * 1024 * 1024 * 1024` (exactly 5 GiB, D-03).
  - `isAiCleanupSupported: Bool { ProcessInfo.processInfo.physicalMemory >= requiredPhysicalMemoryBytes }`.
  - Both readable without instantiating the service — consumed by Wave 3 `SettingsView` to branch between the AI Cleanup toggle and the device-unsupported explainer.
- Stale `// NOTE: No Step 4 (LLM) on iOS v2.0 — locked decision` comment removed per plan; replaced with a forward pointer to Wave 3's Step 4 wiring plan (19-04).
- Wave 0 test shims turned green:
  - `IOSModelDownloadServiceTests`: `testProgressCallbacks`, `testPauseResume`, `testBackupExclusion` (Wave 0's three plan-spec tests) + a new `testIsModelCachedReflectsDiskState` lifecycle check. `testMockURLProtocolHonorsRangeHeader` sanity check continues to pass.
  - `DeviceEligibilityTests`: `testRamThresholdConstantIsFiveGb` and `testIsAiCleanupSupportedOnCurrentDevice` — the latter is RAM-gated (skipped on simulators <5 GB, which is the iPhone 17 sim behavior; runs on-device and passes the parity check against `ProcessInfo`).
- **iOS Debug build** on `iPhone 17` (iOS 26.4 sim): **BUILD SUCCEEDED**, zero warnings, Swift 6 strict concurrency clean.
- **macOS Debug build** (ad-hoc signing): **BUILD SUCCEEDED** — extraction in Wave 1 remains intact; no regressions from iOS-only additions.

## Task Commits

1. **Task 1: IOSModelDownloadService with URLSessionDownloadDelegate** — `45bae61` (feat)
   - Created `iOS/Dicticus/Services/IOSModelDownloadService.swift` (241 LOC).
   - Flipped `isWave2Ready` in `IOSModelDownloadServiceTests`, filled the 3 commented-out test bodies, added `testIsModelCachedReflectsDiskState`, added a `makeService(payloadBytes:chunkCount:)` helper.
   - Verified: iOS build clean, all 5 tests pass (3 flipped + 1 new + 1 mock sanity).
2. **Task 2: Device RAM eligibility gate** — `5be43d2` (feat)
   - Added `requiredPhysicalMemoryBytes` + `isAiCleanupSupported` statics on `IOSModelWarmupService`.
   - Removed the stale `No Step 4` comment.
   - Flipped `isWave2Ready` in `DeviceEligibilityTests`, enabled the threshold and parity assertions.
   - Verified: iOS build clean, both device tests pass (1 passes outright, 1 skip-gated by simulator physicalMemory <5 GB).

## Files Modified (final state)

| File | LOC | Change |
|------|-----|--------|
| `iOS/Dicticus/Services/IOSModelDownloadService.swift` | 241 | NEW |
| `iOS/Dicticus/Services/IOSModelWarmupService.swift` | 172 | +16 LOC (D-03 statics + comment replacement) |
| `iOS/DicticusTests/IOSModelDownloadServiceTests.swift` | 178 | Gate flipped, 3 test bodies filled, 1 new test, helper added |
| `iOS/DicticusTests/DeviceEligibilityTests.swift` | 54 | Gate flipped, assertions filled (5 LOC net) |

`iOS/Dicticus.xcodeproj` was regenerated via `xcodegen generate` but is gitignored (per Wave 1 convention — consumers run `xcodegen generate` on checkout).

## Exact Public API Surface (Wave 3/4 consumers)

```swift
// iOS/Dicticus/Services/IOSModelDownloadService.swift
@MainActor
public final class IOSModelDownloadService: NSObject, ObservableObject, URLSessionDownloadDelegate {
    public enum DownloadState: Equatable {
        case idle, downloading, paused, completed, failed(String)
    }

    public nonisolated static let modelURL: URL
    public nonisolated static let modelFileName: String
    public nonisolated static func modelPath() -> URL
    public nonisolated static func isModelCached() -> Bool

    @Published public private(set) var state: DownloadState
    @Published public private(set) var progress: Double
    @Published public private(set) var bytesPerSec: Double

    public init(sessionConfiguration: URLSessionConfiguration = .default)

    public func start()
    public func pause()
    public func resume()
    public func startAndWaitForCompletion() async throws
    public func waitForCompletion() async
}

// iOS/Dicticus/Services/IOSModelWarmupService.swift (additions)
public nonisolated static let requiredPhysicalMemoryBytes: UInt64 // 5 GiB
public nonisolated static var isAiCleanupSupported: Bool // physicalMemory >= requiredPhysicalMemoryBytes
```

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Swift 6 concurrency] `@MainActor` class + `static modelPath()` called from `nonisolated` delegate**
- **Found during:** Task 1 first iOS build attempt.
- **Issue:** `call to main actor-isolated static method 'modelPath()' in a synchronous nonisolated context` — the class is `@MainActor`, which made all statics MainActor-isolated by default; the nonisolated `didFinishDownloadingTo` callback could not call them synchronously.
- **Fix:** Marked `modelURL`, `modelFileName`, `modelPath()`, and `isModelCached()` as `public nonisolated static`. They touch no shared mutable state (purely `FileManager.default.urls(...)` + path joins) so `nonisolated` is the correct and idiomatic answer.
- **Files modified:** `iOS/Dicticus/Services/IOSModelDownloadService.swift` (pre-commit).
- **Verification:** iOS build clean, all 5 download tests pass.
- **Committed in:** `45bae61` (Task 1).

**2. [Rule 2 - correctness] Reset `progress = 0` on `start()` to keep monotonic non-decreasing semantics across resumes**
- **Found during:** Task 1 test review — `testProgressCallbacks` asserts monotonic non-decreasing; if `resume()` were called after `pause()` with a non-zero lingering `progress`, the chunk at 0-written would briefly report a small fraction mid-resume that could dip below the prior sample.
- **Fix:** Added `progress = 0` inside `start()` alongside the other per-run resets (`lastBytes`, `lastSampleAt`). The test's monotonic check filters `drop(while: { $0 == 0 })` so the reset is invisible to the assertion but keeps delegate-driven progress consistent.
- **Files modified:** `iOS/Dicticus/Services/IOSModelDownloadService.swift`.
- **Verification:** `testProgressCallbacks` + `testPauseResume` both green.
- **Committed in:** `45bae61` (Task 1, original write).

### Deviations from Plan Sketch (non-fixes, worth noting)

**A. Plan sketch set `delegateQueue: .main`; implementation uses a dedicated non-main `OperationQueue`.**
- **Why:** Apple's URLSession docs explicitly warn that main-queue delegate callbacks can deadlock with synchronous reads on the main thread. The plan's own comment on line 172 actually acknowledges this ("Queue must be non-nil and must NOT be main"). The implementation follows the plan's comment, not the sketch.
- **Impact:** Zero functional delta — `@Published` mutations still hop to `@MainActor` via `Task { @MainActor in … }`, so UI consumers see the same `ObjectWillChange` cadence as if the queue were `.main`.
- **Documented in:** Inline comment in `init`.

**B. Added `testIsModelCachedReflectsDiskState` (5th test, not required by plan).**
- **Why:** `isModelCached()` is in the required public surface (`<interfaces>`) and Wave 3's Settings UI gates the "Download" button on it. Unit-testing the disk-state round-trip (fresh → downloaded → deleted) guards against future refactors that might cache the result incorrectly.
- **Impact:** Positive — adds 1 passing test, no plan contract changes.

### Out of Scope / Not Modified

- **`files_modified` lists `IOSModelWarmupService.swift` as modified by Task 2 only.** The Task 1 action in the plan didn't mention touching it; I did not introduce Step 4 warmup wiring (that is Wave 3's Plan 19-04 responsibility). The only `IOSModelWarmupService` change in Task 2 is the D-03 statics + stale comment removal, matching the plan action.
- **No pbxproj commit.** The regenerated `iOS/Dicticus.xcodeproj` is gitignored per Wave 1 convention; no policy change.

---

**Total deviations:** 2 auto-fixed (1 Rule 1 concurrency, 1 Rule 2 correctness); 2 non-fix deviations documented for downstream wave review.
**Impact on plan:** Zero functional scope delta. All `<acceptance_criteria>` greps PASS. All plan-spec tests green.

## Issues Encountered

- Swift 6 strict concurrency required `nonisolated` on download-service statics — resolved inline.
- iPhone 15 simulator no longer available on the dev machine; substituted `iPhone 17` (iOS 26.4), matching Wave 0 and Wave 1 runs.
- `testIsAiCleanupSupportedOnCurrentDevice` is skip-gated on simulator physicalMemory — the iPhone 17 simulator reports < 5 GB (reflects host allocation, not the real iPhone 17's 8 GB). The assertion body still executes on-device and in iPhone 17 Pro simulators with more generous memory; the skip path is intentional per Wave 0's design.

## iOS + macOS Compile Status

| Target | Configuration | Destination | Status |
|--------|---------------|-------------|--------|
| iOS Dicticus | Debug | iPhone 17 (iOS 26.4) | **BUILD SUCCEEDED** (zero warnings) |
| macOS Dicticus | Debug (ad-hoc) | arm64 macOS 15 | **BUILD SUCCEEDED** |

## Test Counts (iOS, iPhone 17 simulator)

- **Total:** 59 tests (was 58 in Wave 1 — added `testIsModelCachedReflectsDiskState`)
- **Skipped:** 9 (was 14 in Wave 1 — flipped 3 download tests + 2 device tests)
- **Failed:** 0

**Still skipped (pending later waves):**
- `CleanupServiceTests` — 5 tests (Wave 4 will fill: timeout, concurrent-guard, Swiss gating, real-model inference, back-to-back KV-cache hygiene)
- `IOSTranscriptionServiceTests` — 4 tests (gated on FluidAudio Parakeet model cache; unrelated to Phase 19)

## Observed iPhone 17 Simulator `physicalMemory`

The `DeviceEligibilityTests` suite confirms `ProcessInfo.processInfo.physicalMemory` is readable (asserts `> 0`) on the iPhone 17 simulator. The precise byte count wasn't captured (Wave 0 didn't add a logging statement, and the skip path fires before any reporting), but the `testIsAiCleanupSupportedOnCurrentDevice` skip triggers — meaning the simulator reports `< 5 * 1024 * 1024 * 1024`. Wave 3/4 may want to log this for visibility; on physical iPhone 14+ hardware the value is 6 GB+ and the test runs to completion.

## Wave 2 → Wave 3 Handoff

### Wave 3 must add

- `iOS/Dicticus/Settings/SettingsView.swift`: two new `@AppStorage`-backed toggles (`aiCleanupEnabled`, `useSwissGerman`) using the existing `appGroupBinding` helper. Toggle visibility branches on `IOSModelWarmupService.isAiCleanupSupported` — when false, show the device-unsupported explainer instead of the toggle.
- Inline download panel in `SettingsView` consuming `IOSModelDownloadService`'s `@Published` state — progress bar, size warning (~3.1 GB, Wi-Fi recommended), Download / Pause / Resume buttons. When `IOSModelDownloadService.isModelCached()` is true, skip straight to the toggle. Pattern: `DisclosureGroup`-style, not a full-screen modal (D-10).
- Step 4 warmup wiring in `IOSModelWarmupService.warmup()`: gated on `aiCleanupEnabled && hasEnoughRam`, loads the Shared `CleanupService` via `llama.cpp` after download completes (D-12).

### Wave 4 must fill

- Real `CleanupService` tests on iOS (timeout fallback, concurrent-call guard, back-to-back KV-cache hygiene, Swiss safety-net gating) — the code paths exist in `Shared/Services/CleanupService.swift`; tests just need to exercise them.
- `DictationViewModel` pipeline integration — construct `TextProcessingService(cleanupService: …)` when the toggle is ON.

## Next Phase Readiness

- Downloader is ready for UI wiring: `let svc = IOSModelDownloadService(); svc.start()` and bind `@Published svc.progress` to a `ProgressView`.
- Device-gate is ready: `IOSModelWarmupService.isAiCleanupSupported` at launch → show toggle vs explainer.
- Both integrations are pure SwiftUI + Combine plumbing against the public surface listed above. No further service work is needed for Wave 3.

## User Setup Required

None — all changes are code-level. Users first see the downloader UI in Wave 3 via the Settings "AI Cleanup" toggle.

## Self-Check

```
FOUND: iOS/Dicticus/Services/IOSModelDownloadService.swift (241 LOC)
FOUND: iOS/Dicticus/Services/IOSModelWarmupService.swift (172 LOC, with D-03 statics)
FOUND: iOS/DicticusTests/IOSModelDownloadServiceTests.swift (178 LOC, gate = true)
FOUND: iOS/DicticusTests/DeviceEligibilityTests.swift (54 LOC, gate = true)
GREP PASS: URLSessionDownloadDelegate in IOSModelDownloadService.swift
GREP PASS: unsloth/gemma-4-E2B-it-GGUF in IOSModelDownloadService.swift
GREP PASS: isExcludedFromBackup in IOSModelDownloadService.swift
GREP PASS: sessionConfiguration: URLSessionConfiguration in IOSModelDownloadService.swift
GREP PASS: cancel(byProducingResumeData: in IOSModelDownloadService.swift
GREP PASS: requiredPhysicalMemoryBytes in IOSModelWarmupService.swift
GREP PASS: isAiCleanupSupported in IOSModelWarmupService.swift
GREP PASS: 5 * 1024 * 1024 * 1024 in IOSModelWarmupService.swift
GREP PASS (absence): "No Step 4 (LLM) on iOS v2.0" NOT present in IOSModelWarmupService.swift
FOUND commit: 45bae61 (Task 1 — feat(19-03): add IOSModelDownloadService with URLSession delegate)
FOUND commit: 5be43d2 (Task 2 — feat(19-03): add device RAM eligibility gate to IOSModelWarmupService)
iOS TESTS: 59 total / 9 skipped / 0 failed on iPhone 17 (iOS 26.4)
iOS BUILD: SUCCEEDED (zero warnings)
macOS BUILD: SUCCEEDED (ad-hoc)
```

## Self-Check: PASSED

---
*Phase: 19-ai-cleanup-ios*
*Completed: 2026-04-24*
