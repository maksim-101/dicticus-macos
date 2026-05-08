---
status: partial
phase: 22-resolver-regression-hotfix
source: [22-VERIFICATION.md]
started: 2026-05-08T21:00:00Z
updated: 2026-05-08T21:00:00Z
---

## Current Test

[awaiting human testing]

## Tests

### 1. iOS xcodebuild test gate on SelfCorrectionResolverTests (25/25)
expected: ** TEST SUCCEEDED ** with 25 tests passing on iOS Simulator (18 existing + 7 new)
result: [pending]

### 2. Live dictation regression check on macOS Release build with the 7 JSONL fixture utterances
expected: Each utterance arrives at the cursor verbatim — no `now`/`noticed`/`wait` content-eating, no spurious whitespace collapsing
result: [pending]

### 3. Confirm scope-aligned narrowing is acceptable in production
expected: Connectors after sentence-terminators without a comma (e.g. `Done. Actually that's wrong.`) no longer fire — confirm this matches user intent vs. prior behavior
result: [pending]

## Summary

total: 3
passed: 0
issues: 0
pending: 3
skipped: 0
blocked: 0

## Gaps
