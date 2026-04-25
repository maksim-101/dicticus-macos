---
phase: 19
slug: ai-cleanup-ios
type: uat-findings-postship
created: 2026-04-25
source: physical-device UAT 2026-04-25 (post-Phase-19.7 ship — Dicticus running with PTT fix `bd17a86`)
feeds_into: [19.5]
parent: 19-UAT-FINDINGS.md
---

# Phase 19 — Post-Ship UAT Findings (round 2)

Second round of UAT findings, captured AFTER Phase 19.7 (macOS Hygiene) shipped and after the push-to-talk modifier-flag-drop fix (`bd17a86`) landed. Recording is stable; user can now actually exercise AI cleanup on macOS for sustained dictations and surface output-quality issues that round-1 UAT couldn't reach because of the PTT regression.

These findings are scoped to **Phase 19.5 (CH-Determinism)**. They strengthen the case to **widen 19.5's scope from iOS-only to cross-platform** — the same Swiss-German rules need to apply on macOS.

---

## Bugs

| ID | Issue | Owner Phase | Notes |
|----|-------|-------------|-------|
| **B5** | AI cleanup transcribes **"Swiss francs" / "Schweizer Franken" → "Euro"** in the cleaned output (currency LABEL replaced, not just format) | **19.5** | Distinct from B3 — B3 was "15 Franken 50 stays literal" (no formatting). B5 is "the model rewrites the currency name." Likely cause: Gemma's training distribution leans EUR for German number+currency contexts; without an explicit Helvetism/CHF anchor in the prompt the model "corrects" CHF to EUR. **Fix candidates:** (a) deterministic currency-detection pass BEFORE the LLM that pins `currency=CHF` and adds `STRICT: keep currency code as 'CHF' / 'Franken' — do not translate to EUR` to the prompt; (b) post-LLM diff check that re-substitutes the original currency token if the model flipped it. Combine with the Swiss-German Helvetism word list (S5) so the LLM has positive evidence. |
| **B6** | Decimal separator inconsistency: **EUR shows `6,70 Euro`** (German comma), **CHF shows `5.70 Franken`** (Swiss point). Should always be `.` for both | **19.5** | This is not just a Swiss-only rule — user wants the **Apple `Locale("de_CH")` + `NumberFormatter`** treatment to apply universally when Swiss German toggle is ON, regardless of currency. Currently the LLM (or some pre-formatter) seems to apply German rules for EUR and Swiss rules for CHF, splitting on currency rather than locale. **Fix:** route ALL number formatting through the post-LLM safety-net `NumberFormatter` configured with `Locale("de_CH")` + the right `currencyCode`, so both `EUR 6.70` and `CHF 5.70` come out with the Swiss decimal point and Swiss thousands apostrophe — in line with B4. The toggle is the trigger; the currency is just metadata. |

## Cross-Platform Decisions (locked during this UAT round)

| ID | Decision | Owner | Rationale |
|----|----------|-------|-----------|
| **S7** | **Phase 19.5 widens scope from iOS-only to cross-platform.** All deterministic CH rules (currency formatter, apostrophe thousands separator, decimal point, Swiss German default ON, Helvetism prompt block) must land on **both iOS AND macOS** in the same phase. | 19.5 | UAT showed B5 + B6 reproduce on macOS just like iOS. Splitting the work would create a window where the platforms diverge on Swiss output. Since the post-LLM formatter and the prompt block live in `Shared/` (per CLAUDE.md "Shared Code" section), one implementation covers both. Scope creep is small (~30 LOC of platform-glue + per-platform Settings UI to expose the toggle). |
| **S8** | **Always-Swiss-decimal-point when Swiss toggle is ON, regardless of currency.** EUR and CHF both render with `.` decimal separator and `'` thousands separator. | 19.5 | Per user UAT: "should always be a point." This means the formatting locale follows the user's *toggle setting*, not the *detected currency*. Implementation: `NumberFormatter` initialized once from `Locale("de_CH")` and reused for any currency; only the `currencyCode` field changes per amount. |

## What this changes for Phase 19.5 plan

The original 19.5 brief (per `19-UAT-FINDINGS.md` row B3/B4 + S1/S4) targeted iOS only and addressed:
- B3: "15 Franken 50" → CHF formatting (deterministic Swiss currency formatter)
- B4: thousands separator `1.250` → `1'250`
- S4: Apple `Locale("de_CH")` + `NumberFormatter` as the formatter
- S5: ~30-item Helvetism word list in prompt

This round adds:
- **B5**: anti-currency-flipping (LLM is rewriting CHF→EUR even when format is OK)
- **B6**: enforce decimal point regardless of currency, not just for CHF
- **S7**: cross-platform delivery (iOS + macOS in the same phase)
- **S8**: toggle-driven locale, currency-agnostic

Net effect: 19.5 is no longer a polish phase — it's the **canonical Swiss output pass** for both platforms, replacing whatever ad-hoc behavior currently exists in the macOS pipeline.

## Out of scope (still)

- B2 Parakeet ASR re-download prompt — already routed to 19.5 as integrated hotfix per `19-UAT-FINDINGS.md`. No change.
- Phase 18 iCloud Sync — still deferred.
- Recording-stops-mid-hold — RESOLVED by `bd17a86`. See `.planning/debug/resolved/ptt-stops-mid-hold.md`.

## How this gets consumed

`/gsd-discuss-phase 19.5` should read BOTH:
1. `19-UAT-FINDINGS.md` (round 1 — B3, B4, S1, S4, S5, S6)
2. `19-UAT-FINDINGS-postship.md` (this file — B5, B6, S7, S8)

…then produce a 19.5 plan with cross-platform deliverables.
