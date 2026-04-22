# Project State: Dicticus

**Last Updated:** 2026-04-22
**Milestone:** v2.0 iOS App — Shortcut Dictation (SHIPPED)

## Project Reference

See: .planning/PROJECT.md (updated 2026-04-21)

**Core value:** Press a key, speak, release — accurate text appears at your cursor instantly, fully private, no cloud dependency.
**Current focus:** Planning v2.1 — iCloud Sync & Keyboard Extension

## Current Position

Phase: 17 of TBD (iCloud Sync & Keyboard)
Plan: 0 of TBD
Status: Pending Planning
Last activity: 2026-04-22 — Milestone v2.0 completed (Phases 12-16)

Progress: [▓▓▓▓▓▓▓▓▓▓] 100% (v2.0 phases)

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
- Phase 17: iCloud Sync conflict resolution for Dictionary entries.
- Phase 18: Keyboard Extension memory limits (30-50MB) may prevent loading the 2.7GB ASR model; may need "Quick Dictation" via app trigger.

## Session Continuity

Last session: 2026-04-22
Stopped at: v2.0 SHIPPED. All requirements met.
Resume file: None
