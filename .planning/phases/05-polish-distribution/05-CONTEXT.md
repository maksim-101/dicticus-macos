# Phase 5: Polish & Distribution - Context

**Gathered:** 2026-04-18
**Status:** Ready for planning

<domain>
## Phase Boundary

Make the app reliable, memory-efficient, and ready for daily use as a packaged DMG. This phase validates memory budget compliance (INFRA-04), adds launch-at-login (APP-05), packages the app as a distributable DMG via Xcode archive, and implements modifier-only hotkeys (Fn+Shift, Fn+Control) via CGEventTap alongside the existing KeyboardShortcuts system.

</domain>

<decisions>
## Implementation Decisions

### Memory Optimization
- **D-01:** Claude's discretion — profile total memory with both ASR and LLM loaded, validate against the 3 GB budget (INFRA-04). Use Instruments or `footprint` CLI to measure resident memory. If over budget, investigate lazy model unloading or quantization changes. User did not need to discuss this area.

### Launch at Login
- **D-02:** Off by default — user explicitly opts in via a toggle in the menu bar dropdown. Respects user agency; dictation apps shouldn't auto-start without consent.
- **D-03:** Settings section in dropdown — add a new settings/preferences section at the bottom of the dropdown (above Quit). Groups app configuration together and provides a natural home for launch-at-login alongside future settings.
- **D-04:** Use LaunchAtLogin-Modern library (macOS 13+) — recommended in CLAUDE.md, handles ServiceManagement API, stores state correctly.

### DMG Packaging
- **D-05:** Xcode archive + export workflow — use `xcodebuild archive` + `xcodebuild -exportArchive` pipeline. More formal approach that integrates with Apple's toolchain natively.
- **D-06:** Unsigned for now — skip code signing and notarization for v1. Users right-click > Open to bypass Gatekeeper. Avoids $99/yr Apple Developer Program cost. Can add later.
- **D-07:** Styled DMG — custom background image with app icon and arrow pointing to Applications folder symlink. Professional look for distribution.

### Modifier-Only Hotkeys
- **D-08:** Parallel system — CGEventTap flagsChanged listener runs alongside KeyboardShortcuts. Modifier-only combos (Fn+Shift, Fn+Control) handled by CGEventTap; standard combos handled by KeyboardShortcuts. HotkeyManager routes both to the same dictation pipeline.
- **D-09:** Fn+Shift and Fn+Control only — just the two defaults from Phase 3 (plain dictation and AI cleanup). Minimal scope, covers the primary use case.
- **D-10:** Configurable via dropdown picker — add a picker in the settings section where users choose from a preset list of Fn-based modifier combos. KeyboardShortcuts recorder can't capture modifier-only combos, so a custom picker is needed.
- **D-11:** Fn-based pairs only in picker — Fn+Shift, Fn+Control, Fn+Option. All Fn-anchored, minimal conflict with system shortcuts. Clean and focused preset list.

### Claude's Discretion
- Memory profiling methodology and tooling choice
- DMG background image design and icon layout
- CGEventTap implementation details (event mask, callback structure, flag debouncing)
- Settings section visual design in the dropdown
- Modifier-only hotkey picker UI layout
- Build script / Makefile structure for the archive+DMG pipeline
- End-to-end test strategy (manual checklist vs automated)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project Context
- `.planning/PROJECT.md` — Core value, privacy constraints, key decisions
- `.planning/REQUIREMENTS.md` — INFRA-04 (memory budget), APP-05 (launch at login) are this phase's requirements
- `.planning/ROADMAP.md` — Phase 5 success criteria, dependency on Phase 4

### Technology Decisions
- `CLAUDE.md` §Supporting Libraries — LaunchAtLogin-Modern (macOS 13+) for login item registration
- `CLAUDE.md` §macOS App Shell — CGEvent for keystroke synthesis (already used in TextInjector), Accessibility API
- `CLAUDE.md` §ASR Engine — FluidAudio + Parakeet TDT v3 memory characteristics (~1.24 GB CoreML package)
- `CLAUDE.md` §Local LLM — Gemma 3 1B IT (~1 GB on disk, ~722 MB GGUF) via llama.cpp

### Prior Phase Context
- `.planning/phases/03-system-wide-dictation/03-CONTEXT.md` — Hotkey defaults (D-04: Fn+Shift, D-05: Fn+Control), Fn key special handling caveat, KeyboardShortcuts recorder views
- `.planning/phases/04-ai-cleanup/04-CONTEXT.md` — LLM memory footprint, sequential warmup pattern (D-07, D-08), model download architecture (D-09, D-10)
- `.planning/phases/01-foundation-app-shell/01-CONTEXT.md` — Unsandboxed distribution, DMG deferred to Phase 5, project.yml + xcodegen pattern

### Existing Code (Phase 5 integration points)
- `Dicticus/Dicticus/DicticusApp.swift` — App entry point, icon state machine, service wiring
- `Dicticus/Dicticus/Services/HotkeyManager.swift` — Current KeyboardShortcuts-based hotkey handling, DictationMode routing
- `Dicticus/Dicticus/Services/TextInjector.swift` — CGEvent usage pattern (already uses CGEvent for Cmd+V synthesis)
- `Dicticus/Dicticus/Services/ModelWarmupService.swift` — ASR + LLM warmup, memory-relevant service
- `Dicticus/Dicticus/Views/MenuBarView.swift` — Current dropdown layout (permissions, warmup, hotkeys, last transcription, quit)
- `Dicticus/Dicticus/Views/HotkeySettingsView.swift` — Existing hotkey configuration UI
- `Dicticus/project.yml` — Build configuration, SPM dependencies, entitlements

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `TextInjector` — Already uses CGEvent for Cmd+V synthesis. CGEventTap for modifier-only hotkeys follows the same CGEvent API patterns.
- `HotkeyManager` — DictationMode enum (.plainDictation, .aiCleanup) and push-to-talk state machine. Modifier-only hotkey events route into the same state machine.
- `MenuBarView` — Existing dropdown layout with sections (permissions, warmup, hotkeys, transcription, quit). Settings section adds below existing content.
- `HotkeySettingsView` — KeyboardShortcuts recorder views. Modifier-only picker sits alongside or replaces these.
- `ModelWarmupService` — ASR + LLM loading with memory-relevant lifecycle. Memory profiling targets this service's loaded state.

### Established Patterns
- `@MainActor` ObservableObject services with `@Published` state
- `.environmentObject()` injection from DicticusApp
- SwiftUI Toggle/Picker patterns in the dropdown
- `project.yml` for declarative build configuration (xcodegen)
- SF Symbol icons with `.symbolEffect()` animations

### Integration Points
- `HotkeyManager` — Add CGEventTap listener as secondary input source alongside KeyboardShortcuts
- `MenuBarView` — Add settings section with launch-at-login toggle and modifier-only hotkey picker
- `project.yml` — Add LaunchAtLogin-Modern SPM dependency; add build phase or script for DMG creation
- Entitlements — CGEventTap requires Accessibility permission (already granted per Phase 1 PermissionManager)

</code_context>

<specifics>
## Specific Ideas

- Modifier-only hotkeys use CGEventTap with `flagsChanged` event type — detect when both modifiers are held simultaneously (e.g., Fn flag + Shift flag both present), and trigger recording on the transition. Release detection when either modifier is released.
- The dropdown picker for modifier combos offers Fn+Shift, Fn+Control, Fn+Option as presets — all Fn-anchored to minimize system shortcut conflicts.
- Styled DMG should have a clean, minimal background with the Dicticus app icon on the left and an Applications folder alias on the right, with a visual arrow or indicator.
- Settings section in the dropdown groups: launch-at-login toggle, modifier-only hotkey pickers (plain dictation combo, AI cleanup combo).

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 05-polish-distribution*
*Context gathered: 2026-04-18*
