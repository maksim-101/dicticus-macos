---
phase: 25-ai-cleanup-quality-v3-brand-acronym-recognition
plan: 02
type: execute
wave: 1
depends_on: []
files_modified:
  - Shared/Services/TextProcessingService.swift
  - macOS/DicticusTests/TextProcessingServiceTests.swift
  - iOS/DicticusTests/TextProcessingServiceTests.swift
autonomous: true
requirements: []
must_haves:
  truths:
    - "When DEBUG_RECORDER is compiled in AND mode == .plain, a JSONL record is appended to the daily DebugRecordings file."
    - "Plain-mode records contain raw, post_dict, post_itn, post_swiss, post_rules (= same as post_swiss in plain mode), and post_swiss_num steps; LLM steps (llm_prompt, llm_raw, post_gate) are nil/absent."
    - "Plain-mode records set mode field to the value of DictationMode.plain.rawValue, distinguishing them from aiCleanup records at analysis time."
    - "File rotation, daily file naming (cleanup-YYYY-MM-DD.jsonl), and 14-day retention apply identically to plain-mode and aiCleanup records — no second file path is created."
    - "macOS and iOS both ship this behavior in the same plan; the change lives in Shared/ so a single edit affects both."
    - "All Phase 24 tests (27/27 SelfCorrectionResolverTests, 10/10 CleanupPromptTests) still pass."
  artifacts:
    - path: "Shared/Services/TextProcessingService.swift"
      provides: "Plain-mode DebugRecorder write path"
      contains: "mode == .plain"
    - path: "macOS/DicticusTests/TextProcessingServiceTests.swift"
      provides: "Test exercising plain-mode DEBUG_RECORDER write path on macOS"
      contains: "testPlainModeWritesDebugRecord"
    - path: "iOS/DicticusTests/TextProcessingServiceTests.swift"
      provides: "Test exercising plain-mode DEBUG_RECORDER write path on iOS"
      contains: "testPlainModeWritesDebugRecord"
  key_links:
    - from: "Shared/Services/TextProcessingService.swift"
      to: "Shared/Diagnostics/DebugRecorder.swift"
      via: "await DebugRecorder.shared.record(record) under #if DEBUG_RECORDER for plain mode"
      pattern: "DebugRecorder\\.shared\\.record"
    - from: "macOS/DicticusTests/TextProcessingServiceTests.swift"
      to: "Shared/Services/TextProcessingService.swift"
      via: "DEBUG_RECORDER-guarded test asserts a record is appended when mode == .plain"
      pattern: "DictationMode\\.plain"
---

<objective>
Make plain-mode dictation observable in the same JSONL stream as AI-cleanup dictation, so Phase 25's capture-window v2 (plan 25-04) can do an apples-to-apples plain-vs-AI A/B from production data.

Purpose: Currently `TextProcessingService.swift` gates the entire `#if DEBUG_RECORDER` write block behind `mode == .aiCleanup` (implicitly — lines 134-321 are inside the `if mode == .aiCleanup` branch for the LLM section, and the record assembly at lines 287-320 references LLM-only fields like `llm_prompt` and `llm_raw`). That means a Debug-Recorder build dictating in plain mode produces ZERO JSONL records, so plain output cannot be A/B-compared to AI output from the same capture window.

Output: A self-contained edit to `TextProcessingService.swift` (Shared, so it ships macOS + iOS in one go) that extends the record-emission path to plain mode with LLM-section fields set to nil. Plus parity tests on both platforms that exercise the new write path under DEBUG_RECORDER.

This plan runs in parallel with 25-01 (no dependency). Whichever lands first does not block the other.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/STATE.md
@.planning/phases/25-ai-cleanup-quality-v3-brand-acronym-recognition/25-CONTEXT.md
@Shared/Services/TextProcessingService.swift
@Shared/Diagnostics/DebugRecorder.swift

<interfaces>
<!-- Key types from DebugRecorder.swift (lines 22-83). Extracted so executor needs no further exploration. -->

```swift
// Shared/Diagnostics/DebugRecorder.swift (DEBUG_RECORDER compile-flag only)
public actor DebugRecorder {
    public static let shared: DebugRecorder
    public func record(_ rec: DebugCleanupRecord)
}

public struct DebugCleanupRecord: Codable, Sendable {
    public let ts: String
    public let session_id: String
    public let lang: String
    public let mode: String              // <-- this is where plain-mode flag lands
    public let model: ModelInfo
    public let sampler: SamplerInfo
    public let steps: Steps
    public let dictionary_context_keys: [String]
    public let anomaly: Anomaly

    public struct Steps: Codable, Sendable {
        public let raw: StepEntry
        public let post_dict: StepEntry
        public let post_itn: StepEntry
        public let post_swiss: StepEntry
        public let post_rules: StepEntry
        public let llm_prompt: LLMPromptEntry?   // OPTIONAL — nil in plain mode
        public let llm_raw: LLMRawEntry?         // OPTIONAL — nil in plain mode
        public let post_gate: GateEntry?         // OPTIONAL — nil in plain mode
        public let post_swiss_num: StepEntry
    }
}
```

The `Steps` struct already has all three LLM fields as Optional. Plain-mode emission simply passes `nil` for those three, no DebugRecorder schema change required.

**Pre-flight verified (2026-05-16 plan-check):** Shared/Diagnostics/DebugRecorder.swift:74-76 declares `llm_prompt: LLMPromptEntry?`, `llm_raw: LLMRawEntry?`, `post_gate: GateEntry?` — all Optional. Plain-mode records will simply omit those three keys. No schema change to DebugRecorder.swift required; it stays out of files_modified.
</interfaces>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Extend TextProcessingService to emit DebugRecorder records in plain mode</name>
  <read_first>
    - Shared/Services/TextProcessingService.swift (full file — current 326 lines)
    - Shared/Diagnostics/DebugRecorder.swift (reference only — Optional fields at lines 74-76 confirmed pre-flight; see interfaces block above)
    - macOS/DicticusTests/TextProcessingServiceTests.swift (existing test scaffold patterns)
    - iOS/DicticusTests/TextProcessingServiceTests.swift (iOS test scaffold patterns)
  </read_first>
  <behavior>
    - When `mode == .plain` AND DEBUG_RECORDER is compiled in, `process(...)` appends one JSONL record to the daily DebugRecordings file with `mode = DictationMode.plain.rawValue`.
    - The plain-mode record's `steps.llm_prompt`, `steps.llm_raw`, `steps.post_gate` are all `nil`.
    - The plain-mode record's `steps.post_rules` equals `steps.post_swiss` (since plain mode skips the rules-cleanup branch at TextProcessingService.swift:114-120).
    - The plain-mode record's `dictionary_context_keys` is `[]` (plain mode never builds the targeted context).
    - The plain-mode record's `anomaly.degenerate_collapse` is `false` (no LLM, no collapse class possible) and `anomaly.very_short_output` follows the same `< 5 chars vs > 30 input` rule used in AI mode.
    - Existing AI-cleanup recorder behavior is byte-for-byte unchanged for `mode == .aiCleanup` — diff of a captured aiCleanup record before and after this change is empty.
    - File path, file naming (`cleanup-YYYY-MM-DD.jsonl`), and 14-day retention are unchanged — DebugRecorder owns those, this plan does not touch them.
  </behavior>
  <action>
**Approach (do NOT duplicate code paths):**

The current file already collects `dbgRawText, dbgPostDict, dbgPostItn, dbgPostSwiss, dbgPostRules, dbgPostSwissNum` step snapshots in the OUTER scope (not inside the `if mode == .aiCleanup` branch). The LLM-section snapshots (`dbgPreGate, dbgGateEntry, dbgDictKeys, cleanupTrace, llmPromptEntry, llmRawEntry`) are inside the AI branch or initialized to defaults at the outer scope.

Refactor so the record-build + `DebugRecorder.shared.record(record)` call at lines 287-320 fires for BOTH `mode == .aiCleanup` AND `mode == .plain`. Concrete edits:

1. Move the declaration of `dbgPostRules`, `dbgPostRulesMs`, `dbgGateEntry`, `dbgDictKeys` (currently in the AI branch at lines 127-132) up so they are unconditionally available — initialize `dbgPostRules = dbgPostSwiss` and `dbgPostRulesMs = 0` for the plain path. `dbgGateEntry` starts `nil`. `dbgDictKeys` starts `[]`. The AI branch overwrites them on its path (no behavior change for AI mode).
2. At lines 257-321, KEEP the `#if DEBUG_RECORDER` block but DROP any implicit assumption that a CleanupServiceTrace is present. `cleanupTrace` is already nil-guarded — verify and document this. `llmPromptEntry` and `llmRawEntry` already default to nil when `cleanupTrace == nil`.
3. Wrap the record assembly so it runs for both modes. Specifically:
    - The outer `#if DEBUG_RECORDER` already wraps lines 257-321.
    - There is no `if mode == .aiCleanup` gate around the record assembly itself (verify by re-reading lines 257-321) — the assembly already runs unconditionally inside DEBUG_RECORDER.
    - **However**, the *upstream* AI-only initializations (e.g. `dbgGateEntry` declared inside the AI branch) mean the record assembly currently only compiles because the AI branch always runs. Fix per (1).
4. Confirm `mode.rawValue` for plain mode resolves to a stable string (likely "plain") — Look it up in `DictationMode` definition and document the literal value in a short header comment on the record-emission block: `// Plain-mode records: mode == "plain". AI-cleanup records: mode == "aiCleanup". Same daily JSONL file.`
5. Add a one-line phase tag in the file header doc-comment summarizing this change under a `/// Phase 25-02 (2026-05-...)` block, matching the existing dated-block convention seen in the V5/V15/Phase 22/24 comment patterns in this file.

**Anti-regression:** DO NOT touch the AI-cleanup write path's content. Run the macOS test target first to confirm `testAICleanupModeWritesDebugRecord` (or equivalent) still produces an identical record shape for AI mode.
  </action>
  <verify>
    <automated>
      cd macOS && xcodebuild -project Dicticus.xcodeproj -scheme Dicticus -destination 'platform=macOS' -configuration Debug build 2>&1 | tail -5 && \
      xcodebuild -project Dicticus.xcodeproj -scheme Dicticus -destination 'platform=macOS' -configuration Debug test -only-testing:DicticusTests/TextProcessingServiceTests -only-testing:DicticusTests/CleanupPromptTests -only-testing:DicticusTests/SelfCorrectionResolverTests 2>&1 | tail -20
    </automated>
  </verify>
  <done>TextProcessingService.swift compiles on macOS and iOS (Shared file). All Phase 24 tests still green. The DebugRecorder write path no longer requires `mode == .aiCleanup` for plain-mode records to be emitted.</done>
  <acceptance_criteria>
    - `grep -n 'mode == .aiCleanup' Shared/Services/TextProcessingService.swift` shows the gate is ONLY around the AI-specific compute (Step 3 LLM call and Step 3a gate), not around the DEBUG_RECORDER record assembly.
    - 27/27 SelfCorrectionResolverTests and 10/10 CleanupPromptTests pass on macOS after the edit.
    - Existing TextProcessingServiceTests pass on macOS after the edit (no regression to AI-mode record shape).
  </acceptance_criteria>
</task>

<task type="auto" tdd="true">
  <name>Task 2: Add parity test on macOS AND iOS exercising plain-mode DEBUG_RECORDER write</name>
  <read_first>
    - macOS/DicticusTests/TextProcessingServiceTests.swift (existing test patterns — how DEBUG_RECORDER is exercised today, how DebugRecorder file paths are isolated per test, how DictationMode is constructed)
    - iOS/DicticusTests/TextProcessingServiceTests.swift (iOS variant — verify the same test scaffold exists / can be added)
    - Shared/Diagnostics/DebugRecorder.swift lines 96-118 (directoryURL is fixed to ~/Library/Application Support/Dicticus/DebugRecordings — tests may need to either tolerate that path or use an alternate test-only path)
  </read_first>
  <behavior>
    - `testPlainModeWritesDebugRecord` (macOS) and a matching iOS variant exercise `TextProcessingService.process(text:..., mode: .plain, ...)` under the DEBUG_RECORDER compile flag, then assert that at least one new line is appended to the day's JSONL file with `"mode":"plain"` and `"llm_prompt":null` (or absent) and `"llm_raw":null`.
    - The test cleans up its appended line (or uses a unique session_id and filters for it) so reruns do not accumulate noise.
    - The test is `#if DEBUG_RECORDER`-gated so non-Debug-Recorder build targets still compile.
    - The test verifies BOTH that plain-mode emits a record AND that AI-cleanup mode (run in the same test) still emits a record with `mode == "aiCleanup"` and non-nil LLM fields — proves no regression.
  </behavior>
  <action>
**macOS:** Add `testPlainModeWritesDebugRecord` to `macOS/DicticusTests/TextProcessingServiceTests.swift`. Pattern:

```swift
#if DEBUG_RECORDER
func testPlainModeWritesDebugRecord() async throws {
    let svc = TextProcessingService(cleanupService: nil)  // plain mode does not need cleanupService
    let session = UUID().uuidString
    // Wire a way to detect THIS test's record — either swizzle session_id, or
    // record a unique input string and filter the JSONL for it.
    let unique = "phase25-02-plain-probe-\(session.prefix(8))"
    _ = await svc.process(text: unique, language: "en", mode: .plain, confidence: 1.0)

    let dir = FileManager.default
        .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("Dicticus/DebugRecordings")
    let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
    f.timeZone = TimeZone(secondsFromGMT: 0)
    let fileURL = dir.appendingPathComponent("cleanup-\(f.string(from: Date())).jsonl")

    // Allow the actor a tick to flush.
    try await Task.sleep(nanoseconds: 50_000_000)
    let lines = try String(contentsOf: fileURL).split(separator: "\n").map(String.init)
    let match = lines.first { $0.contains(unique) }
    XCTAssertNotNil(match, "expected plain-mode record containing '\\(unique)' in \\(fileURL.path)")
    let line = try XCTUnwrap(match)
    XCTAssertTrue(line.contains("\\"mode\\":\\"plain\\""), "expected mode=plain in record")
    XCTAssertTrue(line.contains("\\"llm_prompt\\":null") || !line.contains("llm_prompt"), "llm_prompt should be null/absent in plain mode")
}
#endif
```

If `DictationMode.plain.rawValue` is not "plain", substitute the actual string. Read the enum first.

**iOS:** Mirror the same test in `iOS/DicticusTests/TextProcessingServiceTests.swift`. The iOS app's Application Support path differs (sandbox), so the file URL lookup is identical (`FileManager.default.urls(for: .applicationSupportDirectory, ...)` resolves correctly under the iOS simulator). DO NOT skip iOS — the cross-platform parity rule (`feedback_cleanup_cross_platform_parity` memory) requires both targets.

Adjacent assertion: in the same test, also run a `mode: .aiCleanup` cycle (with a stub `CleanupProvider` if needed) and confirm an `"mode":"aiCleanup"` line is present in the same file. This locks the no-regression invariant.

**Test-pollution mitigation:** Each test run dirties the user's real DebugRecordings JSONL file. That is acceptable for now (the existing AI-cleanup test, if any, has the same property). Document in a `// NOTE:` comment that the test appends to the real user file and is safe under DEBUG_RECORDER only.
  </action>
  <verify>
    <automated>
      cd macOS && xcodebuild -project Dicticus.xcodeproj -scheme Dicticus -destination 'platform=macOS' -configuration Debug -derivedDataPath build/macos-debug test -only-testing:DicticusTests/TextProcessingServiceTests/testPlainModeWritesDebugRecord SWIFT_ACTIVE_COMPILATION_CONDITIONS='DEBUG DEBUG_RECORDER' 2>&1 | tail -10
    </automated>
  </verify>
  <done>`testPlainModeWritesDebugRecord` passes on macOS (compiled with `-D DEBUG_RECORDER`). iOS test added with same name and structure; compiles under both DEBUG and DEBUG_RECORDER active compilation conditions.</done>
  <acceptance_criteria>
    - `testPlainModeWritesDebugRecord` exists in BOTH `macOS/DicticusTests/TextProcessingServiceTests.swift` AND `iOS/DicticusTests/TextProcessingServiceTests.swift`.
    - Both tests are gated behind `#if DEBUG_RECORDER` so non-Debug-Recorder builds compile.
    - macOS test run passes under `-D DEBUG_RECORDER` (verify command above).
    - iOS test compiles cleanly — runtime execution is a nice-to-have but not blocking (iOS simulator runtime is gated on local SDK; per Phase 22's precedent, compile-clean on iOS is sufficient when SDK runtime is unavailable).
  </acceptance_criteria>
</task>

</tasks>

<verification>
- Run the macOS full test suite under `-D DEBUG_RECORDER`: `xcodebuild ... test SWIFT_ACTIVE_COMPILATION_CONDITIONS='DEBUG DEBUG_RECORDER'`. All of `TextProcessingServiceTests`, `CleanupPromptTests`, `SelfCorrectionResolverTests` green.
- Run the macOS full test suite WITHOUT `-D DEBUG_RECORDER` (the production build flag set). Same suites green — confirms `#if DEBUG_RECORDER` guards compile both branches cleanly.
- Manual probe (optional): launch a local Debug-Recorder build (`scripts/install-local.sh`), dictate a short utterance in plain mode, `tail -1 ~/Library/Application\ Support/Dicticus/DebugRecordings/cleanup-$(date +%Y-%m-%d).jsonl | python3 -m json.tool` and confirm `"mode": "plain"`, LLM fields null/absent.
</verification>

<success_criteria>
- Plain-mode dictation cycles produce JSONL records in the same daily file as aiCleanup cycles, distinguishable by the `mode` field.
- Zero changes to AI-cleanup recorder behavior (record shape diff = empty for `mode == "aiCleanup"`).
- macOS and iOS both ship the new test in parity.
- Phase 24's regression invariants hold: 27/27 SelfCorrectionResolverTests, 10/10 CleanupPromptTests green on macOS.
- Plan 25-04's capture window v2 can now collect plain-mode data without further plumbing.
</success_criteria>

<output>
After completion, create `.planning/phases/25-ai-cleanup-quality-v3-brand-acronym-recognition/25-02-SUMMARY.md` capturing:
- Diff summary of `Shared/Services/TextProcessingService.swift` (line range edited, what changed).
- Cross-platform parity proof: paths to the two test files + their test names.
- One captured example plain-mode JSONL record (anonymized — strip any real dictation content, keep schema only).
- Confirmation that Phase 24 regression invariants still hold.
</output>
