---
phase: 01-foundation-app-shell
plan: 03
subsystem: model-warmup
tags: [whisperkit, coreml, warmup, menu-bar, swift, swiftui, tdd]
dependency_graph:
  requires: ["01-01", "01-02"]
  provides: ["ModelWarmupService", "WarmupRow", "warm-up UI wiring"]
  affects: ["DicticusApp.swift", "MenuBarView.swift"]
tech_stack:
  added: []
  patterns: ["Task.detached(priority: .utility) for background ML work", "ObservableObject state machine for warm-up lifecycle", "EnvironmentObject propagation for service injection"]
key_files:
  created:
    - Dicticus/Dicticus/Services/ModelWarmupService.swift
    - Dicticus/Dicticus/Views/WarmupRow.swift
    - Dicticus/DicticusTests/ModelWarmupServiceTests.swift
  modified:
    - Dicticus/Dicticus/DicticusApp.swift
    - Dicticus/Dicticus/Views/MenuBarView.swift
    - Dicticus/Dicticus.xcodeproj/project.pbxproj
decisions:
  - "warmup() called in MenuBarView .onAppear (not App.init) so warm-up lifecycle mirrors dropdown appearance — consistent with Plan 02 permission polling pattern"
  - "showWarmupRow drives both WarmupRow visibility and the conditional Divider above permission rows — single source of truth"
  - "WhisperKitConfig() with no model specified uses auto-recommendation for Phase 1; Phase 2 will pin 'large-v3-turbo'"
metrics:
  duration: "2 minutes"
  completed: "2026-04-15"
  tasks_completed: 2
  files_created: 3
  files_modified: 3
requirements_fulfilled: [INFRA-03]
---

# Phase 01 Plan 03: Model Warm-up Infrastructure Summary

**One-liner:** WhisperKit background warm-up with CoreML compilation at launch, icon pulse animation, and dropdown status row that auto-hides when ready.

## What Was Built

### ModelWarmupService (Services/ModelWarmupService.swift)

`@MainActor ObservableObject` managing WhisperKit initialization lifecycle:

- `isWarming`, `isReady`, `error: String?` — `@Published` state driving all UI
- `showWarmupRow: Bool` — computed; true when warming OR error present, false when ready
- `statusText: String?` — computed; "Preparing models…" while warming, error string on failure, nil when ready
- `warmup()` — guard prevents duplicate calls; delegates to `Task.detached(priority: .utility)` so CoreML compilation never blocks the main thread
- `whisperKitInstance: WhisperKit?` — exposes initialized instance for Phase 2 ASR pipeline

### WarmupRow (Views/WarmupRow.swift)

Conditional SwiftUI view injected as `@EnvironmentObject`:

- Warming state: `ProgressView(.small)` + "Preparing models…" in `.caption` / `.secondary`
- Failed state: `exclamationmark.triangle.fill` icon + error text in `.red`
- Ready state: view body is empty (`showWarmupRow == false`) — row vanishes entirely

### DicticusApp.swift updates

- Added `@StateObject private var warmupService = ModelWarmupService()`
- `warmupService` passed as `.environmentObject` to `MenuBarView`
- Menu bar icon: `Image(systemName: iconName).symbolEffect(.pulse, isActive: warmupService.isWarming)`
- `iconName` computed property: `"mic.slash"` when permissions missing, `"mic"` otherwise (pulse communicates warm-up state)
- `warmupService.warmup()` called in `.onAppear` on the MenuBarExtra content — D-03 fulfilled

### MenuBarView.swift updates

- Added `@EnvironmentObject var warmupService: ModelWarmupService`
- Inserted `WarmupRow()` at top of dropdown (above permission rows) with conditional `Divider` that only appears when warm-up row is visible
- Matches UI-SPEC Dropdown Menu Structure exactly

### ModelWarmupServiceTests (DicticusTests/ModelWarmupServiceTests.swift)

13 unit tests covering:
- Initial state (isWarming=false, isReady=false, error=nil)
- Warming state (statusText, showWarmupRow)
- Ready state (showWarmupRow=false, statusText=nil)
- Error state (showWarmupRow=true, statusText contains error message)
- Guard logic (duplicate warmup() call prevention)

## Decisions Made

| Decision | Rationale |
|----------|-----------|
| `warmup()` called in `MenuBarView.onAppear` not `App.init` | Mirrors Plan 02's `startPolling()` pattern — both tied to dropdown lifetime; consistent, avoids divergent lifecycle strategies |
| `WhisperKitConfig()` with no model (auto-recommendation) | Research Open Question 3 resolved: Phase 1 validates warm-up infrastructure; Phase 2 pins `"large-v3-turbo"` after ASR pipeline integration |
| Conditional Divider above permission rows | Only shown when warm-up row is visible — avoids orphaned divider when row disappears |
| `showWarmupRow` as single source of truth | Both WarmupRow visibility and the Divider check this property — no duplicated logic |

## Threat Mitigations Applied

| Threat ID | Mitigation Applied |
|-----------|-------------------|
| T-03-02 (DoS: CoreML compilation blocks UI) | `Task.detached(priority: .utility)` + `[weak self]` + guard against re-entry |
| T-03-04 (DoS: no network on first launch) | Error state shown: "Model load failed. Restart app." — app remains functional for permission setup |

## Deviations from Plan

None — plan executed exactly as written. Plan 02's PermissionManager code was merged successfully alongside the new warm-up code without overwriting.

## Verification Results

- `xcodebuild build`: BUILD SUCCEEDED
- `xcodebuild test -only-testing DicticusTests/ModelWarmupServiceTests`: 13/13 passed
- `xcodebuild test` (full suite): 35/35 passed, 0 failures

## Self-Check: PASSED

- FOUND: Dicticus/Dicticus/Services/ModelWarmupService.swift
- FOUND: Dicticus/Dicticus/Views/WarmupRow.swift
- FOUND: Dicticus/DicticusTests/ModelWarmupServiceTests.swift
- FOUND commit: 8a7a71b (feat(01-03): implement ModelWarmupService)
- FOUND commit: 98b7169 (feat(01-03): wire warm-up UI)
