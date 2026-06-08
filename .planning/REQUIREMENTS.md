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

- [x] **MEDIA-PAUSE-01**: While push-to-talk is held, a currently-**playing scriptable player** (Apple Music, Spotify) is paused via ScriptingBridge/Apple events and **resumes the same app** on release — true position-preserving pause; only resume what we paused (never start media that wasn't playing); gated by the default-ON "Pause media while dictating" toggle. macOS only. (Spike-003-validated; the MediaRemote now-playing read is entitlement-gated in the signed app and cannot be used.)
- [x] **MEDIA-PAUSE-02**: The media-pause path degrades safely. App carries the `com.apple.security.automation.apple-events` entitlement + `NSAppleEventsUsageDescription`; on Automation-TCC denial (`errAEEventNotPermitted` / -1743), a missing/not-running player, or any AppleScript error, the feature is a **silent no-op** (one warn-level log, never a crash). Running-state is checked via `NSWorkspace` before any `tell application` so a stopped player is never launched.
- [x] **MEDIA-PAUSE-03**: For **non-scriptable** audio sources (browser/YouTube/podcast apps) that ScriptingBridge cannot detect or control, a **mute-output fallback** applies: when no scriptable player was paused on a PTT hold, mute the default system output for the hold and restore on release (restore only if *we* muted — never unmute a user-muted system). Accepts mute ≠ pause (audio keeps advancing silently). Gated by the same toggle.

## v2.4 Requirements

Defined 2026-06-06 for the **Public-Release Readiness + Dictionary as Platform** milestone (Phases 31–35). Authoritative IDs live in `ROADMAP.md` per-phase requirement lists and success criteria; descriptions below are derived from those locked success criteria. 26 requirements across 5 phases. (The ROADMAP milestone header rounds this to "27" — an off-by-one; the enumerated set is 26.)

### Dictionary Split & Provenance (Phase 31, complete)

- [x] **DICT-SPLIT-01**: Release build ships a **truly empty** default dictionary — zero personal entries, zero baked-in universal entries; no personal keys appear as strings in the Release binary or a locally-built DMG
- [x] **DICT-SPLIT-02**: Dev build (local-only `PERSONAL_LEXICON` build flag) loads all ~120 current entries with behavior identical to today — clean-rate baseline preserved, no regression against the V19D 139-record corpus
- [x] **DICT-SPLIT-03**: Entries carry a `source` provenance field (`.default`/`.user`/`.imported`), applied on both macOS and iOS (cross-platform parity)
- [x] **DICT-SPLIT-04**: Leak-free migration — dev builds reseed defaults cleanly; release builds tag unknown persisted entries as `.user` and never delete them (no silent wipe of pre-existing user data)

### Dictionary Import/Export (Phase 31, complete)

- [x] **DICT-IO-01**: User can export their full dictionary to CSV or JSON in one action (macOS: NSSavePanel; iOS: document picker)
- [x] **DICT-IO-02**: User can import a CSV or JSON dictionary with a choice of merge strategy (three strategies); CSV/JSON round-trip is lossless
- [x] **DICT-IO-03**: Malformed rows are rejected with line-number errors (not silently discarded); RFC 4180 CSV handling (UTF-8 BOM stripped, quoted commas/newlines parsed, header skipped)
- [x] **DICT-IO-04**: Import and export are available on macOS **and** iOS (cross-platform parity)

### Tech-Lexicon Recovery (Phase 31, complete)

- [x] **TECHLEX-01**: Onboarding/help copy documents the dictionary + "ask an AI to generate a CSV for your domain" workflow as the canonical tech-mishearing recovery path, on both platforms
- [x] **TECHLEX-02**: User can one-tap import bundled offline starter packs (tech mishearings + brand/product casing + general/mainstream terms) from Settings; imported entries are tagged `source=.imported` and use "existing wins" merge

### Spoken Punctuation (Phase 32, planned)

- [x] **PUNCT-01**: Unambiguous spoken tokens (hyphen, slash, backslash, underscore, asterisk, semicolon, at sign, hash, caret, tilde) always collapse to their symbol in both plain and cleanup modes
- [x] **PUNCT-02**: Conditional spoken tokens (minus, dot, colon, dollar) collapse only between identifier-shaped flanks; `dot` also collapses between numeric flanks ("ten dot five" → "10.5"). (Per decision D-08: `dollar` is conditional, not always-collapse; `pipe` is dropped from the lexicon.)
- [x] **PUNCT-03**: The spoken-punctuation step ships on macOS **and** iOS together (cross-platform parity), and the supported lexicon is discoverable as a static reference list in help/Settings copy on both platforms
- [x] **PUNCT-04**: No prose or arithmetic false positives in a replay of the V19D 139-record corpus — the precision-first gate preserves "five minus three", "the 60 plus rules", and "colon vs. dash"

### iOS First-Run & Onboarding (Phase 33, not started)

- [x] **IOS-ONB-01**: On a device with the model already downloaded, cold-launch shows the home screen directly — no download-screen flash, even briefly
- [x] **IOS-ONB-02**: On first install, the download-screen copy reads clearly with no truncated labels at SE/mini/standard/Pro/Max device widths
- [x] **IOS-ONB-03**: After completing mic permission + model download, a guided onboarding wizard appears automatically
- [x] **IOS-ONB-04**: The onboarding wizard can be re-triggered from Settings at any time
- [x] **IOS-ONB-05**: Settings → Integration shows exactly one Action Button entry — the duplicate item is gone

### V19E — R8 Over-Promotion Fix (Phase 34, not started)

- [x] **V19E-01**: AI cleanup no longer promotes real English words adjacent to number-words into identifier stems — "kink three" stays "kink three", "King Four" stays "King four"; ordinary prose pairings are untouched
- [x] **V19E-02**: A deterministic content-word-preservation gate rejects LLM output that drops a content word (≥4 chars, non-stop-word) present in the post-ITN input, falling back to post-ITN text
- [x] **V19E-03**: The V19D 139-record corpus clean rate does not drop below 90.2% and the 9.3% dictionary-hit baseline is preserved after shipping

### UI Reorganization (Phase 35, discuss-first; may defer to v2.5)

- [ ] **UIORG-01**: Opening the macOS popover, a user can reach dictionary management (add, edit, import, export) without scrolling past unrelated controls
- [ ] **UIORG-02**: All hotkey configuration (standard shortcuts + modifier hotkeys + Fn-key note) is in one consolidated section — no duplicate or scattered config blocks
- [ ] **UIORG-03**: iOS UI is audited against the same IA principles and brought into parity, with review findings documented before any changes are made
- [ ] **UIORG-04**: No existing user-visible behavior regresses — hotkey bindings fire, dictionary contents are preserved, history is accessible, DESIGN.md tokens are respected

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
| ACRONYM-COLLAPSE-01 | Phase 29 | Complete |
| SPOKEN-LETTER-01 | Phase 29 | Complete |
| DICT-ZED-01 | Phase 29 | Complete |
| MEDIA-PAUSE-01 | Phase 30 | Complete |
| MEDIA-PAUSE-02 | Phase 30 | Complete |
| MEDIA-PAUSE-03 | Phase 30 | Complete |
| DICT-SPLIT-01 | Phase 31 | Complete |
| DICT-SPLIT-02 | Phase 31 | Complete |
| DICT-SPLIT-03 | Phase 31 | Complete |
| DICT-SPLIT-04 | Phase 31 | Complete |
| DICT-IO-01 | Phase 31 | Complete |
| DICT-IO-02 | Phase 31 | Complete |
| DICT-IO-03 | Phase 31 | Complete |
| DICT-IO-04 | Phase 31 | Complete |
| TECHLEX-01 | Phase 31 | Complete |
| TECHLEX-02 | Phase 31 | Complete |
| PUNCT-01 | Phase 32 | Planned |
| PUNCT-02 | Phase 32 | Planned |
| PUNCT-03 | Phase 32 | Planned |
| PUNCT-04 | Phase 32 | Planned |
| IOS-ONB-01 | Phase 33 | Complete |
| IOS-ONB-02 | Phase 33 | Complete |
| IOS-ONB-03 | Phase 33 | Complete |
| IOS-ONB-04 | Phase 33 | Complete |
| IOS-ONB-05 | Phase 33 | Complete |
| V19E-01 | Phase 34 | Complete |
| V19E-02 | Phase 34 | Complete |
| V19E-03 | Phase 34 | Complete |
| UIORG-01 | Phase 35 | Pending |
| UIORG-02 | Phase 35 | Pending |
| UIORG-03 | Phase 35 | Pending |
| UIORG-04 | Phase 35 | Pending |

**Coverage:**
- v2.0 requirements: 22 total
- v2.1 requirements (started): 4 total
- v2.3 requirements: 13 total (9 complete + 4 added 2026-05-29 across Phases 29-30)
- v2.4 requirements: 26 total (10 complete Phase 31 + 16 planned/pending Phases 32–35)
- Mapped to phases: 65
- Unmapped: 0

---
*Requirements defined: 2026-04-21*
*Last updated: 2026-06-06 — v2.4 Public-Release Readiness + Dictionary as Platform requirements added (26 reqs across Phases 31–35)*
