# Phase 5: Polish & Distribution - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-18
**Phase:** 05-polish-distribution
**Areas discussed:** Launch at login, DMG packaging, Modifier-only hotkeys

---

## Launch at Login

| Option | Description | Selected |
|--------|-------------|----------|
| Off by default (Recommended) | User explicitly opts in via the menu bar dropdown toggle. Respects user agency. | ✓ |
| On by default | Automatically starts on login. User can disable in settings. | |

**User's choice:** Off by default
**Notes:** None — straightforward preference for user agency.

---

| Option | Description | Selected |
|--------|-------------|----------|
| Settings section (Recommended) | Add a settings/preferences section at the bottom of the dropdown (above Quit). | ✓ |
| Inline below hotkeys | Place the toggle directly below the hotkey configuration section. | |
| You decide | Claude picks the best placement. | |

**User's choice:** Settings section
**Notes:** Groups app configuration together, natural home for future settings.

---

## DMG Packaging

| Option | Description | Selected |
|--------|-------------|----------|
| create-dmg CLI (Recommended) | Simple shell script wrapper. One command creates a styled DMG. | |
| Xcode archive + export | Use xcodebuild archive + exportArchive workflow. More formal. | ✓ |
| You decide | Claude picks the simplest reliable approach. | |

**User's choice:** Xcode archive + export
**Notes:** User prefers the more formal Apple toolchain approach.

---

| Option | Description | Selected |
|--------|-------------|----------|
| Unsigned for now (Recommended) | Skip code signing and notarization for v1. Right-click > Open to bypass. | ✓ |
| Signed + notarized | Full Apple Developer ID signing and notarization. | |
| Ad-hoc signed only | Self-signed, no Apple certificate. | |

**User's choice:** Unsigned for now
**Notes:** Avoids $99/yr Apple Developer Program cost for v1.

---

| Option | Description | Selected |
|--------|-------------|----------|
| Plain DMG (Recommended) | Just the .app and an Applications symlink. No custom background. | |
| Styled DMG | Custom background image with arrow from app icon to Applications folder. | ✓ |

**User's choice:** Styled DMG
**Notes:** User wants professional look despite additional design work.

---

## Modifier-Only Hotkeys

| Option | Description | Selected |
|--------|-------------|----------|
| Parallel system (Recommended) | CGEventTap alongside KeyboardShortcuts. Modifier-only via CGEventTap, standard via KeyboardShortcuts. | ✓ |
| Replace KeyboardShortcuts entirely | Drop KeyboardShortcuts, use CGEventTap for all hotkeys. | |
| You decide | Claude picks the architecture. | |

**User's choice:** Parallel system
**Notes:** Keeps KeyboardShortcuts benefits (recorder UI, conflict detection, UserDefaults) for standard combos.

---

| Option | Description | Selected |
|--------|-------------|----------|
| Fn+Shift and Fn+Control only | Just the two defaults from Phase 3. Minimal scope. | ✓ |
| Any two-modifier combo | Arbitrary pairs like Ctrl+Shift, Ctrl+Option, etc. | |
| Fn-based combos only | Fn+Shift, Fn+Control, Fn+Option. | |

**User's choice:** Fn+Shift and Fn+Control only
**Notes:** Covers the primary use case with minimal complexity.

---

| Option | Description | Selected |
|--------|-------------|----------|
| Fixed defaults for now | Fn+Shift and Fn+Control hardcoded. Simpler implementation. | |
| Configurable via dropdown | Add a picker in settings with preset modifier combo list. | ✓ |

**User's choice:** Configurable via dropdown
**Notes:** User wants flexibility despite additional UI work.

---

| Option | Description | Selected |
|--------|-------------|----------|
| Fn-based pairs only (Recommended) | Fn+Shift, Fn+Control, Fn+Option. All Fn-anchored. | ✓ |
| Fn-based + common pairs | Add Ctrl+Shift, Ctrl+Option alongside Fn combos. | |
| You decide | Claude picks a sensible preset list. | |

**User's choice:** Fn-based pairs only
**Notes:** Minimal system shortcut conflicts with Fn-anchored combos.

---

## Claude's Discretion

- Memory profiling methodology and tooling (user skipped this area entirely)
- DMG background image design and icon layout
- CGEventTap implementation details
- Settings section visual design
- Build script / Makefile structure
- End-to-end test strategy

## Deferred Ideas

None — discussion stayed within phase scope.
