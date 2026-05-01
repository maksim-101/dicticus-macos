---
phase: 20-ai-cleanup-demotion-uat-visibility
verified: 2026-04-27T05:35:00Z
status: human_needed
score: 11/12 must-haves verified (1 with regression caveat)
overrides_applied: 0
gaps:
  - truth: "Phase 19/19.5 regression contract: existing CleanupPromptTests.testDefaultInstructionContent must still pass"
    status: failed
    reason: "Phase 20-02 reworded CleanupPrompt.defaultInstruction (removed 'grammatically correct' phrase + removed 'digits' instruction) but did NOT update the pre-existing macOS test that asserts both substrings. Test now fails with two assertion errors."
    artifacts:
      - path: "macOS/DicticusTests/CleanupPromptTests.swift"
        issue: "Lines 59–60 assert defaultInstruction contains 'grammatically correct' and 'digits' — both substrings were intentionally removed in 28bc664 (feat(20.02): swap CleanupPrompt verb)."
      - path: "Shared/Models/CleanupPrompt.swift"
        issue: "New default uses 'obvious grammar' (not 'grammatically correct') and no longer instructs digit conversion (moved to ITN/RulesCleanupService per plan)."
    missing:
      - "Update macOS/DicticusTests/CleanupPromptTests.swift line 56–62 to reflect the new prompt vocabulary: replace 'grammatically correct' assertion with 'obvious grammar' (or 'punctuation'), and replace 'digits' assertion with a check that confirms the absence of digit guidance (e.g. !instruction.contains('digit')) — consistent with the Phase 20 contract that ITN handles digits, not the LLM."
      - "Verify no parallel iOS-side CleanupPromptTests assertion exists that needs the same update (a quick grep shows iOS bundle has no CleanupPromptTests.swift, so only the macOS file is affected)."
human_verification:
  - test: "Run iOS app build (xcodebuild build -scheme Dicticus -destination 'platform=iOS Simulator,name=iPhone 16') after resolving the local SPM/GRDB submodule clone issue noted in 20-05-SUMMARY.md."
    expected: "BUILD SUCCEEDED on iOS Simulator destination."
    why_human: "Orchestrator-level iOS build was blocked by an environmental SPM issue (GRDB.swift submodule clone fails inside DerivedData). Verifier cannot reproduce a clean iOS DerivedData from this sandbox. macOS build verified GREEN with the same Shared/ sources."
  - test: "Wire `-uiTestsSeedHistory 1` launchArgument handling into the iOS host app startup path so `iOS/DicticusUITests/HistoryDetailViewTests` actually exercises the Picker + Copy assertions instead of XCTSkipping."
    expected: "All four test methods (testPickerDefaultsToRaw, testPolishedSegmentSelectable, testRawSegmentSelectable, testCopyButtonRespectsSelection) execute and pass; none XCTSkip due to missing host wiring."
    why_human: "Plan 20-05 acknowledges the seed wiring was deferred. Today the UI tests skip silently — they compile and run but assert nothing about the Picker contract until the host honours the launchArgument. This is a real gap in the Visibility contract's automated coverage."
  - test: "Manual UAT on iOS Simulator with App Group entitlement intentionally stripped from the dev signing — confirm the simulator launches without crashing and the AiCleanupSection shows the yellow 'History storage degraded' warning row."
    expected: "App launches; Settings shows warning row; pre-Phase-20 simulator-crash regression is gone."
    why_human: "Cannot strip entitlements programmatically from this sandbox without modifying the project file. Plan 20-04's primary user-facing behavior change (no-crash on missing App Group) requires a manual signing-stripped run to fully confirm. The fatalError IS removed from the source (verified) and a fallback path IS implemented (verified), but the end-to-end 'no crash' assertion is observable only by running the app."
  - test: "Manual UAT for the four Phase 20 quality scenarios on a real device: (1) hallucination resilience (utter 'ich bin ausgeflogen' → polished should NOT become 'ausgezogen'); (2) currency-fold ('15 Franken 50 Rappen' → 'CHF 15.50'); (3) self-correction ('110 Franken, ich meine 110 Euro' → '110 Euro'); (4) raw vs polished toggle in the iOS HistoryDetailView."
    expected: "All four scenarios behave per CONTEXT.md spec. Hallucination is gated; currency canonicalizes; self-correction drops the reparandum; toggle swaps raw/polished display and Copy honors selection."
    why_human: "These require real microphone input, a loaded Gemma 4 model, and end-to-end pipeline execution. Test fixtures cover the rules-side determinism (40 cases, 14 adversarial) but the LLM gate's behavior on real hallucinated outputs needs human transcription + judgment. This is the explicit UAT step `/gsd-uat` referenced in plan 20-05's <output> block."
---

# Phase 20: AI Cleanup Demotion + UAT Visibility — Verification Report

**Phase Goal:** Demote the LLM cleanup stage from authoritative rewriter to optional polish layer. Move deterministic cleanup (filler removal, currency-fold, self-correction) into Swift; gate the LLM behind a Levenshtein verification step with a low-creativity prompt; expose raw vs. polished output in the iOS history detail view; replace the App-Group-container `fatalError` in HistoryService with graceful degradation so the app never crashes when entitlements are missing.

**Verified:** 2026-04-27T05:35:00Z
**Status:** human_needed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

Derived from the Phase Goal + the four CONTEXT.md actions (no explicit Success Criteria block in ROADMAP for this phase — phase goal is the contract).

| #   | Truth | Status | Evidence |
| --- | ----- | ------ | -------- |
| 1 | LLM sampler temperature lowered to 0.1 (Action 1) | VERIFIED | `Shared/Services/CleanupService.swift:124` — `llama_sampler_init_temp(0.1)`; preceding comment line 123 cites `gateLLMOutput`. No `0.2` literal remains outside comments. |
| 2 | Default cleanup prompt verb changed to "Lightly edit" (Action 1) | VERIFIED | `Shared/Models/CleanupPrompt.swift:16` — `Lightly edit the following transcribed text…`. Word "Rewrite" appears only in the rationale comment on line 4. |
| 3 | LevenshteinDistance utility exists with `distance` + `normalizedDistance` (Action 1) | VERIFIED | `Shared/Utilities/LevenshteinDistance.swift` — public enum with both static methods, two-row optimization, Character-array operation, 80 lines, fully documented. |
| 4 | `CleanupService.gateLLMOutput` helper + `levenshteinGateThreshold = 0.30` constant exist (Action 1) | VERIFIED | `Shared/Services/CleanupService.swift:565` (constant), `:588` (function). Normalization helper present at `:594+` (lowercased + soft-punctuation strip + whitespace collapse). |
| 5 | Filler removal moved into Swift with conservative ship list (Action 2) | VERIFIED | `Shared/Utilities/FillerWordRemover.swift:33` — germanFillers `{äh,ähm,ehm,hmm}`, `:36` — englishFillers `{uh,um,umm,er,erm}`. `also`/`halt` deliberately deferred per phase note. |
| 6 | Self-correction resolver in Swift, comma-prefix gated, ≤3 token window (Action 2) | VERIFIED | `Shared/Utilities/SelfCorrectionResolver.swift` — public `resolve(_:language:)`, connector list includes `ich meine`, `besser gesagt`, `genauer gesagt`, `oder vielmehr`, `oder besser`, `I mean`, `I meant`, `or rather`, `or better`, `scratch that`. Comma-prefix discipline documented in header comment. |
| 7 | Currency-fold rule canonicalizes "X Franken Y Rappen" → "CHF X.YY" (Action 2) | VERIFIED | `Shared/Utilities/SwissNumberFormatter.swift:79` — `foldCurrencyUnits` defined; `:55` — invoked BEFORE `bridgeCrossTokenDecimal` in `format(_:)`. Comment cites Phase 20 D-02 ordering rationale. |
| 8 | RulesCleanupService orchestrates filler → self-correction → currency-fold → whitespace (Action 2) | VERIFIED | `Shared/Services/RulesCleanupService.swift:38` — `clean(_:language:)` composes all three plus whitespace collapse + trim. Currency-fold gated on language != "en" per its docstring contract. |
| 9 | TextProcessingService Step 2c runs rules pass; Step 3a applies Levenshtein gate (Action 1+2 wiring) | VERIFIED | `Shared/Services/TextProcessingService.swift:68` — `processedText = rulesCleanupService.clean(...)`; `:73` — `let rulesCleanedText = processedText` snapshot; `:97` — `CleanupService.gateLLMOutput(rulesCleaned: rulesCleanedText, llmOutput: processedText)` inside `mode == .aiCleanup` branch only. |
| 10 | HistoryService App-Group `fatalError` replaced with graceful applicationSupport fallback (Action 4) | VERIFIED | `Shared/Services/HistoryService.swift` — `appGroupAvailable` static flag at `:72`; warning logged at `:101`; only one `fatalError` survives (`:140`, the genuinely-unrecoverable DB-init path); `makeForTesting(containerURLProvider:)` at `:148`. String "App Group container not found" gone. |
| 11 | Raw vs polished output exposed in iOS HistoryDetailView with segmented Picker (Action 3) | VERIFIED | `iOS/Dicticus/History/HistoryDetailView.swift:46` — Picker bound to `selectedVariant`; `:53` — ScrollView with `.textSelection(.enabled)`; toolbar at `:73` with Share, Copy (honors in-view selection), Delete. iOS HistoryView `:18` wraps rows in `NavigationLink(value: entry)`; `:26` declares `.navigationDestination(for: TranscriptionEntry.self)`. |
| 12 | macOS HistoryRow gains inline disclosure with same Picker (Action 3 cross-platform parity) | VERIFIED | `macOS/Dicticus/Views/HistoryView.swift:146` — `@State isExpanded`; `:147` — selectedVariant defaults to .raw; `:167` — chevron icon; `:223` — disclosure block with Picker `:225–228` and ScrollView; `:267` — per-row Copy reads `CleanupCopyMode.current`. |

**Score:** 12/12 truths verified at the artifact + wiring level. ONE truth (#2 prompt change) carries a regression caveat — see Anti-Patterns and Gap below.

### Required Artifacts

| Artifact | Expected | Status | Details |
| -------- | -------- | ------ | ------- |
| `Shared/Utilities/LevenshteinDistance.swift` | NEW, ≥50 lines, public enum | VERIFIED | 80 lines; public enum LevenshteinDistance with both static methods. |
| `Shared/Utilities/FillerWordRemover.swift` | NEW, ≥80 lines, public enum | VERIFIED | Public enum + per-language Sets + `strip(_:language:)`. |
| `Shared/Utilities/SelfCorrectionResolver.swift` | NEW, ≥100 lines, public enum | VERIFIED | Public enum `resolve(_:language:)`; connector list + comma-prefix guard. |
| `Shared/Services/RulesCleanupService.swift` | NEW, ≥30 lines, final class | VERIFIED | 58 lines; final class with single `clean(_:language:)` orchestrator. |
| `Shared/Services/TextProcessingService.swift` | MODIFIED with Step 2c + Step 3a | VERIFIED | Both wired; pipeline shape header comment lines 1–22 documents the new ordering. |
| `Shared/Services/CleanupService.swift` | MODIFIED: temp 0.1 + gate helper + threshold | VERIFIED | All three present; existing 19.5 hotfix surfaces (chat-template strip, CurrencyAntiFlip post-LLM, applySwissITN safety net) untouched per visual inspection. |
| `Shared/Models/CleanupPrompt.swift` | MODIFIED: "Lightly edit" + filler/digit guidance removed | VERIFIED (with regression — see gap) | Verb changed; digit guidance removed. Pre-existing macOS test asserting "digits" not updated. |
| `Shared/Services/HistoryService.swift` | MODIFIED: graceful fallback + flag + factory | VERIFIED | `appGroupAvailable` flag; one `fatalError` left (DB-init); `makeForTesting` under DEBUG; TranscriptionEntry conforms to Hashable. |
| `Shared/Models/CleanupCopyMode.swift` | NEW, ~25 lines, public enum | VERIFIED | 45 lines; UserDefaults key `cleanupCopyMode`, default `.raw`. |
| `iOS/Dicticus/History/HistoryDetailView.swift` | NEW, ≥80 lines, segmented Picker + Copy/Share/Delete | VERIFIED | Full implementation with empty-rawText fallback, accessibility labels. |
| `iOS/Dicticus/History/HistoryView.swift` | MODIFIED: NavigationLink + navigationDestination + Copy honors mode | VERIFIED | All three wirings present. |
| `macOS/Dicticus/Views/HistoryView.swift` | MODIFIED: HistoryRow inline disclosure | VERIFIED | isExpanded + chevron + Picker + ScrollView + selection-aware Copy in disclosure + global-default Copy on row. |
| `iOS/Dicticus/Settings/AiCleanupSection.swift` | MODIFIED: appGroupAvailable warning row | VERIFIED | Line 56 reads flag; warning row shown when false. |
| `macOS/Dicticus/Views/SettingsSection.swift` | MODIFIED: parity warning row + Copy mode picker | VERIFIED | Warning row line 32; Copy mode picker line 103+ with Raw/Polished tags. |
| `iOS/Dicticus/Settings/SettingsView.swift` | MODIFIED: Copy mode segmented row | VERIFIED | Lines 33–34 reference CleanupCopyMode tags; binding lines 146–149. |
| `iOS/DicticusTests/Fixtures/RulesCleanup.fixtures.json` | NEW, ≥30 entries, ≥7 adversarial | VERIFIED | 40 entries, 14 adversarial. |
| `iOS/DicticusUITests/HistoryDetailViewTests.swift` | NEW, ≥40 lines, behaviour tests | VERIFIED (with caveat) | 4 test methods present. All four use `XCTSkip` paths when `-uiTestsSeedHistory` host wiring is missing — that wiring is deferred (see human-verification item 2). |

### Key Link Verification

| From | To | Via | Status | Details |
| ---- | -- | --- | ------ | ------- |
| `TextProcessingService` | `RulesCleanupService` | `rulesCleanupService.clean` (Step 2c) | WIRED | Constructor injection (default `RulesCleanupService()`); single call site in `process(...)`. |
| `TextProcessingService` | `CleanupService.gateLLMOutput` | Static call (Step 3a) | WIRED | Single call site, only inside `mode == .aiCleanup` branch after successful LLM call. |
| `RulesCleanupService` | `SwissNumberFormatter.foldCurrencyUnits` | Direct static call | WIRED | Confirmed at `RulesCleanupService.swift:49`. |
| `CleanupService.gateLLMOutput` | `LevenshteinDistance.normalizedDistance` | Static call from gate helper | WIRED | Per `CleanupService.swift` extension body. |
| `iOS HistoryView` | `HistoryDetailView` | `NavigationLink(value:)` + `.navigationDestination(for:)` | WIRED | Both endpoints present; TranscriptionEntry conforms to Hashable so value-routing compiles. |
| `iOS Settings (AiCleanupSection)` | `HistoryService.appGroupAvailable` | SwiftUI conditional | WIRED | Static flag read at view-build time. |
| `macOS Settings (SettingsSection)` | `HistoryService.appGroupAvailable` | SwiftUI conditional | WIRED | Same pattern as iOS. |
| `iOS Settings + macOS Settings + both HistoryView Copy buttons` | UserDefaults key `cleanupCopyMode` | `CleanupCopyMode.current` getter/setter | WIRED | Single source of truth in `Shared/Models/CleanupCopyMode.swift`; consumed by all four call sites verified. |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
| -------- | ------------- | ------ | ------------------ | ------ |
| `HistoryDetailView` | `entry.rawText` / `entry.text` | TranscriptionEntry struct passed via NavigationLink value | Yes — entry comes from GRDB-loaded HistoryService; D-38 schema populates both columns | FLOWING |
| `macOS HistoryRow disclosure` | Same `entry.rawText` / `entry.text` | List binding to historyService.entries | Yes — GRDB fetch | FLOWING |
| `RulesCleanupService.clean` output → `TextProcessingService` `processedText` | Composed transform output | Real ASR text in production; unit tests cover 40 fixtures | Yes — pure transform on real input | FLOWING |
| `CleanupService.gateLLMOutput` decision | `rulesCleaned` and `llmOutput` strings | Both produced upstream in same `process(...)` call | Yes — gate compares two real strings | FLOWING |
| `iOS Settings Copy mode picker` | `CleanupCopyMode.current` binding | UserDefaults.standard read/write | Yes — `Shared/Models/CleanupCopyMode.swift` getter/setter | FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| -------- | ------- | ------ | ------ |
| macOS app builds with Phase 20 sources | `cd macOS && xcodebuild build -project Dicticus.xcodeproj -scheme Dicticus -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO` | `** BUILD SUCCEEDED **` | PASS |
| iOS app builds | `xcodebuild build -scheme Dicticus -destination 'platform=iOS Simulator,name=iPhone 16'` | Not run — environmental SPM issue per 20-05-SUMMARY | SKIP — routed to human verification |
| Phase 20 RulesCleanup fixture corpus has expected size | `jq 'length' iOS/DicticusTests/Fixtures/RulesCleanup.fixtures.json` | `40` (≥30 required) | PASS |
| Adversarial fixture coverage | `jq '[.[]\|select(.category=="adversarial")]\|length'` | `14` (≥7 required) | PASS |
| macOS DicticusTests bundle runs | `xcodebuild test -only-testing:DicticusTests` | 3 failures: `CleanupPromptTests/testDefaultInstructionContent` (Phase 20 regression), `ITNUtilityTests/testMixedText` (PRE-EXISTING from Phase 19.5 minDigitThreshold), `PermissionManagerTests/testAllGrantedReturnsTrueWhenAllGranted` (unrelated, environment) | PARTIAL — 1 Phase 20 regression confirmed |
| iOS DicticusTests bundle runs | Cannot run — environmental block | N/A | SKIP — routed to human verification |
| Only one `fatalError` survives in HistoryService | `grep -c 'fatalError' Shared/Services/HistoryService.swift` | `1` (DB-init only) | PASS |
| Sampler temp is 0.1, not 0.2 | `grep 'llama_sampler_init_temp' Shared/Services/CleanupService.swift` | `llama_sampler_init_temp(0.1)` only | PASS |
| Levenshtein gate threshold is the named constant | `grep 'levenshteinGateThreshold = 0.30' Shared/Services/CleanupService.swift` | Found at line 565 | PASS |

### Requirements Coverage

Phase 20 has no entries in `.planning/REQUIREMENTS.md` — its goals are tracked via the four CONTEXT.md actions and the ACT-* tags in plan frontmatter. Each plan's `requirements:` field declares ACT-* membership; both ACT-1 (LLM-REIN), ACT-2 (RULES), ACT-3 (VISIBILITY), and ACT-4 (RESILIENCE) all map to truths verified above.

| Action | Description | Status | Evidence |
| ------ | ----------- | ------ | -------- |
| ACT-1-LLM-REIN | Lower temp + Lightly edit verb + Levenshtein gate | SATISFIED (with regression caveat) | Truths #1, #2, #3, #4, #9 above |
| ACT-2-RULES | Filler / self-correction / currency-fold / orchestrator | SATISFIED | Truths #5, #6, #7, #8 above |
| ACT-3-VISIBILITY | iOS detail view + macOS disclosure + cross-platform Copy mode | SATISFIED (UI-test coverage dormant — see gap) | Truths #11, #12 above |
| ACT-4-RESILIENCE | Graceful App-Group fallback + flag + Settings warning | SATISFIED | Truth #10 above |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| ---- | ---- | ------- | -------- | ------ |
| `macOS/DicticusTests/CleanupPromptTests.swift` | 59–60 | Stale assertion against pre-Phase-20 prompt vocabulary (asserts "grammatically correct" + "digits" — both removed by Phase 20-02) | WARNING (regression) | Test now fails on every macOS test run. The product change is correct (digit instruction MUST move to ITN per the phase contract) but the existing test was not updated. Blocker for CI green. Easy fix. |
| `iOS/DicticusUITests/HistoryDetailViewTests.swift` | 72, 99, 106 | XCTSkip when `-uiTestsSeedHistory` launchArgument lacks host-side handling | WARNING | UI test target compiles and runs, but every assertion currently skips. Visibility contract has no end-to-end automated coverage on iOS. Plan 20-05 explicitly accepted this deferral. |

No stub artifacts found — all eight new files contain substantive implementations (verified by inspecting LevenshteinDistance, RulesCleanupService, FillerWordRemover, SelfCorrectionResolver, HistoryDetailView, CleanupCopyMode). No TODO/FIXME placeholders introduced by Phase 20 commits.

### Human Verification Required

See `human_verification` section in frontmatter. Four items requiring human follow-up:

1. **Run iOS app build** — orchestrator-level iOS build was blocked by an environmental SPM issue. Code in `Shared/` builds GREEN on macOS, so the cross-platform contract is plausibly intact, but the iOS-target-specific Glue (HistoryDetailView, iOS Settings, NavigationStack wiring) needs a clean iOS build to confirm.
2. **Wire `-uiTestsSeedHistory` in iOS host app** — without it, the four UI test methods all `XCTSkip` and the Visibility contract has no automated end-to-end coverage. Easy follow-up; tracked in 20-05-SUMMARY.md `risks-and-deferrals`.
3. **Manual UAT for App-Group-stripped simulator launch** — the no-crash assertion is observable only by running with stripped entitlements.
4. **Manual UAT for hallucination resilience, currency-fold, self-correction, raw/polished toggle** — the explicit `/gsd-uat` step queued by plan 20-05.

### Gaps Summary

**One real regression** (CleanupPromptTests.testDefaultInstructionContent): Phase 20-02 changed the prompt vocabulary but did not update the corresponding macOS-bundle test. The product change is correct per the phase contract — digit guidance moves to ITN, "grammatically correct" was just a phrasing — but the test wasn't reconciled. Estimated 5-line fix in `macOS/DicticusTests/CleanupPromptTests.swift` lines 56–62.

**Two pre-existing failures** observed but NOT attributed to Phase 20:
- `ITNUtilityTests.testMixedText` — pre-existing breakage from Phase 19.5's `minDigitThreshold = 10` addition (test expects "5 birds" but ITN now leaves single-digit numbers as words by design). Inherited by Phase 20 branch from main.
- `PermissionManagerTests.testAllGrantedReturnsTrueWhenAllGranted` — unrelated environment-dependent permission test; not Phase 20.

**Goal achievement assessment:** All four CONTEXT.md actions are LANDED. The deterministic rules pipeline is the new primary cleanup path, the LLM is gated by the Levenshtein verifier, the iOS history detail view exposes raw vs polished with cross-platform Copy-mode parity, and the App-Group `fatalError` is replaced. The phase goal as stated in ROADMAP line 93 is met at the code level. Outstanding items are the one prompt-test reconciliation, two human-verification automated checks (iOS build + UI test seed wiring), and the standard `/gsd-uat` round.

**Recommendation:** Status is `human_needed` rather than `gaps_found` because the single failing test is a 5-line test reconciliation (not a product bug), the two human-verification items are environmental rather than missing implementation, and the four UAT scenarios are the explicitly-planned next step from plan 20-05's `<output>` block. The next `/gsd-plan-phase --gaps` round can pick up the prompt-test reconciliation as a single-task closure plan, or it can fold into the upcoming UAT-driven changes.

---

*Verified: 2026-04-27T05:35:00Z*
*Verifier: Claude (gsd-verifier)*
*macOS build: GREEN. macOS DicticusTests: 1 Phase-20 regression + 2 pre-existing failures (not attributable to Phase 20).*
*iOS build + iOS tests: routed to human verification per environmental constraint.*
