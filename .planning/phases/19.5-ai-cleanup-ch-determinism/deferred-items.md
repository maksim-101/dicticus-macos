# Phase 19.5 — Deferred Items

Items discovered during execution that are out of scope for the current task per
GSD scope-boundary rules. Documented here for follow-up; NOT fixed in-line.

## D-19.5-01-DEF1 — Pre-existing iOS build failures in `IOSTranscriptionService.swift`

**Discovered during:** Plan 19.5-01 verification build
**Files:** `iOS/Dicticus/Services/IOSTranscriptionService.swift`
**Errors (verbatim from xcodebuild):**

1. Line 232: `error: missing argument for parameter 'decoderState' in call`
   - Call: `try await asrManager.transcribe(resampledSamples)`
   - FluidAudio signature now requires: `transcribe(_:decoderState:language:)` with
     `decoderState: inout TdtDecoderState` (no default).
   - Likely cause: FluidAudio package was bumped in `iOS/project.yml`
     (`from: 0.13.6`) and resolved to a newer version where the API changed.

2. Line 234: `error: cannot infer contextual base in reference to member 'whitespacesAndNewlines'`
   - Call: `result.text.trimmingCharacters(in: .whitespacesAndNewlines)`
   - Likely a cascade from the prior compile error; or the changed `result.text`
     return type lost `String` inference.

**Why deferred:** These errors exist on the base commit
(`72742237c5fccb504e7fbcf24312e10918bc06d8`) prior to any Plan 19.5-01 edit.
Plan 19.5-01's `<files_modified>` does not include `IOSTranscriptionService.swift`;
fixing these would require a FluidAudio API migration that is out of scope
for the B2 stale-`hasModels` fix.

**Verification of pre-existence:** `git diff HEAD -- iOS/Dicticus/Services/IOSTranscriptionService.swift`
returns empty after applying Plan 19.5-01 edits (file untouched by this plan).

**Recommended follow-up:** Open a new GSD task (e.g., `/gsd-debug` or a Phase 19.6 plan)
to migrate `IOSTranscriptionService.swift` to the current FluidAudio API surface
(`decoderState: inout TdtDecoderState`).

**Impact on Plan 19.5-01 acceptance:** The build does not produce `BUILD SUCCEEDED`.
However, all grep-based acceptance criteria for the actual code edits (W6 split,
B1 shape gate, invocation count) pass. The plan's intent (refresh `hasModels`
from disk on warmup entry and on scenePhase `.active`) is achieved by the source
edits. The build failure is in an unrelated file and predates this plan.
