# Dicticus

## What This Is

A fully local, multi-platform dictation app that replaces native dictation on Mac, iPhone, and Windows. Uses on-device ASR and LLM to transcribe speech in German and English with optional AI cleanup — activated via system-wide hotkeys (Mac/Windows) or a custom keyboard/Shortcut (iPhone). Think "MacWhisper but system-wide, cross-platform, and with AI polish."

## Core Value

Press a key, speak, release — accurate text appears at your cursor instantly, fully private, no cloud dependency.

## Requirements

### Validated

(None yet — ship to validate)

### Active

- [ ] Push-to-talk dictation on Mac via configurable hotkey — text pastes at cursor in any app
- [ ] AI cleanup mode on Mac via separate hotkey — grammar, punctuation, filler removal
- [ ] Heavier rewrite mode available (second AI cleanup tier)
- [ ] Auto-detect German/English without manual switching
- [ ] Fully local ASR (Parakeet V3 or equivalent quality)
- [ ] Fully local LLM for AI cleanup (no cloud calls)
- [ ] Mac menu bar app (SwiftBar-style, minimal UI)
- [ ] iPhone dictation replacement (custom keyboard or Shortcut)
- [ ] Windows support for business laptop
- [ ] Multiple hotkey combos for different modes (plain, light cleanup, rewrite)

### Out of Scope

- Email formatting / summarization — future use case, not v1
- Real-time streaming transcription — nice-to-have, not required (batch processing is acceptable)
- Cloud-based ASR/LLM fallback — fully local is a hard requirement
- Custom voice training / speaker profiles — unnecessary for single-user
- GUI-heavy app — this lives in the menu bar / background, not a windowed app

## Context

- User currently uses MacWhisper with Parakeet V3 and is happy with its quality and performance
- MacWhisper limitation: not system-wide, requires copy-paste workflow
- Primary languages: German and English, with auto-detection
- Mac is the primary platform, iPhone and Windows are stretch goals pending research feasibility
- iPhone approach TBD: custom keyboard vs. iOS Shortcut (research will determine)
- Windows approach TBD: may be a separate app with shared architecture
- Whether this is 1, 2, or 3 separate apps depends on platform constraints — research will answer this
- The user's MacBook has Apple Silicon (assumed — relevant for local model performance)

## Constraints

- **Privacy**: All processing must happen on-device — no audio or text sent to any server
- **Performance**: Transcription must feel near-instant after releasing the hotkey (< 2-3 seconds for typical utterances)
- **Local models**: Both ASR and LLM must run locally with quality comparable to Parakeet V3
- **System-wide**: Must work in any text field across any app (browser, native apps, etc.)
- **Activation**: Push-to-talk (Mac/Windows), toggle (iPhone) — not always-listening

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Fully local processing | Privacy + latency + cost — all three matter equally | — Pending |
| Parakeet V3 as quality baseline | User knows and likes this model's accuracy | — Pending |
| Different hotkeys per mode | Clean separation, no mode-switching UI needed | — Pending |
| Paste-at-cursor for text output | Most reliable cross-app method | — Pending |
| Menu bar app on Mac | Minimal footprint, always accessible, no window management | — Pending |
| Auto-detect language | Simpler UX than manual switching | — Pending |

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
*Last updated: 2026-04-14 after initialization*
