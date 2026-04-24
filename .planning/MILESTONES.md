# Milestones: Dicticus

## v1.0 MVP — SHIPPED 2026-04-18

**Phases:** 6 (1-5, 2.1) | **Plans:** 17 | **Commits:** 155 | **Swift LOC:** 3,084

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

---

## v2.0 iOS App — Shortcut Dictation — SHIPPED 2026-04-22

**Phases:** 5 (12-16) | **Plans:** 18 | **Commits:** ~120 | **Target:** iOS 17.0+ (iPhone/iPad)

Transformed Dicticus into a multi-platform solution by introducing a native iOS application. v2.0 focuses on bringing high-accuracy, on-device transcription to iPhone and iPad with deep system integration via Siri Shortcuts and Action Button support.

**Key accomplishments:**
1. **Shared Core Pipeline:** Unified transcription logic into a cross-platform `Shared/` module.
2. **High-Accuracy iOS Dictation:** FluidAudio iOS integration with ~2.7GB model provisioning and background warmup.
3. **System Integration:** `Start Dictation` shortcut for Siri/Action Button and Live Activity for real-time feedback.
4. **Universal Layout:** Native SwiftUI app with adaptive layouts for iPhone and iPad (sidebar).
5. **Local Persistence:** GRDB-backed history and dictionary with FTS5 search.

**Requirements:** 22/22 satisfied (100%)
**Timeline:** 4 days (2026-04-19 to 2026-04-22)
**Summary:** [milestones/v2.0-MILESTONE-SUMMARY.md](milestones/v2.0-MILESTONE-SUMMARY.md)

---

## v2.1 Keyboard Extension & Polish — IN PROGRESS

**Goal:** Close the experience gap between macOS and iOS by adding direct text injection via a custom keyboard extension and enabling cross-device sync.

**Phases:** 17+ (17: Keyboard Extension, 18: iCloud Sync, 19: AI Cleanup)

### Completed Phases

#### Phase 17/17.5: Keyboard Extension — REMOVED (2026-04-24)
- **Scope:** Custom QWERTZ keyboard with integrated dictation button, Darwin IPC between keyboard extension and main app.
- **What was built:** Full IPC architecture (DicticusIPCBridge, DicticusHostBridge, DicticusKeyboardIPCManager, DicticusKeyboardDictationController), warm/cold start detection, heartbeat mechanism, grace periods, state machine, smart text insertion.
- **Why removed:** iOS 26 blocks all known URL-opening techniques from keyboard extensions. Five approaches tried (responder chain legacy/modern selectors, UIApplication cast, SwiftUI openURL environment, extensionContext.open) — all failed. Without URL opening, the keyboard extension cannot bring the main app to the foreground for audio recording.
- **Preserved:** Shortcut-only dictation path (Phase 16) remains fully functional. IPC architecture documented in `.planning/phases/17.5-inline-shortcut-dictation/` for future reference if iOS restores URL opening for keyboard extensions.
- **Reference:** [17.5-KEYVOX-IPC-ANALYSIS.md](phases/17.5-inline-shortcut-dictation/17.5-KEYVOX-IPC-ANALYSIS.md)

### Known Gaps
- **APP-03** (macOS): Recording indicator (red mic.fill) works; transcribing/cleaning icon states not reactive.
- **iCloud Sync**: Dictionary and History are currently local to each device.
- **AI Cleanup (iOS)**: Numbers, currencies, dates need intelligent formatting. Swiss German rules (ß→ss) not yet applied.
