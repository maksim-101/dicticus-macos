# Requirements: Dicticus

**Defined:** 2026-04-14
**Core Value:** Press a key, speak, release — accurate text appears at your cursor instantly, fully private, no cloud dependency.

## v1 Requirements

Requirements for initial release. macOS only. Each maps to roadmap phases.

### Transcription

- [ ] **TRNS-01**: User can push-to-talk via configurable hotkey and text appears at cursor in any app
- [ ] **TRNS-02**: Transcription completes in under 3 seconds for typical utterances (< 30s speech)
- [ ] **TRNS-03**: Auto-detect German and English without manual language switching
- [ ] **TRNS-04**: Voice Activity Detection discards silence to prevent hallucinated output
- [ ] **TRNS-05**: Transcription works in any text field (browser, native apps, terminal)

### AI Cleanup

- [ ] **AICLEAN-01**: Light cleanup mode via separate hotkey (grammar, punctuation, filler word removal)
- [ ] **AICLEAN-02**: Cleanup preserves the user's original words and meaning — only fixes form
- [ ] **AICLEAN-03**: Cleanup works for both German and English text
- [ ] **AICLEAN-04**: LLM runs fully locally with no cloud calls

### App Shell

- [ ] **APP-01**: Menu bar app with minimal UI (no main window)
- [ ] **APP-02**: First-run onboarding guides user through Microphone and Accessibility permissions
- [ ] **APP-03**: Visual recording indicator while push-to-talk is active
- [ ] **APP-04**: Different hotkey combos for plain dictation vs AI cleanup mode
- [ ] **APP-05**: App launches at login (optional, configurable)

### Infrastructure

- [ ] **INFRA-01**: ASR model (Whisper large-v3-turbo) loads at app startup, stays warm in memory
- [ ] **INFRA-02**: LLM model (Gemma 3 1B or equivalent) loads at startup, stays warm
- [ ] **INFRA-03**: Core ML warm-up happens in background at launch (not on first hotkey press)
- [ ] **INFRA-04**: Total memory usage stays under 3 GB on 16 GB Apple Silicon Mac
- [ ] **INFRA-05**: App distributed as unsigned/notarized DMG (not App Store — sandbox incompatible)

## v2 Requirements

Deferred to future release. Tracked but not in current roadmap.

### Enhanced Modes

- **EMODE-01**: Heavy rewrite mode via third hotkey (rephrase for clarity and flow)
- **EMODE-02**: Prompt customization for cleanup behavior
- **EMODE-03**: Live streaming transcription (text appears as you speak)

### History & Polish

- **HIST-01**: Transcription history log with search
- **HIST-02**: Re-paste last transcription shortcut
- **HIST-03**: Auto-update via Sparkle
- **HIST-04**: Model download/management UI

### iPhone

- **IOS-01**: Shortcuts-based dictation (record → transcribe → return text)
- **IOS-02**: Same ASR quality as Mac (WhisperKit)

### Windows

- **WIN-01**: Push-to-talk system-wide hotkey with paste-at-cursor
- **WIN-02**: System tray app
- **WIN-03**: Same ASR quality as Mac (whisper.cpp)

## Out of Scope

Explicitly excluded. Documented to prevent scope creep.

| Feature | Reason |
|---------|--------|
| iOS custom keyboard | iOS blocks microphone access in keyboard extensions |
| Cloud ASR/LLM fallback | Hard privacy requirement — fully local only |
| App Store distribution | Sandbox blocks system-wide hotkeys and text injection |
| Always-listening mode | Anti-feature — privacy risk, battery drain |
| Speaker diarization | Single-user tool, unnecessary |
| Custom voice training | Unnecessary for single-user dictation |
| Subscription pricing | Anti-pattern for local-only tools |
| Real-time streaming (v1) | Batch processing is acceptable, reduces complexity |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| TRNS-01 | Phase 3 | Pending |
| TRNS-02 | Phase 2 | Pending |
| TRNS-03 | Phase 2 | Pending |
| TRNS-04 | Phase 2 | Pending |
| TRNS-05 | Phase 3 | Pending |
| AICLEAN-01 | Phase 4 | Pending |
| AICLEAN-02 | Phase 4 | Pending |
| AICLEAN-03 | Phase 4 | Pending |
| AICLEAN-04 | Phase 4 | Pending |
| APP-01 | Phase 1 | Pending |
| APP-02 | Phase 1 | Pending |
| APP-03 | Phase 3 | Pending |
| APP-04 | Phase 3 | Pending |
| APP-05 | Phase 5 | Pending |
| INFRA-01 | Phase 2 | Pending |
| INFRA-02 | Phase 4 | Pending |
| INFRA-03 | Phase 1 | Pending |
| INFRA-04 | Phase 5 | Pending |
| INFRA-05 | Phase 1 | Pending |

**Coverage:**
- v1 requirements: 19 total
- Mapped to phases: 19
- Unmapped: 0

---
*Requirements defined: 2026-04-14*
*Last updated: 2026-04-14 after roadmap creation*
