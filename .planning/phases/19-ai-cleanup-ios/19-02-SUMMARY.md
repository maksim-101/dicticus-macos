---
phase: 19-ai-cleanup-ios
plan: 02
subsystem: cleanup-cross-platform
tags: [ios, spm, llama, swiss-german, itn, shared-extraction, wave-1]

# Dependency graph
requires:
  - phase: 19-ai-cleanup-ios
    provides: 19-01-SUMMARY (Wave 0 test scaffolds with isWave1Ready gate + callSwissITN shim)
provides:
  - Shared/Services/CleanupService.swift (single source of truth, dual-target compilable, parameterized init)
  - Shared/Utilities/ITNUtility.applySwissITN(to:)
  - Shared/Models/CleanupPrompt Swiss orthography STYLE extension (D-18)
  - Shared/Services/TextProcessingService Step 2b (Swiss ITN call-site)
  - iOS target wired to mattt/llama.swift SPM (resolved 2.8914.0)
  - macOS call-site preservation via explicit CleanupService(inferenceTimeoutSeconds: 5.0)
affects: [19-03-ai-cleanup-ios, 19-04-ai-cleanup-ios, 19-05-ai-cleanup-ios, 19-06-ai-cleanup-ios]

# Tech tracking
tech-stack:
  added:
    - "mattt/llama.swift SPM package on iOS target (iOS/project.yml, from 2.8832.0 → resolved 2.8914.0)"
    - "OTHER_LDFLAGS: '-framework llama' on iOS Dicticus target"
  patterns:
    - "Parameterized init with TimeInterval default + local capture for Sendable-safe task-group closures"
    - "AppGroup toggle gate read inside services: UserDefaults(suiteName: 'group.com.dicticus') ?? .standard"
    - "Flat settings: map on iOS/project.yml (not nested base:), matching existing iOS conventions"
    - "Pure git mv for refactor commit that preserves --follow history, followed by behavior-changing commit"

key-files:
  created:
    - .planning/phases/19-ai-cleanup-ios/deferred-items.md
  modified:
    - iOS/project.yml (added llama SPM package + LlamaSwift product + OTHER_LDFLAGS)
    - Shared/Services/CleanupService.swift (moved from macOS/, parameterized init, Swiss safety-net per D-19)
    - Shared/Utilities/ITNUtility.swift (added applySwissITN per D-16 + D-17)
    - Shared/Models/CleanupPrompt.swift (Swiss STYLE line per D-18, gated on useSwissGerman && language=="de")
    - Shared/Services/TextProcessingService.swift (Step 2b Swiss ITN call-site per D-16)
    - macOS/Dicticus/Services/ModelWarmupService.swift (pass inferenceTimeoutSeconds: 5.0 explicitly)
    - macOS/Dicticus.xcodeproj/project.pbxproj (xcodegen regen after source move)
    - iOS/DicticusTests/ITNUtilityTests.swift (flipped isWave1Ready + wired callSwissITN shim to real API)

key-decisions:
  - "Split Task 2 into 2a (pure git mv) + 2b (parameterize + Swiss safety-net) per plan revision. Commit 2a is a 100% rename — git log --follow Shared/Services/CleanupService.swift resolves full pre-move history."
  - "Shared CleanupService init default: inferenceTimeoutSeconds = 8.0 (iOS per D-04). macOS call-site passes 5.0 explicitly — single source of truth across platforms with platform-specific timeouts at the call-site."
  - "applySwissITN uses direct Unicode replacingOccurrences (ß→ss, U+1E9E→SS) rather than NSRegularExpression. Sub-millisecond per D-16; case-preserving by construction because the two chars map to lowercase/uppercase replacements respectively."
  - "Swiss safety-net inside CleanupService reads UserDefaults suite 'group.com.dicticus' with fallback to .standard — matches the existing iOS SettingsView pattern and Wave 0 SettingsToggleTests canonical key strings (aiCleanupEnabled, useSwissGerman)."
  - "TextProcessingService Step 2b runs for all languages when useSwissGerman is ON (not just 'de'). Reason: mixed de/en dictation users who enable Swiss orthography still want clean Eszett elimination — the prompt extension (D-18) remains de-only, but the deterministic transform runs universally. Matches plan Task 3 Test 6 semantics."
  - "iPhone 17 simulator substitution for iPhone 15 (iOS 26.3.1). Wave 0 already established this — noted in deviations."

patterns-established:
  - "Parameterize shared service init with TimeInterval default + platform-specific call-site override (e.g. `CleanupService()` on iOS vs `CleanupService(inferenceTimeoutSeconds: 5.0)` on macOS)."
  - "When extracting macOS → Shared/, split into refactor+feat commits so git bisect can pinpoint either the move or the semantic change."
  - "xcodegen regen after adding top-level packages OR moving sources — both are required because pbxproj references file paths + package refs verbatim."

requirements-completed: []  # CLEAN-01, CLEAN-02 not complete — cross-platform seams landed; UI + warmup + device gating land in Waves 2-4.

# Metrics
duration: ~1h active work (plan started 2026-04-24T08:38:21Z; completed 2026-04-24T17:49:34Z with idle time between edits)
completed: 2026-04-24
---

# Phase 19 Plan 02: Wave 1 Shared CleanupService + Swiss Transforms Summary

**One-liner:** Wire `mattt/llama.swift` SPM on iOS, lift `CleanupService` into `Shared/` as the dual-target source of truth with parameterized timeout, and land all deterministic Swiss German transforms (ITN `ß→ss`/`ẞ→SS`, prompt STYLE extension, post-LLM safety-net) behind the `useSwissGerman` AppGroup key.

## Performance

- **Started:** 2026-04-24T08:38:21Z
- **Completed:** 2026-04-24T17:49:34Z (~1h active, idle gaps between edits)
- **Tasks:** 3 (Task 1, Task 2a+2b, Task 3)
- **Commits:** 4 atomic (3 task commits + 1 metadata commit after this file)
- **Files modified:** 7 (+ 1 pbxproj regen, + 1 deferred-items.md)

## Accomplishments

- iOS target now links `LlamaSwift`. SPM resolved `llama.swift 2.8914.0` (same major.minor as macOS `from: 2.8832.0`).
- `Shared/Services/CleanupService.swift` is the single source of truth for llama.cpp inference — cross-platform, parameterized init (`inferenceTimeoutSeconds: TimeInterval = 8.0`, `maxOutputTokens: Int32 = 512`).
- D-02 (`n_gpu_layers = 99`), D-05 (temp=0.2, top_k=40, top_p=0.9), D-27 (control-token sanitization) all preserved verbatim across the move.
- D-19 post-LLM Swiss safety-net wired inside `cleanup()`: when `useSwissGerman` AppGroup key is ON, output is passed through `ITNUtility.applySwissITN` before return.
- D-16 / D-17 `applySwissITN(to:)` shipped in `Shared/Utilities/ITNUtility.swift` — direct Unicode `replacingOccurrences` (`ß→ss`, `\u{1E9E}→SS`).
- D-18 Swiss `STYLE:` line conditionally appended in `CleanupPrompt.build()` — gated on `useSwissGerman && language == "de"` so standard-German users aren't affected and English dictation stays untouched.
- `TextProcessingService` Step 2b runs `applySwissITN` on plain + AI-cleanup paths (Dictionary step stays verbatim — dictionary keys may contain `ß` legitimately).
- macOS call-site preserved: `ModelWarmupService` passes `CleanupService(inferenceTimeoutSeconds: 5.0)` explicitly to keep pre-extraction 5-second behavior.
- Wave 0 `ITNUtilityTests` flipped from 4 skipped → 4 passing. Full iOS test count: **58 tests, 14 skipped (was 18), 0 failures** on iPhone 17 simulator.
- macOS Debug build succeeds (ad-hoc signing). All 25 macOS `CleanupServiceTests` pass after the extraction + parameterization.
- `git log --follow Shared/Services/CleanupService.swift` resolves back to `Phase 12` (Shared extraction) and `57d36e1` (initial multi-platform restructure) — full history preserved across the rename.

## Task Commits

1. **Task 1: iOS llama SPM wiring** — `08c17d4` (feat)
   - `iOS/project.yml`: added `llama` package, `LlamaSwift` product, `OTHER_LDFLAGS: "-framework llama"`.
   - DicticusWidget and DicticusTests intentionally NOT depended on `llama`.
   - Regenerated `iOS/Dicticus.xcodeproj` (gitignored; consumers run `xcodegen generate`).
   - Verified: `xcodebuild -resolvePackageDependencies` succeeds, iPhone 17 build succeeds.
2. **Task 2a: Pure git mv `CleanupService.swift` → Shared/** — `a9a1bed` (refactor)
   - Zero semantic changes; `git mv` preserves `--follow` history.
   - macOS xcodeproj regenerated (pbxproj references file paths verbatim).
   - Verified: both targets build, all 25 macOS CleanupServiceTests pass.
3. **Task 2b: Parameterize init + Swiss safety-net + macOS call-site + ITNUtility.applySwissITN** — `c3ee521` (feat)
   - Added `init(inferenceTimeoutSeconds:maxOutputTokens:)` with iOS-tuned defaults (8.0 s, 512 tokens).
   - Replaced hard-coded `5.0` timeout with parameterized local capture (Sendable-safe closure).
   - Added D-19 post-stripPreamble Swiss safety-net gated on `useSwissGerman`.
   - Added `applySwissITN(to:)` to `ITNUtility` so the safety-net call site compiles.
   - `macOS/Dicticus/Services/ModelWarmupService.swift` now builds `CleanupService(inferenceTimeoutSeconds: 5.0)`.
   - Verified: D-02/D-05 greps all PASS; both targets build; 25/25 macOS CleanupServiceTests pass.
4. **Task 3: Swiss prompt STYLE line + TextProcessingService Step 2b + flip Wave 0 shim** — `c0d6a22` (feat)
   - `CleanupPrompt.build()` conditionally appends Swiss orthography STYLE line (gated on `useSwissGerman && language == "de"`).
   - `TextProcessingService.process()` Step 2b runs `applySwissITN` on all languages when `useSwissGerman` is ON.
   - `iOS/DicticusTests/ITNUtilityTests.swift`: `isWave1Ready: false → true`, `callSwissITN` shim body now calls `ITNUtility.applySwissITN(to:)`.
   - Full iOS suite: 58 tests / 14 skipped / 0 failures (was 58 / 18 / 0).

**Plan metadata commit:** created after this SUMMARY is written.

## Files Modified (final LOC counts)

| File | LOC | Change |
|------|-----|--------|
| `Shared/Services/CleanupService.swift` | 504 | +28 LOC for parameterized init + safety-net vs 476 before move |
| `Shared/Utilities/ITNUtility.swift` | 242 | +21 LOC for applySwissITN + docs |
| `Shared/Models/CleanupPrompt.swift` | 83 | +8 LOC for Swiss STYLE branch |
| `Shared/Services/TextProcessingService.swift` | 73 | +9 LOC for Step 2b |
| `macOS/Dicticus/Services/ModelWarmupService.swift` | +3 LOC | Pass inferenceTimeoutSeconds: 5.0 |
| `iOS/project.yml` | +6 LOC | llama SPM + LlamaSwift + OTHER_LDFLAGS |
| `iOS/DicticusTests/ITNUtilityTests.swift` | net -4 LOC | Flipped gate, replaced shim body |

## Decisions Made

- **Timeout default belongs to iOS (D-04, 8 s); macOS overrides at call-site (5.0 s).** The shared service should reflect the platform with the tighter constraint (iOS is the destination for new work); macOS's prior 5-second behavior is preserved explicitly. This keeps the shared default meaningful rather than using a sentinel.
- **Swiss safety-net reads AppGroup suite.** `UserDefaults(suiteName: "group.com.dicticus") ?? .standard` matches the existing iOS SettingsView pattern and the canonical keys defined in Wave 0 `SettingsToggleTests`. Wave 3 SettingsView must use these exact strings in `@AppStorage`.
- **Swiss ITN call-site runs for all languages (not de-only).** The prompt extension (D-18) stays de-only, but the deterministic transform fires whenever the toggle is ON — mixed de/en users benefit. This matches plan Task 3 Test 6.
- **Keep iOS `settings:` map flat (not nested `base:`).** iOS currently uses flat YAML; restructuring would touch unrelated keys. Matches plan Task 1 step 2 instruction.
- **iPhone 17 substitution for iPhone 15** (iOS 26.3.1). Consistent with Wave 0 decision; no behavior delta.
- **Split Task 2 into 2a (mv) + 2b (parameterize).** Makes `git bisect` trivial — the refactor commit is a 100% rename, so regressions localize to either "move broke Xcode project layout" (2a) or "parameterization changed behavior" (2b).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Stale SPM cache prevented initial iOS package resolution**
- **Found during:** Task 1 first `xcodebuild -resolvePackageDependencies` run.
- **Issue:** `/Users/mowehr/Library/Caches/org.swift.swiftpm/artifacts/https___github_com_ggml_org_llama_cpp_releases_download_b8914_llama_b8914_xcframework_zip already exists in file system` → resolver fatalError.
- **Fix:** Deleted the stale cache entry. Resolution then succeeded and produced `llama.swift 2.8914.0`.
- **Files modified:** none (cache only).
- **Verification:** second `xcodebuild -resolvePackageDependencies` run completed with all three packages resolved.
- **Committed in:** n/a (environmental; not a code fix).

**2. [Rule 3 - Blocking] macOS xcodeproj requires explicit file-input after `git mv`**
- **Found during:** Task 2a first macOS build.
- **Issue:** macOS `Dicticus.xcodeproj/project.pbxproj` listed `macOS/Dicticus/Services/CleanupService.swift` as an explicit build input (despite the `sources: - path: Dicticus` recursive rule). Build failed with `Build input file cannot be found`.
- **Fix:** Ran `cd macOS && xcodegen generate` to regenerate the pbxproj against the new `Shared/` location. macOS Debug build then succeeded.
- **Files modified:** `macOS/Dicticus.xcodeproj/project.pbxproj` (committed alongside Task 2b because Task 2a was locked as pure-mv).
- **Verification:** macOS build succeeds; all 25 macOS `CleanupServiceTests` pass.
- **Committed in:** `c3ee521` (Task 2b bundle).

**3. [Rule 3 - Blocking] Task 3 `applySwissITN` dependency order**
- **Found during:** Task 2b — the D-19 safety-net inside `CleanupService.cleanup()` references `ITNUtility.applySwissITN`, but the plan originally lands `applySwissITN` in Task 3.
- **Fix:** Added `applySwissITN` to `ITNUtility.swift` as part of Task 2b (the commit where it is first referenced). Task 3 still lands the call-sites (CleanupPrompt STYLE line, TextProcessingService Step 2b) and flips the Wave 0 test shim.
- **Files modified:** `Shared/Utilities/ITNUtility.swift` in the Task 2b commit instead of the Task 3 commit.
- **Verification:** macOS + iOS builds succeed; ITNUtilityTests pass after Wave 0 shim flip in Task 3.
- **Committed in:** `c3ee521` (Task 2b) for the symbol; `c0d6a22` (Task 3) for the test flip.

**4. [Rule 3 - Blocking] macOS release build requires signing certs the executor doesn't have**
- **Found during:** Task 2a first macOS build attempt.
- **Issue:** `xcodebuild -project macOS/Dicticus.xcodeproj -scheme Dicticus build` failed with "requires a provisioning profile"; `scripts/build-dmg.sh` expects Developer ID environment variables injected via `op run`.
- **Fix:** For verification purposes only, built macOS in Debug with ad-hoc signing disabled: `CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO`. This matches the standard local-dev build command. Production DMG still uses the existing Release pipeline.
- **Files modified:** none (invocation flags only).
- **Verification:** macOS Debug build succeeds cleanly; tests pass.
- **Committed in:** n/a.

### Deferred (out of scope)

**macOS `DicticusTests/ITNUtilityTests/testMixedText` pre-existing failure**
- **Found during:** Post-Task 3 full macOS suite run.
- **Confirmed pre-existing** via `git stash` + re-test on commit `c3ee521` (Task 2b): same failure before any Task 3 changes.
- **Nature:** Test expects `"five"` → `"5"` and `"one"` → `"1"`, but the English ITN has `minDigitThreshold = 10` by design ("spell out one through nine").
- **Logged to:** `.planning/phases/19-ai-cleanup-ios/deferred-items.md`.
- **Decision:** Not fixed inside Wave 1 scope. Belongs to a separate trivial PR that decides whether the test expectation or the threshold is wrong.

---

**Total deviations:** 4 auto-fixed (all Rule 3 - blocking); 1 deferred (out of scope).
**Impact on plan:** Zero functional scope delta. All plan `acceptance_criteria` greps PASS.

## Issues Encountered

- Stale SPM artifacts cache (one-time, environmental).
- macOS pbxproj needed regeneration after git mv (expected consequence of xcodegen).
- macOS release-signed build requires 1Password-injected env vars unavailable in autonomous executor context; debug-signed build used for verification (matches local dev flow).

## iOS + macOS Compile Status

| Target | Configuration | Destination | Status |
|--------|---------------|-------------|--------|
| iOS Dicticus | Debug | iPhone 17 (iOS 26.3.1) | **BUILD SUCCEEDED** |
| macOS Dicticus | Debug (ad-hoc) | arm64 macOS 15 | **BUILD SUCCEEDED** |

## Test Counts

### iOS (iPhone 17 simulator)

- **Total:** 58 tests
- **Skipped:** 14 (was 18 in Wave 0 — the 4 ITNUtility Swiss tests flipped to green)
- **Failed:** 0
- **Still skipped (pending later waves):**
  - CleanupServiceTests: 5 (Wave 4 will fill these — timeout, concurrent-guard, Swiss gating, real-model inference, back-to-back KV-cache hygiene)
  - DeviceEligibilityTests: 2 (Wave 2 — RAM threshold + supported check)
  - IOSModelDownloadServiceTests: 3 (Wave 2 — download service seams)
  - IOSTranscriptionServiceTests: 4 (gated on FluidAudio Parakeet model cache — unrelated to Phase 19)

### macOS

- **Full suite:** 158 tests, 1 failure (pre-existing `testMixedText` — deferred, see above).
- **CleanupServiceTests (targeted):** 25 tests, **0 failures** — verifies no regression from the cross-platform extraction.

## Wave 1 → Wave 2 Handoff

### Wave 2 must add (to turn IOSModelDownloadServiceTests + DeviceEligibilityTests green)

- `iOS/Dicticus/Services/IOSModelDownloadService.swift` with the seams documented in Wave 0 (`init(sessionConfiguration:)`, `startAndWaitForCompletion()`, static `modelURL`/`modelFileName`/`modelPath()`/`isModelCached()`, `@Published state`, `@Published progress`, `start()`/`pause()`/`resume()`).
- `IOSModelWarmupService.ramThresholdBytes: UInt64` and `static var isAiCleanupSupported: Bool` (D-03).
- `isExcludedFromBackup` flag on the downloaded GGUF (Q6).
- In `iOS/DicticusTests/IOSModelDownloadServiceTests.swift` + `DeviceEligibilityTests.swift`: flip `isWave2Ready = true`.

### Wave 3 must add (Settings UI)

- `aiCleanupEnabled` @AppStorage toggle in `iOS/Dicticus/Settings/SettingsView.swift` (canonical key from `SettingsToggleTests`).
- `useSwissGerman` @AppStorage toggle in the same view.
- Inline LLM download panel (progress bar, pause/resume) next to the AI Cleanup toggle (D-10).

### Wave 4 must fill (CleanupServiceTests bodies)

- Real CleanupService instantiation with injected slow inference for D-04 timeout test.
- Back-to-back calls for D-06 KV-cache hygiene (requires real GGUF — already env-gated).
- Swiss safety-net gating test for D-19 (the code path now exists; test just needs to exercise it).
- Concurrent-call guard test for D-28.

## Next Phase Readiness

- Cross-platform seam is live: any iOS code that wants LLM cleanup can construct `CleanupService()` and inject it as the `CleanupProvider` on `TextProcessingService`.
- Swiss deterministic transforms are wired end-to-end for plain dictation — users who set `useSwissGerman = true` already get `ß → ss` on the next recording (UI lands Wave 3).
- `iOS/Dicticus.xcodeproj` and `macOS/Dicticus.xcodeproj` must be regenerated via `xcodegen` on any fresh checkout (same as before this wave).

## User Setup Required

None — all changes are code-level. Wave 3 will introduce the Settings toggles that expose the functionality to end users.

## Self-Check

```
FOUND: Shared/Services/CleanupService.swift (504 LOC)
FOUND: Shared/Utilities/ITNUtility.swift (242 LOC, with applySwissITN)
FOUND: Shared/Models/CleanupPrompt.swift (83 LOC, with Swiss STYLE branch)
FOUND: Shared/Services/TextProcessingService.swift (73 LOC, with Step 2b)
FOUND: iOS/project.yml (with llama SPM + LlamaSwift + OTHER_LDFLAGS)
FOUND: macOS/Dicticus/Services/ModelWarmupService.swift (with inferenceTimeoutSeconds: 5.0)
FOUND: iOS/DicticusTests/ITNUtilityTests.swift (isWave1Ready = true, real callSwissITN)
MISSING: macOS/Dicticus/Services/CleanupService.swift (correct — moved to Shared/)
FOUND commit: 08c17d4 (Task 1)
FOUND commit: a9a1bed (Task 2a)
FOUND commit: c3ee521 (Task 2b)
FOUND commit: c0d6a22 (Task 3)
GREP PASS: n_gpu_layers = 99 in Shared/Services/CleanupService.swift
GREP PASS: llama_sampler_init_temp(0.2) in Shared/Services/CleanupService.swift
GREP PASS: llama_sampler_init_top_k(40) in Shared/Services/CleanupService.swift
GREP PASS: llama_sampler_init_top_p(0.9 in Shared/Services/CleanupService.swift
GREP PASS: useSwissGerman in Shared/Services/CleanupService.swift
GREP PASS: ITNUtility.applySwissITN in Shared/Services/CleanupService.swift
GREP PASS: CleanupService(inferenceTimeoutSeconds: 5.0) in macOS/Dicticus/Services/ModelWarmupService.swift
GREP PASS: STYLE: Use Swiss German orthography in Shared/Models/CleanupPrompt.swift
GREP PASS: applySwissITN in Shared/Services/TextProcessingService.swift
```

## Self-Check: PASSED

---
*Phase: 19-ai-cleanup-ios*
*Completed: 2026-04-24*
