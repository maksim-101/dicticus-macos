---
title: Currency spell-out → numeric conversion
captured: 2026-04-28
updated: 2026-04-30
source: user-feedback (Phase 20.08 spike checkpoint, variant E review)
status: partially-shipped
---

## 2026-04-30 update — Bridge 1.5 covers the common case

Phase 20.08 spike (variant g15) shipped a partial fix:
`SwissNumberFormatter` now has a **Bridge 1.5** word-cardinal cents prep
that digitizes 1–9 (`eins`, `ein`, `zwei`, `drei`, `vier`, `fünf`,
`sechs`, `sieben`, `acht`, `neun`) **only** when followed by
currency + 2-digit cents. Combined with ITN's existing ≥10 digitization
and `SwissNumberFormatter` Bridge 2 cents-fold, the pipeline now handles:

- `"vier Franken fünfzig"` → ITN(fünfzig→50) → Bridge 1.5(vier→4) →
  Bridge 2 → `"4.50 Franken"` ✓
- `"ungefähr vier Franken fünfzig"` → leading qualifier preserved ✓
- `"fünfzehn Franken fünfzig"` → ITN handles both (≥10) → Bridge 2 →
  `"15.50 Franken"` ✓ (already worked pre-20.08)

Bridge 1.5 is a hardcoded 9-word lookup. Tests/fixtures for it were
explicitly **skipped** per discussion 2026-04-30 — fixtures would just
regurgitate the lookup table at itself, locking in current behavior
without extending coverage. If the lookup grows or the rule evolves,
revisit fixture coverage at that point.

## Still-open gaps

- `"achtzig Rappen"` — sub-unit-only amount (no integer Franken). Rappen
  not in Bridge 1.5/2 currency regex; no fold pattern for sub-units alone.
- `"ein Franken"` / `"eine Mark"` — singular without cents stays as word
  ("ein"). Bridge 1.5 requires `\d{2}` cents to follow.
- `"vier Komma fünfzig Franken"` — explicit decimal phrasing not handled.
- `"vier fünfzig Franken"` — colloquial elision (no "Komma", no "Franken
  fünfzig" structure).
- English locale (USD, EUR, GBP) — separate locale path.
- Mixed currencies in one utterance — likely rare, defer.

If real users surface any of these, escalate to a follow-on phase
targeting `Shared/Utilities/ITNUtility.swift` and/or
`Shared/Utilities/SwissNumberFormatter.swift`. Cross-platform: must
ship macOS + iOS together (per `feedback_cleanup_cross_platform_parity`).

---

## Original entry (2026-04-28, pre-20.08)


# Currency spell-out conversion in dictation output

## Finding

When the user dictates an amount in spelled-out form (e.g. "vier Franken
fünfzig"), the pipeline keeps the words verbatim:

> "Das hat mich dann ungefähr vier Franken fünfzig gekostet."

Expected: numeric form with Swiss conventions, e.g.
`"… ungefähr 4.50 Franken …"` or `"… ungefähr CHF 4.50 …"`.

Surfaced during Phase 20.08 prompt-spike checkpoint — variant (e) preserves
the spelled-out tokens correctly per its identity-preservation contract,
which is the right behaviour for that prompt. Numeric conversion is a
*deterministic ITN* concern, not an LLM-cleanup concern.

## Why it happens

Phase 20.08 ships variant (e) — "Output Standard High German exactly as
dictated, only adapt orthography (ß→ss, thousands separator)". By design
the prompt does NOT paraphrase or substitute words, so spelled-out
currency stays as words.

The deterministic post-ASR pipeline (`Shared/Utilities/ITNUtility.swift`)
handles spelled-out *plain numbers* and Swiss letter substitutions but
has no currency-amount collapse — neither for the cardinal+unit pattern
("vier Franken") nor for the cardinal+unit+decimal pattern ("vier Franken
fünfzig").

## Proposed fix (for future planning)

Add a currency-collapse pass to `applyITN` (or a sibling utility) BEFORE
the LLM cleanup runs:

- Detect cardinal-number-word + (Franken|Rappen|Euro|Cent|CHF|EUR|…)
- Optionally followed by a second cardinal-number-word for the decimal
  part (German "fünfzig" → 50, treated as cents/Rappen)
- Emit Swiss-localised numeric form: `4.50 Franken` (period as decimal,
  matches Swiss orthography from 20.06)
- Single-amount form: "vier Franken" → `4 Franken`
- Decimal form: "vier Franken fünfzig" → `4.50 Franken`

Edge cases to test:

- "ungefähr vier Franken fünfzig" — leading qualifier preserved
- "achtzig Rappen" — sub-unit-only amount (no integer Franken)
- "ein Franken" / "eine Mark" — singular forms
- "vier Komma fünfzig Franken" — explicit decimal phrasing
- "vier fünfzig Franken" — colloquial elision (no "Komma", no "Franken
  fünfzig" structure)
- Mixed currencies in one utterance — likely rare, defer
- English dictation — separate locale path (USD, EUR, GBP)

## Where this fits

Phase 20.06 (`llm-swiss-ification-currency-flip`) was the corrective
hotfix for Swiss thousands/decimal separator handling. Currency
spell-out → numeric conversion sits in the same deterministic-ITN bucket
and should be a follow-on phase (Phase 20.09 or similar) targeting
`Shared/Utilities/ITNUtility.swift` only — no LLM-prompt changes needed.

Defer until 20.08 ships and the helvetism-delta gate is observed in the
wild for a release cycle.

Cross-platform: must ship macOS + iOS together (per
`feedback_cleanup_cross_platform_parity.md`).
