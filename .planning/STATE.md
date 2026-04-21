# Project State: Dicticus

**Last Updated:** 2026-04-21
**Milestone:** v2.0 iOS App — Shortcut Dictation

## Project Reference

See: .planning/PROJECT.md (updated 2026-04-21)

**Core value:** Press a key, speak, release — accurate text appears at your cursor instantly, fully private, no cloud dependency.
**Current focus:** Phase 12 — Shared Code Extraction & iOS Scaffold

## Current Position

Phase: 12 of 16 (Shared Code Extraction & iOS Scaffold)
Plan: 0 of TBD in current phase
Status: Ready to plan
Last activity: 2026-04-21 — Roadmap created for v2.0 milestone (5 phases, 22 requirements mapped)

Progress: [░░░░░░░░░░] 0% (v2.0 phases)

## Completed Milestones

- **v1.0 MVP** — Phases 1-5 — SHIPPED 2026-04-18
- **v1.1 Cleanup Intelligence & Distribution** — Phases 6-11 — SHIPPED 2026-04-21 (v1.1.1)

## Codebase Summary

- ~5,000 lines Swift, 11 phases completed, 158 tests (all passing)
- 170 MB physical footprint with both ASR and LLM loaded (macOS)
- Distribution: Developer ID signed + notarized DMG, Sparkle auto-updates
- Repo restructured for multi-platform: `macOS/`, `iOS/` (placeholder), `Shared/` (placeholder)

## Accumulated Context

### Decisions

- iOS uses AudioRecordingIntent (Option B: openAppWhenRun = true) — no 30s timeout constraint, unlimited recording
- Live Activity is mandatory for AudioRecordingIntent — must start before AVAudioSession activation
- Shared/ compiled as sources into both targets (NOT as SPM package — App Intents metadata extraction fails with static libraries)
- No AI cleanup on iOS v2.0 — llama.cpp GGUF has no CoreML acceleration, 3.1 GB impractical on iPhone RAM
- UserDefaults suiteName: "group.com.dicticus" for App Groups shared data
- Model stored in main app container (not App Groups — too large, not shared cross-platform)

### Pending Todos

None yet.

### Blockers/Concerns

- Phase 13: FluidAudio App Groups storage path behavior is MEDIUM confidence — verify `downloadAndLoad(to:)` custom path API on day 1
- Phase 13: `increased-memory-limit` entitlement approval must be initiated early (Apple Developer Portal) — OOM risk on iPhone 12/13 base (4 GB RAM)
- Phase 14: HuggingFace rate limits and geographic restrictions in production — may need CDN mirror strategy for beta

## Session Continuity

Last session: 2026-04-21
Stopped at: Roadmap written, ready to plan Phase 12
Resume file: None
