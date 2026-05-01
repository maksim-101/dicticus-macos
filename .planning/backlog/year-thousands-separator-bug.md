---
title: 4-digit years incorrectly get Swiss thousands separator applied
captured: 2026-04-29
source: user-feedback (Phase 20.08 variant-g rationale session)
status: backlog
severity: medium (cosmetic, but visible on every dated dictation)
---

# 4-digit years rendered as "2'026" instead of "2026"

## Finding

User dictation: "… einen Termin für das Jahr 2026 hat."

Pipeline output: "… einen Termin für das Jahr **2'026** hat."

The Swiss thousands separator is being applied to a 4-digit year, which
is wrong by Swiss orthography conventions: years are written without a
thousands separator (`1999`, `2026`, `2050` — never `1'999`, `2'026`).

## Why it happens

The deterministic Swift pipeline applies a thousands-separator-folding
rule that treats *any* 4-digit-or-longer integer as a number that needs
the Swiss apostrophe separator. Likely in:

- `Shared/Utilities/ITNUtility.swift` — number-folding helpers
- `Shared/Utilities/SwissNumberFormatter.swift` — Swiss-locale folding
  added in Phase 20.06

Years (typical range 1900–2099, plus relevant historical years like
1492, 1789, etc.) should be exempt from thousands-separator folding.

This is **NOT a prompt bug.** Variant (e) RULE 2 says "thousands as
1'250 not 1.250" — that rule is correct in isolation. The bug is in
the deterministic Swift code applying the rule too broadly.

## Proposed fix (for future planning)

Two non-exclusive approaches:

1. **Heuristic year exemption.** When folding a 4-digit integer, skip
   the apostrophe if the integer falls in `1000 ≤ n ≤ 2999` (years).
   Simple, covers 99% of cases. Risk: a true 4-digit count in the
   year range loses formatting (e.g. "ich habe 2024 Schritte gemacht"
   would render `2024` not `2'024`).
2. **Context-aware exemption.** Skip apostrophe when the integer is
   adjacent to a year-context word ("Jahr", "Year", "im", "ab",
   "seit", "bis", "von") within ±2 tokens. More precise; more fragile.

Recommended starting point: option 1 (range heuristic). The collateral
damage on actual 4-digit step-counts is rare and far less visible than
the year-rendering bug, which fires on any dictation that mentions a
year.

## Test cases

- "im Jahr 2026" → "im Jahr 2026" (NOT "2'026")
- "im Jahre 1789" → "im Jahre 1789"
- "von 1999 bis 2024" → "von 1999 bis 2024"
- "ich habe 2'500 Schritte gemacht" → "ich habe 2'500 Schritte gemacht"
  (still folds — outside year range)
- "das kostet 1'250 Franken" → "das kostet 1'250 Franken" (Phase 20.06
  behaviour preserved)
- Edge: "Jahr 2050" — top of typical year range, must still skip fold
- Edge: "Jahr 12345" — 5-digit, never a year, must fold

## Where this fits

Phase 20.06 family — same bucket as the currency-direction fix and the
currency spell-out conversion item. Sibling backlog item:
`.planning/backlog/currency-spell-out-conversion.md`.

A future ITN-polish phase should bundle these:
- Year-exemption (this item)
- Currency spell-out conversion
- Possibly: percent / time-of-day / phone-number renderings

Cross-platform: must ship macOS + iOS together (per
`feedback_cleanup_cross_platform_parity.md`).

Defer until variant (g) ships and stabilises.
