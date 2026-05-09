# Phase 24 — AI Cleanup Quality v2

**Status:** Blocked on data capture (window: 2026-05-09 → 2026-05-12)
**Branch:** TBD (open after capture window closes)
**Trigger:** Phase 22 UAT 2026-05-09 finding G-01 — AI Cleanup (Gemma 4 E2B) does not reliably drop self-corrected / abandoned phrases mid-sentence, even when the surviving text makes the fragment semantically incoherent.
**Evidence accumulating at:** `~/Library/Application Support/Dicticus/DebugRecordings/cleanup-YYYY-MM-DD.jsonl` (Dicticus-Debug-Recorder build installed at `/Applications/Dicticus.app` 2026-05-09)

## Goal

Improve AI Cleanup quality across three axes that are currently under-served by the existing Gemma 4 E2B prompt:

1. **Self-correction handling** — when the speaker abandons a phrase and restates (e.g. `"...persist now or will is not or will it not?"`), cleanup must drop the abandoned fragment and emit only the corrected form.
2. **Speech disfluency removal** — fillers (`um`, `uh`, `you know`, `eh`, `ähm`, `also`), false starts, stuttered word-restarts.
3. **Structured eval refresh** — capture a richer, real-world JSONL corpus; build a labelled reference set; baseline the current prompt against it; measure prompt-variant deltas instead of relying on anecdotal UAT.

## Why this is one phase, not three

The fixes likely converge on a single class of intervention (prompt few-shots + possibly an upgraded LLM model card swap). Splitting them creates redundant eval scaffolding. Eval infrastructure built here serves as a regression net for any future cleanup-prompt change.

## Trigger evidence (verbatim)

From Phase 22 UAT 2026-05-09, AI Cleanup mode:

| Input (spoken) | AI Cleanup output | Expected output |
|---|---|---|
| `"And what you did will persist now or will is not or will it not?"` | (full verbatim — no cleanup) | `"And what you did will persist now or will it not?"` |

The model treated the input as legitimate phrasing instead of recognizing that `"or will is not"` and `"or will it not"` are mutually exclusive alternatives where the second is the speaker's intended completion.

## Capture window protocol

- 2026-05-09: Dicticus-Debug-Recorder build installed to `/Applications/Dicticus.app` (Developer ID re-signed, `com.dicticus.app`, TeamIdentifier `VTWHBCCP36`). User to dictate normally — both AI Cleanup and Plain Dictation modes — for 3 days.
- 2026-05-12: Capture window closes. Inspect `cleanup-2026-05-09.jsonl`, `cleanup-2026-05-10.jsonl`, `cleanup-2026-05-11.jsonl`, `cleanup-2026-05-12.jsonl`. Catalog observed self-correction patterns + disfluency patterns into a labelled fixture set.
- After 2026-05-12: Restore Release build to `/Applications/Dicticus.app` (the current Debug-Recorder install is sitting at `macOS/build/Build/Products/Release/Dicticus.app`, Developer ID re-signed). Then run `/gsd-plan-phase 24`.

## Out of scope (deferred)

- **Phase 23** (Decimal Words & Digit Grouping) — separate ITN regression class, already deferred from Phase 22.
- **Mixed-language cleanup translation** — known limitation, not in this phase's scope.
- **Custom dictionary v2** — separate backlog item.

## Cross-platform parity

Per memory `feedback_cleanup_cross_platform_parity`: any cleanup-pipeline change ships on macOS AND iOS together. Phase 24 plans must include iOS counterparts.

## References

- Phase 22 UAT: `.planning/phases/22-resolver-regression-hotfix/22-HUMAN-UAT.md` (Gap G-01)
- Auto-memory: `project_ai_cleanup_self_correction_gap.md`
- Auto-memory: `project_cleanup_philosophy.md` ("near-gibberish → sensical German" expectation)
- Auto-memory: `feedback_cleanup_cross_platform_parity.md`
- Auto-memory: `feedback_tests_as_regression_nets.md` (don't write fixtures that just regurgitate hardcoded behavior at itself)
