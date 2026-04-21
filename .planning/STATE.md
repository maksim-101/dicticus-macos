# Project State: Dicticus

**Last Updated:** 2026-04-21
**Milestone:** v2.0 iOS App — Shortcut Dictation

## Current Position

Phase: Not started (defining requirements)
Plan: —
Status: Defining requirements
Last activity: 2026-04-21 — Milestone v2.0 started

## Completed Milestones

- **v1.0 MVP** — Phases 1-5 — SHIPPED 2026-04-18
- **v1.1 Cleanup Intelligence & Distribution** — Phases 6-11 — SHIPPED 2026-04-21 (v1.1.1)

## Codebase Summary

- ~5,000 lines Swift, 11 phases completed, 158 tests (all passing)
- 170 MB physical footprint with both ASR and LLM loaded (macOS)
- Distribution: Developer ID signed + notarized DMG, Sparkle auto-updates
- Repo restructured for multi-platform: `macOS/`, `iOS/` (placeholder), `Shared/` (placeholder)

## Current Technical Stack

- **ASR**: Parakeet TDT v3 (FluidAudio on Apple Neural Engine) — macOS + iOS
- **LLM**: Gemma 4 E2B Q4_K_M (llama.cpp Metal) — macOS only
- **Database**: SQLite / GRDB + FTS5
- **UI**: SwiftUI (macOS 15+ / iOS 18+)

## Accumulated Context

- iOS blocks microphone access in keyboard extensions — Shortcut approach avoids this
- Custom keyboard deferred to v2.1 (requires main-app bounce architecture for mic)
- FluidAudio SDK works on iOS 17+ with same Parakeet CoreML model
- Parakeet CoreML model is ~1.24 GB — model delivery strategy TBD (research phase)
- Custom dictionary is higher priority on iOS due to hardware constraints (no AI cleanup in v2.0)
- Shared code extraction planned: DictionaryService, ITNUtility, CleanupPrompt → `Shared/`

## Known Issues / Technical Debt (from v1.1)

- Phase 11 PLAN exists without SUMMARY (Gemini skipped GSD summary artifact — code is complete and verified)
- `NumberFormatter` replaced with custom parser for German ITN, but ordinals/dates/currency not yet handled
- AI cleanup adds ~1-2s latency (acceptable for current use)

## Project Reference

See: .planning/PROJECT.md (updated 2026-04-21)

**Core value:** Press a key, speak, release — accurate text appears at your cursor instantly, fully private, no cloud dependency.
**Current focus:** v2.0 iOS App — Shortcut Dictation
