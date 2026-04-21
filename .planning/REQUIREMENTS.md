# Requirements: Dicticus

**Defined:** 2026-04-19
**Core Value:** Press a key, speak, release — accurate text appears at your cursor instantly, fully private, no cloud dependency.

## v1.1 Requirements

Requirements for v1.1 Cleanup Intelligence & Distribution. Each maps to roadmap phases.

### Cleanup Quality

- [x] **CLEAN-01**: Cleanup output contains no quotation marks that were not present in the original dictated speech — Phase 6
- [x] **CLEAN-06**: Cleanup output correctly includes apostrophes for contractions (e.g. "don't", "it's", "you're") in both English and German — Phase 9
- [x] **CLEAN-02**: LLM upgraded from Gemma 3 1B to Gemma 4 E2B (~3.1 GB Q4_K_M) with llama.cpp Metal — Phase 9
- [x] **CLEAN-03**: User can dictate broken/non-native German and cleanup produces grammatically correct, sensible German that preserves intended meaning — Phase 9
- [x] **CLEAN-04**: Cleanup prompt includes few-shot examples of broken German → corrected German for meaning inference — Phase 9
- [x] **CLEAN-05**: Cleanup latency remains under 5 seconds after model upgrade on Apple Silicon — Phase 9

### Text Processing

- [x] **TEXT-01**: Cardinal numbers in dictated speech appear as digits in output (e.g. "twenty three" → "23", "dreiundzwanzig" → "23") for both German and English — Phase 10
- [x] **TEXT-02**: User can define find-replace pairs in settings that correct recurring ASR errors (e.g. "cloud" → "Claude") — Phase 10
- [x] **TEXT-03**: Dictionary replacements apply after ASR and before LLM cleanup so the model sees corrected terms — Phase 10

### Distribution

- [x] **DIST-01**: App is signed with Apple Developer ID certificate and notarized via notarytool — Phase 7
- [x] **DIST-02**: App launches without Gatekeeper override (no right-click → Open required) — Phase 7
- [x] **DIST-03**: llama.cpp Metal inference works correctly under hardened runtime with appropriate entitlements — Phase 7
- [x] **DIST-04**: App checks for updates automatically via Sparkle and user can install updates with one click — Phase 8
- [x] **DIST-05**: Appcast hosted on GitHub with EdDSA-signed updates — Phase 8

### UI Polish

- [x] **UX-01**: Menu bar icon reflects all pipeline states (idle, recording, transcribing, cleaning) reactively ��� Phase 6
- [x] **UX-02**: User can view transcription history in a searchable list showing timestamp, language, mode, and text preview — Phase 11
- [x] **UX-03**: User can search transcription history by text content via full-text search — Phase 11
- [x] **UX-04**: User can copy text from any history entry — Phase 11

## v1.2 Requirements

Deferred to future release. Tracked but not in current roadmap.

### Text Processing

- **TEXT-04**: Ordinal number ITN ("dritte" → "3.", "third" → "3rd")
- **TEXT-05**: Date and currency formatting in ITN
- **TEXT-06**: Per-language dictionary rules

### History

- **HIST-01**: History export to file

## Out of Scope

Explicitly excluded. Documented to prevent scope creep.

| Feature | Reason |
|---------|--------|
| Regex-based dictionary | Overkill; simple find-replace covers the use case |
| Cloud cleanup fallback | Violates core privacy constraint |
| Swiss German ASR | Separate milestone; research links saved for later |
| Prompt customization UI | Premature until cleanup quality is proven |
| NeMo/WFST ITN pipeline | Python dependency; rule-based Swift covers 99% of cases |
| Usage analytics/stats | Vanity metrics, adds UI complexity for minimal value |
| Real-time streaming transcription | Parakeet is batch-mode; over-engineering for push-to-talk |
| Model auto-download on update | Sparkle updates should not trigger multi-GB downloads silently |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| CLEAN-01 | Phase 6: Bug Fixes & Reactivity | Complete |
| CLEAN-02 | Phase 9: Model Upgrade & Intelligent Cleanup | Complete |
| CLEAN-03 | Phase 9: Model Upgrade & Intelligent Cleanup | Complete |
| CLEAN-04 | Phase 9: Model Upgrade & Intelligent Cleanup | Complete |
| CLEAN-05 | Phase 9: Model Upgrade & Intelligent Cleanup | Complete |
| CLEAN-06 | Phase 9: Model Upgrade & Intelligent Cleanup | Complete |
| TEXT-01 | Phase 10: Text Processing Pipeline | Complete |
| TEXT-02 | Phase 10: Text Processing Pipeline | Complete |
| TEXT-03 | Phase 10: Text Processing Pipeline | Complete |
| DIST-01 | Phase 7: Code Signing & Notarization | Complete |
| DIST-02 | Phase 7: Code Signing & Notarization | Complete |
| DIST-03 | Phase 7: Code Signing & Notarization | Complete |
| DIST-04 | Phase 8: Auto-Update via Sparkle | Complete |
| DIST-05 | Phase 8: Auto-Update via Sparkle | Complete |
| UX-01 | Phase 6: Bug Fixes & Reactivity | Complete |
| UX-02 | Phase 11: Transcription History | Complete |
| UX-03 | Phase 11: Transcription History | Complete |
| UX-04 | Phase 11: Transcription History | Complete |

**Coverage:**
- v1.1 requirements: 17 total
- Mapped to phases: 17
- Unmapped: 0

---
*Requirements defined: 2026-04-19*
*Last updated: 2026-04-21 — all v1.1 requirements validated after milestone completion*
