---
status: partial
phase: 22-resolver-regression-hotfix
source: [22-VERIFICATION.md]
started: 2026-05-08T21:00:00Z
updated: 2026-05-09T00:30:00Z
---

## Current Test

Test 1 (iOS xcodebuild gate) — only remaining open item; deferrable since iOS test file is byte-identical to macOS.

## Tests

### 1. iOS xcodebuild test gate on SelfCorrectionResolverTests (25/25)
expected: ** TEST SUCCEEDED ** with 25 tests passing on iOS Simulator (18 existing + 7 new)
result: [pending]

### 2. Live dictation regression check on macOS Release build with the 7 JSONL fixture utterances
expected: Each utterance arrives at the cursor verbatim — no `now`/`noticed`/`wait` content-eating, no spurious whitespace collapsing
result: passed — UAT 2026-05-09 on /Applications/Dicticus.app (Developer ID re-signed, com.dicticus.app, TeamIdentifier=VTWHBCCP36). All 7 fixtures verified in both AI Cleanup and Plain Dictation modes. `now`/`actually`/`noticed` survived in every case. Two harmless Parakeet ASR variations observed (`"a home assistant"` insertion; `"notice"` for `"noticed"` in record 29) — both passed through the resolver unchanged, confirming the `\b` guard works for whatever ASR emits.

### 3. Confirm scope-aligned narrowing is acceptable in production
expected: Connectors after sentence-terminators without a comma (e.g. `Done. Actually that's wrong.`) no longer fire — confirm this matches user intent vs. prior behavior
result: passed — UAT 2026-05-09. User confirmed `"Done, actually that's wrong."` output is acceptable. Scope-narrowing accepted.

## Summary

total: 3
passed: 2
issues: 0
pending: 1
skipped: 0
blocked: 0

## Gaps

### G-01 (out of Phase 22 scope) — AI Cleanup misses self-corrections
Observed during Test 2 UAT: input `"And what you did will persist now or will is not or will it not?"` was passed through verbatim by AI Cleanup (Gemma 4 E2B). Expected behavior: cleanup should drop the abandoned `"or will is not"` fragment because the surviving `"or will it not"` makes it semantically incoherent. This is a cleanup-quality gap, not a resolver regression — Phase 22 scope is the resolver only. Tracked in memory `project_ai_cleanup_self_correction_gap` for future cleanup work (likely needs few-shot examples in the prompt or eval coverage of self-correction patterns).
