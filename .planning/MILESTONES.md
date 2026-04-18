# Milestones: Dicticus

## v1.0 MVP — SHIPPED 2026-04-18

**Phases:** 6 (1, 2, 2.1, 3, 4, 5) | **Plans:** 17 | **Commits:** 155 | **Swift LOC:** 3,084

Fully local macOS dictation app with push-to-talk hotkeys, on-device ASR (Parakeet TDT v3 via FluidAudio), AI cleanup (Gemma 3 1B via llama.cpp), and DMG distribution.

**Key accomplishments:**
1. System-wide push-to-talk dictation — hold hotkey, speak, release, text at cursor in any app
2. On-device ASR via FluidAudio + Parakeet TDT v3 — German 5% WER, English 6% WER, ~200x realtime on ANE
3. Local AI cleanup via Gemma 3 1B + llama.cpp — grammar/punctuation correction, no cloud dependency
4. Modifier-only hotkeys (Fn+Shift, Fn+Control) via NSEvent global monitor
5. 170 MB memory footprint — well under 3 GB budget
6. DMG distribution with permissions onboarding

**Requirements:** 18/19 satisfied, 1 partial (APP-03 cosmetic icon state)
**Timeline:** 4 days (2026-04-14 to 2026-04-18)
**Archive:** [milestones/v1.0-ROADMAP.md](milestones/v1.0-ROADMAP.md) | [milestones/v1.0-REQUIREMENTS.md](milestones/v1.0-REQUIREMENTS.md) | [milestones/v1.0-MILESTONE-AUDIT.md](milestones/v1.0-MILESTONE-AUDIT.md)

### Known Gaps
- **APP-03** (partial): Recording indicator (red mic.fill) works; transcribing/cleaning icon states not reactive (@State vs @StateObject)
- 13 non-critical tech debt items (see audit)
