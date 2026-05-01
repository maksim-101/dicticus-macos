---
phase: 20-ai-cleanup-demotion-uat-visibility
plan: 04
subsystem: persistence
tags: [history, app-group, grdb, sqlite, resilience, settings-ui, swiftui]

requires:
  - phase: 20-ai-cleanup-demotion-uat-visibility
    provides: "Wave 1 RED test (HistoryServiceTests.testFallbackFlagSettableForUI) locking the appGroupAvailable + makeForTesting contract"
  - phase: 19-ios-ai-cleanup
    provides: "HistoryService Phase 19 D-38 schema (text + rawText columns) and TextProcessingService Step 4 save call site"

provides:
  - "HistoryService graceful App-Group fallback (no fatalError on missing entitlement)"
  - "HistoryService.appGroupAvailable static flag exposing init outcome to Settings UIs"
  - "HistoryService.databaseFileURL diagnostic property for tests + future tooling"
  - "HistoryService.makeForTesting(containerURLProvider:) DEBUG-only injection seam"
  - "iOS Settings AiCleanupSection warning row (additive, top of section)"
  - "macOS Settings SettingsSection parity warning row (additive, above Launch-at-Login)"

affects:
  - "20-05 raw/polished history visibility (consumes appGroupAvailable surface)"
  - "Future iOS keyboard extension revival (diagnostic surface already in place)"
  - "Phase 19 / 19.5 history-touching tests (verified still GREEN)"

tech-stack:
  added: []
  patterns:
    - "Injectable provider closure for entitlement-dependent FS resolution (test seam without entitlement gymnastics)"
    - "Static flag + log-once warning pattern for one-shot init diagnostics surfaced to Settings UIs"
    - "Cross-platform parity rule: cleanup-pipeline UI changes ship on iOS AND macOS together"

key-files:
  created: []
  modified:
    - "Shared/Services/HistoryService.swift (graceful fallback + appGroupAvailable + databaseFileURL + makeForTesting)"
    - "iOS/Dicticus/Settings/AiCleanupSection.swift (additive yellow warning row at top of Section)"
    - "macOS/Dicticus/Views/SettingsSection.swift (additive parity warning row above Launch-at-Login)"
    - "macOS/Dicticus.xcodeproj/project.pbxproj (xcodegen regen — picks up Wave 2 shared files that 20-03 SUMMARY did not commit)"

key-decisions:
  - "Convenience init delegates to designated init(containerURLProvider:) — keeps singleton call-site unchanged while exposing the test seam"
  - "appGroupAvailable defaults to true at declaration so any code reading the flag before HistoryService.init() runs sees the optimistic value (no false-positive warning row at app cold-start)"
  - "Log-once via class-level didLogFallback Bool — prevents log spam if any future test or tool constructs additional instances"
  - "databaseFileURL exposed as `let` on the instance (not static) — tests assert per-instance fallback location; production reads it for diagnostics"
  - "Warning row placed inside AiCleanupSection (not SettingsView root) per D-36 boundary forbidding SettingsView modifications"

patterns-established:
  - "Pattern: replace fatalError on entitlement-dependent FS lookups with provider-injectable fallback + diagnostic flag, surfaced through Settings UIs symmetrically across platforms"
  - "Pattern: xcodegen-tracked iOS project (gitignored) + xcodegen-tracked macOS project (committed) — both must be regenerated when Shared/ adds files; macOS regen is the reviewable artefact"

requirements-completed:
  - ACT-4-RESILIENCE

duration: 14min
completed: 2026-04-26
---

# Phase 20 Plan 04: HistoryService Graceful App-Group Fallback Summary

**Replaced HistoryService:61 fatalError with applicationSupport fallback under Bundle.main.bundleIdentifier, exposed appGroupAvailable static flag + databaseFileURL diagnostic, added DEBUG-only makeForTesting factory, and surfaced symmetric yellow-triangle warning rows on iOS AiCleanupSection and macOS SettingsSection — DB-init fatalError at line 73 deliberately preserved.**

## Performance

- **Duration:** 14 min
- **Started:** 2026-04-26T18:25:28Z
- **Completed:** 2026-04-26T18:39:57Z
- **Tasks:** 3
- **Files modified:** 4 (1 Shared service + 1 iOS view + 1 macOS view + 1 xcodeproj regen)

## Accomplishments

- iOS simulator no longer crashes when the App Group entitlement isn't picked up — HistoryService now falls back to `applicationSupportDirectory/<bundleID>/Database/History.sqlite` and continues normal operation.
- New static surface `HistoryService.appGroupAvailable: Bool` lets Settings UIs render a non-blocking diagnostic row. The flag is set once during init (immutable for the process lifetime), so static reads in SwiftUI are correct.
- New `HistoryService.makeForTesting(containerURLProvider:)` DEBUG seam unlocks deterministic testing of the fallback path — the Wave 1 RED test `HistoryServiceTests.testFallbackFlagSettableForUI` now GREEN.
- Cross-platform parity: warning rows on both iOS (AiCleanupSection top, with keyboard-extension caveat) and macOS (SettingsSection above Launch-at-Login, no keyboard-extension reference). macOS-specific copy reflects the platform's lack of keyboard extensions.
- Phase 19 / 19.5 history-touching tests verified still GREEN (macOS HistoryServiceTests: 4/4 pass; iOS HistoryServiceTests: 1 pass + 1 environmentally skipped).
- Second `fatalError` at HistoryService DB-init catch site PRESERVED — that path is genuinely unrecoverable (corrupt SQLite / no disk) and not entitlement-dependent.

## Task Commits

Each task was committed atomically with --no-verify (parallel-mode worktree):

1. **Task 1: Replace App-Group fatalError with graceful fallback in HistoryService** — `ca6a30a` (feat)
2. **Task 2: Surface fallback warning in iOS Settings (AiCleanupSection)** — `64e6d31` (feat)
3. **Task 3: Add parity warning row to macOS Settings (SettingsSection)** — `bb04845` (feat)

_Note: orchestrator commits the SUMMARY + tracking files post-wave._

## Files Created/Modified

- `Shared/Services/HistoryService.swift` — Replaced lines 58–75 init body with provider-injectable design:
  - Added `StorageBackend` enum, `resolveStorage(provider:)` static helper, `appGroupAvailable` static flag, `didLogFallback` log-once guard, `databaseFileURL` instance property.
  - Refactored `init` into `convenience init` (singleton path) + designated `init(containerURLProvider:)`.
  - Added `#if DEBUG static func makeForTesting(containerURLProvider:)` factory.
  - Preserved DB-init fatalError unchanged.
- `iOS/Dicticus/Settings/AiCleanupSection.swift` — Added conditional `appGroupFallbackWarningRow` at top of `Section` body (additive only). Existing toggles, downloader panel, RAM-gate explainer, Swiss German toggle untouched.
- `macOS/Dicticus/Views/SettingsSection.swift` — Added conditional warning row + `appGroupFallbackWarningRow` helper view (additive only). Sits above Launch-at-Login with a Divider separator when shown. Existing modifier-hotkey pickers and dictionary button untouched.
- `macOS/Dicticus.xcodeproj/project.pbxproj` — Regenerated via `xcodegen` to pick up Wave 2 shared files (`RulesCleanupService.swift`, `FillerWordRemover.swift`, `SelfCorrectionResolver.swift`, `LevenshteinDistance.swift`, `SwissNumberFormatter.swift`, etc.) that the 20-03 SUMMARY claimed were wired but were never committed. Necessary for Plan 20-04 verification builds to succeed.

## Decisions Made

- **Convenience init pattern over default-arg init:** Swift's default-argument init was theoretically simpler but produced a less readable diff (every singleton call site reads as the `private init()` it has always been). Convenience-delegates-to-designated keeps the public-facing singleton path byte-identical while exposing the test seam.
- **`databaseFileURL` as instance `let`, not static:** The test asserts per-instance fallback location, and future diagnostics may want to compare singleton vs. test-instance paths. Static would have hidden which instance the URL belongs to.
- **`appGroupAvailable` defaults to `true`:** Optimistic default avoids a false-positive warning row in the (vanishingly small) window between app launch and HistoryService.init(). Once init runs the flag reflects reality.
- **macOS warning row placed at top of Settings (above Launch-at-Login), not at the AI-cleanup-related cluster:** The macOS SettingsSection is a single VStack without sub-sections, and the warning is most useful at the prominent top position. This differs from iOS placement (top of AiCleanupSection) because iOS has formal `Section` containers and that's where the user looks for AI-related state.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Added missing `databaseFileURL` property to HistoryService**
- **Found during:** Task 1 (writing GREEN code against the Wave 1 RED test)
- **Issue:** The Wave 1 RED test (`HistoryServiceTests.swift` line 67) asserts on `service.databaseFileURL.path.hasPrefix(appSupport.path)`. The plan's `<interfaces>` block did not list this property in the new public surface, but the test demands it to verify the fallback storage location. Without it the test cannot compile.
- **Fix:** Added `let databaseFileURL: URL` instance property, set during `init` to the resolved DB path. Internal access (no `private`) so the test target sees it via `@testable import`.
- **Files modified:** `Shared/Services/HistoryService.swift`
- **Verification:** Wave 1 RED test compiles and passes.
- **Committed in:** `ca6a30a` (Task 1 commit)

**2. [Rule 3 - Blocking] Regenerated macOS xcodeproj to include Wave 2 shared files**
- **Found during:** Task 1 (initial verification build)
- **Issue:** The Wave 2 plan (20-03 — rules-first cleanup + Levenshtein gate) added `Shared/Utilities/{FillerWordRemover,SelfCorrectionResolver,LevenshteinDistance}.swift`, `Shared/Services/RulesCleanupService.swift`, and several test files. The 20-03 SUMMARY claimed these were wired into the pipeline (and ran tests) but the macOS xcodeproj was NOT regenerated, leaving `RulesCleanupService` invisible to TextProcessingService's compile unit. Both iOS and macOS builds failed at base `1c111c0` with `cannot find type 'RulesCleanupService' in scope` BEFORE my Plan 20-04 changes — a pre-existing Wave 2 omission blocking my verification builds.
- **Fix:** Ran `xcodegen generate` in `macOS/` and `iOS/` directories. Restored both `Package.resolved` files from the parent worktree to keep FluidAudio pinned to the same revision (the iOS app target picked up an incompatible newer FluidAudio API otherwise).
- **Files modified:** `macOS/Dicticus.xcodeproj/project.pbxproj` (iOS xcodeproj is gitignored — regen not committed but applied).
- **Verification:** Both iOS and macOS app targets BUILD SUCCEEDED; macOS HistoryServiceTests 4/4 pass; iOS HistoryServiceTests new contract test passes.
- **Committed in:** `ca6a30a` (Task 1 commit, bundled with HistoryService refactor)

**3. [Rule 3 - Blocking] Pinned Package.resolved to parent-worktree FluidAudio revision**
- **Found during:** Task 1 (after xcodegen regen, iOS build started failing on `IOSTranscriptionService.swift:232` with `missing argument for parameter 'decoderState'`)
- **Issue:** Fresh xcodegen regen + DerivedData created during this worktree's runs resolved `from: "0.13.6"` to a newer FluidAudio revision (`d302273…`) than the main worktree's pinned revision (`57551cd…`). The newer FluidAudio AsrManager API breaks IOSTranscriptionService.transcribe call site. NOT something Plan 20-04 should fix — it is upstream API drift unrelated to App-Group fallback.
- **Fix:** Copied `Package.resolved` from `/Users/mowehr/code/dicticus/iOS/Dicticus.xcodeproj/.../Package.resolved` (and macOS equivalent) into this worktree, then ran `xcodebuild -resolvePackageDependencies` to lock the older revision. Package.resolved files are gitignored so no commit needed — the parent worktree's pin is the source of truth.
- **Files modified:** `iOS/Dicticus.xcodeproj/.../Package.resolved`, `macOS/Dicticus.xcodeproj/.../Package.resolved` (both gitignored)
- **Verification:** Both builds GREEN after restore.
- **Committed in:** Not committed (gitignored files)

---

**Total deviations:** 3 auto-fixed (1 contract gap in plan vs. RED test, 2 pre-existing Wave 2 infrastructure gaps)
**Impact on plan:** All three were unavoidable to verify Plan 20-04 work. The first reflects a minor under-specification in the plan (test references `databaseFileURL` but interfaces section didn't list it) — adding it as a Rule 3 blocker resolution. The second and third reflect Wave 2 (20-03) hygiene gaps that should be flagged for the orchestrator and a future plan-checker run. No scope creep into Plan 20-04 itself.

## Issues Encountered

- **Pre-existing Wave 2 build break (RulesCleanupService missing from project membership):** The 20-03 SUMMARY indicated that `RulesCleanupService` was wired into TextProcessingService Step 2c, but the `.pbxproj` change was not part of the commit. Both iOS and macOS BUILD FAILED at base `1c111c0` before I touched anything. Resolved by regenerating projects via xcodegen — recommend a Wave 2 retro / plan-checker investigation: SUMMARY claimed work that was not actually committed.
- **iOS HistoryServiceTests `testAppGroupAvailableFlagDefaultsTrue` skipped (by design):** The Wave 1 test author flagged this with `XCTSkipIf(containerURL == nil, …)` for CI environments without provisioning. Skip path triggers in this worktree (no provisioning profile attached). Not a regression — explicitly anticipated by the test.

## User Setup Required

None — App Group entitlement remains optional. Production builds with the entitlement provisioned take the happy path identically to today (no behavioural change). Misconfigured / dev builds now show a non-blocking warning row instead of crashing.

## Next Phase Readiness

- **Plan 20-05 (raw/polished history visibility) unblocked:** Consumes the same `HistoryService.appGroupAvailable` flag plus the unchanged Phase 19 D-38 schema (text + rawText columns). Plan 20-05 may further extend `macOS/Dicticus/Views/SettingsSection.swift` — the additive warning-row helper added here sits at the top and won't conflict with downstream additions.
- **Wave 2 (20-03) project-membership gap surfaced:** The Wave 2 commit set was incomplete (RulesCleanupService not added to xcodeproj despite being wired in TextProcessingService). A retroactive fix landed here as a Rule 3 deviation. Recommend the orchestrator run plan-checker against 20-03 to confirm no other artefacts are missing.
- **No new external dependencies, no new entitlements, no new build steps.**

## Self-Check: PASSED

- File `Shared/Services/HistoryService.swift` modified ✓
- File `iOS/Dicticus/Settings/AiCleanupSection.swift` modified ✓
- File `macOS/Dicticus/Views/SettingsSection.swift` modified ✓
- Commit `ca6a30a` (Task 1) — verified in `git log`
- Commit `64e6d31` (Task 2) — verified in `git log`
- Commit `bb04845` (Task 3) — verified in `git log`
- Plan automated verification:
  - `! grep -nE 'App Group container not found' Shared/Services/HistoryService.swift` → PASS (string absent)
  - `grep -c 'fatalError' Shared/Services/HistoryService.swift` → 1 (DB-init only, as required)
  - `grep -c 'HistoryService.appGroupAvailable' iOS/Dicticus/Settings/AiCleanupSection.swift` → 1 (single read)
  - `grep -c 'HistoryService.appGroupAvailable' macOS/Dicticus/Views/SettingsSection.swift` → 1 (single read)
- iOS HistoryServiceTests/testFallbackFlagSettableForUI → PASSED
- iOS HistoryServiceTests/testAppGroupAvailableFlagDefaultsTrue → SKIPPED (no entitlement in worktree, by design)
- macOS HistoryServiceTests (4 existing tests) → ALL PASSED (no Phase 19 regression)
- macOS app build → BUILD SUCCEEDED
- iOS app build (iPhone 17 simulator) → BUILD SUCCEEDED

---
*Phase: 20-ai-cleanup-demotion-uat-visibility*
*Completed: 2026-04-26*
