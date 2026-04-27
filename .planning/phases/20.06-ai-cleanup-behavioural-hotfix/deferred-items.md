# Deferred items — Phase 20.06

## Pre-existing iOS build break (NOT caused by 20.06-01)

`iOS/Dicticus/Services/IOSTranscriptionService.swift` fails to compile against the
current FluidAudio SDK pinned in `iOS/project.yml`:

- line 232:70 — error: missing argument for parameter 'decoderState' in call
- line 234:65 — error: cannot infer contextual base in reference to member 'whitespacesAndNewlines'

Confirmed pre-existing by stashing the 20.06-01 patch and re-running
`xcodebuild build -project iOS/Dicticus.xcodeproj` — same errors on base
commit 452ddb6 (the worktree base). Independent of the HELVETISMS prompt edit.

**Action:** track separately. Plan 20.06-01 ships the macOS-side prompt fix;
the Shared/ source itself is platform-agnostic and the macOS build proves the
Swift compiles. iOS verification of the prompt change will land via the iOS
test target once the FluidAudio API drift is resolved (separate plan).
