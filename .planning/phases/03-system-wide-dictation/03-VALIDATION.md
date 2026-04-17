---
phase: 3
slug: system-wide-dictation
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-17
---

# Phase 3 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest (Xcode built-in) |
| **Config file** | Dicticus/DicticusTests/ (existing test target in project.yml) |
| **Quick run command** | `xcodebuild test -project Dicticus/Dicticus.xcodeproj -scheme Dicticus -destination 'platform=macOS' -only-testing:DicticusTests 2>&1 \| tail -20` |
| **Full suite command** | `xcodebuild test -project Dicticus/Dicticus.xcodeproj -scheme Dicticus -destination 'platform=macOS' 2>&1 \| tail -40` |
| **Estimated runtime** | ~15 seconds |

---

## Sampling Rate

- **After every task commit:** Run quick run command (unit tests only)
- **After every plan wave:** Run full suite command
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 03-01-01 | 01 | 1 | APP-03 | — | N/A | unit | `xcodebuild test ... -only-testing:DicticusTests/HotkeyManagerTests/testIconStateRecording` | ❌ W0 | ⬜ pending |
| 03-01-02 | 01 | 1 | APP-04 | — | N/A | unit | `xcodebuild test ... -only-testing:DicticusTests/HotkeyManagerTests/testTwoHotkeysRegistered` | ❌ W0 | ⬜ pending |
| 03-01-03 | 01 | 1 | D-02 | — | N/A | unit | `xcodebuild test ... -only-testing:DicticusTests/HotkeyManagerTests/testShortPressDiscard` | ❌ W0 | ⬜ pending |
| 03-01-04 | 01 | 1 | D-03 | — | Key repeat flood prevention | unit | `xcodebuild test ... -only-testing:DicticusTests/HotkeyManagerTests/testKeyRepeatSuppression` | ❌ W0 | ⬜ pending |
| 03-02-01 | 02 | 1 | D-07 | T-03-01 | Minimize clipboard exposure time | unit | `xcodebuild test ... -only-testing:DicticusTests/TextInjectorTests/testClipboardSaveRestore` | ❌ W0 | ⬜ pending |
| 03-02-02 | 02 | 1 | D-19 | — | N/A | unit | `xcodebuild test ... -only-testing:DicticusTests/HotkeyManagerTests/testRejectWhileTranscribing` | ❌ W0 | ⬜ pending |
| 03-03-01 | 03 | 2 | TRNS-01 | — | N/A | manual-only | N/A -- requires physical hotkey + target app | N/A | ⬜ pending |
| 03-03-02 | 03 | 2 | TRNS-05 | — | N/A | manual-only | N/A -- requires focus in different apps | N/A | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `DicticusTests/HotkeyManagerTests.swift` -- covers D-02, D-03, D-19, APP-03, APP-04
- [ ] `DicticusTests/TextInjectorTests.swift` -- covers D-07 clipboard save/restore
- [ ] `DicticusTests/NotificationServiceTests.swift` -- covers D-15, D-17 notification posting
- [ ] KeyboardShortcuts SPM dependency added to project

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Hold hotkey, speak, release, text appears at cursor | TRNS-01 | Requires physical hotkey press + focus in target app | 1. Open Notes.app 2. Press+hold hotkey 3. Speak a sentence 4. Release 5. Verify text appears at cursor |
| Text injection in browsers, native apps, terminal | TRNS-05 | Requires focus in different apps | 1. Test in Safari address bar 2. Test in TextEdit 3. Test in Terminal.app 4. Verify text appears in each |
| Recording indicator shows red mic | APP-03 | Visual verification of menu bar icon | 1. Hold hotkey 2. Observe menu bar icon changes to red filled mic 3. Release 4. Observe spinner then normal mic |
| AI cleanup hotkey is silent stub | D-13 | Requires physical hotkey interaction | 1. Press AI cleanup hotkey 2. Verify nothing happens -- no recording, no notification |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
