---
title: RulesCleanupService profanity-list audit and addition
captured: 2026-04-29
source: user-feedback (Phase 20.08 variant-g rationale session)
status: backlog
severity: low (feature gap, not a regression)
---

# Profanity removal in deterministic cleanup pass

## Finding

User stated as part of the unified cleanup goal:

> "if they swear … that should get cleaned out"

Disfluencies — stutters, repetitions, filler words, **swearing** — are
the deterministic Swift pre-pass's responsibility (Phase 20.02-03,
`RulesCleanupService`). The variant (g) LLM prompt does NOT and SHOULD
NOT carry profanity removal — that would re-duplicate work and create
the same prompt-architecture violation that variant (g) Draft 2 hit.

But: as far as we can tell, `RulesCleanupService` has a
`FillerWordRemover` for conservative shipping-list fillers (ähm,
"also", etc.) but **no profanity word-list**. So today, swearing flows
through to the LLM, which is then told to "preserve speaker's intent"
and leaves it in.

## Why it happens

Phase 20.02 demoted filler / digit-conversion duties from the LLM to
deterministic Swift, but the migration scope was conservative. Adding
a profanity list was not part of that scope. No subsequent phase has
added one.

## Proposed work (for future planning)

Three deliverables in one phase:

1. **Audit.** Read `Shared/Services/RulesCleanupService.swift` and any
   `FillerWord*`-named helpers; confirm there is no existing profanity
   pass (this finding is based on grep, not a full read).
2. **Word list.** Curate a German + English profanity list. Sources to
   consider: existing open-source lists (e.g. List of Dirty, Naughty,
   Obscene, and Otherwise Bad Words / LDNOOBW), filtered by relevance
   and severity. Decide on coverage: hard profanity always removed?
   "Scheisse" / "verdammt" — toggle-controlled? Default behaviour?
3. **Implementation.** Add a `ProfanityRemover` (or extend
   `FillerWordRemover`) with case-insensitive token matching. Test
   coverage: standalone tokens, mid-sentence, repeated profanity, and
   "preserve meaning" cases (e.g. "verdammt schön" — "damned beautiful"
   as intensifier vs. expletive).

## Open questions

- **User-controllable.** Should profanity removal be a user setting
  (off by default? on by default?), or always-on? Recommend a
  per-user toggle in settings.
- **Severity tiers.** Hard profanity (always remove) vs. mild
  expletives ("verdammt", "scheisse" — keep, soften, or remove?).
- **Multilingual.** Coverage for English at minimum; Swiss German
  swearing is its own dialect ("Siech", "huere", etc.) — separate
  list or excluded entirely until Swiss-German ASR phase?
- **Idiomatic uses.** "verdammt schön" / "scheisse kompliziert" — the
  word is grammatically functioning as an intensifier. Token-level
  removal would break the sentence. Need context-aware handling or
  conservative scope (only remove standalone exclamations).

## Test cases

- Standalone exclamation: "Verdammt, das war knapp." → "Das war knapp."
- Mid-sentence: "Ich war so scheisse müde." → ?? (intensifier — open Q)
- Repeated: "Scheisse, scheisse, scheisse." → "" (or single neutral
  expression of frustration?)
- Mixed-language: "Was the fuck, war das jetzt?" → "Was war das jetzt?"
- Idiom: "Das ist scheissegal." → ?? (compound — open Q)

## Where this fits

`Shared/Services/RulesCleanupService.swift` — the deterministic Swift
pre-pass. Sibling helper to `FillerWordRemover`. Cross-platform: must
ship macOS + iOS together (per `feedback_cleanup_cross_platform_parity.md`).

Defer until variant (g) ships and stabilises. Pair with the
RulesCleanupService audit broader scope review if one is planned.

## Note on relationship to variant (g)

Variant (g) explicitly does NOT carry profanity removal. The prompt's
"Preserve the speaker's intent" line means swearing flows through if
nothing upstream removes it. This backlog item closes that gap; without
it, dictating an angry sentence will yield clean grammar but preserved
expletives in the output, which the user has stated is wrong.
