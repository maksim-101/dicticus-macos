# Dicticus

## What This Is

A fully local macOS dictation app that replaces native dictation with system-wide push-to-talk hotkeys, on-device ASR (Parakeet TDT v3 via FluidAudio on Apple Neural Engine), and optional AI cleanup (Gemma 3 1B via llama.cpp). Works in any text field across any app — browser, native apps, terminal.

## Core Value

Press a key, speak, release — accurate text appears at your cursor instantly, fully private, no cloud dependency.

## Current Milestone: v1.1 Cleanup Intelligence & Distribution

**Goal:** Transform AI cleanup from literal grammar correction into intelligent meaning inference for non-native/broken German, add number formatting and custom dictionary, and ship a properly signed macOS app with auto-updates.

**Target features:**
- Inverse text normalization (numbers as digits, not words)
- Intelligent AI cleanup that handles broken/non-native German (infer meaning from gibberish)
- Fix cleanup quote injection bug
- Custom dictionary (find-and-replace for recurring ASR errors)
- Apple Developer signing + notarization
- Auto-update via Sparkle
- Fix APP-03 icon state reactivity
- Transcription history log with search

## Current State

**Shipped:** v1.0 MVP (2026-04-18)
**Codebase:** 3,084 lines Swift, 6 phases, 17 plans
**Memory:** 170 MB physical footprint with both ASR and LLM loaded
**Distribution:** Ad-hoc signed DMG, drag-to-Applications install

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

### Partially Validated

- ⚠ Visual recording indicator — v1.0 (recording mic.fill works; transcribing/cleaning icon states not reactive due to @State vs @StateObject)

### Active (v1.1)

- [ ] Inverse text normalization (numbers as digits, not words)
- [ ] Intelligent AI cleanup for broken/non-native German
- [ ] Fix cleanup quote injection bug
- [ ] Custom dictionary (find-and-replace for recurring ASR errors)
- [ ] Apple Developer Program signing and notarization
- [ ] Auto-update via Sparkle
- [ ] Fix APP-03 icon state reactivity (@StateObject refactor)
- [ ] Transcription history log with search

### Future

- [ ] iPhone dictation replacement (custom keyboard or Shortcut)
- [ ] Windows support for business laptop
- [ ] Heavier rewrite mode (second AI cleanup tier)
- [ ] Prompt customization for cleanup behavior
- [ ] Model integrity check (SHA256 for GGUF downloads)
- [ ] Swiss German ASR module (dialect → Standard German)

### Out of Scope

- iOS custom keyboard — iOS blocks microphone access in keyboard extensions
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
*Last updated: 2026-04-19 after v1.1 milestone start*
