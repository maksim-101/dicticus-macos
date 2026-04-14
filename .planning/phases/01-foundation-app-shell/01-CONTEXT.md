# Phase 1: Foundation & App Shell - Context

**Gathered:** 2026-04-14
**Status:** Ready for planning

<domain>
## Phase Boundary

Deliver a running macOS menu bar app (SwiftUI MenuBarExtra) with unsandboxed entitlements, first-run permissions onboarding for Microphone and Accessibility, and background model warm-up infrastructure for Core ML compilation — the foundation everything else builds on.

</domain>

<decisions>
## Implementation Decisions

### Permissions Onboarding Flow
- **D-01:** Sequential per-permission prompts — guide user through Microphone, Accessibility, and Input Monitoring permissions one at a time with direct links to System Settings panes
- **D-02:** If user denies a permission, show degraded state indicator in the menu bar dropdown with a re-prompt option — non-blocking, user can grant permissions later from the menu

### Model Warm-up Strategy
- **D-03:** Model warm-up starts immediately at app launch in background (matches INFRA-03 requirement) — no delay until first hotkey press
- **D-04:** Progress shown via menu bar icon animation (e.g., pulsing or loading indicator) plus status text in the dropdown menu — no splash screen, no modal, non-intrusive

### Menu Bar Design
- **D-05:** Menu bar dropdown in Phase 1 shows: permission status indicators, model warm-up status, and Quit — minimal for foundation phase; settings and mode controls come in later phases
- **D-06:** Menu bar icon uses SF Symbol monochrome template image — native macOS appearance, adapts to light/dark mode automatically

### Project Structure
- **D-07:** Single app target with Swift Package Manager for dependencies — simplest approach for a menu bar app; helpers/extensions can be added in later phases if needed
- **D-08:** whisper.cpp and llama.cpp integrated via SPM with C library wrappers — clean dependency management, avoids manual framework embedding

### Claude's Discretion
- Xcode project naming and bundle identifier conventions
- Specific SF Symbol choice for menu bar icon
- Internal module/file organization within the single target
- Entitlements plist configuration details

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project Context
- `.planning/PROJECT.md` — Core value, constraints, key decisions
- `.planning/REQUIREMENTS.md` — APP-01, APP-02, INFRA-03, INFRA-05 are this phase's requirements
- `.planning/ROADMAP.md` — Phase 1 success criteria and dependency chain

### Technology Decisions
- `CLAUDE.md` §Technology Stack — Recommended stack with whisper.cpp, llama.cpp, Swift+SwiftUI, KeyboardShortcuts, WhisperKit decisions

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- None — greenfield project, no existing code

### Established Patterns
- None — patterns will be established in this phase

### Integration Points
- Menu bar app shell will be the host for all subsequent phase features (ASR pipeline, hotkeys, AI cleanup)
- Model warm-up infrastructure must support adding LLM warm-up in Phase 4
- Permission checks must be reusable for Phase 3's system-wide hotkey registration

</code_context>

<specifics>
## Specific Ideas

- App should feel like a lightweight macOS-native menu bar utility (similar to Rectangle, Dato, or Lungo)
- Permissions onboarding should link directly to the relevant System Settings pane (e.g., Privacy & Security > Microphone)
- WhisperKit Core ML compilation can take significant time on first launch — the warm-up indicator must handle multi-minute waits gracefully

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 01-foundation-app-shell*
*Context gathered: 2026-04-14*
