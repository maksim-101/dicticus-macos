# Roadmap: Dicticus

## Overview

Dicticus is a fully local macOS dictation app that replaces native dictation with push-to-talk hotkeys, on-device ASR (Whisper large-v3-turbo via whisper.cpp), and optional AI cleanup (Gemma 3 1B via llama.cpp). The roadmap delivers five phases: foundation scaffolding with permissions and menu bar shell, then ASR pipeline with VAD and language detection, then system-wide push-to-talk with paste-at-cursor, then AI cleanup modes via local LLM, and finally memory optimization and DMG distribution. Each phase delivers a testable vertical slice -- by the end of Phase 3, plain dictation works end-to-end.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [x] **Phase 1: Foundation & App Shell** - Xcode project, unsandboxed entitlements, menu bar presence, permissions onboarding, model warm-up infrastructure (completed 2026-04-15)
- [ ] **Phase 2: ASR Pipeline** - Audio capture, VAD, Whisper large-v3-turbo transcription, auto language detection (de/en)
- [ ] **Phase 2.1: ASR Engine Swap** - Replace WhisperKit with FluidAudio + Parakeet TDT v3 for better de/en quality and ANE performance (INSERTED)
- [ ] **Phase 3: System-Wide Dictation** - Push-to-talk hotkeys, paste-at-cursor, recording indicator, per-mode hotkey routing
- [ ] **Phase 4: AI Cleanup** - Local LLM integration (Gemma 3 1B via llama.cpp), light cleanup mode, bilingual cleanup, latency validation
- [ ] **Phase 5: Polish & Distribution** - Memory budget validation, launch-at-login, DMG packaging, modifier-only hotkeys

## Phase Details

### Phase 1: Foundation & App Shell
**Goal**: A running macOS menu bar app that guides the user through permissions and warms up ML models in the background -- the foundation everything else builds on
**Depends on**: Nothing (first phase)
**Requirements**: APP-01, APP-02, INFRA-03, INFRA-05
**Success Criteria** (what must be TRUE):
  1. App appears as a menu bar icon with a dropdown menu (no main window)
  2. First launch guides user through Microphone, Accessibility, and Menu Bar permission grants with direct links to System Settings
  3. App shows a "warming up" indicator on first launch while Core ML compiles; subsequent launches are fast
  4. App entitlements configured for unsandboxed distribution (Hardened Runtime enabled, sandbox disabled); DMG packaging deferred to Phase 5
**Plans**: 3 plans

Plans:
- [x] 01-01-PLAN.md — Xcode project scaffold with MenuBarExtra shell, entitlements, and WhisperKit SPM dependency
- [x] 01-02-PLAN.md — Permissions onboarding (PermissionManager, sequential flow, dropdown status rows)
- [x] 01-03-PLAN.md — Model warm-up infrastructure (WhisperKit CoreML init, icon animation, progress UI)

### Phase 2: ASR Pipeline
**Goal**: The app can capture microphone audio, detect speech via VAD, and transcribe it accurately in German and English -- the core inference engine
**Depends on**: Phase 1
**Requirements**: TRNS-02, TRNS-03, TRNS-04, INFRA-01
**Success Criteria** (what must be TRUE):
  1. Whisper large-v3-turbo model loads at app startup and stays warm in memory (no reload per request)
  2. Audio is captured at 16kHz mono via AVAudioEngine with correct sample rate conversion
  3. VAD discards silence and sub-0.3s clips -- no hallucinated text on empty recordings
  4. Transcription of a typical utterance (< 30s) completes in under 3 seconds on Apple Silicon
  5. Language is auto-detected between German and English (restricted to de/en set) without manual switching
**Plans**: 2 plans

Plans:
- [x] 02-01-PLAN.md — TranscriptionService + DicticusTranscriptionResult model with three-layer VAD, language detection, and unit tests
- [x] 02-02-PLAN.md — Pin large-v3-turbo model in ModelWarmupService, wire TranscriptionService into app, integration checkpoint

### Phase 2.1: ASR Engine Swap: WhisperKit to FluidAudio + Parakeet TDT v3 (INSERTED)

**Goal:** Replace WhisperKit + Whisper large-v3-turbo with FluidAudio + Parakeet TDT v3 as the sole ASR engine, preserving the TranscriptionService public API so Phase 3 can consume it unchanged
**Requirements**: TRNS-02, TRNS-03, TRNS-04, INFRA-01, INFRA-03
**Depends on:** Phase 2
**Plans:** 2 plans

Plans:
- [x] 02.1-01-PLAN.md — Replace WhisperKit SPM dependency with FluidAudio, rewrite ModelWarmupService for AsrManager + VadManager
- [x] 02.1-02-PLAN.md — Rewrite TranscriptionService with AVAudioEngine + FluidAudio + NLLanguageRecognizer, adapt tests, zero WhisperKit remnants

### Phase 3: System-Wide Dictation
**Goal**: User can hold a hotkey, speak, release, and transcribed text appears at the cursor in any app -- the core user-facing workflow
**Depends on**: Phase 2
**Requirements**: TRNS-01, TRNS-05, APP-03, APP-04
**Success Criteria** (what must be TRUE):
  1. User holds a configurable hotkey, speaks, releases, and text appears at the cursor position in the frontmost app
  2. Text injection works in browsers (Safari, Chrome), native apps (Notes, TextEdit), and terminal (Terminal.app, iTerm2)
  3. Menu bar icon changes visually while recording is active (recording indicator)
  4. Different hotkey combos are registered for plain dictation vs AI cleanup mode (mode routing by hotkey identity, not state toggle)
  5. Original clipboard contents are preserved after text injection (clipboard restore)
**Plans**: 4 plans
**UI hint**: yes

Plans:
- [x] 03-01-PLAN.md — KeyboardShortcuts SPM dependency, hotkey name definitions, TextInjector clipboard service, NotificationService
- [x] 03-02-PLAN.md — HotkeyManager push-to-talk state machine, DicticusApp icon state machine, service wiring
- [x] 03-03-PLAN.md — Menu bar dropdown UI (hotkey config section, last transcription preview), end-to-end verification checkpoint
- [x] 03-04-PLAN.md — UAT gap closure: non-Latin script rejection, inter-segment spacing, launch permission check, copy feedback

### Phase 4: AI Cleanup
**Goal**: User can dictate with a separate hotkey and receive grammar-corrected, punctuation-fixed text that preserves their original meaning -- AI-enhanced dictation
**Depends on**: Phase 3
**Requirements**: AICLEAN-01, AICLEAN-02, AICLEAN-03, AICLEAN-04, INFRA-02
**Success Criteria** (what must be TRUE):
  1. Light cleanup hotkey produces text with corrected grammar, punctuation, and filler words removed
  2. Cleanup preserves the user's original words and meaning -- it fixes form, not content
  3. Cleanup works correctly for both German and English text (language-appropriate grammar rules)
  4. LLM (Gemma 3 1B) runs fully locally via llama.cpp with no network calls
  5. Total latency for cleanup mode (ASR + LLM) stays under 4 seconds for typical utterances
**Plans**: 3 plans

Plans:
- [x] 04-01-PLAN.md — llama.swift SPM dependency, ModelDownloadService for GGUF caching, CleanupPrompt language-specific templates, unit tests
- [x] 04-02-PLAN.md — CleanupService with llama.cpp inference pipeline (tokenize, decode, sample, detokenize), state machine, timeout/fallback, tests
- [x] 04-03-PLAN.md — Wire LLM into warmup, HotkeyManager AI cleanup pipeline, DicticusApp icon state with cleanup indicator, notifications

### Phase 5: Polish & Distribution
**Goal**: The app is reliable, memory-efficient, and ready for daily use as a packaged DMG
**Depends on**: Phase 4
**Requirements**: INFRA-04, APP-05
**Success Criteria** (what must be TRUE):
  1. Total memory usage stays under 3 GB with both ASR and LLM models loaded on a 16 GB Apple Silicon Mac
  2. App can optionally launch at login (configurable in settings)
  3. App is packaged as a DMG that a user can download, drag to Applications, and run without additional setup beyond permission grants
  4. Modifier-only hotkeys (Fn+Shift, Fn+Control) are available as push-to-talk activation options alongside standard key combos
**Plans**: 3 plans

Plans:
- [ ] 05-01-PLAN.md — LaunchAtLogin-Modern SPM dependency, ModifierCombo model, ModifierHotkeyListener CGEventTap service with unit tests
- [ ] 05-02-PLAN.md — Settings section UI (launch-at-login toggle, modifier hotkey pickers), HotkeyManager + DicticusApp wiring
- [ ] 05-03-PLAN.md — DMG build pipeline (build-dmg.sh, styled background), memory profiling script (verify-memory.sh), human verification

## Progress

**Execution Order:**
Phases execute in numeric order: 1 -> 2 -> 2.1 -> 3 -> 4 -> 5

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Foundation & App Shell | 3/3 | Complete   | 2026-04-15 |
| 2. ASR Pipeline | 2/2 | Complete | 2026-04-15 |
| 2.1. ASR Engine Swap | 2/2 | Complete | 2026-04-16 |
| 3. System-Wide Dictation | 4/4 | Complete | 2026-04-17 |
| 4. AI Cleanup | 3/3 | Complete | 2026-04-17 |
| 5. Polish & Distribution | 0/3 | Not started | - |
