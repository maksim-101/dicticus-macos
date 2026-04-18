---
phase: 05-polish-distribution
verified: 2026-04-18T15:00:00Z
status: human_needed
score: 3/4 must-haves verified automatically; SC1 verified by human, SC3 needs override
overrides_applied: 0
overrides: []
human_verification:
  - test: "DMG background image deviation: build-dmg.sh intentionally drops dmg-background.png in favor of native Finder theme (commit 6f9caff). The plan truth 'DMG is styled with background image' and key_link to dmg-background.png are not met. However, the roadmap SC3 only requires a working drag-to-Applications DMG — which the human verified. Confirm the native-theme DMG is acceptable and add an override, OR re-add the background image."
    expected: "Either (a) override accepted: native Finder theme DMG is acceptable for distribution, OR (b) dmg-background.png recreated and --background flag restored in build-dmg.sh"
    why_human: "The deviation is intentional (the commit message states 'use native Finder theme'). Only the developer can confirm whether this tradeoff is accepted for v1 distribution."
---

# Phase 5: Polish & Distribution Verification Report

**Phase Goal:** The app is reliable, memory-efficient, and ready for daily use as a packaged DMG
**Verified:** 2026-04-18T15:00:00Z
**Status:** human_needed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Total memory usage stays under 3 GB with both ASR and LLM models loaded on a 16 GB Apple Silicon Mac | VERIFIED (human result provided) | phys_footprint: 170 MB, peak: 285 MB — well under 3,072 MB budget. verify-memory.sh functional (exists, executable, `BUDGET_MB=3072`, `footprint -p`, PASS/FAIL logic). Human-run result provided in task context. |
| 2 | App can optionally launch at login (configurable in settings) | VERIFIED | `LaunchAtLogin.Toggle("Launch at Login")` in `SettingsSection.swift:26`. LaunchAtLogin-Modern 1.1.0 declared in `project.yml:18`. Toggle wired via `@Binding var plainDictationCombo` / `cleanupCombo` in MenuBarView. SMAppService is the source of truth per code comment (D-02/D-04). |
| 3 | App is packaged as a DMG that a user can download, drag to Applications, and run without additional setup beyond permission grants | VERIFIED (human result provided) | `scripts/build-dmg.sh` exists, executable (-rwxr-xr-x), builds Release .app with `CODE_SIGN_IDENTITY="-"`, invokes `create-dmg` with `--volname "Dicticus"`, `--app-drop-link 480 200`, Gatekeeper bypass documented. Human confirmed DMG builds, mounts, installs, and launches (prompt context). NOTE: `dmg-background.png` was intentionally removed (commit 6f9caff) — native Finder theme used instead. This deviates from the plan's must_have "DMG is styled with background image" but the roadmap SC only requires a working drag-to-Applications DMG. |
| 4 | Modifier-only hotkeys (Fn+Shift, Fn+Control) are available as push-to-talk activation options alongside standard key combos | VERIFIED | `ModifierCombo` enum defines `fnShift`, `fnControl`, `fnOption` with correct `CGEventFlags`. `ModifierHotkeyListener` implements CGEventTap `.listenOnly` on `.flagsChanged`. `SettingsSection` renders Picker with `ModifierCombo.allCases`. `HotkeyManager.setupModifierListener()` wires `onComboActivated`/`onComboReleased` to `handleKeyDown`/`handleKeyUp`. `DicticusApp` creates `@StateObject private var modifierListener` and calls `setupModifierListener()` after ASR warmup. 9 unit tests pass. |

**Score:** 4/4 truths achievable — SC1 verified by human result, SC3 verified by human result (with background image deviation needing human override decision)

### Deferred Items

None — all roadmap success criteria are addressed in this phase.

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `Dicticus/project.yml` | LaunchAtLogin-Modern SPM dependency declaration | VERIFIED | Lines 18-19: `LaunchAtLogin: url: https://github.com/sindresorhus/LaunchAtLogin-Modern.git`, line 71: `- package: LaunchAtLogin`. DicticusTests target does NOT include it. |
| `Dicticus/Dicticus/Models/ModifierCombo.swift` | ModifierCombo enum with Fn-based presets and CGEventFlags mapping | VERIFIED | 47 lines. Defines `enum ModifierCombo: CaseIterable, Identifiable, Codable, Equatable, Sendable` with `fnShift`, `fnControl`, `fnOption`. `flags` computed property returns `[.maskSecondaryFn, .maskShift/Control/Alternate]`. `displayName` returns "Fn + Shift", "Fn + Control", "Fn + Option". |
| `Dicticus/Dicticus/Services/ModifierHotkeyListener.swift` | CGEventTap-based listener for modifier-only hotkeys | VERIFIED | 260 lines. `class ModifierHotkeyListener: ObservableObject, @unchecked Sendable`. `@Published var plainDictationCombo` and `@Published var cleanupCombo` with UserDefaults `didSet` persistence. Static `callback: CGEventTapCallBack`. `detectTransition(from:to:plainCombo:cleanupCombo:)` pure static function. `CGEvent.tapCreate` with `.listenOnly`. `var onComboActivated` and `var onComboReleased` closures. |
| `Dicticus/DicticusTests/ModifierHotkeyListenerTests.swift` | Unit tests for flag transition logic | VERIFIED | 154 lines, 9 test methods (exceeds min_lines: 40). All 6 required test behaviors covered plus 3 additional edge cases. `detectTransition` used as the pure function under test. |
| `Dicticus/Dicticus/Views/SettingsSection.swift` | Settings section with LaunchAtLogin.Toggle and modifier hotkey pickers | VERIFIED | 79 lines (exceeds min_lines: 40). `import LaunchAtLogin`. `LaunchAtLogin.Toggle("Launch at Login")`. `Text("Settings")` with `.font(.headline)`. `Text("Modifier Hotkeys")` with `.font(.headline)`. Two `Picker` controls with `.pickerStyle(.menu)`. `ModifierCombo.allCases`. Accessibility labels on both pickers. External keyboard note text. |
| `Dicticus/Dicticus/Views/MenuBarView.swift` | Updated dropdown with Settings section above Quit | VERIFIED | Contains `@EnvironmentObject var modifierListener: ModifierHotkeyListener`. `SettingsSection(plainDictationCombo: $modifierListener.plainDictationCombo, cleanupCombo: $modifierListener.cleanupCombo)` inserted between last transcription section and Quit button with unconditional `Divider` above and below. |
| `Dicticus/Dicticus/Services/HotkeyManager.swift` | ModifierHotkeyListener integration with push-to-talk state machine | VERIFIED | `private var modifierListener: ModifierHotkeyListener?`. `func setupModifierListener(_ listener: ModifierHotkeyListener)` wires `onComboActivated` → `handleKeyDown(mode:)` and `onComboReleased` → `handleKeyUp(mode:)`, then calls `listener.start()`. |
| `Dicticus/Dicticus/DicticusApp.swift` | ModifierHotkeyListener lifecycle management | VERIFIED | `@StateObject private var modifierListener = ModifierHotkeyListener()`. `.environmentObject(modifierListener)` passed to `MenuBarView`. `hotkeyManager.setupModifierListener(modifierListener)` called in `onChange(of: warmupService.isReady)` after `hotkeyManager.setup(...)`. |
| `scripts/build-dmg.sh` | Complete build + DMG creation pipeline | VERIFIED | 83 lines (exceeds min_lines: 30). Executable (-rwxr-xr-x). `xcodebuild -configuration Release`. `CODE_SIGN_IDENTITY="-"`. `create-dmg --volname "Dicticus"`. `--app-drop-link 480 200`. `--icon "Dicticus.app" 180 200`. "System Settings > Privacy & Security" Gatekeeper instruction. Does NOT use `xcodebuild archive`. |
| `scripts/dmg-background.png` | 1320x800 Retina background image for styled DMG | DEVIATION | File was created (commit 6efc832) then intentionally removed (commit 6f9caff: "drop custom background image from DMG, use native Finder theme"). The background folder visibility issue and dark/light mode compatibility drove the decision. The roadmap SC does not require a styled background; only the plan's truth "DMG is styled with background image" requires it. |
| `scripts/verify-memory.sh` | Memory profiling script using footprint CLI | VERIFIED | 66 lines (exceeds min_lines: 15). Executable (-rwxr-xr-x). `BUDGET_MB=3072`. `footprint -p "$APP_NAME"`. `phys_footprint` extraction. `PASS`/`FAIL` output with budget comparison. `pgrep -x` check for running process. |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `ModifierHotkeyListener.swift` | `ModifierCombo.swift` | uses ModifierCombo for combo matching | VERIFIED | Pattern "ModifierCombo" found: enum iterated in `detectTransition` loop (line 241), `plainDictationCombo: ModifierCombo` / `cleanupCombo: ModifierCombo` property types. |
| `ModifierHotkeyListener.swift` | CoreGraphics CGEventTap | CGEvent.tapCreate with flagsChanged event mask | VERIFIED | `CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .listenOnly, eventsOfInterest: eventMask, callback: Self.callback, userInfo: userInfo)` at line 158. |
| `SettingsSection.swift` | `ModifierHotkeyListener.swift` | Picker selection binding updates listener combo properties | VERIFIED | Pattern "modifierListener" found in `MenuBarView.swift` line 23 (`@EnvironmentObject var modifierListener`) and lines 81-84 (`SettingsSection(plainDictationCombo: $modifierListener.plainDictationCombo, cleanupCombo: $modifierListener.cleanupCombo)`). |
| `HotkeyManager.swift` | `ModifierHotkeyListener.swift` | onComboActivated/onComboReleased closures calling handleKeyDown/handleKeyUp | VERIFIED | Pattern "onComboActivated" found at line 110: `listener.onComboActivated = { [weak self] mode in self?.handleKeyDown(mode: mode) }`. Pattern "onComboReleased" at line 113. |
| `DicticusApp.swift` | `ModifierHotkeyListener.swift` | listener start() called at app launch, passed to HotkeyManager | VERIFIED | Pattern "modifierListener" found: `@StateObject private var modifierListener = ModifierHotkeyListener()` (line 10), `.environmentObject(modifierListener)` (line 27), `hotkeyManager.setupModifierListener(modifierListener)` (line 70). |
| `build-dmg.sh` | `project.yml` | xcodegen generate reads project.yml to create Xcode project | VERIFIED | "xcodegen generate" at line 21 of build-dmg.sh. |
| `build-dmg.sh` | `dmg-background.png` | --background argument to create-dmg | NOT_WIRED | `dmg-background.png` was intentionally removed (commit 6f9caff). `build-dmg.sh` no longer contains `--background` flag or references to the file. This is an intentional deviation from the plan; the plan must_have "DMG is styled with background image" fails. The roadmap SC3 (working drag-to-Applications DMG) is met. |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|--------------------|--------|
| `SettingsSection.swift` | `plainDictationCombo`, `cleanupCombo` | `ModifierHotkeyListener` `@Published` properties, UserDefaults persistence | Yes — loaded from UserDefaults in `init()`, defaults to `.fnShift` / `.fnControl` (D-09) | FLOWING |
| `SettingsSection.swift` | `LaunchAtLogin.Toggle` state | `SMAppService` (LaunchAtLogin-Modern reads system state directly) | Yes — SMAppService is system-managed, no UserDefaults caching | FLOWING |
| `ModifierHotkeyListener` → `HotkeyManager` | `mode: DictationMode` dispatched via closures | CGEventTap `flagsChanged` events, `detectTransition()` pure function | Yes — real modifier key events from CGEventTap, dispatched to main via `DispatchQueue.main.async` | FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| ModifierHotkeyListener unit tests pass | `wc -l Dicticus/DicticusTests/ModifierHotkeyListenerTests.swift` | 154 lines, 9 test methods; SUMMARY reports all 9 pass, full DicticusTests suite passes with no regressions | PASS |
| build-dmg.sh is executable and complete | `ls -la scripts/build-dmg.sh` | `-rwxr-xr-x ... 2740 Apr 18 13:53 build-dmg.sh` | PASS |
| verify-memory.sh is executable and complete | `ls -la scripts/verify-memory.sh` | `-rwxr-xr-x ... 2036 Apr 18 13:10 verify-memory.sh` | PASS |
| LaunchAtLogin-Modern in project.yml | `grep LaunchAtLogin Dicticus/project.yml` | Found at lines 18-19 (package), 71 (target dependency) | PASS |
| All documented commits exist | `git show a88e319 1f0b9c3 2028fa6 87383bf 6efc832 a2028c8` | All 6 commits found with matching descriptions | PASS |
| Memory budget (human-provided) | `./scripts/verify-memory.sh` | phys_footprint: 170 MB, neural_peak: 468 MB (ANE, not in phys_footprint), peak: 285 MB — PASS | PASS |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| APP-05 | 05-01-PLAN.md, 05-02-PLAN.md | App launches at login (optional, configurable) | SATISFIED | `LaunchAtLogin.Toggle` in `SettingsSection.swift`. LaunchAtLogin-Modern 1.1.0 SPM dependency in `project.yml`. Toggle wired via `@EnvironmentObject` in `MenuBarView`. SMAppService reads login item state without UserDefaults caching. |
| INFRA-04 | 05-03-PLAN.md | Total memory usage stays under 3 GB on 16 GB Apple Silicon Mac | SATISFIED | `verify-memory.sh` script measures `phys_footprint` vs `BUDGET_MB=3072`. Human-verified result: 170 MB phys_footprint, 285 MB peak — well under budget. |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `scripts/verify-memory.sh` | 13 | `BUDGET_BYTES=3221225472` declared but never used (only `BUDGET_MB` is used) | Info | Dead code, no functional impact. Flagged in code review as IN-01. |
| `Dicticus/Dicticus/Views/SettingsSection.swift` | 42-67 | No duplicate-combo validation — user can assign same modifier combo to both dictation modes, making AI cleanup hotkey unreachable | Warning | Functional limitation: if user selects same combo for both pickers, `detectTransition` priority loop makes AI cleanup permanently unreachable. Flagged in code review as WR-01. |
| `Dicticus/Dicticus/Services/ModifierHotkeyListener.swift` | 27 | Missing `deinit` that calls `stop()` — unretained CGEventTap pointer could dangle if listener is deallocated before tap is disabled | Warning | Currently safe (lifetime tied to DicticusApp @StateObject), but fragile. Flagged in code review as WR-02. |
| `Dicticus/Dicticus/Services/ModifierHotkeyListener.swift` | 177-184 | `self.runLoop = rl` written from detached background thread; `stop()` reads from main thread — unsynchronized access not covered by `@unchecked Sendable` comment | Warning | TSan would flag this; low crash risk in practice given current call pattern. Flagged in code review as WR-03. |

No blockers found. All anti-patterns are warnings or info-level items documented in the code review report.

### Human Verification Required

#### 1. Confirm dmg-background.png deviation is acceptable

**Test:** Review that the DMG distributed to users uses the native Finder theme (no custom dark background or arrow). Open the mounted DMG in Finder and confirm the appearance is acceptable for v1 distribution.

**Expected:** Either (a) native-theme DMG is accepted as-is — add override in VERIFICATION.md frontmatter to close the plan truth deviation, OR (b) re-add the background image by restoring `scripts/dmg-background.png` and the `--background` flag in `build-dmg.sh`.

**Why human:** The background image was intentionally removed by the developer in commit 6f9caff with message "Removes the .background folder visibility issue and ensures the DMG looks clean in both dark and light mode." This is a developer-accepted aesthetic tradeoff. Only the developer can confirm whether the resulting DMG appearance is acceptable for distribution, or whether the styled background should be restored.

**To accept the deviation, add to the VERIFICATION.md frontmatter:**

```yaml
overrides:
  - must_have: "DMG is styled with background image, app icon, and Applications symlink"
    reason: "Custom background image removed — native Finder theme used instead. Avoids .background folder visibility issue and dark/light mode incompatibility. DMG still contains app icon and Applications symlink; only the custom background is absent."
    accepted_by: "maksim-101"
    accepted_at: "2026-04-18T00:00:00Z"
```

### Gaps Summary

One plan-level deviation found that blocks marking the phase as fully `passed` without developer input:

**The `dmg-background.png` artifact and the plan truth "DMG is styled with background image" are not met.** The file was intentionally deleted (commit `6f9caff`) in favor of the native macOS Finder theme, which avoids `.background` folder visibility issues and dark/light mode incompatibility. The key link from `build-dmg.sh` to `dmg-background.png` via `--background` argument is broken because the `--background` flag was also removed.

This deviation does NOT block the roadmap success criterion SC3 ("App is packaged as a DMG that a user can download, drag to Applications, and run") — the DMG works correctly and the human confirmed it installs and launches. It only violates the plan-level must_have about styling.

All four roadmap success criteria are substantively achieved. The only open item is a human decision: accept the native-theme DMG deviation with an override, or restore the background image.

---

_Verified: 2026-04-18T15:00:00Z_
_Verifier: Claude (gsd-verifier)_
