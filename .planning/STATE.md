---
gsd_state_version: 1.0
milestone: v2.4
milestone_name: Public-Release Readiness + Dictionary as Platform
status: Awaiting next milestone
stopped_at: Phase 35 Plan 07 — Phase 35 complete. UAT approved on Developer-ID-signed build. DESIGN.md updated. Conformance report closed.
last_updated: "2026-06-09T17:55:27.211Z"
last_activity: 2026-06-09 — Milestone v2.4 completed and archived
progress:
  total_phases: 22
  completed_phases: 20
  total_plans: 80
  completed_plans: 82
  percent: 91
---

# Project State: Dicticus

**Last Updated:** 2026-06-06 — v2.4 roadmap created (5 phases, 27 requirements)
**Milestone:** v2.4 Public-Release Readiness + Dictionary as Platform
**Previous milestone:** v2.3 Live-Capture Quality Pass — shipped 2026-06-06 (macOS 1.3.0, tag `macos-v1.3.0`)

## Current Position

Phase: v2.4 complete (2026-06-09); next: v2.5 planning
Plan: —
Status: v2.4 complete / v2.5 next
Last activity: 2026-06-09 — Milestone v2.4 completed and archived; doc close-out done

### Next Action

1. Cut `macos-v2.4.0` release (DMG + Sparkle appcast update on gh-pages) and `ios-v2.4.0` (TestFlight / device install)
2. Start v2.5 planning: Phase 36 (iOS Background Dictation, spike-first) + public release + NSStatusItem refactor

v2.4 completed phases:

1. ✅ Phase 31: Dictionary Split + Import/Export + TECHLEX docs (BLOCKER) — DONE
2. ✅ Phase 32: Spoken Punctuation (deterministic pre-LLM pass, cross-platform) — DONE
3. ✅ Phase 33: iOS First-Run & Onboarding Polish — DONE
4. ✅ Phase 34: V19E — R8 Over-Promotion Fix — DONE (2026-06-08)
5. ✅ Phase 35: UI Reorganization — DONE (2026-06-09, UAT approved)

**Residual from Phase 31:** iOS on-device verification of import/export + starter packs (covered by shared-code parity; both targets build) — fold into the next iOS device pass / Phase 33.

## Phase Overview

| Phase | Goal | Requirements | Status |
|-------|------|--------------|--------|
| 31. Dictionary as Platform | Public default split + CSV import/export + docs | DICT-SPLIT-01..04, DICT-IO-01..04, TECHLEX-01..02 | ✅ Complete (2026-06-06) |
| 32. Spoken Punctuation | Deterministic pre-LLM punctuation collapse (Shared/) | PUNCT-01..04 | ✅ Complete (2026-06-07) |
| 33. iOS First-Run & Onboarding | Fix flash glitch, truncation, duplicate; add wizard | IOS-ONB-01..05 | ✅ Complete (2026-06-07) |
| 34. V19E — R8 Over-Promotion Fix | Tighten R8, add content-word gate | V19E-01..03 | ✅ Complete (2026-06-08) |
| 35. UI Reorganization (discuss-first) | Declutter popover, promote dictionary, consolidate hotkeys | UIORG-01..04 | ✅ Complete (2026-06-09) |

## Key Decisions (v2.4)

| Decision | Rationale |
|----------|-----------|
| Phase 31 groups DICT-SPLIT + DICT-IO + TECHLEX | TECHLEX-01 is docs for the CSV workflow that only makes sense after import/export ships; DICT-SPLIT is unacceptable without import as the "empty default" remedy |
| Phase 33 (iOS onboarding) sequenced before Phase 35 (UI reorg) | Onboarding bugs are concrete and decoupled; fixing them doesn't require IA decisions |
| Phase 35 flagged discuss-first | IA questions (popover vs. floating window, iOS navigation pattern) cannot be pre-decided — must be resolved in the phase discussion |
| Q-03 locked: mechanism B for Settings-open (35-02) | `NSApp.activate(ignoringOtherApps: true)` then `openSettings()` — both A and B verified on signed build; B chosen for documented `.accessory` first-click-foreground hardening; C rejected (Stage Manager conflict). ⌘, auto-registers; Settings coexists with dictionary/history WindowGroups. |
| UIORG-02 complete (35-05) | All hotkey config consolidated into HotkeysPane — standard recorders (from HotkeySettingsView) + Fn modifier pickers + Re-register (from SettingsSection) in one Form with two labeled groups. HotkeySettingsView and SettingsSection deleted. |
| SwissGermanFormRow extracted in AiCleanupPane (35-05) | SwissGermanToggleRow uses popover-padded HStack layout; Settings Form needs bare Toggle. Private struct with identical App-Group-scoped UserDefaults backing. |
| V19E (Phase 34) independent | Quality track shares no files with dictionary/UI work; can ship in any window |
| Cross-platform parity applies to Phases 31, 32 | DICT-SPLIT-03, DICT-IO-04, PUNCT-03 explicitly require iOS parity in the same phase |
| SC3 harness not app-faithful (Phase 34) | score_v19e_corpus.py live mode applies Levenshtein-only gate against raw input — not the real app chain (rules-clean + gateContentWords + Levenshtein); measured 38.3% vs 55.6% floor is a measurement artifact; phase gated on test suite (443/435 GREEN) instead; harness rebuild tracked in .planning/backlog/ |

## Accumulated Context

### Architectural constraints

- `DictionaryService.swift` in `Shared/` — any dictionary changes ship macOS + iOS together
- Public build must not define `PERSONAL_LEXICON` flag — local xcconfig only, not in repo
- `PersonalLexicon.json` is gitignored — Moritz's entries preserved locally, not shipped
- `SpokenPunctuationCollapse` step lives in `Shared/Utilities/` (Phase 29 precedent for Shared/ deterministic steps)
- Phase 35 (UI reorg): no pipeline/prompt/model changes — pure IA refactor; must respect DESIGN.md tokens

### Quality baselines to preserve

- V19D 139-record corpus: 90.2% clean rate, 9.3% dictionary-hit baseline
- V19E (Phase 34): 443 macOS + 435 iOS tests GREEN (incl. 5 testGateContentWords_* + V19E prompt tests); SC1 negatives pass (no K3/K4 collapse); dict-hit 37.0% unchanged
- 443 macOS tests passing (Phase 34 wave 3, branch feature/phase-31-dictionary-platform)
- Phase 35 (UI reorg): discuss-first gate; may defer to v2.5

### v2.4 resolved notes

- Phase 35 shipped 2026-06-09 — UI reorg complete, UAT approved
- TECHLEX-02 shipped (3 bundled starter packs in Phase 31; precision bar cleared)

## Session Continuity

Last session: 2026-06-09T00:00:00.000Z
Stopped at: Phase 35 Plan 07 — Phase 35 complete. UAT approved on Developer-ID-signed build. DESIGN.md updated. Conformance report closed.
Next: Cut macos-v2.4.0 release OR begin Phase 36 (iOS Background Dictation, spike-first, v2.5 candidate)

---

**(archived context below — v2.3 closeout)**

v2.3 shipped as macOS 1.3.0 (build 5, 2026-06-06). Phase 30 (PTT media auto-pause): ScriptingBridge pause tier (Music/Spotify) + CoreAudio/AppleScript mute-output fallback verified in signed-app UAT. Hardware-volume DACs documented as unsupported edge case for the mute fallback. Notarized DMG + Sparkle auto-update live.

## Deferred Items (acknowledged and deferred at v2.4 close — 2026-06-09)

Total: **28** — predominantly historical items carried across milestones. None block v2.4 or the public release.

| Category | Item / Slug | Status |
|----------|-------------|--------|
| Debug session | ai-cleanup-quality-regression | partially-resolved (2026-05-09) |
| Debug session | log-analysis-2026-05-26 | unknown |
| Debug session | log-analysis-2026-06-04 | unknown |
| Debug session | recording-interruption-cleanup-quality | completed (2026-05-03) |
| UAT gap | Phase 19 — 19-UAT-CATALOG.md | awaiting_user_signoff |
| UAT gap | Phase 19 — 19-UAT-FINDINGS-postship.md | unknown (historical) |
| UAT gap | Phase 19 — 19-UAT-FINDINGS.md | unknown (historical) |
| UAT gap | Phase 20 — 20-UAT-FINDINGS.md | triaged-pending-20.06-plan (historical) |
| UAT gap | Phase 20.06 — 20.06-04-UAT-RESULTS.md | unknown (historical) |
| UAT gap | Phase 20.08 — 20.08-04-UAT-RESULTS.md | unknown (historical) |
| UAT gap | Phase 20.08 — 20.08-05-UAT-RESULTS.md | pass-with-notes, user-accepted 2026-05-01 |
| UAT gap | Phase 22 — 22-HUMAN-UAT.md | partial (1 open scenario) |
| UAT gap | Phase 27 — 27-HUMAN-UAT.md | partial (5 open scenarios) |
| UAT gap | Phase 30 — 30-02-UAT-RESULTS.md | unknown |
| UAT gap | Phase 30 — 30-03-UAT-RESULTS.md | unknown |
| UAT gap | Phase 31 — 31-HUMAN-UAT.md | passed |
| UAT gap | Phase 32 — 32-HUMAN-UAT.md | passed |
| UAT gap | Phase 33 — 33-HUMAN-UAT.md | resolved |
| UAT gap | Phase 34 — 34-HUMAN-UAT.md | partial (3 open scenarios; SC3 harness non-app-faithful) |
| Verification gap | Phase 17.5 — 17.5-VERIFICATION.md | human_needed (historical) |
| Verification gap | Phase 22 — 22-VERIFICATION.md | human_needed |
| Verification gap | Phase 27 — 27-VERIFICATION.md | human_needed (closed via debug-log evidence) |
| Verification gap | Phase 28 — 28-VERIFICATION.md | human_needed (closed via debug-log evidence) |
| Verification gap | Phase 31 — 31-VERIFICATION.md | human_needed |
| Verification gap | Phase 33 — 33-VERIFICATION.md | human_needed |
| Verification gap | Phase 34 — 34-VERIFICATION.md | human_needed |
| Verification gap | Phase 35 — 35-VERIFICATION.md | human_needed |
| Context question | Phase 35 — 35-CONTEXT.md (Q-01/Q-02/Q-03) | Q-01 (right-click Quit) and Q-03 (Settings scene) resolved in Phase 35; Q-02 (degraded-state placement) still open |

## Operator Notes

- `.planning/` is gitignored — no GSD commits target `.planning/*` files
- Cross-platform parity per `feedback_cleanup_cross_platform_parity` — all Shared/ changes ship macOS + iOS together
- English-first UAT acceptable per `project_usage_pattern_english_dominant`; German regressions validated via corpus
- Installed macOS app: build 5 (macos-v1.3.0), Developer ID signed + notarized

## Operator Next Steps

- Start the next milestone with /gsd-new-milestone
