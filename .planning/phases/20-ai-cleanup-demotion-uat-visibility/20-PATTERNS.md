# Phase 20 PATTERNS — Closest analogs in the Dicticus codebase

**Created:** 2026-04-26
**Source:** Direct codebase inspection (pattern-mapper agent stalled at 600s; this document was written by manual inventory).

## New / Modified Files

### `Shared/Utilities/LevenshteinDistance.swift` — NEW

- **Closest analog:** `Shared/Utilities/SwissNumberFormatter.swift` and `Shared/Utilities/CurrencyAntiFlip.swift` — both pure-Swift `struct` namespaces with `static` methods, no instance state, fixture-driven tests.
- **Pattern to follow:** `enum LevenshteinDistance { static func distance(_ a: String, _ b: String) -> Int; static func normalized(_ a: String, _ b: String) -> Double }`. Pure value semantics, no Foundation types beyond `String`.
- **Deviations:** None — direct fit. Recommend `enum` (caseless namespace) over `struct` since there is no need for instances.
- **Tests:** Mirror `SwissNumberFormatterTests` style — XCTest fixture pairs in JSON for known-distance pairs, plus boundary cases (empty strings, identical strings, Unicode).

### `Shared/Utilities/FillerWordRemover.swift` — NEW

- **Closest analog:** `Shared/Models/SwissHelvetisms.swift` (a `struct SwissHelvetisms { static let words: [String] }` — flat data + small static helpers) and `Shared/Utilities/CurrencyAntiFlip.swift` (regex detection on text).
- **Pattern to follow:** `enum FillerWordRemover { static let germanFillers: Set<String>; static let englishFillers: Set<String>; static func strip(_ text: String, language: String) -> String }`. Word-boundary regex matching to avoid false positives.
- **Deviations:** Sets, not arrays — membership lookups must be O(1). Word-boundary aware, never substring removal.
- **Conservative ship list (from RESEARCH.md):** `{äh, ähm, ehm, hmm}` (de) + `{uh, um, umm, er, erm}` (en). Explicitly exclude `also`, `ja`, `genau`, `like`, `well`, `okay` — these have semantic meaning.

### `Shared/Utilities/SelfCorrectionResolver.swift` — NEW

- **Closest analog:** `Shared/Utilities/CurrencyAntiFlip.swift` — regex-driven scanning with bounded windows + the `bridgeCrossTokenDecimal` regex chain in `SwissNumberFormatter` (`Shared/Utilities/SwissNumberFormatter.swift:bridgeCrossTokenDecimal`) which uses NSRegularExpression with negative lookbehind.
- **Pattern to follow:** `enum SelfCorrectionResolver { static func resolve(_ text: String, language: String) -> String }`. Regex matches `\b(X), (ich meine|I mean|or rather|rather|genauer gesagt) (Y)\b` with a comma-prefix guard; replace `X, connector Y` with `Y` only when X looks like a single noun-ish token (no spaces).
- **Deviations:** Must respect Shriberg's noisy-channel guidance — bounded backward scan ≤ 3 tokens, no fire when no clear replacement candidate.

### `Shared/Utilities/CurrencyFolder.swift` — NEW (or methods on `SwissNumberFormatter`)

- **Closest analog:** `bridgeCrossTokenDecimal` inside `SwissNumberFormatter.swift` — already does cross-token currency-aware folding.
- **Pattern to follow:** Either extend `SwissNumberFormatter` with a `foldCurrencyUnits(_:)` static method OR introduce a sibling `enum CurrencyFolder`. **Recommendation:** extend `SwissNumberFormatter` — keeps the "Swiss number normalization" surface coherent and ensures pipeline ordering stays simple.
- **Order-of-operations:** Currency-fold runs **before** `bridgeCrossTokenDecimal` in `SwissNumberFormatter.format(_:)`. The existing negative-lookbehind guards (`(?<![.,'\u{2019}])`) keep idempotency on already-folded outputs.
- **Test fixtures:** Extend `iOS/DicticusTests/Fixtures/SwissNumberFormatter.fixtures.json` with `"15 Franken 50 Rappen"` → `"CHF 15.50"`, `"10 Euro 75 Cent"` → `"€10.75"`, etc.

### `Shared/Services/RulesCleanupService.swift` — NEW

- **Closest analog:** `Shared/Services/DictionaryService.swift` — small Shared/ service that mutates a string and is composed in `TextProcessingService.process()`. Also `Shared/Services/CleanupService.swift` for state observability via `@Published`/MainActor (though RulesCleanup likely doesn't need either — it's a pure transform).
- **Pattern to follow:** `final class RulesCleanupService { func clean(_ text: String, language: String) -> String }` — thin orchestrator that calls `FillerWordRemover.strip` → `SelfCorrectionResolver.resolve` → `SwissNumberFormatter.foldCurrencyUnits` (or the chosen split). Keep the service thin; complexity lives in the utilities.
- **Deviations:** No `@MainActor`, no `@Published` — pure function semantics. Singleton or DI: consume via `TextProcessingService.process` constructor injection like `DictionaryService` does.
- **Decision delegated to planner:** if the orchestration is small enough, fold into `TextProcessingService` directly without a new file.

### `Shared/Services/CleanupService.swift` — MODIFIED

- **Closest analog:** itself — modify line 123 (`llama_sampler_init_temp(0.2)` → `llama_sampler_init_temp(0.1)`) per RESEARCH.md, and add a post-call gate.
- **Pattern to follow:** Add a static `gateLLMOutput(_ llmOutput: String, against rulesCleaned: String) -> String` returning either `llmOutput` (gate passed) or `rulesCleaned` (gate rejected). Call site is `TextProcessingService` after the LLM stage; CleanupService stays free of Levenshtein knowledge — orchestration belongs upstairs.
- **Deviations:** Avoid leaking Levenshtein into CleanupService. Place the gate in TextProcessingService so CleanupService remains the "raw LLM" provider.

### `Shared/Services/TextProcessingService.swift` — MODIFIED

- **Closest analog:** itself — current shape: Step 1 dictionary, Step 2 ITN, Step 3 LLM (optional), Step 3b SwissNumberFormatter, Step 4 history save (D-38).
- **New shape:** Step 1 dictionary → Step 2 ITN → **Step 2c RulesCleanupService** (new) → Step 3 LLM (optional) → Step 3a Levenshtein gate → Step 3b SwissNumberFormatter (existing) → Step 4 history save.
- **Pattern to follow:** existing step numbering convention. Each step is a single line that mutates `processedText`.
- **Deviations:** None.

### `Shared/Models/CleanupPrompt.swift` — MODIFIED

- **Closest analog:** itself — change `defaultInstruction` text only. Keep `userInstruction()` UserDefaults override path intact.
- **Pattern to follow:** Replace `"Rewrite the following transcribed text…"` with `"Lightly edit the following transcribed text…"` and adjust verb framing throughout (no "remove filler words" instruction — that moves to Swift; no "write numbers as digits" instruction if rules pass already handles it). Keep STRICT currency anti-flip + Swiss style + Helvetism blocks intact.
- **Deviations:** None.

### `Shared/Services/HistoryService.swift` — MODIFIED

- **Closest analog:** the existing init at lines 58–75. App Group lookup with `containerURL(forSecurityApplicationGroupIdentifier:)`.
- **Pattern to follow:** Replace lines 60–62 (`guard let containerURL …  fatalError(…)`) with:
  ```swift
  let containerURL: URL
  if let appGroup = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.dicticus") {
      containerURL = appGroup
  } else {
      Self.log.warning("App Group container unavailable — falling back to Application Support (history not shared with extensions)")
      containerURL = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
      Self.appGroupAvailable = false
  }
  ```
- **Settings surface:** add `static private(set) var appGroupAvailable: Bool = true` so iOS Settings UI can show a non-blocking warning row when fallback is active. Mirror surface on macOS for parity even though macOS rarely hits this path.
- **Deviations:** The second `fatalError` at line 73 (DB-init failure) stays — that is genuinely unrecoverable and not entitlement-dependent.

### iOS detail view — `iOS/Dicticus/History/HistoryDetailView.swift` — NEW

- **Closest analog:** No iOS detail view exists today; closest pattern is `iOS/Dicticus/History/HistoryView.swift` itself which already wraps content in `NavigationStack`. Settings panel `iOS/Dicticus/Settings/SettingsView.swift` uses sheet-style presentation.
- **Pattern to follow:** Add `NavigationLink(value: entry)` on `HistoryRow`, wire `.navigationDestination(for: TranscriptionEntry.self) { entry in HistoryDetailView(entry: entry) }` on the existing `NavigationStack`.
- **HistoryDetailView shape:** segmented `Picker` with two cases `Polished` / `Raw`, swap displayed text between `entry.text` and `entry.rawText`. Toolbar Copy button copies the currently-shown text. Long-form text is a `ScrollView` with `Text(...)` (not `lineLimit(3)`).
- **GRDB record `Hashable` conformance:** `TranscriptionEntry` already conforms to `Identifiable` via the `id` column; verify `Hashable` is automatic (struct with all-Hashable members) or add explicit conformance.
- **Default toggle position:** `.raw` per Phase 20 CONTEXT decision (until LLM trust is rebuilt).
- **Deviations:** None — modern SwiftUI standard.

### macOS parity — inline disclosure on `HistoryRow`

- **Closest analog:** `macOS/Dicticus/Views/HistoryView.swift:139–196` — `HistoryRow` is already a fairly rich row with TagView decorations.
- **Pattern to follow (per RESEARCH.md recommendation):** add a chevron / disclosure expand-state to `HistoryRow`; expanded row shows segmented Polished/Raw `Picker` and full text `ScrollView` inline. Avoids rewriting macOS navigation model (no NavigationStack on the menu-bar window).
- **Alternative:** sheet/popover with the same content — but inline disclosure stays closest to existing macOS visual language.
- **Deviations:** macOS does NOT need a separate `HistoryDetailView.swift` file — disclosure state lives on `HistoryRow`.

### Toggle surfacing — Settings + per-row Copy default

- **Closest analog:** `Shared/Utilities/SwissDefaultMigration.swift` for one-time default seeding, plus `iOS/Dicticus/Settings/SettingsView.swift` for the toggle UI itself.
- **Pattern to follow:** UserDefaults key `cleanupCopyMode` with values `"raw"` / `"polished"`, defaulting to `"raw"`. Settings has a row "Copy mode: Polished / Raw" segmented control. The `HistoryRow.copyToClipboard` reads this default and copies the matching column.
- **Deviations:** None.

## Test patterns to follow

- **Unit tests (utilities):** `iOS/DicticusTests/SwissNumberFormatterTests.swift` is the gold reference — pure-Swift tests, fixture JSON loaded via `Bundle(for:).url(forResource:)`, hand-written explicit cases plus a fixture-corpus loop.
- **macOS service tests:** `macOS/DicticusTests/CleanupServiceTests.swift` for `@MainActor` async tests with `XCTSkipUnless(ModelDownloadService.isModelCached())` for integration paths. Mirror this for any RulesCleanupService integration path.
- **Levenshtein test fixtures:** seed with at minimum `(""→"", 0)`, `("abc"→"abc", 0)`, `("abc"→"abd", 1)`, `("ausgeflogen"→"ausgezogen", small)`, `("Franken"→"Euro", high)`, plus normalized-distance assertions.
- **Filler tests:** corpus of dictation snippets with embedded fillers; assertion that semantic words (`also`, `ja`) survive untouched.
- **Self-correction tests:** must include a `"I mean it"` negative case (no replacement should fire), `"Franken, ich meine Euro"` positive case, and a window-boundary case.
- **History detail-view snapshot:** if `swift-snapshot-testing` is in the project (verify in planning), add a snapshot for the segmented Picker + content swap. If not, defer to manual UAT.
- **Test placement:** all utility tests in `iOS/DicticusTests/` since iOS is the primary tested target; cross-platform coverage from Shared/ is automatic.

## Cross-platform parity notes

Per `feedback_cleanup_cross_platform_parity` memory, every cleanup-pipeline change ships on macOS + iOS together. The following items must land in the same atomic phase:

1. `Shared/Services/CleanupService.swift` temp lowering + prompt verb change → both platforms automatically (Shared/ is compiled into both apps).
2. `Shared/Services/TextProcessingService.swift` Step 2c + 3a → both platforms automatically.
3. `Shared/Services/HistoryService.swift` graceful degradation → both platforms automatically (with a Settings-warning surface that needs UI on each platform).
4. `Shared/Utilities/Levenshtein/Filler/SelfCorrection/CurrencyFolder` → both platforms automatically.
5. **Asymmetric** — iOS gets a new `HistoryDetailView.swift` (sheet/navigation push). macOS gets `HistoryRow` inline disclosure expansion. Both expose raw + polished + per-row Copy mode.
6. **Asymmetric** — iOS Settings adds a "Copy mode" segmented control row. macOS Settings adds the same row in its existing `SettingsSection`. Both write the same UserDefaults key.

The Levenshtein gate, filler removal, self-correction, and currency-fold are deterministic — fixture-tested in `iOS/DicticusTests/` covers macOS too because the code is in `Shared/`. The macOS test target imports the same Shared/ files; if a macOS-specific fixture path is needed it must be added separately, but the recommended TDD path is iOS-tests-first.

## Files that should NOT be touched in Phase 20

- `Shared/Models/SwissHelvetisms.swift` — Phase 19.5 locked content; no Phase 20 edits expected.
- `Shared/Utilities/CurrencyAntiFlip.swift` — Phase 19.5 locked detection logic; no Phase 20 edits expected.
- `Shared/Utilities/SwissDefaultMigration.swift` — Phase 19.5 default-seed logic; no Phase 20 edits expected.
- `iOS/Dicticus/Settings/AiCleanupSection.swift` — Phase 19 settings section; expect minimal additive edit only (Copy-mode row + App-Group fallback warning), nothing else.
