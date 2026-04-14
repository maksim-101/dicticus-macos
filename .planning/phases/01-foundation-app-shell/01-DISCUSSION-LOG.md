# Phase 1: Foundation & App Shell - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-14
**Phase:** 01-foundation-app-shell
**Areas discussed:** Permissions Onboarding Flow, Model Warm-up Strategy, Menu Bar Design, Project Structure
**Mode:** Auto (all areas auto-selected, recommended defaults chosen)

---

## Permissions Onboarding Flow

| Option | Description | Selected |
|--------|-------------|----------|
| Sequential per-permission prompts | Guide user through each permission one at a time with System Settings links | ✓ |
| Single modal walk-through | Show all permissions in one onboarding sheet | |
| In-menu status indicators only | No onboarding flow, just show status in menu | |

**User's choice:** [auto] Sequential per-permission prompts (recommended default)
**Notes:** Most common macOS pattern for apps needing multiple permissions. Direct links to System Settings panes.

| Option | Description | Selected |
|--------|-------------|----------|
| Degraded state indicator with re-prompt | Non-blocking, show status in menu, let user grant later | ✓ |
| Block app until granted | Refuse to proceed without all permissions | |
| Silent degradation | Hide features that need missing permissions | |

**User's choice:** [auto] Degraded state indicator with re-prompt (recommended default)
**Notes:** Non-blocking approach lets user explore the app even without all permissions granted.

---

## Model Warm-up Strategy

| Option | Description | Selected |
|--------|-------------|----------|
| Menu bar icon animation + dropdown status | Lightweight, non-intrusive progress indication | ✓ |
| Splash screen with progress bar | Modal progress display during compilation | |
| Silent background load | No visual indication of warm-up | |

**User's choice:** [auto] Menu bar icon animation + dropdown status text (recommended default)
**Notes:** Non-intrusive, fits the lightweight menu bar app ethos.

| Option | Description | Selected |
|--------|-------------|----------|
| Immediately at app launch | Start warm-up as soon as app starts | ✓ |
| On first hotkey press | Lazy load when user first tries to dictate | |
| User-triggered from menu | Manual "Load Models" action | |

**User's choice:** [auto] Immediately at app launch in background (recommended default)
**Notes:** Matches INFRA-03 requirement. No cold-start penalty on first dictation.

---

## Menu Bar Design

| Option | Description | Selected |
|--------|-------------|----------|
| Status indicators + Quit | Minimal: permission status, warm-up status, quit | ✓ |
| Full settings access | Include preferences, model management, hotkey config | |
| Progressive disclosure | Start minimal, expand as features unlock | |

**User's choice:** [auto] Status indicators + Quit (recommended default)
**Notes:** Minimal for foundation phase. Settings and mode controls come in later phases.

| Option | Description | Selected |
|--------|-------------|----------|
| SF Symbol monochrome template | Native macOS appearance, adapts to light/dark | ✓ |
| Custom icon asset | Branded icon, requires manual dark mode handling | |

**User's choice:** [auto] SF Symbol monochrome template image (recommended default)
**Notes:** Standard macOS menu bar icon approach. Automatic light/dark mode adaptation.

---

## Project Structure

| Option | Description | Selected |
|--------|-------------|----------|
| Single target + SPM | Simplest structure, dependencies via Swift Package Manager | ✓ |
| Multi-target (app + helper) | Separate targets for main app and background helpers | |
| Workspace with frameworks | Modular but more complex setup | |

**User's choice:** [auto] Single app target with SPM dependencies (recommended default)
**Notes:** Simplest approach. Helpers/extensions can be added later if needed.

| Option | Description | Selected |
|--------|-------------|----------|
| SPM with C library wrappers | Clean dependency management via Package.swift | ✓ |
| Manual framework embedding | Drag frameworks into Xcode project | |
| CocoaPods/Carthage | Third-party dependency managers | |

**User's choice:** [auto] SPM with C library wrappers (recommended default)
**Notes:** Avoids manual framework embedding. whisper.cpp and llama.cpp both support SPM.

---

## Claude's Discretion

- Xcode project naming and bundle identifier conventions
- Specific SF Symbol choice for menu bar icon
- Internal module/file organization within the single target
- Entitlements plist configuration details

## Deferred Ideas

None — discussion stayed within phase scope
