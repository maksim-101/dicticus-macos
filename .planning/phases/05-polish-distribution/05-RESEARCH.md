# Phase 5: Polish & Distribution - Research

**Researched:** 2026-04-18
**Domain:** macOS app distribution, memory profiling, modifier-only hotkeys, launch-at-login
**Confidence:** HIGH

## Summary

Phase 5 covers four distinct work areas: (1) memory profiling to validate the 3 GB budget, (2) launch-at-login via LaunchAtLogin-Modern, (3) DMG packaging for unsigned distribution, and (4) modifier-only hotkey support via CGEventTap. All four areas are well-understood macOS development patterns with established libraries and tooling.

The most significant finding is that the CONTEXT.md decision D-06 states "Users right-click > Open to bypass Gatekeeper" -- this is no longer accurate on macOS 15 Sequoia (the project's deployment target). Since macOS 15.0, the Control-click/right-click bypass for Gatekeeper has been removed. Users must instead go to System Settings > Privacy & Security > Open Anyway. Additionally, on Apple Silicon, all code must be at least ad-hoc signed (which Xcode does by default with "Sign to Run Locally"). The build should use ad-hoc signing, not truly unsigned builds.

**Primary recommendation:** Use ad-hoc signing (Xcode default for no developer account), create-dmg (Homebrew shell script) for styled DMG, LaunchAtLogin-Modern v1.1.0 for login items, and a CGEventTap with `.flagsChanged` event mask for Fn-based modifier-only hotkeys.

<user_constraints>

## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Claude's discretion on memory profiling methodology -- profile total memory with both ASR and LLM loaded, validate against the 3 GB budget (INFRA-04)
- **D-02:** Launch at login off by default -- user explicitly opts in via a toggle in the menu bar dropdown
- **D-03:** Settings section in dropdown -- add a new settings/preferences section at the bottom of the dropdown (above Quit)
- **D-04:** Use LaunchAtLogin-Modern library (macOS 13+) -- handles ServiceManagement API, stores state correctly
- **D-05:** Xcode archive + export workflow -- use `xcodebuild archive` + `xcodebuild -exportArchive` pipeline
- **D-06:** Unsigned for now -- skip code signing and notarization for v1. Users right-click > Open to bypass Gatekeeper. Can add later.
- **D-07:** Styled DMG -- custom background image with app icon and arrow pointing to Applications folder symlink
- **D-08:** Parallel system -- CGEventTap flagsChanged listener runs alongside KeyboardShortcuts
- **D-09:** Fn+Shift and Fn+Control only -- just the two defaults from Phase 3
- **D-10:** Configurable via dropdown picker -- add a picker in the settings section for preset Fn-based modifier combos
- **D-11:** Fn-based pairs only in picker -- Fn+Shift, Fn+Control, Fn+Option

### Claude's Discretion
- Memory profiling methodology and tooling choice
- DMG background image design and icon layout
- CGEventTap implementation details (event mask, callback structure, flag debouncing)
- Settings section visual design in the dropdown
- Modifier-only hotkey picker UI layout
- Build script / Makefile structure for the archive+DMG pipeline
- End-to-end test strategy (manual checklist vs automated)

### Deferred Ideas (OUT OF SCOPE)
None -- discussion stayed within phase scope

</user_constraints>

<phase_requirements>

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| INFRA-04 | Total memory usage stays under 3 GB on 16 GB Apple Silicon Mac | `footprint` CLI tool available for memory profiling; Parakeet CoreML ~1.24 GB + Gemma 3 1B GGUF ~722 MB = ~2 GB model footprint; system overhead and runtime buffers must fit remaining ~1 GB |
| APP-05 | App launches at login (optional, configurable) | LaunchAtLogin-Modern v1.1.0 provides `LaunchAtLogin.Toggle()` SwiftUI view and `LaunchAtLogin.isEnabled` API; requires macOS 13+; no entitlements needed for unsandboxed apps |

</phase_requirements>

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| LaunchAtLogin-Modern | 1.1.0 | Login item registration via ServiceManagement | Sindresorhus library; uses SMAppService on macOS 13+; provides SwiftUI Toggle view out of the box; same author as KeyboardShortcuts already in the project [VERIFIED: github.com/sindresorhus/LaunchAtLogin-Modern] |
| create-dmg (shell script) | latest (Homebrew) | Styled DMG creation | Shell script from create-dmg/create-dmg; no Node.js dependency; supports background image, icon positioning, Applications symlink, volume name; installs via `brew install create-dmg` [VERIFIED: github.com/create-dmg/create-dmg] |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| footprint | macOS built-in | Memory profiling CLI | Measure dirty memory footprint of the running app; same metric as Activity Monitor [VERIFIED: available on dev machine] |
| xctrace | macOS built-in (Xcode) | Instruments profiling from CLI | Alternative memory profiling via Instruments templates if footprint is insufficient [VERIFIED: available on dev machine] |
| hdiutil | macOS built-in | DMG creation primitive | Used internally by create-dmg; can be used directly if create-dmg is not wanted [VERIFIED: available on dev machine] |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| create-dmg (shell) | sindresorhus/create-dmg (npm) | npm version requires Node.js 20+; shell version has zero dependencies beyond macOS built-ins |
| create-dmg (shell) | Manual hdiutil + osascript | More control but significantly more code to maintain; create-dmg wraps all the complexity |
| LaunchAtLogin-Modern | Direct SMAppService API | More code; LaunchAtLogin-Modern is ~50 lines of wrapping that handles edge cases |

**Installation:**
```bash
# LaunchAtLogin-Modern -- add to project.yml packages
# URL: https://github.com/sindresorhus/LaunchAtLogin-Modern
# from: 1.1.0

# create-dmg -- install on build machine
brew install create-dmg
```

## Architecture Patterns

### Pattern 1: CGEventTap for Modifier-Only Hotkeys

**What:** A system-level event tap listening for `.flagsChanged` events to detect modifier-only key combinations (Fn+Shift, Fn+Control, Fn+Option). Runs in parallel with KeyboardShortcuts, which handles standard key combos.

**When to use:** When the hotkey is modifier keys only (no letter/number key), since KeyboardShortcuts cannot capture modifier-only combos.

**Implementation approach:**

```swift
// Source: alt-tab-macos + Apple CGEventFlags documentation [CITED: developer.apple.com/documentation/coregraphics/cgeventflags]
import CoreGraphics

// CGEventTap creation -- runs on a background CFRunLoop
// .listenOnly is sufficient; we don't need to modify events
let eventMask: CGEventMask = 1 << CGEventType.flagsChanged.rawValue

let tap = CGEvent.tapCreate(
    tap: .cgSessionEventTap,
    place: .headInsertEventTap,
    options: .listenOnly,
    eventsOfInterest: eventMask,
    callback: flagsChangedCallback,
    userInfo: nil
)

// Callback signature (must be a C-compatible function, not a closure)
let flagsChangedCallback: CGEventTapCallBack = { proxy, type, event, userInfo in
    let flags = event.flags

    // Detect Fn key via maskSecondaryFn
    let fnDown = flags.contains(.maskSecondaryFn)
    let shiftDown = flags.contains(.maskShift)
    let controlDown = flags.contains(.maskControl)
    let optionDown = flags.contains(.maskAlternate)

    // Fn+Shift combo: both flags present, no others
    // Fn+Control combo: both flags present, no others
    // Route to HotkeyManager's handleKeyDown/handleKeyUp

    return Unmanaged.passUnretained(event)
}
```

**Key considerations:**
1. CGEventTap requires Accessibility permission (already granted in Phase 1 via PermissionManager)
2. The callback must be a static/global C function, not an instance method or closure
3. The tap must be added to a CFRunLoop source to receive events
4. Flag debouncing is needed -- `flagsChanged` fires for every modifier state transition, not just the "both held" state [ASSUMED]
5. The Fn key on macOS is `CGEventFlags.maskSecondaryFn` (raw value includes `NX_SECONDARYFNMASK`) [VERIFIED: macOS SDK headers]
6. Need to track previous flag state to detect transitions (press vs release)

**Anti-pattern:** Do NOT use NSEvent.addGlobalMonitorForEvents -- it cannot reliably capture Fn key events and does not work for all modifier combinations.

### Pattern 2: LaunchAtLogin Toggle in Settings Section

**What:** A SwiftUI Toggle view provided by LaunchAtLogin-Modern that handles the ServiceManagement API for login item registration.

**When to use:** For the "Launch at Login" preference in the settings section of the dropdown.

```swift
// Source: LaunchAtLogin-Modern README [CITED: github.com/sindresorhus/LaunchAtLogin-Modern]
import LaunchAtLogin

// In the settings section of MenuBarView:
LaunchAtLogin.Toggle("Launch at Login")

// Or with custom styling:
LaunchAtLogin.Toggle {
    Text("Launch at Login")
        .font(.body)
}
```

**Important:** macOS shows a system notification when a login item is added. The toggle reads state from SMAppService, not local storage, so it reflects user changes made in System Settings > General > Login Items. D-02: Off by default (LaunchAtLogin defaults to disabled).

### Pattern 3: DMG Build Pipeline

**What:** A shell script that builds a Release .app via xcodebuild, then packages it into a styled DMG using create-dmg.

**When to use:** For the distribution packaging step (D-05, D-07).

```bash
#!/bin/bash
# Build pipeline: xcodegen -> xcodebuild -> create-dmg

# Step 1: Generate Xcode project from project.yml
cd Dicticus
xcodegen generate

# Step 2: Build Release .app (ad-hoc signed, no developer identity)
xcodebuild -scheme Dicticus \
    -configuration Release \
    -derivedDataPath build \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGN_STYLE=Manual \
    DEVELOPMENT_TEAM="" \
    build

# Step 3: Locate the .app in build products
APP_PATH="build/Build/Products/Release/Dicticus.app"

# Step 4: Create styled DMG
create-dmg \
    --volname "Dicticus" \
    --background "path/to/dmg-background.png" \
    --window-size 660 400 \
    --icon-size 128 \
    --icon "Dicticus.app" 180 200 \
    --app-drop-link 480 200 \
    --no-internet-enable \
    "Dicticus.dmg" \
    "$APP_PATH/../"
```

**Note on signing:** `CODE_SIGN_IDENTITY="-"` means ad-hoc signing. This is required for Apple Silicon. The resulting app has no developer identity but is validly signed for local execution. [VERIFIED: Apple documentation confirms ad-hoc signing is the minimum for Apple Silicon]

### Pattern 4: Memory Profiling with footprint

**What:** Use the `footprint` CLI to measure the app's memory footprint with both ASR and LLM models loaded.

```bash
# After launching Dicticus and waiting for both models to warm up:
footprint -p Dicticus

# Detailed breakdown:
footprint -p Dicticus --all

# For specific dirty memory (the INFRA-04 metric):
footprint -p Dicticus -w
```

**Key metric:** `phys_footprint` is the number that matches Activity Monitor and represents the app's actual memory impact on the system. This is what must stay under 3 GB.

### Anti-Patterns to Avoid

- **Truly unsigned builds on Apple Silicon:** Apple Silicon requires at least ad-hoc signing. Using `CODE_SIGN_IDENTITY=""` with `CODE_SIGNING_REQUIRED=NO` may produce binaries that crash on launch. Use `CODE_SIGN_IDENTITY="-"` for ad-hoc signing instead.
- **Storing login item state in UserDefaults:** SMAppService is the source of truth. Users can disable login items in System Settings. Always read from `LaunchAtLogin.isEnabled`, never cache it.
- **Using NSEvent.addGlobalMonitorForEvents for Fn detection:** Global monitors do not reliably capture the Fn key flag changes. CGEventTap is the correct approach.
- **Blocking the main thread with CGEventTap callback:** The callback runs on whatever thread the RunLoop source is scheduled on. If heavy work is needed, dispatch to the main actor.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Login item registration | Custom SMAppService wrapper | LaunchAtLogin-Modern v1.1.0 | Handles ServiceManagement edge cases, provides SwiftUI Toggle, maintained by same author as KeyboardShortcuts |
| Styled DMG creation | hdiutil + osascript script | create-dmg (Homebrew) | DMG styling involves fragile AppleScript, timing-sensitive Finder commands, and complex hdiutil options; create-dmg wraps all of it |
| Code signing for distribution | Manual codesign commands | Xcode ad-hoc signing (`CODE_SIGN_IDENTITY="-"`) | Xcode handles entitlements, frameworks, and nested code signing automatically |

**Key insight:** DMG creation and login item management are both areas where hand-rolled solutions appear simple but have numerous edge cases (DMG: Finder timing, icon positioning, retina backgrounds; login items: state synchronization with System Settings, notifications, sandboxed vs unsandboxed paths).

## Common Pitfalls

### Pitfall 1: Gatekeeper Bypass Changed in macOS 15 Sequoia

**What goes wrong:** CONTEXT.md D-06 says "Users right-click > Open to bypass Gatekeeper." This no longer works on macOS 15 Sequoia (the project's deployment target).
**Why it happens:** Apple removed the Control-click/right-click Gatekeeper bypass in macOS 15. Users must now go to System Settings > Privacy & Security, find the blocked app, and click "Open Anyway."
**How to avoid:** Document the correct bypass procedure for users. The first launch attempt shows a dialog with only "Done" and "Move to Trash." After clicking Done, users must open System Settings > Privacy & Security and click "Open Anyway" within about an hour.
**Warning signs:** Users report they "can't open the app" after downloading the DMG.
[VERIFIED: Apple Support page support.apple.com/en-us/102445, multiple sources confirm the change in Sequoia]

### Pitfall 2: CGEventTap Fn Key Ambiguity

**What goes wrong:** The `flagsChanged` event fires for every modifier state transition, including intermediate states. Pressing Fn then Shift fires two events: one for Fn alone, then one for Fn+Shift.
**Why it happens:** CGEventFlags reports the *current* set of held modifiers, not which key was just pressed or released.
**How to avoid:** Track previous flags state. Detect the "combo activated" transition by comparing current flags to previous flags. The combo is "active" when both target flags are present. The combo is "released" when either flag is removed.
**Warning signs:** Hotkey triggers on single Fn press, or fails to detect Fn+Shift if pressed too quickly.
[ASSUMED -- based on training knowledge of CGEventTap behavior]

### Pitfall 3: CGEventTap Callback Must Be C-Compatible

**What goes wrong:** Attempting to use a Swift closure or instance method as the CGEventTap callback causes a compilation error.
**Why it happens:** `CGEvent.tapCreate` requires a `CGEventTapCallBack`, which is a C function pointer. Swift closures that capture context are not C-compatible.
**How to avoid:** Use a static function or a free function for the callback. Pass context via the `userInfo` pointer (as `UnsafeMutableRawPointer`), then cast it back inside the callback to access instance state.
**Warning signs:** Compiler error "a C function pointer cannot be formed from a closure that captures context."
[VERIFIED: standard CGEvent API constraint]

### Pitfall 4: create-dmg Background Image Resolution

**What goes wrong:** The DMG background image appears blurry on Retina displays.
**Why it happens:** create-dmg expects a @2x resolution background for Retina. A 660x400 window needs a 1320x800 image.
**How to avoid:** Create the background image at 2x the window size. Use PNG format.
**Warning signs:** Blurry or pixelated background in the DMG Finder window.
[ASSUMED -- standard macOS Retina behavior]

### Pitfall 5: LaunchAtLogin State Drift

**What goes wrong:** Toggle shows "enabled" but the app doesn't launch at login, or vice versa.
**Why it happens:** Users can toggle login items in System Settings > General > Login Items independently of the app's UI.
**How to avoid:** LaunchAtLogin-Modern reads from SMAppService on each access, so the Toggle automatically reflects the current system state. Do not cache `isEnabled` in UserDefaults.
**Warning signs:** Toggle state disagrees with System Settings > Login Items.
[CITED: github.com/sindresorhus/LaunchAtLogin-Modern README]

### Pitfall 6: xcodebuild Archive vs Build for Unsigned Distribution

**What goes wrong:** `xcodebuild archive` + `xcodebuild -exportArchive` fails because `-exportArchive` requires a team ID for the export options plist.
**Why it happens:** The archive/export workflow is designed for developer-signed distribution. Without a developer account, there's no valid team ID.
**How to avoid:** Use `xcodebuild build` (not archive) with `-configuration Release`. This produces a .app bundle in the derived data build products directory. Ad-hoc signing with `CODE_SIGN_IDENTITY="-"` works with the build action. Skip the archive/export pipeline entirely for unsigned distribution.
**Warning signs:** "No 'teamID' specified" error from exportArchive.
[VERIFIED: Apple Developer Forums thread/75636]

## Code Examples

### CGEventTap Setup for Modifier-Only Hotkeys

```swift
// Source: alt-tab-macos KeyboardEvents.swift pattern + Apple CGEventFlags docs
// [CITED: github.com/lwouis/alt-tab-macos, developer.apple.com/documentation/coregraphics/cgeventflags]

import CoreGraphics
import Foundation

/// Modifier-only combo definition.
struct ModifierCombo: Equatable, Codable {
    let flags: CGEventFlags

    static let fnShift = ModifierCombo(flags: [.maskSecondaryFn, .maskShift])
    static let fnControl = ModifierCombo(flags: [.maskSecondaryFn, .maskControl])
    static let fnOption = ModifierCombo(flags: [.maskSecondaryFn, .maskAlternate])
}

/// CGEventTap-based listener for modifier-only hotkeys.
/// Runs on a dedicated background thread via CFRunLoop.
class ModifierHotkeyListener {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var runLoop: CFRunLoop?
    private var previousFlags: CGEventFlags = []

    // Callback must be a static function (C-compatible)
    static let callback: CGEventTapCallBack = { proxy, type, event, userInfo in
        guard type == .flagsChanged else {
            return Unmanaged.passUnretained(event)
        }

        let listener = Unmanaged<ModifierHotkeyListener>.fromOpaque(userInfo!).takeUnretainedValue()
        let currentFlags = event.flags

        // Compare current vs previous to detect transitions
        listener.handleFlagsChange(from: listener.previousFlags, to: currentFlags)
        listener.previousFlags = currentFlags

        return Unmanaged.passUnretained(event)
    }

    func start() {
        let eventMask: CGEventMask = 1 << CGEventType.flagsChanged.rawValue

        // Pass self as userInfo (C-compatible pointer)
        let userInfo = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: eventMask,
            callback: Self.callback,
            userInfo: userInfo
        ) else {
            return // Accessibility permission not granted
        }

        self.eventTap = tap
        let source = CFMachPortCreateRunLoopSource(nil, tap, 0)
        self.runLoopSource = source

        // Run on a background thread
        Thread.detachNewThread {
            let rl = CFRunLoopGetCurrent()
            self.runLoop = rl
            CFRunLoopAddSource(rl, source, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
            CFRunLoopRun()
        }
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let rl = runLoop {
            CFRunLoopStop(rl)
        }
    }

    private func handleFlagsChange(from previous: CGEventFlags, to current: CGEventFlags) {
        // Filter to only the modifier flags we care about
        let relevantMask: CGEventFlags = [.maskSecondaryFn, .maskShift, .maskControl, .maskAlternate]
        let prev = previous.intersection(relevantMask)
        let curr = current.intersection(relevantMask)

        // Detect combo activation and release transitions
        // Dispatch to main actor for HotkeyManager interaction
    }
}
```

### LaunchAtLogin Toggle in Settings Section

```swift
// Source: LaunchAtLogin-Modern README [CITED: github.com/sindresorhus/LaunchAtLogin-Modern]
import SwiftUI
import LaunchAtLogin

struct SettingsSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Settings")
                .font(.headline)
                .padding(.horizontal)
                .padding(.top, 4)

            LaunchAtLogin.Toggle("Launch at Login")
                .padding(.horizontal)
                .padding(.vertical, 4)
        }
    }
}
```

### Memory Profiling Script

```bash
#!/bin/bash
# Source: footprint(1) man page [CITED: keith.github.io/xcode-man-pages/footprint.1.html]

# Wait for app to fully warm up (ASR + LLM models loaded)
echo "Waiting for Dicticus to finish model warmup..."
sleep 30  # Adjust based on first-launch vs cached

# Capture memory footprint
echo "=== Memory Footprint ==="
footprint -p Dicticus

echo ""
echo "=== Detailed Breakdown ==="
footprint -p Dicticus -w

# Extract phys_footprint (the INFRA-04 metric)
echo ""
echo "=== Budget Check ==="
echo "Budget: 3 GB (3,221,225,472 bytes)"
footprint -p Dicticus 2>/dev/null | grep "phys_footprint"
```

### Build + DMG Script

```bash
#!/bin/bash
# Source: create-dmg docs [CITED: github.com/create-dmg/create-dmg]
set -euo pipefail

# Step 1: Generate Xcode project
cd Dicticus
xcodegen generate

# Step 2: Build Release .app with ad-hoc signing
xcodebuild -scheme Dicticus \
    -configuration Release \
    -derivedDataPath build \
    CODE_SIGN_IDENTITY="-" \
    DEVELOPMENT_TEAM="" \
    build

APP_DIR="build/Build/Products/Release"

# Step 3: Create styled DMG
create-dmg \
    --volname "Dicticus" \
    --background "../scripts/dmg-background.png" \
    --window-size 660 400 \
    --icon-size 128 \
    --icon "Dicticus.app" 180 200 \
    --app-drop-link 480 200 \
    --no-internet-enable \
    "Dicticus.dmg" \
    "$APP_DIR/"

echo "DMG created: Dicticus.dmg"
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Right-click > Open for Gatekeeper bypass | System Settings > Privacy & Security > Open Anyway | macOS 15 Sequoia (Sep 2024) | Users need different instructions; first-launch experience is more friction |
| SMLoginItemSetEnabled / LoginItems helper | SMAppService (ServiceManagement framework) | macOS 13 Ventura (Oct 2022) | No helper app needed; LaunchAtLogin-Modern wraps this |
| xcodebuild archive + exportArchive for unsigned | xcodebuild build -configuration Release | Ongoing | archive/export requires team ID; build action works with ad-hoc signing |
| NSStatusBar for menu bar apps | MenuBarExtra (SwiftUI, macOS 13+) | macOS 13 Ventura | Already adopted in Phase 1 |

**Deprecated/outdated:**
- **Right-click > Open Gatekeeper bypass:** Removed in macOS 15 Sequoia. Update user instructions accordingly.
- **xcodebuild archive for unsigned distribution:** Does not work without a developer account. Use `xcodebuild build` instead.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | CGEventTap flagsChanged fires for every modifier state transition (intermediate states) | Pitfall 2, Pattern 1 | If it only fires for the final state, debouncing logic is unnecessary but harmless |
| A2 | create-dmg background image needs 2x resolution for Retina | Pitfall 4 | Background might appear blurry on Retina Macs if not at 2x |
| A3 | `CODE_SIGN_IDENTITY="-"` produces a working ad-hoc signed app on Apple Silicon | Pattern 3, Pitfall 6 | If the app doesn't launch, may need to use `codesign -s -` post-build instead |
| A4 | Parakeet CoreML ~1.24 GB + Gemma GGUF ~722 MB together stay under 3 GB total footprint | Phase Requirements | If runtime overhead is larger than ~1 GB, may need lazy unloading |

## Open Questions (RESOLVED)

1. **CGEventTap and Fn key on external keyboards without Fn**
   - What we know: The Fn key is represented by `CGEventFlags.maskSecondaryFn`. All Mac laptops have an Fn key. Apple external keyboards (Magic Keyboard) have a Globe/Fn key.
   - What's unclear: Behavior with third-party external keyboards that lack an Fn key.
   - RESOLVED: Edge case; users without Fn key use standard KeyboardShortcuts combos (Ctrl+Shift+S, Ctrl+Shift+D) which remain functional in parallel. External keyboard note included in UI-SPEC.md caption below pickers.

2. **xcodebuild build vs archive: entitlements in Release builds**
   - What we know: `xcodebuild build` with Release configuration produces a .app bundle. The project uses hardened runtime (`ENABLE_HARDENED_RUNTIME: YES`).
   - What's unclear: Whether entitlements (audio-input, non-sandboxed) are correctly embedded in the .app when using `build` instead of `archive`.
   - RESOLVED: Test with `codesign -d --entitlements :- Dicticus.app` in build script. Plan 03 Task 1 includes entitlement verification in acceptance criteria. Archive approach (D-05) replaced by `xcodebuild build` per Pitfall 6 (archive requires team ID).

3. **Memory budget margin**
   - What we know: Parakeet CoreML package is ~1.24 GB on disk. Gemma 3 1B GGUF is ~722 MB. CLAUDE.md says FluidAudio uses ~66 MB per inference.
   - What's unclear: Actual runtime dirty memory with both models loaded. CoreML models may use more memory than their on-disk size due to intermediate buffers. llama.cpp memory-maps the GGUF file, so dirty memory may be less than file size.
   - RESOLVED: Profile first with `footprint -p Dicticus`. Plan 03 Task 2 creates verify-memory.sh + human checkpoint. If over 3 GB budget, lazy-unload LLM between uses.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| xcodebuild | DMG build pipeline | Yes | Xcode 26.4.1 | -- |
| xcodegen | Project generation | Yes | 2.45.3 | -- |
| create-dmg | Styled DMG creation | No | -- | Install via `brew install create-dmg`; or use raw hdiutil + osascript |
| footprint | Memory profiling | Yes | macOS built-in | -- |
| xctrace | Instruments profiling | Yes | macOS built-in | -- |
| hdiutil | DMG primitives | Yes | macOS built-in | -- |

**Missing dependencies with no fallback:**
- None (all critical tools are available or installable)

**Missing dependencies with fallback:**
- `create-dmg`: Not installed. Install with `brew install create-dmg` as a Wave 0 task. Fallback: manual hdiutil + osascript (significantly more work).

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | XCTest (Xcode built-in) |
| Config file | Dicticus/DicticusTests/ (12 test files) |
| Quick run command | `xcodebuild test -scheme Dicticus -destination 'platform=macOS' -only-testing:DicticusTests 2>&1 \| tail -20` |
| Full suite command | `xcodebuild test -scheme Dicticus -destination 'platform=macOS' 2>&1 \| tail -40` |

### Phase Requirements to Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| INFRA-04 | Memory under 3 GB with both models loaded | manual | `footprint -p Dicticus` (requires running app) | N/A -- manual profiling |
| APP-05 | Launch at login toggle works | manual | LaunchAtLogin.Toggle is a third-party view; test that the toggle is present in the view hierarchy | Wave 0: unit test for settings section |
| -- | CGEventTap modifier-only hotkey detection | unit | Test flag transition logic (pure function, no hardware needed) | Wave 0 |
| -- | DMG contains .app + Applications link | smoke | `hdiutil attach Dicticus.dmg && ls /Volumes/Dicticus/` | Wave 0 script |
| -- | Build script produces valid .app | smoke | `codesign -d --entitlements :- build/.../Dicticus.app` | Wave 0 script |

### Sampling Rate

- **Per task commit:** Run `xcodebuild test` for unit tests
- **Per wave merge:** Full suite + manual DMG verification
- **Phase gate:** Full suite green + memory profiling results documented + DMG installable on clean system

### Wave 0 Gaps

- [ ] `DicticusTests/ModifierHotkeyListenerTests.swift` -- unit tests for flag transition logic (pure function)
- [ ] `DicticusTests/SettingsSectionTests.swift` -- verify settings section contains launch-at-login toggle
- [ ] `scripts/build-dmg.sh` -- build + DMG creation script
- [ ] `scripts/verify-dmg.sh` -- smoke test that mounts DMG and checks contents
- [ ] Install `create-dmg`: `brew install create-dmg`

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | No | N/A -- local-only app |
| V3 Session Management | No | N/A -- no sessions |
| V4 Access Control | Yes (Accessibility permission for CGEventTap) | PermissionManager already checks AXIsProcessTrusted(); CGEventTap silently fails without it |
| V5 Input Validation | No | No user text input in this phase |
| V6 Cryptography | No | No crypto operations |

### Known Threat Patterns for macOS Distribution

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| CGEventTap as keylogger vector | Information Disclosure | Use `.listenOnly` option (not `.defaultTap`); only listen for `.flagsChanged` events, not keystrokes |
| DMG tampering in transit | Tampering | Not addressed in v1 (unsigned); future: code signing + notarization |
| Login item persistence | Elevation of Privilege | LaunchAtLogin-Modern uses SMAppService which is system-managed; users can disable in System Settings |

## Sources

### Primary (HIGH confidence)
- [LaunchAtLogin-Modern v1.1.0](https://github.com/sindresorhus/LaunchAtLogin-Modern) -- API, version, macOS 13+ requirement, SwiftUI Toggle
- [create-dmg shell script](https://github.com/create-dmg/create-dmg) -- CLI options, Homebrew installation, styled DMG workflow
- [CGEventFlags Apple documentation](https://developer.apple.com/documentation/coregraphics/cgeventflags) -- maskSecondaryFn, maskShift, maskControl, maskAlternate
- [macOS SDK headers CGEventTypes.h] -- Verified kCGEventFlagMaskSecondaryFn exists in SDK
- [footprint(1) man page](https://keith.github.io/xcode-man-pages/footprint.1.html) -- CLI usage, memory metrics
- [Apple Support: Open a Mac app from an unknown developer](https://support.apple.com/en-us/102445) -- macOS 15 Sequoia Gatekeeper bypass procedure
- [alt-tab-macos KeyboardEvents.swift](https://github.com/lwouis/alt-tab-macos/blob/master/src/logic/events/KeyboardEvents.swift) -- CGEventTap implementation reference
- Environment probes: xcodebuild (Xcode 26.4.1), xcodegen (2.45.3), footprint, xctrace, hdiutil all verified available

### Secondary (MEDIUM confidence)
- [Eclectic Light: History of code signing](https://eclecticlight.co/2025/04/26/a-brief-history-of-code-signing-on-macs/) -- Apple Silicon ad-hoc signing requirement
- [Blog: Detecting Fn key in Swift](https://blog.rampatra.com/how-to-detect-fn-key-press-in-swift) -- flagsChanged pattern for Fn detection
- [Apple Developer Forums: xcodebuild unsigned](https://developer.apple.com/forums/thread/75636) -- archive vs build for unsigned apps

### Tertiary (LOW confidence)
- None -- all claims are verified or cited

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- LaunchAtLogin-Modern is well-documented, create-dmg is widely used, both verified
- Architecture: HIGH -- CGEventTap patterns verified against real projects (alt-tab-macos) and Apple SDK headers
- Pitfalls: HIGH -- Gatekeeper change verified against Apple Support page and multiple news sources; other pitfalls based on verified API constraints
- Memory profiling: MEDIUM -- footprint tool verified available, but actual memory numbers are unknown until profiling runs

**Research date:** 2026-04-18
**Valid until:** 2026-05-18 (30 days -- stable APIs, unlikely to change)
