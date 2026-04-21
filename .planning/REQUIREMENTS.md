# Requirements: Dicticus iOS

**Defined:** 2026-04-21
**Core Value:** Press a key, speak, release — accurate text appears at your cursor instantly, fully private, no cloud dependency.

## v2.0 Requirements

Requirements for iOS app initial release. Each maps to roadmap phases.

### Infrastructure

- [ ] **INFRA-01**: macOS app passes all 158 existing tests after shared code extraction to `Shared/`
- [ ] **INFRA-02**: iOS app uses Xcode 26 project format (not xcodegen), compiles and launches on iOS 17+ simulator
- [ ] **INFRA-03**: App Groups container (`group.com.dicticus`) configured for shared data between app and future extensions

### ASR Pipeline

- [ ] **ASR-01**: User can transcribe speech in German and English on iPhone/iPad using on-device Parakeet TDT v3
- [ ] **ASR-02**: Transcription starts within 2 seconds of user stopping speech (model pre-warmed)
- [ ] **ASR-03**: ASR model loads automatically when app comes to foreground

### Model Management

- [ ] **MODEL-01**: User can download the Parakeet ASR model on first launch with progress indicator
- [ ] **MODEL-02**: User can resume an interrupted model download without re-downloading
- [ ] **MODEL-03**: User sees storage check and Wi-Fi recommendation before download begins

### Activation

- [ ] **ACT-01**: User can trigger dictation via Siri Shortcut (AudioRecordingIntent, app opens to recording screen)
- [ ] **ACT-02**: User sees a Live Activity recording indicator while dictating
- [ ] **ACT-03**: User can record for unlimited duration (no time cap)
- [ ] **ACT-04**: User receives guided setup wizard for Action Button configuration
- [ ] **ACT-05**: User receives guided setup wizard for Back Tap configuration
- [ ] **ACT-06**: User can trigger dictation via Siri voice command

### Text Delivery

- [ ] **TEXT-01**: Transcribed text is automatically copied to clipboard after dictation

### Custom Dictionary

- [ ] **DICT-01**: User can add, edit, and remove dictionary entries on iOS
- [ ] **DICT-02**: Dictionary corrections are applied automatically to transcriptions

### Onboarding

- [ ] **ONBD-01**: User sees explanation of why microphone access is needed before system permission prompt
- [ ] **ONBD-02**: First-run onboarding guides user through model download and Shortcut setup

### Universal App

- [ ] **UAPP-01**: App works on iPhone with phone-optimized layout
- [ ] **UAPP-02**: App works on iPad with tablet-optimized layout

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
| Custom keyboard | Deferred to v2.1 — Shortcut approach first, keyboard if needed |
| Mixed-language cleanup | Known limitation — Gemma translates minority language |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| INFRA-01 | Phase 12 | Pending |
| INFRA-02 | Phase 12 | Pending |
| INFRA-03 | Phase 12 | Pending |
| ASR-01 | Phase 13 | Pending |
| ASR-02 | Phase 13 | Pending |
| ASR-03 | Phase 13 | Pending |
| ACT-01 | Phase 13 | Pending |
| ACT-02 | Phase 13 | Pending |
| ACT-03 | Phase 13 | Pending |
| ACT-06 | Phase 13 | Pending |
| TEXT-01 | Phase 13 | Pending |
| MODEL-01 | Phase 14 | Pending |
| MODEL-02 | Phase 14 | Pending |
| MODEL-03 | Phase 14 | Pending |
| DICT-01 | Phase 15 | Pending |
| DICT-02 | Phase 15 | Pending |
| ONBD-01 | Phase 16 | Pending |
| ONBD-02 | Phase 16 | Pending |
| ACT-04 | Phase 16 | Pending |
| ACT-05 | Phase 16 | Pending |
| UAPP-01 | Phase 16 | Pending |
| UAPP-02 | Phase 16 | Pending |

**Coverage:**
- v2.0 requirements: 22 total
- Mapped to phases: 22
- Unmapped: 0

---
*Requirements defined: 2026-04-21*
*Last updated: 2026-04-21 — traceability populated after roadmap creation*
