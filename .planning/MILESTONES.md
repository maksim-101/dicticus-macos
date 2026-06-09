# Milestones: Dicticus

## v2.4 Public-Release Readiness + Dictionary as Platform — SHIPPED 2026-06-09

**Phases:** 5 (31-35) | **Plans:** 18 | **Branch:** `feature/phase-31-dictionary-platform` | **Status:** code-complete, locally validated on a Developer-ID-signed build (public DMG/notarize + iOS device install pending)

Made the custom dictionary a user-owned platform, added deterministic spoken punctuation, polished iOS onboarding, fixed an AI-cleanup over-promotion regression, and reorganized the macOS + iOS UI into a clean tabbed information architecture.

**Key accomplishments:**

1. **Dictionary as Platform (Phase 31)** — public build ships a curated minimal default; developer-personal entries gated behind `PERSONAL_LEXICON` (zero bytes in Release); CSV/JSON import-export + offline starter packs + TECHLEX docs. Cross-platform (macOS + iOS).
2. **Spoken Punctuation (Phase 32)** — deterministic pre-LLM punctuation collapse in `Shared/` — unambiguous tokens always collapse, conditional tokens (minus/dot/colon) only between identifier-shaped flanks. Cross-platform.
3. **iOS First-Run & Onboarding (Phase 33)** — fixed download-screen truncation + phantom flash + duplicate UI; added a guided post-setup wizard.
4. **V19E — R8 Over-Promotion Fix (Phase 34)** — tightened R8 and added a set-membership content-word gate (`gateContentWords`) catching local word-loss (kink→K3, King Four→K4) invisible to whole-text Levenshtein; full suite GREEN.
5. **UI Reorganization (Phase 35)** — macOS popover decomposed into a fixed-height tabbed shell (Home/Dictionary/History) + 4-pane ⌘, Settings window; iOS promoted to 3 tabs (Dictate/Dictionary/History) with frequency-ordered Settings; dictionary list sorts user entries on top; Stage Manager window-identity fix; popover Quit + header tooltips. 8 signed-build UAT findings fixed and developer-approved.

**Verification:** macOS 453 XCTest (1 pre-existing failure `testBlocksUntilCleaned`); iOS builds clean. UIORG-01..04 verified against codebase evidence; Phase 35 UAT approved on a Developer-ID-signed build (2026-06-09).

**Known deferred items at close:** 28 (4 debug sessions, 15 UAT gaps, 8 verification gaps, 1 context question — overwhelmingly historical, carried across milestones; see STATE.md → Deferred Items).

**Timeline:** 2026-06-06 (v2.4 roadmap) → 2026-06-09
**Archive:** [milestones/v2.4-ROADMAP.md](milestones/v2.4-ROADMAP.md) · [milestones/v2.4-REQUIREMENTS.md](milestones/v2.4-REQUIREMENTS.md)

### Next milestone candidates (v2.5)

- **Phase 36 — iOS Background Dictation Recording** (spike-first)
- Public release: notarized `macos-v2.4.0` DMG + Sparkle appcast; iOS `ios-v2.4.0` device/TestFlight
- True menu-bar right-click→Quit (NSStatusItem refactor, deferred from Phase 35)
- Stage Manager fix: ongoing watch

---

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

## v2.1 AI Cleanup & Swiss-Ification Polish — SHIPPED 2026-05-01

**Phases:** 8 (17, 17.5, 19, 19.5, 19.7, 20, 20.06, 20.08) | **Commits since v2.0:** 166 | **Release tag:** `macos-v1.2.0`

Originally scoped as "Keyboard Extension + iCloud Sync." Pivoted: keyboard extension removed (iOS 26 blocked URL-opening); AI cleanup quality became the dominant work stream. Shipped as a notarized macOS release distributed via Sparkle + GitHub Releases.

**Key accomplishments:**

1. **AI cleanup pipeline** — Gemma 4 E2B upgrade, cross-platform `Shared/Models/CleanupPrompt.swift`, numbers/currencies/dates formatting via `SwissNumberFormatter` (Bridge 1.5), Swiss German orthography (ß→ss, dialect-gate), sampler-chain alignment, variant (g15) prompt with R6 order-lock tests.
2. **macOS distribution** — `macos-v1.2.0` notarized DMG, Sparkle EdDSA-signed auto-update via gh-pages `appcast.xml`, build pipeline hardened (unsigned build → deep-sign → notarize → staple).
3. **Keyboard extension pivot** — Phase 17/17.5 removed; full Darwin IPC architecture preserved in history for future revival if iOS restores URL opening.
4. **Repo hygiene** — `.planning/` untracked + gitignored; full `git filter-repo` history rewrite scrubbed `.planning/` from all 463 prior commits.

**Production UAT verdict (2026-05-01):** macOS Release ACCEPTED. R-G15-01 (currency-digit truncation) closed. Sentence-stitching residue carried as known limitation.
**Timeline:** 10 days (2026-04-22 → 2026-05-01)
**Summary:** [milestones/v2.1-MILESTONE-SUMMARY.md](milestones/v2.1-MILESTONE-SUMMARY.md)

### Carried to next milestone

- **Phase 18 — iCloud Sync (CloudKit)** for Dictionary + History.
- **Phase 19.6 — iOS UX polish** (depends on DESIGN.md).
- **Phase 21 — iOS TestFlight distribution** (see backlog).

### Known limitations (accepted)

- **APP-03** (macOS): Recording indicator works; transcribing/cleaning icon states not reactive (cosmetic, carried from v1.0).
- **Sentence-stitching residue** (Gemma occasionally comma-merges adjacent ASR clauses) — below acceptance bar.
- **30s dictation cutoff** — user-reported, not reliably reproducible (logged to backlog).
