# Requirements: Dicticus v2.5

**Defined:** 2026-06-09
**Core Value:** Press a key, speak, release — accurate text appears at your cursor instantly, fully private, no cloud dependency.

## v2.5 Requirements

### iOS Background Dictation (IOSBG)

- [x] **IOSBG-01**: User can keep a dictation recording running on iOS while switching apps or with the screen locked, with the system recording indicator visible.
- [ ] **IOSBG-02**: A backgrounded dictation reliably finalizes and makes its transcript available (no data loss) when the user returns.
- [ ] **IOSBG-03**: The background-recording design is validated against App Store review rules (clear user-facing purpose, correct AVAudioSession category) via a spike before implementation.

### iOS Distribution (IOSDIST)

- [ ] **IOSDIST-01**: User can install Dicticus from TestFlight (then App Store) on a physical iPhone without building from source.
- [ ] **IOSDIST-02**: On first launch the ~2.7 GB ASR model downloads post-install via Background Assets/ODR with clear size + progress and consent — not bundled in the binary.
- [ ] **IOSDIST-03**: The app passes App Review with an accurate "Data Not Collected" privacy label and specific microphone/background justifications.

### Context-Aware Formatting (CTXFMT)

- [ ] **CTXFMT-01**: AI cleanup adapts tone/formatting to the active macOS app (e.g., code editor vs. chat vs. email).
- [ ] **CTXFMT-02**: Active-app context is detected locally and passed into the on-device LLM prompt — no network.
- [ ] **CTXFMT-03**: User can disable context-aware formatting or override the detected context.

### Voice Edit Commands (VEDIT)

- [ ] **VEDIT-01**: User can issue spoken edit/correction commands (e.g., "scratch that", "new paragraph", "capitalize X") that are applied to dictated text.
- [ ] **VEDIT-02**: Edit commands are recognized deterministically and distinguished from literal dictation, fully locally.

### Windows Feasibility (WIN)

- [ ] **WIN-01**: A written feasibility report scoping a Windows port (ASR, LLM, app shell, global hotkey + text injection, model-sharing) with a recommendation and rough effort estimate. No shipping code.

## Future Requirements

Deferred — acknowledged but not in the v2.5 roadmap.

- Real-time streaming text display during dictation
- File / batch audio-file transcription
- Full Windows port (post-spike, after WIN-01 report)
- Voice edit command expansion beyond the initial command set
- Swiss German ASR module (dialect → Standard German)
- Heavier rewrite mode (second AI cleanup tier, Phi-3 Mini)
- Prompt customization for cleanup behavior
- Model integrity check (SHA256 for GGUF downloads)

## Out of Scope

Explicitly excluded. Documented to prevent scope creep.

| Feature | Reason |
|---------|--------|
| Cloud sync / cloud LLM | Breaks the strictly-local core value — hard architectural constraint |
| Speaker diarization | Not a dictation need; single-user tool |
| iOS custom keyboard (text-at-cursor without paste) | iOS blocks microphone access in keyboard extensions; removed in v2.4 milestone after all URL-opening workarounds failed on iOS 26 |

## Traceability

Which phases cover which requirements.

| Requirement | Phase | Status |
|-------------|-------|--------|
| IOSBG-01 | Phase 36 | Complete |
| IOSBG-02 | Phase 36 | Pending |
| IOSBG-03 | Phase 36 | Pending |
| IOSDIST-01 | Phase 37 | Pending |
| IOSDIST-02 | Phase 37 | Pending |
| IOSDIST-03 | Phase 37 | Pending |
| CTXFMT-01 | Phase 38 | Pending |
| CTXFMT-02 | Phase 38 | Pending |
| CTXFMT-03 | Phase 38 | Pending |
| VEDIT-01 | Phase 39 | Pending |
| VEDIT-02 | Phase 39 | Pending |
| WIN-01 | Phase 40 | Pending |

**Coverage:**

- v2.5 requirements: 12 total
- Mapped to phases: 12
- Unmapped: 0 — 100% coverage

---
*Requirements defined: 2026-06-09*
*Last updated: 2026-06-09 — traceability populated by roadmapper (Phases 36-40)*
