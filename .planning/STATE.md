# Project State: Dicticus

**Last Updated:** 2026-04-22
**Milestone:** v2.0 iOS App — Shortcut Dictation (SHIPPED)

## Project Reference

See: .planning/PROJECT.md (updated 2026-04-21)

**Core value:** Press a key, speak, release — accurate text appears at your cursor instantly, fully private, no cloud dependency.
**Current focus:** v2.1 — Keyboard Extension (text at cursor without app switching)

## Current Position

Phase: 17 of TBD (Keyboard Extension)
Plan: 2 of 4
Status: In Progress
Last activity: 2026-04-22 — Keyboard UI (SwiftUI QWERTZ Layout) implemented (17-02)

Progress: [▓▓▓▓▓▓▓▓▓▓] 100% (v2.0 phases)
Progress (v2.1): [▓▓░░░░░░░░] 20%

## Completed Milestones

- **v1.0 MVP** — Phases 1-5 — SHIPPED 2026-04-18
- **v1.1 Cleanup Intelligence & Distribution** — Phases 6-11 — SHIPPED 2026-04-21 (v1.1.1)
- **v2.0 iOS App — Shortcut Dictation** — Phases 12-16 — SHIPPED 2026-04-22

## Key Decisions

### Technical
- **D-15:** Used `NavigationSplitView` with adaptive logic for iPad sidebar support (Phase 16).
- **D-16:** Integrated `GRDB` for shared transcription history between app and future extensions (Phase 15).
- **D-17:** Implemented "Whats New" flow to highlight v2.0 features to upgrading users (Phase 16).

## Active Concerns / Risks
- Phase 17: Keyboard extension 30-50MB memory limit — ASR runs in main app, not extension (bounce architecture). Resolved by design.
- Phase 18: iCloud Sync conflict resolution for Dictionary entries.
- iOS 26 `SpeechAnalyzer` supports German — benchmark vs Parakeet v3 before committing to model download flow long-term.

## Session Continuity

Last session: 2026-04-22
Stopped at: Keyboard UI (Plan 17-02) complete. Foundations (17-01) also verified as complete.
Resume file: .planning/phases/17-keyboard-extension/17-03-PLAN.md
