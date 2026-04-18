---
phase: 05-polish-distribution
plan: "03"
subsystem: distribution
tags: [dmg, packaging, memory-profiling, ad-hoc-signing, infra]
dependency_graph:
  requires:
    - 05-01 (settings section + UI polish must be present in the .app being packaged)
    - 05-02 (modifier-only hotkeys wired before DMG is built)
  provides:
    - scripts/build-dmg.sh (Release .app + styled DMG creation pipeline)
    - scripts/verify-memory.sh (INFRA-04 memory budget validation)
    - scripts/dmg-background.png (1320x800 Retina DMG background asset)
  affects: []
tech_stack:
  added:
    - create-dmg 1.2.3 (Homebrew shell script, styled DMG creation)
  patterns:
    - xcodebuild build with CODE_SIGN_IDENTITY="-" for ad-hoc signed Release .app
    - footprint CLI for phys_footprint memory measurement
    - Pillow (Python) for programmatic PNG background generation
key_files:
  created:
    - scripts/build-dmg.sh
    - scripts/dmg-background.png
    - scripts/verify-memory.sh
  modified: []
decisions:
  - D-05 deviation: xcodebuild archive replaced by xcodebuild build — archive/exportArchive requires Team ID which the project lacks (unsigned distribution per D-06). Same Release .app output, ad-hoc signed.
  - DMG window layout: icon at (180,200), Applications link at (480,200), 660x400 window, 128pt icon size — matches RESEARCH.md Pattern 3
  - Gatekeeper bypass: System Settings > Privacy & Security > Open Anyway (macOS 15 Sequoia — right-click bypass removed per Pitfall 1)
metrics:
  duration: "10 minutes"
  completed_date: "2026-04-18"
  tasks_completed: 2
  tasks_total: 3
  files_created: 3
  files_modified: 0
status: checkpoint-pending
checkpoint_task: "Task 3: Verify DMG installation and memory budget"
---

# Phase 05 Plan 03: DMG Build Pipeline and Memory Profiling Summary

**One-liner:** DMG build pipeline with ad-hoc signed Release app via create-dmg, plus footprint-based 3 GB memory budget validation script.

## Status

**PAUSED at Task 3: checkpoint:human-verify (blocking)**

Tasks 1 and 2 are complete and committed. Task 3 requires the human to build the DMG, mount it, install the app, and run memory profiling. The executor did not run the full build pipeline (per plan instructions).

## Completed Tasks

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Create build-dmg.sh and DMG background image | `6efc832` | scripts/build-dmg.sh, scripts/dmg-background.png |
| 2 | Create memory profiling script | `a2028c8` | scripts/verify-memory.sh |

## What Was Built

### Task 1: build-dmg.sh and dmg-background.png

`scripts/build-dmg.sh` is a complete 4-step build pipeline:
1. `xcodegen generate` — regenerates Xcode project from project.yml
2. `xcodebuild -configuration Release CODE_SIGN_IDENTITY="-"` — builds ad-hoc signed Release .app
3. `codesign -d --entitlements` — verifies entitlements embedded correctly
4. `create-dmg` — creates styled DMG with dark background, icon at (180,200), Applications symlink at (480,200)

`scripts/dmg-background.png` is a 1320x800 Retina PNG (2x of 660x400 DMG window):
- Background: #1C1C1E dark grey
- Right arrow (→) at center in white at 40% opacity
- "Drag Dicticus to Applications" label below arrow in white at 70% opacity
- Fully opaque RGB (no alpha channel — required for DMG backgrounds)

### Task 2: verify-memory.sh

`scripts/verify-memory.sh` measures Dicticus memory against the 3 GB INFRA-04 budget:
- Checks `pgrep -x Dicticus` to confirm app is running before profiling
- Runs `footprint -p Dicticus` and `footprint -p Dicticus -w` for full breakdown
- Extracts `phys_footprint` value and compares to `BUDGET_MB=3072`
- Outputs `PASS: NNN MB <= 3072 MB budget` or `FAIL` with recommendations
- Expected result: ~2-2.5 GB (Parakeet CoreML 1.24 GB + Gemma 3 1B GGUF 722 MB + runtime overhead)

## Pending: Task 3 Human Verification

**Type:** checkpoint:human-verify  
**Blocking:** Yes — INFRA-04 acceptance requires measured phys_footprint result

### Verification Steps

1. **Build the DMG:**
   ```bash
   cd /Users/mowehr/code/dicticus && ./scripts/build-dmg.sh
   ```
   Expected: `Dicticus.dmg` created in the project root.

2. **Mount and inspect:**
   ```bash
   hdiutil attach Dicticus.dmg
   ls /Volumes/Dicticus/
   ```
   Expected: `Dicticus.app` and `Applications` symlink visible.

3. **Install and launch:** Drag Dicticus.app from the DMG to Applications (or a test folder), then launch it. On first launch: System Settings > Privacy & Security > Open Anyway.

4. **Wait for models to load:** Menu bar dropdown shows "Ready" status for both ASR and LLM models.

5. **Run memory verification:**
   ```bash
   cd /Users/mowehr/code/dicticus && ./scripts/verify-memory.sh
   ```
   Expected: `PASS: NNN MB <= 3072 MB budget`

6. **Test dictation:** Perform a quick dictation from the DMG-installed copy to confirm end-to-end function.

7. **Unmount:**
   ```bash
   hdiutil detach /Volumes/Dicticus
   ```

### Resume Signal

Type "approved" with memory profiling results, or describe issues found.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] create-dmg exit code handling**
- **Found during:** Task 1
- **Issue:** The plan's original build script had a logic error — the `$?` check after `|| { ... }` inside the compound command always evaluates to 0, making the error detection unreliable
- **Fix:** Captured exit code in `EXIT_CODE` variable before the compound command, then evaluated `$EXIT_CODE` correctly
- **Files modified:** scripts/build-dmg.sh
- **Commit:** 6efc832

### Architectural Notes

**D-05 deviation (from plan, not this executor):** The plan acknowledges that CONTEXT.md D-05 specifies `xcodebuild archive + exportArchive`, but RESEARCH.md Pitfall 6 found that `archive` requires a Team ID. The build script uses `xcodebuild build` instead. This deviation was pre-decided in the plan — no change needed by this executor.

## Known Stubs

None — scripts are complete and functional. The only incomplete item is the human verification step (Task 3).

## Threat Flags

None — no new network endpoints, auth paths, or trust boundaries introduced. The DMG distribution threat (T-05-06) and memory budget threat (T-05-07) are both handled per the plan's threat model.

## Self-Check

**Files created:**
- scripts/build-dmg.sh: exists, executable (-rwxr-xr-x)
- scripts/dmg-background.png: exists, 1320x800 pixels
- scripts/verify-memory.sh: exists, executable (-rwxr-xr-x)

**Commits:**
- 6efc832: feat(05-03): add DMG build script and background image
- a2028c8: feat(05-03): add memory profiling script (INFRA-04)

## Self-Check: PASSED
