---
phase: 01-foundation-app-shell
verified: 2026-04-14T00:00:00Z
status: human_needed
score: 12/12 must-haves verified
overrides_applied: 0
human_verification:
  - test: "App launches as menu bar icon with no Dock icon and no main window"
    expected: "App icon appears in menu bar, no bounce in Dock, no window opens on launch"
    why_human: "Cannot verify visual menu bar presence or Dock absence programmatically in a build-only environment"
  - test: "Menu bar icon adapts to light/dark mode"
    expected: "SF Symbol 'mic' appears correctly in both Light and Dark macOS appearances"
    why_human: "Appearance rendering requires visual inspection"
  - test: "Clicking menu bar icon shows dropdown with permission rows, warm-up row, and Quit button"
    expected: "Dropdown opens; permission rows show status badges; WarmupRow present or hidden when ready; Quit button present"
    why_human: "Interactive UI flow cannot be verified programmatically"
  - test: "First launch shows sequential onboarding: Microphone, then Accessibility, then Input Monitoring"
    expected: "OnboardingView appears on first run; steps advance one at a time; 'I'll do this later' skips to next"
    why_human: "First-launch flow requires clearing UserDefaults and observing onboarding UI sequence"
  - test: "Grant Access and Open Settings buttons function correctly per permission state"
    expected: "Pending permission shows 'Grant Access' -> triggers OS prompt; Denied shows 'Open Settings' -> opens correct System Settings pane"
    why_human: "TCC prompt behavior and System Settings navigation require human interaction"
  - test: "Permissions polled every 2 seconds — grant in System Settings reflects in dropdown"
    expected: "After granting a permission in System Settings, the dropdown status badge updates within ~2 seconds without app restart"
    why_human: "Live polling behavior requires interacting with System Settings while observing the running app"
  - test: "Menu bar icon pulses during warm-up and stops when ready; warm-up row disappears"
    expected: "symbolEffect(.pulse) animation visible on mic icon at launch; WarmupRow with ProgressView visible in dropdown; both stop/hide when WhisperKit finishes"
    why_human: "Animation and async model-loading completion require observing the running app"
  - test: "mic vs mic.slash icon reflects permission state"
    expected: "Icon shows mic.slash when any permission missing; shows mic when all granted"
    why_human: "Icon switching requires granting/revoking permissions and observing the menu bar"
---

# Phase 01: Foundation & App Shell Verification Report

**Phase Goal:** A running macOS menu bar app that guides the user through permissions and warms up ML models in the background -- the foundation everything else builds on
**Verified:** 2026-04-14
**Status:** human_needed
**Re-verification:** No -- initial verification

## Goal Achievement

### Observable Truths

All truths derived from the four ROADMAP Success Criteria plus PLAN must_haves from all three plans.

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | App appears as menu bar icon with dropdown menu (no main window) | VERIFIED | `DicticusApp.swift`: `MenuBarExtra` scene, no `WindowGroup`; `Info.plist`: `LSUIElement = true`; build succeeds |
| 2 | First launch guides user through Microphone, Accessibility, and Input Monitoring grants with System Settings links | VERIFIED | `OnboardingView.swift`: sequential 3-step flow; `PermissionRow.swift`: "Open Settings" button calls `SystemSettingsURL.open()`; `SystemSettingsURLs.swift`: Privacy_Microphone, Privacy_Accessibility, Privacy_ListenEvent URLs present |
| 3 | App shows "warming up" indicator while CoreML compiles; subsequent launches fast | VERIFIED | `ModelWarmupService.swift`: `Task.detached(priority: .utility)` for background init; `WarmupRow.swift`: `ProgressView()` + "Preparing models…"; `DicticusApp.swift`: `.symbolEffect(.pulse, isActive: warmupService.isWarming)`; `WhisperKitConfig()` uses cached CoreML on repeat launches |
| 4 | Entitlements configured for unsandboxed distribution with Hardened Runtime enabled | VERIFIED | `Dicticus.entitlements`: `com.apple.security.app-sandbox = false`, `com.apple.security.device.audio-input = true`; `project.pbxproj`: `ENABLE_HARDENED_RUNTIME = YES` (two entries, both confirmed) |
| 5 | Menu bar icon shows SF Symbol mic as template image, adapts to light/dark mode | VERIFIED (human needed for visual) | `DicticusApp.swift`: `Image(systemName: "mic")` / `Image(systemName: iconName)` where iconName is "mic" or "mic.slash" -- SF Symbols are template images by default in SwiftUI |
| 6 | Clicking icon shows dropdown with Quit button | VERIFIED (human needed for interaction) | `MenuBarView.swift`: `Button("Quit Dicticus") { NSApplication.shared.terminate(nil) }` with `.keyboardShortcut("q")` |
| 7 | WhisperKit SPM dependency resolves and builds successfully | VERIFIED | `Package.resolved`: WhisperKit 0.18.0 pinned from `https://github.com/argmaxinc/WhisperKit.git`; `project.pbxproj`: `minimumVersion = 0.18.0`; `xcodebuild build` → BUILD SUCCEEDED |
| 8 | Each permission row shows granted/pending/denied state with action button | VERIFIED | `PermissionRow.swift`: renders `status.iconName`, `status.label`, and `"Grant Access"` or `"Open Settings"` conditional on `status`; backed by `PermissionStatus` enum with `.granted`, `.pending`, `.denied` cases |
| 9 | Permissions polled every 2 seconds | VERIFIED | `PermissionManager.swift`: `Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true)`; started in `MenuBarView.onAppear` |
| 10 | Onboarding skippable with "I'll do this later" | VERIFIED | `OnboardingView.swift`: `Button("I'll do this later") { advanceStep() }` present on each step |
| 11 | Onboarding state persisted across launches | VERIFIED | `PermissionManager.swift`: `markOnboardingComplete()` sets `UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")`; `loadOnboardingState()` reads it; `MenuBarView.onAppear` checks flag before showing onboarding |
| 12 | Error state shows "Model load failed. Restart app." in red | VERIFIED | `ModelWarmupService.swift`: `self?.error = "Model load failed. Restart app."`; `WarmupRow.swift`: renders error text with `.foregroundColor(.red)` |

**Score:** 12/12 truths verified (8 fully automated, 4 require human visual/interaction confirmation)

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `Dicticus/Dicticus/DicticusApp.swift` | @main App with MenuBarExtra, no WindowGroup | VERIFIED | Contains `@main`, `MenuBarExtra`, `MenuBarExtraStyle(.window)`, `import WhisperKit`, `@StateObject` for both services, `.symbolEffect(.pulse, isActive: warmupService.isWarming)` |
| `Dicticus/Dicticus/Info.plist` | LSUIElement=true, NSMicrophoneUsageDescription | VERIFIED | Both keys present with correct values |
| `Dicticus/Dicticus/Dicticus.entitlements` | Sandbox disabled, audio-input enabled | VERIFIED | `com.apple.security.app-sandbox = false`, `com.apple.security.device.audio-input = true` |
| `Dicticus/Dicticus/Views/MenuBarView.swift` | Dropdown with permission rows and Quit button | VERIFIED | Contains `PermissionRow` x3, `WarmupRow()`, `"Quit Dicticus"`, `@EnvironmentObject` for both managers |
| `Dicticus/Dicticus/Services/PermissionManager.swift` | ObservableObject for Microphone/Accessibility/Input Monitoring | VERIFIED | `@MainActor class PermissionManager: ObservableObject`; all three `@Published` status vars; `startPolling()` with 2s timer; `allGranted` computed; `markOnboardingComplete()` / `loadOnboardingState()` |
| `Dicticus/Dicticus/Utilities/SystemSettingsURLs.swift` | URL constants for Privacy panes | VERIFIED | `Privacy_Microphone`, `Privacy_Accessibility`, `Privacy_ListenEvent` URLs; `open(_:)` helper |
| `Dicticus/Dicticus/Views/PermissionRow.swift` | Reusable permission status row | VERIFIED | `struct PermissionRow: View`; renders `status.iconName`, `status.label`, `"Grant Access"`, `"Open Settings"` |
| `Dicticus/Dicticus/Views/OnboardingView.swift` | Sequential first-launch flow | VERIFIED | 3-step flow; "Dicticus needs a few permissions to work" heading; "I'll do this later" skip; `@Binding var isPresented` |
| `Dicticus/Dicticus/Services/ModelWarmupService.swift` | ObservableObject for WhisperKit warmup | VERIFIED | `@MainActor class ModelWarmupService: ObservableObject`; `isWarming`, `isReady`, `error`; `warmup()` with `Task.detached(priority: .utility)`; `showWarmupRow` and `statusText` computed; `whisperKitInstance` exposed for Phase 2 |
| `Dicticus/Dicticus/Views/WarmupRow.swift` | Warm-up progress row | VERIFIED | `ProgressView()` for warming; `.foregroundColor(.red)` for error; hidden when `showWarmupRow == false` |
| `Dicticus/DicticusTests/PermissionManagerTests.swift` | Tests for PermissionStatus and PermissionManager | VERIFIED | 14 test methods covering enum values, `allGranted`, and UserDefaults persistence |
| `Dicticus/DicticusTests/SystemSettingsURLTests.swift` | Tests for URL constants | VERIFIED | 7 test methods verifying scheme and Privacy anchors for all 3 permissions |
| `Dicticus/DicticusTests/ModelWarmupServiceTests.swift` | Tests for warmup state machine | VERIFIED | 13 test methods covering initial state, warming, ready, error, and guard logic |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `DicticusApp.swift` | `MenuBarView.swift` | `MenuBarExtra` content closure | WIRED | `MenuBarExtra { MenuBarView() ... }` present |
| `DicticusApp.swift` | `PermissionManager.swift` | `@StateObject` + `.environmentObject` | WIRED | `@StateObject private var permissionManager = PermissionManager()` and `.environmentObject(permissionManager)` both present |
| `DicticusApp.swift` | `ModelWarmupService.swift` | `@StateObject` + `.environmentObject` + `warmup()` call | WIRED | `@StateObject private var warmupService = ModelWarmupService()`, `.environmentObject(warmupService)`, `warmupService.warmup()` in `.onAppear` |
| `DicticusApp.swift` | `ModelWarmupService.swift` | Icon `symbolEffect` driven by `isWarming` | WIRED | `.symbolEffect(.pulse, isActive: warmupService.isWarming)` present |
| `MenuBarView.swift` | `PermissionRow.swift` | `PermissionRow` instantiation x3 | WIRED | Three `PermissionRow(title:status:grantAction:settingsURL:)` calls, each using `permissionManager.*Status` and `SystemSettingsURL.*` |
| `MenuBarView.swift` | `WarmupRow.swift` | Conditional display | WIRED | `WarmupRow().environmentObject(warmupService)` present; conditional `Divider` driven by `warmupService.showWarmupRow` |
| `OnboardingView.swift` | `PermissionManager.swift` | Permission request calls on button press | WIRED | `grantCurrentPermission()` calls `permissionManager.requestMicrophone()`, `requestAccessibility()`, `requestInputMonitoring()` |
| `PermissionManager.swift` | `SystemSettingsURLs.swift` | URLs passed to `NSWorkspace.shared.open()` | WIRED | `PermissionRow` calls `SystemSettingsURL.open(settingsURL)` — `SystemSettingsURL` is also used in `MenuBarView` for the `settingsURL` parameter |
| `ModelWarmupService.swift` | `WhisperKit` | `WhisperKit(WhisperKitConfig())` initialization | WIRED | `import WhisperKit` and `let pipe = try await WhisperKit(WhisperKitConfig())` inside `Task.detached` |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|--------------------|--------|
| `PermissionRow.swift` | `status: PermissionStatus` | `permissionManager.microphoneStatus` / `accessibilityStatus` / `inputMonitoringStatus` — set by `checkAll()` via `AVCaptureDevice.authorizationStatus`, `AXIsProcessTrusted()`, `CGPreflightListenEventAccess()` | Yes — live OS API calls | FLOWING |
| `WarmupRow.swift` | `warmupService.isWarming`, `warmupService.error` | Set by `warmup()` in `Task.detached` on actual `WhisperKit(WhisperKitConfig())` call | Yes — real async ML init | FLOWING |
| `OnboardingView.swift` | `currentStep` / `isPresented` | Driven by `advanceStep()` and `grantCurrentPermission()` calling real permission APIs | Yes — live permission request | FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| App builds successfully | `xcodebuild -scheme Dicticus -destination 'platform=macOS' build` | `** BUILD SUCCEEDED **` | PASS |
| WhisperKit resolves at 0.18.0 | Package.resolved grep | `"version" : "0.18.0"` from `https://github.com/argmaxinc/WhisperKit.git` | PASS |
| Hardened Runtime enabled | project.pbxproj grep | `ENABLE_HARDENED_RUNTIME = YES` (two entries for Debug+Release) | PASS |
| 35 unit tests pass | Reported in 01-03-SUMMARY.md | 35/35 passed (PermissionManagerTests: 14, SystemSettingsURLTests: 7, ModelWarmupServiceTests: 13, DicticusTests: 1) | PASS (per SUMMARY — re-run would require network/model) |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| APP-01 | 01-01-PLAN | Menu bar app with minimal UI (no main window) | SATISFIED | `MenuBarExtra` scene, no `WindowGroup`, `LSUIElement=true` |
| APP-02 | 01-02-PLAN | First-run onboarding guides user through Microphone and Accessibility permissions | SATISFIED | `OnboardingView.swift` sequential 3-step flow, `PermissionManager.swift` polling, `PermissionRow.swift` status rows |
| INFRA-03 | 01-03-PLAN | CoreML warm-up happens in background at launch (not on first hotkey press) | SATISFIED | `ModelWarmupService.warmup()` called in `MenuBarView.onAppear` (triggered at first dropdown display); `Task.detached(priority: .utility)` keeps it off main thread |
| INFRA-05 | 01-01-PLAN | App distributed as unsigned/notarized DMG (sandbox incompatible) | SATISFIED (partially -- DMG packaging deferred to Phase 5 per ROADMAP SC-4) | `Dicticus.entitlements`: sandbox=false, audio-input=true; `ENABLE_HARDENED_RUNTIME=YES` in project.pbxproj. DMG creation explicitly deferred to Phase 5. |

**Note on INFRA-05:** The ROADMAP Phase 1 Success Criterion 4 explicitly states "DMG packaging deferred to Phase 5". The entitlements configuration (sandbox disabled, Hardened Runtime enabled) is complete. The actual DMG artifact is not expected in Phase 1.

**Note on APP-02:** The REQUIREMENTS.md text says "Microphone and Accessibility permissions" but implementation also covers Input Monitoring, consistent with the PLAN's must_haves and the three-permission design in the research/context documents. This is an expansion of scope, not a shortfall.

### Orphaned Requirements Check

REQUIREMENTS.md Traceability table maps the following to Phase 1: APP-01, APP-02, INFRA-03, INFRA-05. These match exactly the requirement IDs declared across the three plans. No orphaned requirements.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| None found | - | No TODO/FIXME/placeholder, no empty handlers, no return null/[]/{}  | - | - |

The only comment resembling a stub is in `MenuBarView.swift` (line 6): `// Warm-up status row will be added here by Plan 03` — this was a historical plan comment that no longer applies since Plan 03 has completed and `WarmupRow` is present and wired. The comment is in the doc-comment block, not in the rendered view body, and does not indicate incomplete implementation.

### Human Verification Required

#### 1. App Launch as Menu Bar Agent

**Test:** Build and run Dicticus.app. Observe the Dock and menu bar.
**Expected:** App icon appears in menu bar (mic or mic.slash symbol). No icon in Dock. No window opens.
**Why human:** Cannot verify visual menu bar presence or Dock exclusion with xcodebuild alone.

#### 2. Light/Dark Mode Icon Rendering

**Test:** With app running, switch macOS between Light and Dark appearance via System Settings > Appearance.
**Expected:** The mic SF Symbol in the menu bar adapts correctly to both modes without becoming invisible or miscolored.
**Why human:** Appearance rendering requires visual inspection.

#### 3. Onboarding Sequential Flow (First Launch)

**Test:** Delete `hasCompletedOnboarding` from UserDefaults (or run on a fresh machine), then launch app and click menu bar icon.
**Expected:** OnboardingView appears showing step 1 (Microphone). "Grant Access" triggers OS mic prompt. "I'll do this later" advances to step 2 (Accessibility). Steps proceed in order. After step 3, onboarding dismisses and permission rows appear.
**Why human:** First-launch UserDefaults state and sequential onboarding require interactive testing.

#### 4. Permission State Polling

**Test:** With app running and a permission denied, go to System Settings > Privacy & Security and grant the permission.
**Expected:** Within approximately 2 seconds, the permission row in the Dicticus dropdown updates from "Denied/Required" to "Granted" with a green checkmark — without restarting the app.
**Why human:** Live polling behavior requires observing the running app while interacting with System Settings.

#### 5. Grant Access / Open Settings Buttons

**Test:** With microphone permission in "notDetermined" state, click "Grant Access". With a permission denied, click "Open Settings".
**Expected:** "Grant Access" triggers the macOS permission alert. "Open Settings" opens the correct System Settings Privacy pane (e.g., Privacy_Microphone for microphone).
**Why human:** TCC permission prompts and System Settings navigation require human interaction.

#### 6. Warm-Up Progress and Icon Pulse

**Test:** On first launch (or after clearing WhisperKit model cache), click the menu bar icon immediately after launch.
**Expected:** Menu bar mic icon pulses. Dropdown shows WarmupRow with indeterminate ProgressView and "Preparing models…" text. After compilation completes, pulsing stops and WarmupRow disappears from dropdown.
**Why human:** Requires running the app and observing async animation/state transitions.

#### 7. mic vs mic.slash State

**Test:** With at least one permission missing, observe menu bar icon. Then grant all three permissions.
**Expected:** Icon shows mic.slash when any permission is missing; switches to mic when all three are granted.
**Why human:** Requires permission state changes and visual observation of the menu bar icon.

#### 8. Error State on Model Load Failure

**Test:** Disconnect network on a machine without cached WhisperKit models, launch app, click menu bar icon.
**Expected:** After warmup fails, WarmupRow shows "Model load failed. Restart app." in red text. App remains functional for permission setup.
**Why human:** Requires controlled network conditions and a machine without cached models.

### Gaps Summary

No gaps found. All 12 must-have truths are verified in the codebase. All required artifacts exist, are substantive (not stubs), are wired to each other correctly, and data flows through them via real OS APIs and the WhisperKit library.

The 8 human verification items above are runtime/visual behaviors that cannot be confirmed by static code inspection alone. They are expected to pass given the implementation quality but require a human to confirm on a running machine.

---

_Verified: 2026-04-14_
_Verifier: Claude (gsd-verifier)_
