---
phase: 01-foundation-app-shell
plan: 01
subsystem: macOS App Shell
tags: [swift, swiftui, menubarextra, whisperkit, xcode, spm, entitlements]
dependency_graph:
  requires: []
  provides: [Xcode project, MenuBarExtra app shell, WhisperKit SPM dependency, unsandboxed entitlements]
  affects: [01-02, 01-03]
tech_stack:
  added: [WhisperKit 0.18.0, xcodegen]
  patterns: [MenuBarExtra .window style, LSUIElement menu bar agent, Hardened Runtime without sandbox]
key_files:
  created:
    - Dicticus/Dicticus/DicticusApp.swift
    - Dicticus/Dicticus/Views/MenuBarView.swift
    - Dicticus/Dicticus/Info.plist
    - Dicticus/Dicticus/Dicticus.entitlements
    - Dicticus/Dicticus/Assets.xcassets/Contents.json
    - Dicticus/Dicticus/Assets.xcassets/AppIcon.appiconset/Contents.json
    - Dicticus/DicticusTests/DicticusTests.swift
    - Dicticus/project.yml
    - Dicticus/Dicticus.xcodeproj/project.pbxproj
    - Dicticus/Dicticus.xcodeproj/project.xcworkspace/contents.xcworkspacedata
    - Dicticus/Dicticus.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved
  modified: []
decisions:
  - xcodegen used to generate reproducible project.pbxproj from project.yml spec
  - WhisperKit 0.18.0+ (upToNextMajor) chosen; resolves to 0.18.0 with locked Package.resolved
  - import WhisperKit placed in DicticusApp.swift to verify SPM linkage at compile time
  - menuBarExtraStyle(.window) chosen over .menu to support future custom UI in Plans 02/03
metrics:
  duration: "3 minutes"
  completed_date: "2026-04-15"
  tasks_completed: 2
  tasks_total: 2
  files_created: 11
  files_modified: 0
requirements_satisfied: [APP-01, INFRA-05]
---

# Phase 01 Plan 01: Xcode Project Shell and WhisperKit SPM Summary

**One-liner:** SwiftUI MenuBarExtra shell with LSUIElement, unsandboxed Hardened Runtime entitlements, and WhisperKit 0.18.0 linked via xcodegen-generated Xcode project.

## What Was Built

A runnable macOS menu bar app foundation:

- `DicticusApp.swift` — `@main` App struct with `MenuBarExtra { MenuBarView() }` scene and SF Symbol `"mic"` icon; no `WindowGroup`
- `MenuBarView.swift` — Dropdown with placeholder comment for Plans 02/03 content and a "Quit Dicticus" button with `keyboardShortcut("q")`
- `Info.plist` — `LSUIElement=true` (no Dock icon) and `NSMicrophoneUsageDescription` for TCC prompt
- `Dicticus.entitlements` — Sandbox disabled (`com.apple.security.app-sandbox: false`), audio input enabled (`com.apple.security.device.audio-input: true`)
- `project.yml` — xcodegen spec declaring `ENABLE_HARDENED_RUNTIME=YES`, `SWIFT_VERSION=6.0`, `MACOSX_DEPLOYMENT_TARGET=15.0`, and WhisperKit SPM package
- `Package.resolved` — Pins WhisperKit 0.18.0 with transitive dependencies (swift-transformers, swift-collections, etc.)

## Commits

| Task | Commit | Description |
|------|--------|-------------|
| Task 1: Xcode project shell | c18e859 | feat(01-01): create Xcode project with MenuBarExtra shell and entitlements |
| Task 2: WhisperKit SPM | e9a994b | feat(01-01): add WhisperKit SPM dependency and verify resolution |

## Verification Results

All acceptance criteria passed:

- `xcodebuild build` → `** BUILD SUCCEEDED **`
- `xcodebuild -resolvePackageDependencies` → `whisperkit: https://github.com/argmaxinc/WhisperKit.git @ 0.18.0`
- `DicticusApp.swift` contains `@main`, `MenuBarExtra`, `Image(systemName: "mic")`, `.menuBarExtraStyle(.window)`, `import WhisperKit`; no `WindowGroup`
- `MenuBarView.swift` contains `"Quit Dicticus"` and `NSApplication.shared.terminate`
- `Info.plist` contains `LSUIElement` (true) and `NSMicrophoneUsageDescription`
- `Dicticus.entitlements` contains `com.apple.security.app-sandbox` (false) and `com.apple.security.device.audio-input` (true)
- `project.pbxproj` contains WhisperKit URL and minimumVersion 0.18.0
- `ENABLE_HARDENED_RUNTIME = YES` in project.pbxproj build settings

## Deviations from Plan

### Auto-fixed Issues

None required. Plan executed as written with one intentional tooling decision:

**[Tooling] xcodegen used instead of manual project.pbxproj creation**
- The plan suggested "manual Xcode project creation" as the approach
- xcodegen was available (`/opt/homebrew/bin/xcodegen`) and generates a reproducible, maintainable project.pbxproj from a declarative YAML spec
- This is strictly better — the project.yml serves as source of truth for project structure and build settings, and the project.pbxproj can be regenerated from it
- No functional deviation from plan requirements; all build settings match exactly

## Known Stubs

None. The comment `// Permission rows and warm-up status will be added by Plans 02 and 03` in MenuBarView.swift is intentional scaffolding per the plan's Phase 1 scope (D-05). The view renders correctly with just the Quit button.

## Threat Flags

No new security surface beyond the plan's threat model. The three mitigations in the threat register are all implemented:

- **T-01-02 (Elevation of Privilege):** `ENABLE_HARDENED_RUNTIME = YES` verified in project.pbxproj; only `audio-input` entitlement granted
- **T-01-03 (Information Disclosure):** NSMicrophoneUsageDescription explicitly states "Your audio never leaves this device"

## Self-Check: PASSED

Files verified to exist:
- Dicticus/Dicticus/DicticusApp.swift: FOUND
- Dicticus/Dicticus/Views/MenuBarView.swift: FOUND
- Dicticus/Dicticus/Info.plist: FOUND
- Dicticus/Dicticus/Dicticus.entitlements: FOUND
- Dicticus/Dicticus.xcodeproj/project.pbxproj: FOUND
- Dicticus/Dicticus.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved: FOUND

Commits verified:
- c18e859: FOUND
- e9a994b: FOUND
