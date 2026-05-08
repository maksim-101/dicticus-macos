---
phase: 22-resolver-regression-hotfix
reviewed: 2026-05-08T00:00:00Z
depth: standard
files_reviewed: 4
files_reviewed_list:
  - Shared/Utilities/SelfCorrectionResolver.swift
  - macOS/DicticusTests/SelfCorrectionResolverTests.swift
  - iOS/DicticusTests/SelfCorrectionResolverTests.swift
  - macOS/DicticusTests/CleanupPromptTests.swift
findings:
  critical: 0
  warning: 4
  info: 5
  total: 9
status: issues_found
---

# Phase 22: Code Review Report

**Reviewed:** 2026-05-08
**Depth:** standard
**Files Reviewed:** 4
**Status:** issues_found

## Summary

The Phase 22 hotfix tightens the SelfCorrectionResolver regex from a permissive substring-prone pattern to one anchored at start-of-string-or-comma with a trailing `\b` word-boundary guard. The fix is correct in principle and the seven added regression fixtures (byte-identical across macOS and iOS) genuinely lock in the substring-bug closure (`now`/`noticed`/`waitress`).

However, the new pattern introduces a **silent semantic narrowing** that conflicts with the docstring and is not directly covered by the regression net: connectors after sentence-terminators (`.`, `?`, `!`, `;`, `:`) without a comma now fail to match on their own. Existing tests still pass only because the longer chains contain a downstream `, <connector>` that re-enters the regex via the comma branch — this is incidental coverage, not designed coverage. Four warnings flag this and other behaviour gaps. The CleanupPrompt absence-assertion test is sound.

No security issues. No data-loss risks. Cross-platform parity is exact (verified via diff of the two test files).

## Warnings

### WR-01: Pattern silently narrowed beyond doc — sentence-terminator connectors no longer fire on their own

**File:** `Shared/Utilities/SelfCorrectionResolver.swift:75`
**Issue:** The previous regex allowed any of `[,;:.?!]?\s+` OR `,\s*` as the prefix to a connector. The new regex `(?i)(?:^|,)\s*(\(alternation))\b(\s*)` only allows `^` or `,`. This means inputs like `"It's broken. Scratch that, fix it."` or `"Was es Montag? Nein, Dienstag."` — where the connector follows `.` / `?` / `!` / `;` / `:` instead of `,` — will no longer match the connector at the sentence boundary. The hotfix's own UAT test `testEnglishNoCommaTimeCorrection` (`"...8 o'clock. No, actually at 7 o'clock."`) only passes because the regex matches `, actually` (comma-anchored second connector) and ignores the `. No` bigram entirely. If the input had been `"...8 o'clock. No actually at 7 o'clock."` (no comma after `No`) the resolver would now no-op where the old regex would have fired.

The doc-block at lines 13–14 says "The connector MUST be preceded by a comma" — but lines 73–74 contradictorily describe the match as `, <connector>\s*`, omitting the `^` alternative. The narrowing matches the doc's first claim but the contract written in the JSONL-fixture comments (lines 256–263) is about substring guards, not about removing sentence-terminator support. Either the narrowing is intentional (then update the doc and add fixtures asserting `". No actually X"` no-ops) or unintentional (then restore the broader prefix with an added `\b` guard).

**Fix:** Pick one of:
```swift
// Option A — accept the narrowing, document it, lock it with a fixture:
// (no code change; add tests asserting ". <connector> X" without comma is a no-op)

// Option B — restore sentence-boundary support with substring safety:
let pattern = "(?i)(?:^|[,.;:!?])\\s*(\(alternation))\\b(\\s*)"
```
Add a regression fixture either way so the next refactor cannot silently flip the behaviour again.

---

### WR-02: `^` is not multiline-anchored — start-of-string anchor is fragile in multi-line input

**File:** `Shared/Utilities/SelfCorrectionResolver.swift:75`
**Issue:** Without the `(?m)` flag, `^` only matches position 0 of the entire input string, never after embedded newlines. ASR cleanup pipelines occasionally feed multi-utterance text containing `\n`. After the narrowing in WR-01, an utterance like `"first line.\nNo, this is wrong"` cannot match — the `\n` is neither `^` nor `,`. The pre-fix regex matched here via the `\s+` branch.

**Fix:** Add the multiline flag if multi-line input is supported:
```swift
let pattern = "(?im)(?:^|,)\\s*(\(alternation))\\b(\\s*)"
```
Or document that `resolve(_:language:)` is single-utterance only and have callers split on newlines first.

---

### WR-03: Capture group 2 (`(\\s*)`) is captured but never read — dead capture

**File:** `Shared/Utilities/SelfCorrectionResolver.swift:75`
**Issue:** The pattern declares two capture groups: group 1 (the connector) and group 2 (trailing whitespace). Only group 1 is ever read (line 97). Group 2 is unused dead state. NSRegularExpression still allocates and tracks it. Worse, the comment at line 73 (`group layout: full match = ',  <connector>\s*' (consumed), group 1 = the connector text itself`) does not even mention the second group, so any future maintainer reading 75 vs. 73 will be confused about whether group 2 is load-bearing.

**Fix:** Use a non-capturing group:
```swift
let pattern = "(?i)(?:^|,)\\s*(\(alternation))\\b(?:\\s*)"
```

---

### WR-04: Backward-window cap is documented as 3 but coded as 6 — pre-existing but now reinforced by Phase 22 fixtures

**File:** `Shared/Utilities/SelfCorrectionResolver.swift:164-192`
**Issue:** The doc at lines 15–16 and 38 promises "Backward window cap = 3 tokens. Never delete more than the most recent 3 backward tokens." Line 165 and 192 use **6**: `let lastSixIndex = max(0, backwardCount - 6)` and `min(dropCount ?? 1, min(6, backwardCount))`. The function `testGermanBackwardWindowCappedAtThree` only exercises the case where the first-repair-token alignment finds a match within the last 3 tokens, so the 6-vs-3 discrepancy is invisible to the test suite. The Phase 22 hotfix did not introduce this — but the new fixtures (no-op cases) do not exercise it either, so the regression net does not protect against a future refactor that drifts the cap further. If the docstring is the contract, the code is wrong; if the code is the contract, the docstring lies.

**Fix:** Reconcile. Either change the cap to 3 to honour the doc + the cap test:
```swift
let lastWindowIndex = max(0, backwardCount - 3)
let lastWindow = Array(backwardTokens[lastWindowIndex..<backwardCount])
// ...
let actualDrop = min(dropCount ?? 1, min(3, backwardCount))
```
Or update the docstring to admit the alignment-search window is 6 (with hard drop cap derived from match position) and add a fixture proving a 4-token-back match still drops 4 tokens. Pick whichever is intentional and write the missing fixture either way.

---

## Info

### IN-01: Doc/code drift in line 73 comment — `^` alternative omitted

**File:** `Shared/Utilities/SelfCorrectionResolver.swift:73`
**Issue:** Comment claims "full match = `, <connector>\s*` (consumed)" but the new regex also matches at `^`. After fixing WR-01, this comment will be wrong in either direction. Update it as part of the same patch.
**Fix:** Replace with: `// Group layout: full match = '<,|^>\s*<connector>\b\s*' (consumed), group 1 = connector text.`

---

### IN-02: JSONL-fixture comment says "regex at line 75" — line numbers are brittle

**File:** `macOS/DicticusTests/SelfCorrectionResolverTests.swift:260`
**File:** `iOS/DicticusTests/SelfCorrectionResolverTests.swift:260`
**Issue:** Both test files reference "the SelfCorrectionResolver regex at line 75". Line numbers drift on every edit; this comment will be stale by the next refactor. Use a stable anchor (function name or sentinel comment) instead.
**Fix:** Replace `at line 75` with `(see SelfCorrectionResolver.swift, the pattern in resolve(_:language:))`.

---

### IN-03: `wait` connector regression net has only one fixture and a slightly misleading docstring

**File:** `macOS/DicticusTests/SelfCorrectionResolverTests.swift:325-335`
**File:** `iOS/DicticusTests/SelfCorrectionResolverTests.swift:325-335`
**Issue:** Phase 22's stated bug list (per file's own header comment, lines 256–263) names `waitress` as one of the substring-match victims, but no fixture exercises `waitress` directly. The closest is `"oh wait, I just noticed"` which does NOT contain `waitress`. The substring-against-`waitress` claim is therefore not regression-locked. Also the docstring at line 327 mixes two assertions (`wait` no-op AND `\b` blocks `no`-in-`noticed`) — better split into two named tests for diagnostic clarity when one fails.
**Fix:** Add one fixture explicitly: `"the waitress brought water"` → unchanged, language `en`. Either as part of this hotfix or filed to backlog with the JSONL ID.

---

### IN-04: `pureCorrectionConnectors` is a `Set<String>` of lowercased literals but is not declared `static let lazy`

**File:** `Shared/Utilities/SelfCorrectionResolver.swift:285-293`
**Issue:** Pre-existing. The set is a `static let` constant — Swift initialises it once. No real bug, but the `let pureCorrection = pureCorrectionConnectors` copy on line 86 of every call is harmless because Swift `Set` is value-typed but COW-backed. Mention only because review touches the file.
**Fix:** Drop the local copy and reference `Self.pureCorrectionConnectors` directly. Cosmetic.

---

### IN-05: `connectorList(for:)` and `pronounAbortSet(for:)` silently default unknown locales to German

**File:** `Shared/Utilities/SelfCorrectionResolver.swift:312, 321`
**Issue:** Pre-existing. Passing `language: "fr"` or `language: ""` returns the German connector list and German pronoun set. This is documented nowhere and means a misconfigured caller will run German rewriting against French/Italian text. Not introduced by Phase 22 but worth flagging since this review touched the file.
**Fix:** Either return an empty list for unknown locales (turning resolver into a no-op for unsupported languages) or log a warning. At minimum add a doc-comment line above the helpers.

---

_Reviewed: 2026-05-08_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
