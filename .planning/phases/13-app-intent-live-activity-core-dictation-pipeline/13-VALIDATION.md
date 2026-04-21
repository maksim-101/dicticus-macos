---
phase: 13
slug: app-intent-live-activity-core-dictation-pipeline
status: draft
nyquist_compliant: true
wave_0_complete: false
created: 2026-04-21
updated: 2026-04-21
---

# Phase 13 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest (Xcode 26) |
| **Config file** | iOS/DicticusTests/ (test target in project.yml) |
| **Quick run command** | `xcodebuild test -project iOS/Dicticus.xcodeproj -scheme Dicticus -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:DicticusTests` |
| **Full suite command** | `xcodebuild test -project iOS/Dicticus.xcodeproj -scheme Dicticus -destination 'platform=iOS Simulator,name=iPhone 17 Pro'` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run quick test command
- **After every plan wave:** Run full suite command
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 13-01-01 | 01 | 1 | ACT-02 | T-13-01 | ContentState has no sensitive data | unit | `xcodebuild build -project iOS/Dicticus.xcodeproj -scheme Dicticus -destination 'platform=iOS Simulator,name=iPhone 17 Pro'` | N/A (build) | ⬜ pending |
| 13-01-02 | 01 | 1 | ACT-02 | T-13-02 | NSMicrophoneUsageDescription present | unit | `grep -c "NSMicrophoneUsageDescription" iOS/Dicticus/Info.plist && grep -c "NSSupportsLiveActivities" iOS/Dicticus/Info.plist` | N/A (grep) | ⬜ pending |
| 13-02-01 | 02 | 1 | ASR-01, ASR-02 | T-13-03, T-13-04 | Non-Latin script guard, three-layer VAD | unit+integration | `xcodebuild test -project iOS/Dicticus.xcodeproj -scheme Dicticus -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:DicticusTests/IOSTranscriptionServiceTests` | Created by Plan 02 Task 2 | ⬜ pending |
| 13-02-02 | 02 | 1 | ASR-03 | T-13-05 | Mic permission gated by iOS | unit | `xcodebuild test -project iOS/Dicticus.xcodeproj -scheme Dicticus -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:DicticusTests/IOSModelWarmupServiceTests` | Created by Plan 02 Task 2 | ⬜ pending |
| 13-03-01 | 03 | 2 | ACT-01, ACT-03, TEXT-01 | T-13-06, T-13-07 | NotificationCenter process-internal, clipboard write guarded | unit | `xcodebuild test -project iOS/Dicticus.xcodeproj -scheme Dicticus -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:DicticusTests/DictationViewModelTests` | Created by Plan 03 Task 2 | ⬜ pending |
| 13-03-02 | 03 | 2 | ACT-01, ACT-06 | — | N/A | manual | N/A — requires Siri voice activation on device | ❌ | ⬜ pending |
| 13-03-03 | 03 | 2 | ACT-02, ACT-03 | — | N/A | checkpoint | Human-verify: app launches, DictationView works, record/stop cycle | N/A | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Test files are created by the plans themselves (no separate Wave 0 needed):

- [x] `iOS/DicticusTests/IOSTranscriptionServiceTests.swift` — created by Plan 02 Task 2, covers ASR-01, ASR-02 (language detection, script validation, configuration)
- [x] `iOS/DicticusTests/IOSModelWarmupServiceTests.swift` — created by Plan 02 Task 2, covers ASR-03 (warmup state machine)
- [x] `iOS/DicticusTests/DictationViewModelTests.swift` — created by Plan 03 Task 2, covers ACT-01, ACT-02, TEXT-01 (ViewModel state machine, ordering constraints)

*Existing XCTest infrastructure from macOS target covers framework setup.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Unlimited recording duration | ACT-03 | Requires real device with microphone | Record for >30s on device, verify no timeout |
| Siri voice command trigger | ACT-06 | Requires Siri invocation on real device | Say "Hey Siri, start dictation", verify app opens and recording begins |
| Dynamic Island appearance | ACT-02 | Visual verification on real device | Trigger dictation, verify Live Activity appears in Dynamic Island |
| Neural Engine transcription | ASR-01 | CoreML model inference requires device | Speak German and English phrases, verify accurate transcription |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references (test files created by Plans 02 and 03)
- [x] No watch-mode flags
- [x] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending execution
