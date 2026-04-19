# Roadmap: Dicticus

## Milestones

- ✅ **v1.0 MVP** — Phases 1-5 (shipped 2026-04-18) — [Archive](milestones/v1.0-ROADMAP.md)
- 🚧 **v1.1 Cleanup Intelligence & Distribution** — Phases 6-11 (in progress)

## Phases

<details>
<summary>✅ v1.0 MVP (Phases 1-5) — SHIPPED 2026-04-18</summary>

See [milestones/v1.0-ROADMAP.md](milestones/v1.0-ROADMAP.md) for full v1.0 phase details.

</details>

### 🚧 v1.1 Cleanup Intelligence & Distribution (In Progress)

**Milestone Goal:** Transform AI cleanup into intelligent meaning inference for non-native German, add number formatting and custom dictionary, and ship a properly signed macOS app with auto-updates.

- [x] **Phase 6: Bug Fixes & Reactivity** - Fix cleanup quote injection and menu bar icon state reactivity
- [ ] **Phase 7: Code Signing & Notarization** - Sign and notarize the app so it launches without Gatekeeper override
- [ ] **Phase 8: Auto-Update via Sparkle** - Add automatic update checking and one-click install via Sparkle
- [ ] **Phase 9: Model Upgrade & Intelligent Cleanup** - Upgrade LLM to Gemma 4 E2B and redesign cleanup for non-native German
- [ ] **Phase 10: Text Processing Pipeline** - Add cardinal number ITN and custom dictionary with correct pipeline ordering
- [ ] **Phase 11: Transcription History** - Searchable history log with copy support via GRDB + FTS5

## Phase Details

### Phase 6: Bug Fixes & Reactivity
**Goal**: Existing features work correctly -- cleanup produces clean output without injected quotes, and the menu bar icon reflects all pipeline states in real time
**Depends on**: Nothing (first phase of v1.1; builds on v1.0 codebase)
**Requirements**: CLEAN-01, UX-01
**Success Criteria** (what must be TRUE):
  1. User triggers AI cleanup on any dictation and the output never contains quotation marks that were not in the original speech
  2. Menu bar icon visibly changes when transitioning between idle, recording, transcribing, and cleaning states
  3. User can observe distinct icon states for all four pipeline stages without opening any panel or log
**Plans**: TBD

### Phase 7: Code Signing & Notarization
**Goal**: The app is properly signed and notarized so users can install and launch it like any legitimate Mac app -- no Gatekeeper workarounds
**Depends on**: Phase 6
**Requirements**: DIST-01, DIST-02, DIST-03
**Success Criteria** (what must be TRUE):
  1. User downloads the DMG and double-clicks to open the app without needing right-click > Open or any Gatekeeper override
  2. macOS displays no security warnings during installation or first launch
  3. AI cleanup (llama.cpp Metal inference) works correctly in the signed, hardened-runtime build with all necessary entitlements
  4. The app passes `spctl --assess --type execute` and `codesign --verify --deep --strict`
**Plans**: TBD

### Phase 8: Auto-Update via Sparkle
**Goal**: Users receive updates automatically without manual DMG downloads -- the app checks for updates in the background and offers one-click install
**Depends on**: Phase 7 (requires signed app for update verification)
**Requirements**: DIST-04, DIST-05
**Success Criteria** (what must be TRUE):
  1. User sees a "Check for Updates..." menu item in the menu bar dropdown and can trigger a manual update check
  2. App automatically checks for updates in the background (default: every 24 hours) and shows a notification when an update is available
  3. User can install an update with one click (download, quit, replace, relaunch)
  4. Appcast is hosted on GitHub with EdDSA-signed updates that Sparkle verifies before installing
**Plans**: TBD

### Phase 9: Model Upgrade & Intelligent Cleanup
**Goal**: AI cleanup evolves from literal grammar correction to intelligent meaning inference -- non-native German speakers get sensible, corrected output even from broken or garbled dictation
**Depends on**: Phase 7 (hardened runtime entitlements must be validated before swapping the LLM)
**Requirements**: CLEAN-02, CLEAN-03, CLEAN-04, CLEAN-05
**Success Criteria** (what must be TRUE):
  1. Gemma 4 E2B (~3.1 GB Q4_K_M) loads and runs via llama.cpp Metal, replacing Gemma 3 1B as the default cleanup model
  2. User dictates broken/non-native German (wrong prepositions, garbled word order, semantically wrong words) and cleanup produces grammatically correct German that preserves the intended meaning
  3. Cleanup prompt includes few-shot examples demonstrating broken German to corrected German transformations
  4. Cleanup latency remains under 5 seconds for a typical utterance on Apple Silicon (M1/M2/M3/M4)
**Plans**: TBD

### Phase 10: Text Processing Pipeline
**Goal**: Numbers appear as digits in dictation output, and users can define corrections for recurring ASR errors -- both integrated into the processing pipeline in the correct order
**Depends on**: Phase 6 (bug fixes complete); Phase 9 (cleanup prompt includes ITN instructions for cleanup mode)
**Requirements**: TEXT-01, TEXT-02, TEXT-03
**Success Criteria** (what must be TRUE):
  1. User dictates "twenty three" or "dreiundzwanzig" and the output contains "23" in both plain and cleanup modes
  2. User can add, edit, and remove find-replace pairs in settings (e.g. "cloud" -> "Claude")
  3. Dictionary replacements apply after ASR and before LLM cleanup, so the LLM sees corrected terms
  4. Pipeline order is correct: ASR -> Dictionary -> LLM cleanup (with ITN) -> Text Injection
**Plans**: TBD
**UI hint**: yes

### Phase 11: Transcription History
**Goal**: Users can review, search, and recover past dictations without re-dictating -- a searchable log of all transcription activity
**Depends on**: Phase 6 (bug fixes complete)
**Requirements**: UX-02, UX-03, UX-04
**Success Criteria** (what must be TRUE):
  1. User can open a history panel from the menu bar and see a scrollable list of past transcriptions with timestamp, language, mode, and text preview
  2. User can type in a search field and find past transcriptions by text content via full-text search
  3. User can copy the full text of any history entry to the clipboard with one click
**Plans**: TBD
**UI hint**: yes

## Progress

**Execution Order:**
Phases execute in numeric order: 6 -> 7 -> 8 -> 9 -> 10 -> 11

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
| 9. Model Upgrade & Intelligent Cleanup | v1.1 | 0/0 | Not started | - |
| 10. Text Processing Pipeline | v1.1 | 0/0 | Not started | - |
| 11. Transcription History | v1.1 | 0/0 | Not started | - |
