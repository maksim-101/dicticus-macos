---
title: macOS dictation acronym spacing
captured: 2026-04-26
source: user-feedback (Phase 19.5 execution pause)
status: backlog
---

# Acronym spacing in dictation output

## Finding

When dictating an acronym on macOS, Parakeet outputs the letters with whitespace
separators: `N R S N A` instead of `NRSNA`.

## Why it happens

ASR (Parakeet TDT v3) emits each spelled letter as its own token with a leading
space. The post-ASR pipeline (`Shared/Utilities/ITNUtility.swift`) handles
spelled-out numbers and Swiss letter substitutions but has no acronym collapse.

## Proposed fix (for future planning)

Add an acronym-collapse pass alongside `applyITN`. Detection heuristic:
- 3+ consecutive single-letter tokens separated by spaces
- Each letter is uppercase or could be uppercased
- Followed by whitespace or punctuation

Edge cases to test:
- "I am O K" — 3 single letters but should NOT collapse (mixed sentence words)
- "die N R S N A" — should collapse to "die NRSNA"
- "I O S" — likely should collapse to "IOS"
- "U S A" — should collapse to "USA"
- Dictating in German with mixed German letters

## Where this fits

Likely a follow-on phase to 19.5/19.6 — sits in the same "deterministic
post-ASR cleanup" bucket as Swiss number formatting. Could also be folded into
a future ASR-postprocessing polish phase or routed via `/gsd-debug` if the user
wants a focused investigation.

Memory pointer: `project_acronym_spacing_finding.md`
