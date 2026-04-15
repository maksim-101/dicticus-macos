---
phase: 2
slug: asr-pipeline
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-15
---

# Phase 2 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest (built-in) |
| **Config file** | Dicticus.xcodeproj (xcodegen from project.yml) |
| **Quick run command** | `xcodebuild test -scheme Dicticus -destination 'platform=macOS,arch=arm64' -only-testing:DicticusTests -quiet` |
| **Full suite command** | `xcodebuild test -scheme Dicticus -destination 'platform=macOS,arch=arm64' -quiet` |
| **Estimated runtime** | ~10 seconds |

---

## Sampling Rate

- **After every task commit:** Run `xcodebuild test -scheme Dicticus -destination 'platform=macOS,arch=arm64' -only-testing:DicticusTests -quiet`
- **After every plan wave:** Run `xcodebuild test -scheme Dicticus -destination 'platform=macOS,arch=arm64' -quiet`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 02-01-01 | 01 | 1 | INFRA-01 | — | N/A | unit | `xcodebuild test -scheme Dicticus -destination 'platform=macOS,arch=arm64' -only-testing:DicticusTests/TranscriptionServiceTests/testUsesSharedInstance -quiet` | No -- Wave 0 | pending |
| 02-01-02 | 01 | 1 | TRNS-04 | — | N/A | unit | `xcodebuild test -scheme Dicticus -destination 'platform=macOS,arch=arm64' -only-testing:DicticusTests/TranscriptionServiceTests/testMinimumDuration -quiet` | No -- Wave 0 | pending |
| 02-01-03 | 01 | 1 | TRNS-03 | — | N/A | unit | `xcodebuild test -scheme Dicticus -destination 'platform=macOS,arch=arm64' -only-testing:DicticusTests/TranscriptionServiceTests/testLanguageRestriction -quiet` | No -- Wave 0 | pending |
| 02-02-01 | 02 | 1 | TRNS-02 | — | N/A | integration (manual) | Manual test with actual model | No | pending |

*Status: pending / green / red / flaky*

---

## Wave 0 Requirements

- [ ] `DicticusTests/TranscriptionServiceTests.swift` -- covers TRNS-03, TRNS-04, INFRA-01 (language restriction, minimum duration, silence detection, shared instance usage)
- [ ] `DicticusTests/TranscriptionResultTests.swift` -- covers DicticusTranscriptionResult struct correctness

*Existing test infrastructure (XCTest + DicticusTests target) already configured in project.yml.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Transcription under 3s for <30s audio | TRNS-02 | Requires actual Whisper model loaded on Apple Silicon hardware | 1. Launch app 2. Wait for warmup 3. Record ~10s speech 4. Measure time from recording stop to text output |
| Audio captured at 16kHz mono | TRNS-02 | Requires live microphone and AVAudioEngine session | 1. Launch app 2. Check audio format in debug output 3. Verify 16000 Hz sample rate, 1 channel |

---

## Validation Sign-Off

- [ ] All tasks have automated verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
