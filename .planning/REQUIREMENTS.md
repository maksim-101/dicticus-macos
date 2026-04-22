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

- **KEYB-01**: User can trigger dictation via custom keyboard mic button
- **KEYB-02**: Transcribed text appears at cursor in any text field (no paste required)

### AI Cleanup

- **CLEAN-01**: User can enable AI cleanup for grammar/punctuation correction on iOS
- **CLEAN-02**: AI cleanup runs fully locally via llama.cpp Metal on iPhone

### History & Sync

- **HIST-01**: User can view transcription history on iOS
- **HIST-02**: Custom dictionary syncs between macOS and iOS via iCloud

### Quick Dictation

- **QUICK-01**: User can dictate up to 20 seconds with text returned as Shortcut output for automation chains

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

**Coverage:**
- v2.0 requirements: 22 total
- Mapped to phases: 22
- Unmapped: 0

---
*Requirements defined: 2026-04-21*
*Last updated: 2026-04-22 — all v2.0 requirements met*
