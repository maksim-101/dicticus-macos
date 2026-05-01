# Dicticus

## What This Is

A fully local, multi-platform dictation app that replaces native dictation on Mac and iPhone/iPad. Uses on-device ASR (Parakeet TDT v3 via FluidAudio on Apple Neural Engine) and optional AI cleanup (Gemma 4 E2B via llama.cpp on macOS). macOS: system-wide push-to-talk hotkeys, works in any text field. iOS: Shortcut-based activation, transcribed text to clipboard.

## Core Value

Press a key, speak, release — accurate text appears at your cursor instantly, fully private, no cloud dependency.

## Completed Milestones

- **v1.0 MVP** — shipped 2026-04-18
- **v1.1 Cleanup Intelligence & Distribution** — shipped 2026-04-21 (v1.1.1)

## Current Milestone: v2.0 iOS App — Shortcut Dictation

**Goal:** Bring Dicticus to iPhone and iPad with Shortcut-based activation, on-device Parakeet ASR, and custom dictionary.

**Target features:**
- On-device ASR via FluidAudio + Parakeet TDT v3 on iOS (Neural Engine)
- Shortcut/App Intent activation (Action Button, Back Tap, Siri)
- Transcribed text to clipboard or Shortcut output
- Custom dictionary (find-and-replace corrections)
- Model management (download/bundle strategy)
- Universal app (iPhone + iPad)
- Shared code extraction to `Shared/` for cross-platform reuse

## Current State

**macOS Version:** v1.1.1 (released 2026-04-21)
**Codebase:** ~5,000 lines Swift, 11 phases, 158 tests (all passing)
**Memory:** 170 MB physical footprint with both ASR and LLM loaded
**Distribution:** Developer ID signed + notarized DMG, Sparkle auto-updates
**LLM:** Gemma 4 E2B (Q4_K_M, ~3.1 GB) via llama.cpp Metal

## Requirements

### Validated

- ✓ Push-to-talk via configurable hotkey, text at cursor in any app — v1.0
- ✓ Transcription < 3 seconds for typical utterances — v1.0
- ✓ Auto-detect German/English without manual switching — v1.0
- ✓ VAD discards silence to prevent hallucinated output — v1.0
- ✓ Works in any text field (browser, native apps, terminal) — v1.0
- ✓ Light cleanup mode via separate hotkey (grammar, punctuation, filler removal) — v1.0
- ✓ Cleanup preserves original meaning — v1.0
- ✓ Cleanup works for German and English (single-language) — v1.0
- ✓ LLM runs fully locally with no cloud calls — v1.0
- ✓ Menu bar app with minimal UI — v1.0
- ✓ First-run onboarding for permissions — v1.0
- ✓ Separate hotkeys per mode (plain dictation, AI cleanup) — v1.0
- ✓ Launch at login (configurable) — v1.0
- ✓ ASR and LLM warm at startup — v1.0
- ✓ CoreML background warmup at launch — v1.0
- ✓ Memory < 3 GB (achieved 170 MB) — v1.0
- ✓ DMG distribution — v1.0
- ✓ Modifier-only hotkeys (Fn+Shift, Fn+Control) — v1.0
- ✓ Inverse text normalization (numbers as digits, not words) — v1.1
- ✓ Intelligent AI cleanup for broken/non-native German — v1.1
- ✓ Fix cleanup quote injection bug — v1.1
- ✓ Custom dictionary (find-and-replace for recurring ASR errors) — v1.1
- ✓ Apple Developer Program signing and notarization — v1.1
- ✓ Auto-update via Sparkle — v1.1
- ✓ Fix APP-03 icon state reactivity (@StateObject refactor) — v1.1
- ✓ Transcription history log with search — v1.1

### Active (v2.0)

- [ ] On-device ASR via FluidAudio + Parakeet TDT v3 on iOS (Neural Engine)
- [ ] Shortcut/App Intent activation (Action Button, Back Tap, Siri)
- [ ] Transcribed text to clipboard or Shortcut output
- [ ] Custom dictionary on iOS (find-and-replace corrections)
- [ ] Model management on iOS (download/bundle strategy)
- [ ] Universal app (iPhone + iPad)
- [ ] Shared code extraction to `Shared/` for cross-platform reuse

### Future

- [ ] iOS custom keyboard activation (text-at-cursor without paste)
- [ ] Windows support for business laptop
- [ ] iOS AI cleanup (Gemma via llama.cpp Metal on iPhone)
- [ ] Heavier rewrite mode (second AI cleanup tier)
- [ ] Prompt customization for cleanup behavior
- [ ] Model integrity check (SHA256 for GGUF downloads)
- [ ] Swiss German ASR module (dialect → Standard German)

### Out of Scope

- iOS custom keyboard with direct mic access — iOS blocks microphone access in keyboard extensions (keyboard approach deferred to v2.1 with main-app bounce architecture)
- Cloud ASR/LLM fallback — fully local is a hard requirement
- App Store distribution — sandbox blocks global hotkeys and text injection
- Always-listening mode — privacy risk, battery drain
- Speaker diarization — single-user tool
- Custom voice training — unnecessary for dictation
- Real-time streaming (v1) — batch processing acceptable
- Mixed-language AI cleanup — Gemma 3 1B too small for reliable multilingual instruction following

## Constraints

- **Privacy**: All processing on-device — no audio or text sent to any server
- **Performance**: Transcription < 2-3 seconds after releasing hotkey
- **Local models**: ASR and LLM run locally with quality comparable to Parakeet V3
- **System-wide**: Works in any text field across any app
- **Activation**: Push-to-talk, not always-listening

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Fully local processing | Privacy + latency + cost | ✓ Good — 170 MB footprint, sub-second cleanup |
| FluidAudio + Parakeet TDT v3 | Better de/en quality than Whisper, 5-10x faster | ✓ Good — German 5% WER, English 6% WER |
| llama.cpp for LLM | Future Windows portability via C API | ✓ Good — Gemma 3 1B runs well on Metal |
| Different hotkeys per mode | Clean separation, no mode-switching UI | ✓ Good — KeyboardShortcuts + modifier combos |
| Paste-at-cursor via clipboard | Most reliable cross-app method | ✓ Good — works in all tested apps |
| NSEvent global monitor | macOS 15 disables CGEventTap for ad-hoc signed apps | ✓ Good — simpler code, reliable |
| Unsandboxed DMG distribution | Sandbox blocks global hotkeys and text injection | ✓ Good — Gatekeeper override needed |
| xcodegen for project generation | Reproducible .pbxproj from declarative project.yml | ✓ Good — eliminates merge conflicts |
| ASR engine swap (Phase 2.1) | User preferred Parakeet v3 quality over Whisper | ✓ Good — seamless API-level swap |
| iOS Shortcut-first approach | Keyboard extension can't access mic; Shortcut is simpler to build and test | — Pending |
| No AI cleanup for iOS v1 | Hardware constraints make dictionary more important; keep scope tight | — Pending |
| Universal app (iPhone + iPad) | Same codebase, wider reach | — Pending |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-04-21 after v2.0 milestone start*
