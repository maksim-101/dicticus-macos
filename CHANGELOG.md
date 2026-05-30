# Changelog

All notable changes to Dicticus (macOS + iOS). This is a high-level history — when things were added, changed, or fixed — consolidated from git history, tags, GitHub releases, and `.planning/` milestone records. Day-to-day fixes are rolled up into their release.

Dicticus is a fully local, on-device dictation app (ASR via FluidAudio/Parakeet TDT v3, AI cleanup via llama.cpp/Gemma) for macOS and iOS. Versioning note: the product milestone line (v1.0 → v2.3) and the macOS release-tag line (`v0.1.0` … `macos-v1.2.0`) evolved separately; both are shown where they apply.

---

## v2.3 — Live-Capture Quality Pass (in progress, since 2026-05-26)

Quality pass driven by analysis of real multi-day dictation logs (the DebugRecorder capture). Focus: stop the dictionary from corrupting text, and sharpen the AI cleanup prompt.

- **Phase 27 (2026-05-27)** — Dictionary hallucination guard (stops fuzzy-matching from mangling correct words), DebugRecorder enrichment, and a batch of brand/jargon dictionary additions.
- **Phase 28 (2026-05-27)** — "V19D" AI-cleanup prompt iteration: better clause handling, contraction handling, de-duplication, and number formatting.
- **Phase 29 (2026-05-29)** — Post-ASR fixes: spelled-out acronyms collapse (`N F S K` → `NFSK`), spoken letter names resolve inside acronyms (zed/zee → Z, etc.), and the Zed IDE (misheard as "set") is recovered via a period-anchored dictionary entry. Cross-platform (macOS + iOS).
- **Phase 30 (planned)** — Pause media playback while push-to-talk is held (macOS).
- **Fix** — ASR model download now retries on a transient network drop instead of failing the whole download (the ~2.7 GB Parakeet download from HuggingFace would abort on a single "connection reset"). macOS + iOS.

_Not yet cut as a released build._

---

## v2.2 — Adaptive Cleanup & Stability — shipped 2026-05-03 → 2026-05-22

Stability and correctness work on the cleanup pipeline, plus number/ITN handling.

- **Adaptive cleanup & stability (2026-05-03)** — Debounce fix, surgical completion, 6-token repair window.
- **Resolver regression hotfix (2026-05-08)** — Fixed self-correction regex (comma-prefix + word boundaries); locked behavior with cross-platform fixtures.
- **Pipeline quality hardening (2026-05-22)** — Inverse text normalization for spoken decimal markers (`Punkt`/`Komma`/`point`) and fixes for comma-separated digit words.

---

## v2.1 — AI Cleanup & Swiss-Ification Polish — shipped 2026-05-01  ·  tag `macos-v1.2.0`

Originally scoped as "keyboard extension + iCloud sync," but pivoted: the iOS keyboard extension was removed (iOS 26 blocked the URL-opening trick it relied on), and AI cleanup quality became the main work. Shipped as a notarized macOS release with auto-update.

- **AI cleanup overhaul** — Upgraded to Gemma 4 E2B; numbers/currencies/dates formatting; Swiss German orthography (ß→ss, dialect-aware); refined cleanup prompt with order-locking tests.
- **macOS distribution hardened** — Notarized DMG, Sparkle EdDSA-signed auto-update feed, full build→sign→notarize→staple pipeline.
- **Keyboard extension pivot** — Removed from shipping app; architecture preserved in history for possible future revival.
- **Repo hygiene** — Planning artifacts moved out of version control.

_Known limitations carried forward: non-reactive transcribing/cleaning menu-bar icon (cosmetic); occasional sentence-stitching by the LLM._

---

## v2.0 — iOS App (Shortcut Dictation) — shipped 2026-04-22

Dicticus became multi-platform with a native iOS app for iPhone and iPad.

- **Shared core pipeline** — Transcription/cleanup logic unified into a cross-platform `Shared/` module used by both macOS and iOS.
- **On-device iOS dictation** — FluidAudio on iOS with ~2.7 GB model provisioning and background warmup.
- **System integration** — "Start Dictation" Siri Shortcut / Action Button support and a Live Activity for real-time feedback.
- **Universal layout** — Adaptive SwiftUI UI (iPhone + iPad sidebar).
- **Local persistence** — History and dictionary stored via GRDB with full-text search.

---

## v1.1 — Cleanup Intelligence & Distribution — shipped 2026-04-20/21  ·  tags `v1.1.0`, `v1.1.1`

- **Smarter AI cleanup** — Upgraded the LLM to Gemma 4 E2B; redesigned prompt infers meaning from broken/non-native German rather than just fixing grammar.
- **Inverse text normalization** — Spelled-out numbers become digits, English and German ("one hundred twenty three" / "einhundertdreiundzwanzig" → "123").
- **Custom dictionary** — User-configurable find-and-replace for recurring ASR errors, pre-seeded with 35+ common fixes (pipeline: ASR → Dictionary → ITN → AI cleanup).
- **Transcription history** — Searchable full-text history of past dictations (GRDB + FTS5) with one-click copy.
- **Distribution** — Developer ID signed + Apple notarized (no Gatekeeper override); Sparkle auto-updates via EdDSA-signed appcast.
- **v1.1.1 patch (2026-04-21)** — Fixed default dictionary entries not populating on Sparkle updates (only fresh installs).

---

## v1.0 — MVP — shipped 2026-04-18  ·  tags `v1.0`, `v0.1.0`

First working release: a fully local macOS menu-bar dictation app.

- **System-wide push-to-talk** — Hold a hotkey, speak, release; text appears at the cursor in any app.
- **On-device ASR** — FluidAudio + Parakeet TDT v3 (German ~5% WER, English ~6% WER), ~200× realtime on the Apple Neural Engine.
- **Local AI cleanup** — Gemma (via llama.cpp) for grammar/punctuation; no cloud dependency.
- **Modifier-only hotkeys** — Fn+Shift / Fn+Control via a global event monitor.
- **Lightweight** — ~170 MB memory footprint.
- **DMG distribution** with a permissions onboarding flow.

---

_For deeper detail on any release, see the per-milestone records under `.planning/milestones/` and the phase summaries in `.planning/phases/` (local only — not tracked in git). GitHub Releases: https://github.com/maksim-101/dicticus-macos/releases_
