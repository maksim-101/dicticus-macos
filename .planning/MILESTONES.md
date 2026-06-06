# Milestones: Dicticus

## v2.3 Live-Capture Quality Pass (Shipped: 2026-06-06)

**Phases completed:** 4 phases (27–30), 12 plans
**Shipped as:** macOS `1.3.0` (build 5), tag `macos-v1.3.0` — first functional release since 1.2.0, so it delivers v2.2 + v2.3 together to existing users.

**Key accomplishments:**

- **Dictionary hallucination guard (Phase 27)** — two-tier fuzzy guard (allowlist veto + ratio cap) stops valid English/German words being corrupted into brand names (the `remind→Gemini` / `applies→AppLite` class); cleanup recorder enriched with per-replacement `{key,from,to}` attribution; K7 brand misses added.
- **V19D cleanup prompt (Phase 28)** — preserves substantive clauses and contractions, generalizes stutter dedup beyond `the the`, settles a principled standalone-number policy, and drops the biased static topic-words line.
- **Post-ASR deterministic fixes (Phase 29)** — acronym collapse (`N F S K`→`NFSK`), spoken-letter lexicon (`zed`/`zee`→`Z`), and Zed-editor recognition (`the set.`→`Zed.`); shipped cross-platform (macOS + iOS).
- **PTT media auto-pause, macOS (Phase 30)** — ScriptingBridge pause/resume of Apple Music & Spotify while dictating, plus a CoreAudio/AppleScript mute-output fallback for non-scriptable audio (browser/YouTube); signed-app UAT verified both tiers.
- **Reliability** — ASR model download now retries on transient network drops (macOS + iOS).
- **Shipped** — notarized DMG + Sparkle auto-update; milestone audit passed (15/15 requirements, 0 blockers).

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
