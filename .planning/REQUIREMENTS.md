# Requirements: Dicticus iOS

**Defined:** 2026-04-21
**Core Value:** Press a key, speak, release — accurate text appears at your cursor instantly, fully private, no cloud dependency.

## v2.0 Requirements

Requirements for iOS app initial release. Each maps to roadmap phases.

### Infrastructure

- [x] **INFRA-01**: macOS app passes all 158 existing tests after shared code extraction to `Shared/`
- [x] **INFRA-02**: iOS app uses Xcode 26 project format (via xcodegen), compiles and launches on iOS 17+ simulator
- [x] **INFRA-03**: App Groups container (`group.com.dicticus`) configured for shared data between app and future extensions

### ASR Pipeline

- [x] **ASR-01**: User can transcribe speech in German and English on iPhone/iPad using on-device Parakeet TDT v3
- [x] **ASR-02**: Transcription starts within 2 seconds of user stopping speech (model pre-warmed)
- [x] **ASR-03**: ASR model loads automatically when app comes to foreground

### Model Management

- [x] **MODEL-01**: User can download the Parakeet ASR model on first launch with progress indicator
- [x] **MODEL-02**: User can resume an interrupted model download without re-downloading
- [x] **MODEL-03**: User sees storage check and Wi-Fi recommendation before download begins

### Activation

- [x] **ACT-01**: User can trigger dictation via Siri Shortcut (AudioRecordingIntent, app opens to recording screen)
- [x] **ACT-02**: User sees a Live Activity recording indicator while dictating
- [x] **ACT-03**: User can record for unlimited duration (no time cap)
- [x] **ACT-04**: User receives guided setup wizard for Action Button configuration
- [x] **ACT-05**: User receives guided setup wizard for Back Tap configuration
- [x] **ACT-06**: User can trigger dictation via Siri voice command

### Text Delivery

- [x] **TEXT-01**: Transcribed text is automatically copied to clipboard after dictation

### Custom Dictionary

- [x] **DICT-01**: User can add, edit, and remove dictionary entries on iOS
- [x] **DICT-02**: Dictionary corrections are applied automatically to transcriptions

### Onboarding

- [x] **ONBD-01**: User sees explanation of why microphone access is needed before system permission prompt
- [x] **ONBD-02**: First-run onboarding guides user through model download and Shortcut setup

### Universal App

- [x] **UAPP-01**: App works on iPhone with phone-optimized layout
- [x] **UAPP-02**: App works on iPad with tablet-optimized layout

## v2.1 Requirements

Deferred to future release. Tracked but not in current roadmap.

### Keyboard Activation

- [x] **KEYB-01**: User can trigger dictation via custom keyboard mic button
- [x] **KEYB-02**: Transcribed text appears at cursor in any text field (no paste required)

### AI Cleanup

- **CLEAN-01**: User can enable AI cleanup for grammar/punctuation correction on iOS
- **CLEAN-02**: AI cleanup runs fully locally via llama.cpp Metal on iPhone

### History & Sync

- **HIST-01**: User can view transcription history on iOS
- **HIST-02**: Custom dictionary syncs between macOS and iOS via iCloud

### Quick Dictation

- **QUICK-01**: User can dictate up to 20 seconds with text returned as Shortcut output for automation chains

## v2.3 Requirements

Defined 2026-05-26 from `.planning/debug/log-analysis-2026-05-26.md`. Scope: live-capture-driven quality polish. No new features.

### Dictionary Safety (Phase 27)

- [x] **DICT-SAFE-01**: User's transcription is never corrupted by fuzzy-pass mutating a real English word into a brand name (e.g. `remind → Gemini`, `applies → AppLite` must not happen)
- [x] **DICT-SAFE-02**: Fuzzy-pass replacements are bounded by a valid-word guard before Levenshtein swap is applied
- [x] **DICT-EXPAND-01**: Dictionary covers observed live-capture brand misses (Aqara, Karpathy, Swissfolio, Gemini, cron job, Claude Code variants) so common dev/IoT terms transcribe correctly

### Recorder Diagnosability (Phase 27)

- [x] **OBS-DICT-01**: Debug recorder schema emits a per-replacement `{key, from, to}` array for every dictionary mutation, so future log analyses can attribute mutations without re-running

### Prompt Quality (Phase 28)

- [x] **LLM-CLAUSE-01**: AI cleanup preserves substantive clauses verbatim — no silent deletions of meaningful phrases like `in the meantime`
- [x] **LLM-CONTR-01**: AI cleanup handles English contractions cleanly — no malformed outputs like `I't have`
- [x] **LLM-DEDUP-01**: AI cleanup collapses immediate word repetitions beyond `the the` (e.g. `for for`, `that that`, `unusual, unusual`)
- [x] **LLM-NUM-01**: Standalone digit-words in prose (`one`, `three`, etc.) follow a principled and consistent policy across the rules + LLM pipeline
- [x] **LLM-PROMPT-AUDIT-01**: Static `Domain topic words` line in the prompt is audited for bias and either justified, generalized, or removed

### ASR Post-Processing (Phase 29)

- [x] **ACRONYM-COLLAPSE-01**: Deterministic post-ASR step collapses spaced single/short uppercase fragment runs (`N F S K`→`NFSK`), handles mixed-case fragments (`Br N A C`), and does not corrupt non-acronym single-letter runs (`I am O K`)
- [x] **SPOKEN-LETTER-01**: Inside a spelling run, spoken letter names resolve to letters — Z spoken as "zed"/"zee"→`Z` (plus `aitch`→H, `double-u`→W); ambiguous "zee" handled conservatively
- [x] **DICT-ZED-01**: `DictionaryService` default entry `"the set."`→`"Zed."` ships (Spike-001-validated; period-anchored to avoid "the set of …" / compound "X set" false positives)

### Media Control (Phase 30, macOS)

- [ ] **MEDIA-PAUSE-01**: While push-to-talk is held, currently-playing media is paused (or muted per agreed fallback) and resumes on release — macOS only. Approach selected by spike (MediaRemote / media-key / mute) given macOS 15.4+ now-playing entitlement gating

## Out of Scope

Explicitly excluded. Documented to prevent scope creep.

| Feature | Reason |
|---------|--------|
| Cloud ASR/LLM | Fully local is a hard requirement |
| Background recording without foreground app | iOS blocks microphone access in background |
| Always-listening mode | Privacy and battery concern |
| App Store distribution (v2.0) | TestFlight / ad-hoc first |
| AI cleanup on iOS | Deferred to v2.1 — keep scope tight, hardware constraints |
| Mixed-language cleanup | Known limitation — Gemma translates minority language |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| INFRA-01 | Phase 12 | Completed |
| INFRA-02 | Phase 12 | Completed |
| INFRA-03 | Phase 12 | Completed |
| ASR-01 | Phase 13 | Completed |
| ASR-02 | Phase 13 | Completed |
| ASR-03 | Phase 13 | Completed |
| ACT-01 | Phase 13 | Completed |
| ACT-02 | Phase 13 | Completed |
| ACT-03 | Phase 13 | Completed |
| ACT-06 | Phase 13 | Completed |
| TEXT-01 | Phase 13 | Completed |
| MODEL-01 | Phase 14 | Completed |
| MODEL-02 | Phase 14 | Completed |
| MODEL-03 | Phase 14 | Completed |
| DICT-01 | Phase 15 | Completed |
| DICT-02 | Phase 15 | Completed |
| ONBD-01 | Phase 16 | Completed |
| ONBD-02 | Phase 16 | Completed |
| ACT-04 | Phase 16 | Completed |
| ACT-05 | Phase 16 | Completed |
| UAPP-01 | Phase 16 | Completed |
| UAPP-02 | Phase 16 | Completed |
| KEYB-01 | Phase 17 | Completed |
| KEYB-02 | Phase 17 | Completed |
| CLEAN-01 | Phase 19 | Completed |
| CLEAN-02 | Phase 19 | Completed |
| DICT-SAFE-01 | Phase 27 | Complete |
| DICT-SAFE-02 | Phase 27 | Complete |
| DICT-EXPAND-01 | Phase 27 | Complete |
| OBS-DICT-01 | Phase 27 | Complete |
| LLM-CLAUSE-01 | Phase 28 | Complete |
| LLM-CONTR-01 | Phase 28 | Complete |
| LLM-DEDUP-01 | Phase 28 | Complete |
| LLM-NUM-01 | Phase 28 | Complete |
| LLM-PROMPT-AUDIT-01 | Phase 28 | Complete |
| ACRONYM-COLLAPSE-01 | Phase 29 | Not started |
| SPOKEN-LETTER-01 | Phase 29 | Not started |
| DICT-ZED-01 | Phase 29 | Not started |
| MEDIA-PAUSE-01 | Phase 30 | Not started |

**Coverage:**
- v2.0 requirements: 22 total
- v2.1 requirements (started): 4 total
- v2.3 requirements: 13 total (9 complete + 4 added 2026-05-29 across Phases 29-30)
- Mapped to phases: 39
- Unmapped: 0

---
*Requirements defined: 2026-04-21*
*Last updated: 2026-05-26 — v2.3 Live-Capture Quality Pass requirements added (9 reqs across Phases 27-28)*
