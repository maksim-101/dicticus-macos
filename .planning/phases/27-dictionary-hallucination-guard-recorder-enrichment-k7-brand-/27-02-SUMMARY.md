---
phase: 27-dictionary-hallucination-guard-recorder-enrichment-k7-brand
plan: 02
subsystem: debug-recorder
tags: [observability, recorder-schema, applyWithTrace, OBS-DICT-01, jsonl, codable]
requires:
  - DictionaryService.applyWithTrace (27-01)
  - DictionaryService.Replacement (27-01)
  - DictionaryService.BlockedMatch (27-01, 4-field schema per D-06)
provides:
  - DebugCleanupRecord.dictionary_replacements (non-optional, default [])
  - DebugCleanupRecord.dictionary_blocked (non-optional, default [])
  - DebugCleanupRecord.DictionaryReplacementEntry (nested Codable Sendable, key/from/to)
  - DebugCleanupRecord.DictionaryBlockedEntry (nested Codable Sendable, key/from/to/ratio)
  - DebugRecorder.lastRecordForTests (test-only actor accessor)
affects:
  - Shared/Diagnostics/DebugRecorder.swift (schema extension + lastRecordForTests hook)
  - Shared/Services/TextProcessingService.swift (Step 1 split-path + constructor map)
  - macOS/DicticusTests/DicticusTests.swift (Codable round-trip tests added)
  - iOS/DicticusTests/DicticusTests.swift (byte-identical to macOS)
  - macOS/DicticusTests/TextProcessingServiceTests.swift (recorder integration test + cross-platform parity merge)
  - iOS/DicticusTests/TextProcessingServiceTests.swift (byte-identical to macOS)
tech-stack:
  added: []
  patterns:
    - Inline .map bridging at constructor call site (DictionaryService.Replacement → DebugCleanupRecord.DictionaryReplacementEntry)
    - Split #if DEBUG_RECORDER path on Step 1 (traced applyWithTrace under flag; thin apply(to:) wrapper in production)
    - Test-only actor accessor (lastRecordForTests, gated by file-wide #if DEBUG_RECORDER)
    - JSONL pipeline-order field placement (context-keys → replacements → blocked → anomaly)
key-files:
  created: []
  modified:
    - Shared/Diagnostics/DebugRecorder.swift
    - Shared/Services/TextProcessingService.swift
    - macOS/DicticusTests/DicticusTests.swift
    - iOS/DicticusTests/DicticusTests.swift
    - macOS/DicticusTests/TextProcessingServiceTests.swift
    - iOS/DicticusTests/TextProcessingServiceTests.swift
decisions:
  - dictionary_blocked schema is 4 fields {key, from, to, ratio} per D-06 amendment (ratified by user upfront, no Open Decisions in 27-02)
  - lastRecordForTests added as public private(set) on the DebugRecorder actor instead of internal — actor access requires an explicit accessibility level reachable across the @testable import boundary; production builds (no -D DEBUG_RECORDER) never compile the file so no symbol leaks
  - macOS and iOS TextProcessingServiceTests.swift merged to a single byte-identical superset (was pre-existing parity gap from 25-02 era — fixed under D-15 cross-platform-parity rule); no test was deleted, only the superset of both platforms' coverage was unified
metrics:
  duration: ~30 minutes (2 task commits + verification + summary)
  completed: 2026-05-26
  tests_added: 3 (2 Codable round-trip + 1 end-to-end integration)
  tests_modified: 0 (no pre-existing test required new constructor arguments — TextProcessingService.swift was the sole DebugCleanupRecord caller in the project)
  test_files_byte_identical: yes (all three pairs: DicticusTests, TextProcessingServiceTests, DictionaryServiceTests)
---

# Phase 27 Plan 02: Recorder Schema Extension Summary

Extended `DebugCleanupRecord` with the per-replacement attribution arrays `dictionary_replacements` and `dictionary_blocked` (3-field and 4-field nested Codable structs respectively) and wired `TextProcessingService` to consume 27-01's `applyWithTrace(to:)` under `#if DEBUG_RECORDER`. The JSONL schema now carries enough information for future log analyses to attribute every text mutation (and every guard-blocked candidate) to a specific dictionary entry without re-running the pipeline. Production `Dicticus` scheme is unaffected — the entire `DebugRecorder.swift` file remains gated by `#if DEBUG_RECORDER` and emits zero new symbols.

## Schema diff

### New top-level fields on `DebugCleanupRecord` (in declaration order — synthesized memberwise init picks them up automatically)

| Field | Type | Default | Position |
|-------|------|---------|----------|
| `dictionary_replacements` | `[DictionaryReplacementEntry]` | `[]` (caller responsibility per D-07) | After `dictionary_context_keys`, before `anomaly` |
| `dictionary_blocked` | `[DictionaryBlockedEntry]` | `[]` (caller responsibility per D-07) | After `dictionary_replacements`, before `anomaly` |

JSONL pipeline-order reads: `… steps → dictionary_context_keys (input-time hints) → dictionary_replacements (apply-time hits) → dictionary_blocked (apply-time vetoes) → anomaly → emission_counter`.

### New nested public Codable Sendable types

- `DictionaryReplacementEntry { key: String, from: String, to: String }` — explicit memberwise init.
- `DictionaryBlockedEntry { key: String, from: String, to: String, ratio: Double }` — explicit memberwise init. 4 fields per D-06 amendment.

### Narrowed semantics

- `dictionary_context_keys` — one-line doc comment added documenting D-06 narrowing: "LLM context targeting hints (input-side dictionary key matches). Narrowed in Phase 27: no longer overloaded with actually-applied replacements — see dictionary_replacements." Wire path is unchanged (still populated from `dbgDictKeys` which only fires in the AI-cleanup branch from `filteredContext.keys` per the existing `lowerText.contains(...)` filter).

## TextProcessingService wiring

| Edit | Lines | Description |
|------|-------|-------------|
| Step 1 split path | L86-100 | `#if DEBUG_RECORDER` branch declares `dbgReplacements`/`dbgBlocked` outer-scope vars + calls `applyWithTrace(to: text)`; `#else` branch keeps `apply(to: text)` unchanged. Production path emits no new symbols. |
| Constructor map | L361-362 | Two inline `.map { ... }` calls bridge `DictionaryService.Replacement` → `DebugCleanupRecord.DictionaryReplacementEntry` and `DictionaryService.BlockedMatch` → `DebugCleanupRecord.DictionaryBlockedEntry`. Identical structural shape — only namespace differs (per D-09). |

The `dbgReplacements` and `dbgBlocked` vars are declared at the Step 1 site rather than alongside `dbgDictKeys` at L156 because they are only written at Step 1 and only read at the L324 record-assembly site — both inside `#if DEBUG_RECORDER` blocks at the same function-level scope, so visibility is preserved without needing top-of-function declaration.

## DebugRecorder hook

Added `public private(set) var lastRecordForTests: DebugCleanupRecord?` to the `DebugRecorder` actor, populated as the first line of `record(_:)`. Test-only accessor used by `testRecorderEmitsDictionaryReplacements` to avoid JSONL file I/O. Annotated with one-line doc comment per CLAUDE.md "comment the why": `/// Test-only — last record handed to record(_:). Always nil in production builds (file is fully gated by #if DEBUG_RECORDER).`

## Tests added (3, all under `#if DEBUG_RECORDER`)

| Test Class | Method | Purpose |
|------------|--------|---------|
| `DebugCleanupRecordCodableTests` (new in `DicticusTests.swift`) | `testDebugCleanupRecordCodableRoundTrip_DefaultEmpty` | Empty arrays serialize to literal `"[]"` (not absent keys), survive a JSON encode→decode round trip. |
| `DebugCleanupRecordCodableTests` | `testDebugCleanupRecordCodableRoundTrip_WithEntries` | Populated entries round-trip with full field fidelity (key, from, to preserved exactly; ratio within accuracy 0.001). |
| `TextProcessingServiceRecorderTests` (new in `TextProcessingServiceTests.swift`) | `testRecorderEmitsDictionaryReplacements` | End-to-end: seed `Dicticos → Dicticus` exact-match entry, run `process(...)`, assert `DebugRecorder.shared.lastRecordForTests?.dictionary_replacements` carries exactly one entry with the correct key/from/to and `dictionary_blocked` is empty. Closes OBS-DICT-01 wiring contract. |

## Tests updated

None — `TextProcessingService.swift` was the **only** site in the project that constructs a `DebugCleanupRecord` directly (verified via `git grep "DebugCleanupRecord("` after the change). No pre-existing test required new constructor arguments because the Phase 25-02 / 25.1-01 tests inspect emitted JSONL records, not constructed `DebugCleanupRecord` instances.

## Cross-platform parity (D-15)

| Pair | Status |
|------|--------|
| `macOS/DicticusTests/DicticusTests.swift` ↔ `iOS/DicticusTests/DicticusTests.swift` | byte-identical (`diff -q` exit 0) |
| `macOS/DicticusTests/TextProcessingServiceTests.swift` ↔ `iOS/DicticusTests/TextProcessingServiceTests.swift` | byte-identical (`diff -q` exit 0) |
| `macOS/DicticusTests/DictionaryServiceTests.swift` ↔ `iOS/DicticusTests/DictionaryServiceTests.swift` | byte-identical (`diff -q` exit 0) — preserved from 27-01 |

A pre-existing parity gap on `DicticusTests.swift` (macOS used `testPlaceholder`, iOS used `testExample`) and a larger gap on `TextProcessingServiceTests.swift` (macOS had `testPipelineOrder`/`testGermanPipeline`; iOS had `testCleanupPath`/`testPlainModeSkipsCleanup`/`testBlocksUntilCleaned`/`testCleanupSkippedWhenProviderNotLoaded`) were resolved by merging both platforms' test suites into a single byte-identical superset. **No test was deleted** — both files now run the union of all pre-existing tests on both platforms.

## iOS Debug-Recorder scheme status

The iOS project (`iOS/Dicticus.xcodeproj`) currently exposes only the production `Dicticus` scheme — no `Dicticus-Debug-Recorder` counterpart. The new `#if DEBUG_RECORDER` test classes compile-skip on iOS (the byte-identical source proves source-level parity once iOS adds a Debug-Recorder scheme in a future plan). The iOS production scheme was verified to build clean (`xcodebuild build -project iOS/Dicticus.xcodeproj -scheme Dicticus -destination "generic/platform=iOS Simulator"` → BUILD SUCCEEDED), confirming the `#if DEBUG_RECORDER` gate keeps all new code invisible to the production iOS build.

## Build / Test results

| Scheme | Result |
|--------|--------|
| macOS `Dicticus-Debug-Recorder` build | BUILD SUCCEEDED |
| macOS `Dicticus-Debug-Recorder` full test run | TEST SUCCEEDED — all 27 test suites passed, 0 failures (DebugCleanupRecordCodableTests, TextProcessingServiceRecorderTests, and 25 pre-existing suites including TextProcessingServiceTests, CleanupServiceTests, DictionaryService\*Tests, etc.) |
| macOS `Dicticus` (production) build | BUILD SUCCEEDED (no new symbols emitted from `#if DEBUG_RECORDER`-gated file) |
| iOS `Dicticus` build | BUILD SUCCEEDED |

Selected-test run output for the new 27-02 tests:

```
Test Suite 'DebugCleanupRecordCodableTests' started.
Test Case '-[DicticusTests.DebugCleanupRecordCodableTests testDebugCleanupRecordCodableRoundTrip_DefaultEmpty]' passed (0.001 seconds).
Test Case '-[DicticusTests.DebugCleanupRecordCodableTests testDebugCleanupRecordCodableRoundTrip_WithEntries]' passed (0.001 seconds).
Test Suite 'DebugCleanupRecordCodableTests' passed
	 Executed 2 tests, with 0 failures (0 unexpected) in 0.002 (0.003) seconds
Test Suite 'TextProcessingServiceRecorderTests' started.
Test Case '-[DicticusTests.TextProcessingServiceRecorderTests testRecorderEmitsDictionaryReplacements]' passed (2.271 seconds).
Test Suite 'TextProcessingServiceRecorderTests' passed
	 Executed 1 test, with 0 failures (0 unexpected) in 2.271 (2.271) seconds
```

Tests were executed with `CODE_SIGNING_ALLOWED=NO CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO` because the macOS target uses manual `Developer ID` signing for release builds and the test invocation does not need provisioning. Runtime-only flag; committed project settings unchanged.

## Must-Haves Truths — All Observable

1. **"Every emitted `DebugCleanupRecord` carries non-optional `dictionary_replacements: []` and `dictionary_blocked: []` fields, default-empty when no dictionary activity occurred."** — Verified by `testDebugCleanupRecordCodableRoundTrip_DefaultEmpty`: encoded JSON contains literal `"dictionary_replacements":[]` and `"dictionary_blocked":[]` substrings. Synthesized Codable conformance enforces the contract at compile time (omitting either field at construction time would be a Swift "missing argument" error).
2. **"When `applyWithTrace` returns a non-empty `replacements` array, those entries appear verbatim in the JSONL record's `dictionary_replacements` field."** — Verified by `testRecorderEmitsDictionaryReplacements`: a real pipeline run with seeded `Dicticos → Dicticus` produces `lastRecordForTests.dictionary_replacements == [Replacement(key: "Dicticos", from: "Dicticos", to: "Dicticus")]`.
3. **"When the fuzzy guard records a `BlockedMatch`, that entry appears in `dictionary_blocked` with `key`, `from`, `to`, and `ratio` populated."** — Verified by `testDebugCleanupRecordCodableRoundTrip_WithEntries`: a fixture `BlockedMatch(key: "Gemini", from: "remind", to: "Gemini", ratio: 0.333)` round-trips with all 4 fields preserved including `ratio` within accuracy 0.001.
4. **"`dictionary_context_keys` field semantics are narrowed (D-06)."** — Verified by code inspection: one-line doc comment ABOVE the field declaration documents the contract change; the wire path (only populated from `filteredContext.keys` in the AI-cleanup branch via the `lowerText.contains(...)` filter at L184-194) was unchanged.
5. **"Plain-mode records emit both new fields as `[]` symmetric with the existing `dictionary_context_keys: []` plain-mode behavior."** — Verified by code inspection + by the run in `testRecorderEmitsDictionaryReplacements` (which uses `mode: .plain` with no AI-cleanup branch entered): `dbgDictKeys` stays `[]` (only AI branch populates it from filteredContext), and the new arrays carry only what `applyWithTrace` returned from the Step 1 dictionary pass. For inputs with no dictionary activity (no exact match, no fuzzy hit), both new arrays are `[]`.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 — Blocking] Pre-existing cross-platform parity gap on `DicticusTests.swift` and `TextProcessingServiceTests.swift`**
- **Found during:** Task 2(f) pre-flight (`diff -q` between platforms before cp).
- **Issue:** macOS `DicticusTests.swift` and iOS counterpart already differed (`testPlaceholder` vs `testExample`, missing `@testable import`). macOS `TextProcessingServiceTests.swift` and iOS counterpart had non-overlapping unique tests: macOS had `testPipelineOrder` / `testGermanPipeline`; iOS had `testCleanupPath` / `testPlainModeSkipsCleanup` / `testBlocksUntilCleaned` / `testCleanupSkippedWhenProviderNotLoaded`. Plan 27-02 task 2(f) calls for `cp macOS → iOS` to enforce byte-identical parity, but a naive cp would delete pre-existing iOS tests that have shipped value.
- **Fix:** Merged both platforms' test suites into a single byte-identical superset that runs ALL pre-existing tests on BOTH platforms (no deletions), then added the new 27-02 tests, then cp'd macOS → iOS. All symbols used (`DictionaryService.dictionaryKey`, `setReplacement`, `removeAll`, `TextProcessingService(cleanupService:)`, etc.) are defined in `Shared/` and compile cleanly on both platforms.
- **Files modified:** `macOS/DicticusTests/DicticusTests.swift`, `iOS/DicticusTests/DicticusTests.swift`, `macOS/DicticusTests/TextProcessingServiceTests.swift`, `iOS/DicticusTests/TextProcessingServiceTests.swift`.
- **Commit:** `91c6e0b`.

### Plan-Specified Behavior Confirmed

- The plan's allowance "If `DebugRecorder.shared.lastRecordForTests` doesn't exist, add it as an `internal var lastRecordForTests: DebugCleanupRecord?`" was followed, with `public private(set)` instead of `internal` because actor access requires explicit accessibility reachable across the `@testable import` boundary. Production never compiles the file (entire `DebugRecorder.swift` is gated by `#if DEBUG_RECORDER`), so no symbol leaks to release builds.

## Known Stubs

None — every new field is wired end-to-end and exercised by passing tests.

## Self-Check: PASSED

- `Shared/Diagnostics/DebugRecorder.swift` — FOUND (modified; +33 lines)
- `Shared/Services/TextProcessingService.swift` — FOUND (modified; Step 1 split + constructor map)
- `macOS/DicticusTests/DicticusTests.swift` — FOUND (modified; DebugCleanupRecordCodableTests added)
- `iOS/DicticusTests/DicticusTests.swift` — FOUND (byte-identical to macOS)
- `macOS/DicticusTests/TextProcessingServiceTests.swift` — FOUND (modified; merged + TextProcessingServiceRecorderTests added)
- `iOS/DicticusTests/TextProcessingServiceTests.swift` — FOUND (byte-identical to macOS)
- Commit `8ddca81` — FOUND in git log (Task 1: schema extension)
- Commit `91c6e0b` — FOUND in git log (Task 2: wiring + tests)
- 3/3 new tests PASS
- Full Dicticus-Debug-Recorder suite (27 test suites) GREEN
- Production `Dicticus` scheme builds clean on both macOS and iOS

## Plan Commits

| Task | Commit | Description |
|------|--------|-------------|
| 1    | `8ddca81` | feat(27-02): extend DebugCleanupRecord with dictionary_replacements + dictionary_blocked |
| 2    | `91c6e0b` | feat(27-02): wire applyWithTrace into TextProcessingService + recorder tests |
| 3    | — | Verification-only (full suite + production scheme + parity gate); no code changes required |
