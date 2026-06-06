---
gsd_state_version: 1.0
milestone: v2.4
milestone_name: Public-Release Readiness + Dictionary as Platform
status: executing
stopped_at: Phase 31 context gathered
last_updated: "2026-06-06T14:46:42.885Z"
last_activity: 2026-06-06
progress:
  total_phases: 21
  completed_phases: 15
  total_plans: 65
  completed_plans: 65
  percent: 71
---

# Project State: Dicticus

**Last Updated:** 2026-06-06 — v2.4 roadmap created (5 phases, 27 requirements)
**Milestone:** v2.4 Public-Release Readiness + Dictionary as Platform
**Previous milestone:** v2.3 Live-Capture Quality Pass — shipped 2026-06-06 (macOS 1.3.0, tag `macos-v1.3.0`)

## Current Position

Phase: 31 (dictionary-as-platform) — EXECUTING
Plan: 3 of 3
Status: Ready to execute
Last activity: 2026-06-06

Progress: [██████████] 100%

### Next Action

**`/gsd-plan-phase 31`** — Dictionary as Platform (public-release BLOCKER). Sequence:

1. Phase 31: Dictionary Split + Import/Export + TECHLEX docs (BLOCKER — ship before any public release)
2. Phase 32: Spoken Punctuation (deterministic pre-LLM pass, cross-platform)
3. Phase 33: iOS First-Run & Onboarding Polish (decoupled — can interleave with 32)
4. Phase 34: V19E — R8 Over-Promotion Fix (independent quality track)
5. Phase 35: UI Reorganization (discuss-first; may defer to v2.5)

## Phase Overview

| Phase | Goal | Requirements | Status |
|-------|------|--------------|--------|
| 31. Dictionary as Platform | Public default split + CSV import/export + docs | DICT-SPLIT-01..04, DICT-IO-01..04, TECHLEX-01..02 | Not started |
| 32. Spoken Punctuation | Deterministic pre-LLM punctuation collapse (Shared/) | PUNCT-01..04 | Not started |
| 33. iOS First-Run & Onboarding | Fix flash glitch, truncation, duplicate; add wizard | IOS-ONB-01..05 | Not started |
| 34. V19E — R8 Over-Promotion Fix | Tighten R8, add content-word gate | V19E-01..03 | Not started |
| 35. UI Reorganization (discuss-first) | Declutter popover, promote dictionary, consolidate hotkeys | UIORG-01..04 | Not started |

## Key Decisions (v2.4)

| Decision | Rationale |
|----------|-----------|
| Phase 31 groups DICT-SPLIT + DICT-IO + TECHLEX | TECHLEX-01 is docs for the CSV workflow that only makes sense after import/export ships; DICT-SPLIT is unacceptable without import as the "empty default" remedy |
| Phase 33 (iOS onboarding) sequenced before Phase 35 (UI reorg) | Onboarding bugs are concrete and decoupled; fixing them doesn't require IA decisions |
| Phase 35 flagged discuss-first | IA questions (popover vs. floating window, iOS navigation pattern) cannot be pre-decided — must be resolved in the phase discussion |
| V19E (Phase 34) independent | Quality track shares no files with dictionary/UI work; can ship in any window |
| Cross-platform parity applies to Phases 31, 32 | DICT-SPLIT-03, DICT-IO-04, PUNCT-03 explicitly require iOS parity in the same phase |

## Accumulated Context

### Architectural constraints

- `DictionaryService.swift` in `Shared/` — any dictionary changes ship macOS + iOS together
- Public build must not define `PERSONAL_LEXICON` flag — local xcconfig only, not in repo
- `PersonalLexicon.json` is gitignored — Moritz's entries preserved locally, not shipped
- `SpokenPunctuationCollapse` step lives in `Shared/Utilities/` (Phase 29 precedent for Shared/ deterministic steps)
- Phase 35 (UI reorg): no pipeline/prompt/model changes — pure IA refactor; must respect DESIGN.md tokens

### Quality baselines to preserve

- V19D 139-record corpus: 90.2% clean rate, 9.3% dictionary-hit baseline
- 282 macOS tests passing (build 5, tag `macos-v1.3.0`)
- Phase 34 (V19E) must validate against the V19D corpus

### Known sequencing risk

- Phase 35 may slip to v2.5 without blocking public release — Phases 31-34 are sufficient for public-release readiness
- TECHLEX-02 is evidence-gated (optional) — only ship the small tech-mishearing default lexicon if entries clear a precision bar

## Session Continuity

Last session: 2026-06-06T14:46:42.878Z
Stopped at: Phase 31 context gathered
Next: `/gsd-plan-phase 31`

---

**(archived context below — v2.3 closeout)**

v2.3 shipped as macOS 1.3.0 (build 5, 2026-06-06). Phase 30 (PTT media auto-pause): ScriptingBridge pause tier (Music/Spotify) + CoreAudio/AppleScript mute-output fallback verified in signed-app UAT. Hardware-volume DACs documented as unsupported edge case for the mute fallback. Notarized DMG + Sparkle auto-update live.

## Deferred Items (carried from v2.3)

| Category | Count | Notes |
|----------|-------|-------|
| UAT gaps | 11 | `human_verification` items in phase VERIFICATIONs — mostly closed via live-capture/debug-log evidence |
| Verification gaps | 4 | Phases 27 & 28 verified `human_needed`, closed via debug-log evidence |
| Phase 35 (UI reorg) | 1 | May slip to v2.5 — discuss-first gate applies |

## Operator Notes

- `.planning/` is gitignored — no GSD commits target `.planning/*` files
- Cross-platform parity per `feedback_cleanup_cross_platform_parity` — all Shared/ changes ship macOS + iOS together
- English-first UAT acceptable per `project_usage_pattern_english_dominant`; German regressions validated via corpus
- Installed macOS app: build 5 (macos-v1.3.0), Developer ID signed + notarized
