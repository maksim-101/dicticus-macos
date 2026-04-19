# Phase 6: Bug Fixes & Reactivity - Context

**Gathered:** 2026-04-19
**Status:** Ready for planning

<domain>
## Phase Boundary

Fix two existing defects in the v1.0 codebase:
1. **CLEAN-01:** Cleanup output injects quotation marks not present in original speech
2. **UX-01:** Menu bar icon does not reactively update for transcribing and cleaning states

No new features. Both are bug fixes on shipped functionality.

</domain>

<decisions>
## Implementation Decisions

### Quote Stripping (CLEAN-01)
- **D-01:** Strip ALL quotation marks from LLM cleanup output unconditionally — dictation does not need literal quotes, and the model injects them unpredictably
- **D-02:** Cover all Unicode quote variants: ASCII `"`, smart quotes `""`, German low-9 `„`, guillemets `«»`, single curly `''`
- **D-03:** Implement as a final step in `stripPreamble()` after all other post-processing, using `CharacterSet`-based removal
- **D-04:** Existing surrounding-quote stripping (lines 459-463 in CleanupService.swift) becomes redundant but harmless — can be left or removed at implementer's discretion

### Icon State Reactivity (UX-01)
- **D-05:** Root cause: `@State private var transcriptionService/cleanupService` in DicticusApp.swift does not observe `@Published` changes on `ObservableObject` reference types — SwiftUI's `@State` is for value types
- **D-06:** Fix by relaying pipeline state through `HotkeyManager` (already `@StateObject` in DicticusApp, so SwiftUI observes its `@Published` properties)
- **D-07:** Add `@Published var pipelineState: PipelineState` enum to HotkeyManager with cases: `idle`, `recording`, `transcribing`, `cleaning`
- **D-08:** HotkeyManager subscribes to `TranscriptionService.$state` and `CleanupService.$state` via Combine and updates `pipelineState` accordingly
- **D-09:** `iconName` computed property in DicticusApp switches on `hotkeyManager.pipelineState` instead of reading `@State` service properties directly
- **D-10:** Remove `@State private var transcriptionService/cleanupService` from DicticusApp if no longer needed after the relay pattern is in place

### Testing
- **D-11:** Unit tests for quote stripping covering edge cases: mid-text quotes, mixed Unicode quote types, empty string after stripping, text with no quotes (passthrough)
- **D-12:** Manual UAT for icon reactivity — visual state transitions cannot be meaningfully unit tested
- **D-13:** UAT checklist: (1) plain dictation shows mic.fill → waveform.circle → mic, (2) cleanup dictation shows mic.fill → waveform.circle → sparkles → mic, (3) all transitions visible without opening any panel

### Claude's Discretion
- Whether to remove the existing surrounding-quote strip code (D-04) or leave it as defense-in-depth
- Exact Combine wiring pattern for HotkeyManager state relay (sink vs assign)
- Whether `PipelineState` enum lives in HotkeyManager or a separate file

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Bug Context
- `Dicticus/Dicticus/Services/CleanupService.swift` — stripPreamble() at line 355, existing surrounding-quote strip at lines 459-463
- `Dicticus/Dicticus/Models/CleanupPrompt.swift` — Current prompt with "no quotes" instruction (line 37)
- `Dicticus/Dicticus/DicticusApp.swift` — @State service properties (lines 15-20), iconName computed property (lines 93-108), label closure (lines 35-81)

### Service Contracts
- `Dicticus/Dicticus/Services/TranscriptionService.swift` — State enum (.idle, .recording, .transcribing), @Published state property
- `Dicticus/Dicticus/Services/HotkeyManager.swift` — Existing @StateObject in DicticusApp, pipeline orchestration

### Requirements
- `.planning/REQUIREMENTS.md` — CLEAN-01 (line 13), UX-01 (line 35)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `CleanupService.stripPreamble()` — Existing post-processing pipeline where quote stripping naturally fits as a final step
- `HotkeyManager` — Already @StateObject in DicticusApp, already owns pipeline lifecycle (setup, recording, transcription, cleanup calls)
- `CleanupServiceTests.swift` — Existing test file with `stripPreamble` tests to extend

### Established Patterns
- All services are `@MainActor ObservableObject` with `@Published` state enums
- `HotkeyManager` already references `TranscriptionService` and `CleanupService` — Combine subscriptions fit naturally
- Post-processing in `stripPreamble()` follows a sequential strip-normalize-clean pattern

### Integration Points
- `DicticusApp.swift` label closure — where iconName is computed and symbolEffect is applied
- `HotkeyManager.setup()` — where TranscriptionService and CleanupService are wired in (natural place to set up Combine subscriptions)

</code_context>

<specifics>
## Specific Ideas

No specific requirements — standard bug fix approaches apply.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 06-bug-fixes-reactivity*
*Context gathered: 2026-04-19*
