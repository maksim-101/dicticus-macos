# Phase 20 — Deferred Items

Out-of-scope discoveries logged during execution. Not fixed by current plans.

## Pre-existing iOS build breakage (unrelated to Phase 20 plans)

**File:** `iOS/Dicticus/Services/IOSTranscriptionService.swift:232-234`

**Errors:**
- Line 232: `missing argument for parameter 'decoderState' in call`
  — `asrManager.transcribe(resampledSamples)` no longer matches the FluidAudio
    0.14.1 API; the call needs an additional `decoderState:` argument.
- Line 234: `cannot infer contextual base in reference to member 'whitespacesAndNewlines'`
  — Cascades from line 232's failure (the result is now untyped after compile error).

**Discovered during:** Plan 20.02 Task 1 verification (`xcodebuild test -only-testing:DicticusTests/LevenshteinDistanceTests`).

**Why deferred:**
- Reproduces on the pre-Wave-2 base commit (1cc3c3f) without any Phase 20 changes applied.
- It is a FluidAudio SDK upgrade follow-up (FluidAudio bumped 0.13.6 → 0.14.1 in `Package.resolved`).
- Out of scope for plan 20-02 per SCOPE BOUNDARY rule (Levenshtein gate, prompt verb, sampler temp).

**Verification path used in plans 20-02 / 20-03:**
- macOS target builds with my changes (`xcodebuild build -scheme Dicticus -destination 'platform=macOS' CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO` → BUILD SUCCEEDED).
- Static greps confirm the planner's truth-set assertions on `Shared/` files.

**Suggested follow-up:** A separate ticket to rewire `IOSTranscriptionService.transcribe` against the FluidAudio 0.14.1 `decoderState` API, or pin `Package.resolved` back to 0.13.6.
