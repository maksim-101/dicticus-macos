# Phase 20.08 Deferred Items

## Out-of-scope discoveries during plan 20.08-01 execution

### iOS FluidAudio API drift (pre-existing, unrelated to plan changes)

**Discovered:** 2026-04-27 during plan 20.08-01 (worktree agent-a6aea3d9ae2b69bec).

**Symptom:** `xcodebuild build -scheme Dicticus -destination 'platform=iOS Simulator,name=iPhone 17' -project iOS/Dicticus.xcodeproj` fails compiling `iOS/Dicticus/Services/IOSTranscriptionService.swift`:

- `IOSTranscriptionService.swift:232:70: error: missing argument for parameter 'decoderState' in call`
- `IOSTranscriptionService.swift:234:65: error: cannot infer contextual base in reference to member 'whitespacesAndNewlines'`

**Provenance:** Same drift documented in Phase 20.06-01 SUMMARY and explicitly flagged in `20.08-RESEARCH.md` §7 risk #3 + `20.08-PATTERNS.md` cross-cutting issue #4 as "may need to be deferred."

**Scope decision:** Out of scope for plan 20.08-01 — `SwissDialectForms.swift` and the associated test files do not touch FluidAudio APIs. Per executor SCOPE BOUNDARY rule, only auto-fix issues directly caused by current task changes.

**Plan 20.08-01 acceptance criteria explicit fallback:** Task 2 acceptance criteria allow either iOS test execution OR a documented deferral citing the FluidAudio drift. Macros twin (Task 3) must still pass — this is the proof of `Shared/` correctness.

**iOS test status for plan 20.08-01:** DEFERRED. iOS test target cannot build until FluidAudio drift is resolved. macOS test execution provides the proof of `SwissDialectForms.swift` correctness.

**Owner:** Future iOS hotfix phase (likely Phase 20.07 or 21).
