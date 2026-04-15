---
phase: 1
slug: foundation-app-shell
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-15
---

# Phase 1 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest (built-in with Xcode) |
| **Config file** | Dicticus.xcodeproj or Package.swift test targets |
| **Quick run command** | `xcodebuild test -scheme Dicticus -only-testing DicticusTests -quiet` |
| **Full suite command** | `xcodebuild test -scheme Dicticus -quiet` |
| **Estimated runtime** | ~10 seconds |

---

## Sampling Rate

- **After every task commit:** Run `xcodebuild test -scheme Dicticus -only-testing DicticusTests -quiet`
- **After every plan wave:** Run `xcodebuild test -scheme Dicticus -quiet`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 01-01-01 | 01 | 1 | APP-01 | — | N/A | build | `xcodebuild build -scheme Dicticus -quiet` | ❌ W0 | ⬜ pending |
| 01-02-01 | 02 | 1 | APP-02 | — | N/A | manual | Manual permission grant verification | ❌ W0 | ⬜ pending |
| 01-03-01 | 03 | 2 | INFRA-03 | — | N/A | manual | Launch app and observe warm-up indicator | ❌ W0 | ⬜ pending |
| 01-03-02 | 03 | 2 | INFRA-05 | — | N/A | build | `xcodebuild build -scheme Dicticus -configuration Release -quiet` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] Xcode project created with test target (DicticusTests)
- [ ] Basic build test passes (`xcodebuild build -scheme Dicticus -quiet` exits 0)

*Test infrastructure is established as part of Phase 1 project scaffolding.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Menu bar icon visible | APP-01 | Requires visual inspection of macOS menu bar | Launch app, verify icon appears in menu bar |
| Permission onboarding flow | APP-02 | Requires interactive System Settings grants | Launch fresh (reset permissions), verify sequential prompts for Mic, Accessibility, Input Monitoring |
| Warm-up indicator | INFRA-03 | Requires visual inspection of CoreML compilation progress | Launch app after clearing CoreML cache, verify pulsing icon and "Preparing models..." text |
| DMG packaging | INFRA-05 | Requires manual drag-to-Applications install test | Build DMG, mount, drag to /Applications, launch from Finder |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
