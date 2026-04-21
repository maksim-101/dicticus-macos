# Roadmap: Dicticus

## Milestones

- ✅ **v1.0 MVP** — Phases 1-5 (shipped 2026-04-18) — [Archive](milestones/v1.0-ROADMAP.md)
- ✅ **v1.1 Cleanup Intelligence & Distribution** — Phases 6-11 (shipped 2026-04-20)
- 📋 **v2.0 iOS App — Shortcut Dictation** — Phases 12-16 (planned)

## Phases

<details>
<summary>✅ v1.0 MVP (Phases 1-5) — SHIPPED 2026-04-18</summary>

See [milestones/v1.0-ROADMAP.md](milestones/v1.0-ROADMAP.md) for full v1.0 phase details.

</details>

<details>
<summary>✅ v1.1 Cleanup Intelligence & Distribution — SHIPPED 2026-04-20</summary>

**Milestone Goal:** Transform AI cleanup into intelligent meaning inference for non-native German, add number formatting and custom dictionary, and ship a properly signed macOS app with auto-updates.

- [x] **Phase 6: Bug Fixes & Reactivity** - Fix cleanup quote injection and menu bar icon state reactivity
- [x] **Phase 7: Code Signing & Notarization** - Sign and notarize the app so it launches without Gatekeeper override
- [x] **Phase 8: Auto-Update via Sparkle** - Add automatic update checking and one-click install via Sparkle
- [x] **Phase 9: Model Upgrade & Intelligent Cleanup** - Upgrade LLM to Gemma 4 E2B and redesign cleanup for non-native German
- [x] **Phase 10: Text Processing Pipeline** - Add cardinal number ITN and custom dictionary with correct pipeline ordering
- [x] **Phase 11: Transcription History** - Searchable history log with copy support via GRDB + FTS5

</details>

### 📋 v2.0 iOS App — Shortcut Dictation (Planned)

**Milestone Goal:** Bring Dicticus to iPhone and iPad with Shortcut-based activation, on-device Parakeet ASR via FluidAudio, custom dictionary, and model management — fully private, no cloud dependency.

- [ ] **Phase 12: Shared Code Extraction & iOS Scaffold** - Extract platform-agnostic services to `Shared/`, create iOS Xcode 26 target, configure App Groups
- [ ] **Phase 13: App Intent + Live Activity + Core Dictation Pipeline** - Wire DictateIntent, AudioRecordingIntent, AVAudioSession, FluidAudio ASR, and clipboard output into an end-to-end dictation flow
- [ ] **Phase 14: Model Management** - First-launch model download with progress UI, Wi-Fi warning, resume support, and storage consent
- [ ] **Phase 15: Custom Dictionary & Post-Processing** - Apply DictionaryService and ITN corrections to iOS transcriptions, wire UserDefaults App Groups suite
- [ ] **Phase 16: Onboarding, Universal App & Distribution** - Mic permission priming, Shortcut setup wizard, Action Button and Back Tap guides, iPad layout, TestFlight-ready build

## Phase Details

### Phase 11: Transcription History
**Goal**: Users can review, search, and recover past dictations without re-dictating — a searchable log of all transcription activity
**Depends on**: Phase 6 (bug fixes complete)
**Requirements**: UX-02, UX-03, UX-04
**Success Criteria** (what must be TRUE):
  1. User can open a history panel from the menu bar and see a scrollable list of past transcriptions with timestamp, language, mode, and text preview
  2. User can type in a search field and find past transcriptions by text content via full-text search
  3. User can copy the full text of any history entry to the clipboard with one click
**Plans**: Complete
**UI hint**: yes

### Phase 12: Shared Code Extraction & iOS Scaffold
**Goal**: Platform-agnostic services live in `Shared/` and compile into both macOS and iOS targets — macOS app continues to pass all 158 tests, and a bare iOS app target launches on simulator
**Depends on**: Phase 11 (v1.1 complete)
**Requirements**: INFRA-01, INFRA-02, INFRA-03
**Success Criteria** (what must be TRUE):
  1. macOS app builds and all 158 existing tests pass after shared code extraction — no regressions
  2. iOS app target compiles and launches on iOS 17+ simulator (Xcode 26 project format, not xcodegen)
  3. App Groups container (`group.com.dicticus`) is configured and accessible from the iOS app
  4. `DictionaryService`, `ITNUtility`, `HistoryService`, `TextProcessingService`, `TranscriptionResult`, and `CleanupPrompt` compile from `Shared/` into both targets without `#if os()` conditionals in shared files
**Plans**: 3 plans
Plans:
- [ ] 12-01-PLAN.md — Protocol & Base Models Extraction
- [ ] 12-02-PLAN.md — Services Move & App Groups Refactor
- [ ] 12-03-PLAN.md — iOS Project Scaffold & Wiring

### Phase 13: App Intent + Live Activity + Core Dictation Pipeline
**Goal**: Users can trigger dictation from a Siri Shortcut and receive the transcribed text on their clipboard — the complete end-to-end dictation flow working on a real iPhone
**Depends on**: Phase 12
**Requirements**: ASR-01, ASR-02, ASR-03, ACT-01, ACT-02, ACT-03, ACT-06, TEXT-01
**Success Criteria** (what must be TRUE):
  1. User can trigger dictation via a Siri Shortcut (AudioRecordingIntent), the app foregrounds, and a Live Activity recording indicator appears in the Dynamic Island or Lock Screen
  2. User can speak in German or English and receive accurate on-device transcription via Parakeet TDT v3 on the Neural Engine
  3. Transcription starts within 2 seconds of the user stopping speech when the model is pre-warmed (loaded on app foreground)
  4. User can record without a time cap (Option B: app foregrounds, no 30-second Shortcut timeout constraint)
  5. Transcribed text is automatically written to the clipboard at the end of dictation, available for paste in any app
  6. User can trigger dictation via Siri voice command ("Hey Siri, start dictation")
**Plans**: TBD
**UI hint**: yes

### Phase 14: Model Management
**Goal**: Users can download and manage the Parakeet ASR model on first launch with clear progress feedback, storage consent, and resilient download behavior
**Depends on**: Phase 12
**Requirements**: MODEL-01, MODEL-02, MODEL-03
**Success Criteria** (what must be TRUE):
  1. User sees a storage consent screen showing model size (~2.69 GB) and a Wi-Fi recommendation before any download begins
  2. User can monitor download progress via a progress bar with percentage and remaining size indicators
  3. User can close and reopen the app mid-download and the download resumes from where it left off without re-downloading from the beginning
**Plans**: TBD
**UI hint**: yes

### Phase 15: Custom Dictionary & Post-Processing
**Goal**: Custom dictionary corrections and inverse text normalization are applied to every iOS transcription — the same correction quality users have on macOS
**Depends on**: Phase 13
**Requirements**: DICT-01, DICT-02
**Success Criteria** (what must be TRUE):
  1. User can add, edit, and remove custom dictionary entries on iOS via a dedicated settings screen
  2. Dictionary corrections are automatically applied to every transcription before the text reaches the clipboard (e.g., "Cloud" → "Claude" if configured)
  3. Dictionary entries persist across app restarts and are stored in the App Groups container for future extension access
**Plans**: TBD
**UI hint**: yes

### Phase 16: Onboarding, Universal App & Distribution
**Goal**: New users are guided through permissions, model download, and Shortcut setup — the app works well on both iPhone and iPad — and a TestFlight-ready build is produced
**Depends on**: Phase 14, Phase 15
**Requirements**: ONBD-01, ONBD-02, ACT-04, ACT-05, UAPP-01, UAPP-02
**Success Criteria** (what must be TRUE):
  1. First-run user sees a contextual explanation of why microphone access is needed before the system permission prompt appears
  2. First-run onboarding flow guides the user through model download and how to add the Dicticus Shortcut to their library
  3. User receives a step-by-step in-app wizard showing how to assign the Dicticus Shortcut to the Action Button
  4. User receives in-app instructions for setting up Back Tap to trigger dictation
  5. App is usable on iPhone with a phone-optimized layout (no broken constraints or oversized elements)
  6. App is usable on iPad with a tablet-optimized layout (centered content card, space used appropriately)
**Plans**: TBD
**UI hint**: yes

## Progress

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 1. Foundation & App Shell | v1.0 | 3/3 | Complete | 2026-04-15 |
| 2. ASR Pipeline | v1.0 | 2/2 | Complete | 2026-04-15 |
| 2.1. ASR Engine Swap (INSERTED) | v1.0 | 2/2 | Complete | 2026-04-16 |
| 3. System-Wide Dictation | v1.0 | 4/4 | Complete | 2026-04-17 |
| 4. AI Cleanup | v1.0 | 3/3 | Complete | 2026-04-17 |
| 5. Polish & Distribution | v1.0 | 3/3 | Complete | 2026-04-18 |
| 6. Bug Fixes & Reactivity | v1.1 | 2/2 | Complete | 2026-04-19 |
| 7. Code Signing & Notarization | v1.1 | 1/1 | Complete | 2026-04-19 |
| 8. Auto-Update via Sparkle | v1.1 | 1/1 | Complete | 2026-04-19 |
| 9. Model Upgrade & Intelligent Cleanup | v1.1 | 1/1 | Complete | 2026-04-19 |
| 10. Text Processing Pipeline | v1.1 | 1/1 | Complete | 2026-04-19 |
| 11. Transcription History | v1.1 | 1/1 | Complete | 2026-04-19 |
| 12. Shared Code Extraction & iOS Scaffold | v2.0 | 0/3 | Planned | - |
| 13. App Intent + Live Activity + Core Dictation Pipeline | v2.0 | 0/TBD | Not started | - |
| 14. Model Management | v2.0 | 0/TBD | Not started | - |
| 15. Custom Dictionary & Post-Processing | v2.0 | 0/TBD | Not started | - |
| 16. Onboarding, Universal App & Distribution | v2.0 | 0/TBD | Not started | - |