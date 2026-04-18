---
phase: 5
slug: polish-distribution
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-18
---

# Phase 5 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest (Xcode built-in) |
| **Config file** | Dicticus/DicticusTests/ (12 test files) |
| **Quick run command** | `xcodebuild test -scheme Dicticus -destination 'platform=macOS' -only-testing:DicticusTests 2>&1 \| tail -20` |
| **Full suite command** | `xcodebuild test -scheme Dicticus -destination 'platform=macOS' 2>&1 \| tail -40` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run `xcodebuild test -scheme Dicticus -destination 'platform=macOS' -only-testing:DicticusTests 2>&1 | tail -20`
- **After every plan wave:** Run `xcodebuild test -scheme Dicticus -destination 'platform=macOS' 2>&1 | tail -40`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** ~30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 05-01-01 | 01 | 1 | INFRA-04 | — | N/A | manual | `footprint -p Dicticus` | N/A — manual | ⬜ pending |
| 05-02-01 | 02 | 1 | APP-05 | — | N/A | unit | `xcodebuild test -only-testing:DicticusTests/SettingsSectionTests` | ❌ W0 | ⬜ pending |
| 05-02-02 | 02 | 1 | — | T-05-03 | Login item via SMAppService only | unit | `xcodebuild test -only-testing:DicticusTests/SettingsSectionTests` | ❌ W0 | ⬜ pending |
| 05-03-01 | 03 | 1 | — | T-05-01 | `.listenOnly` CGEventTap, flagsChanged only | unit | `xcodebuild test -only-testing:DicticusTests/ModifierHotkeyListenerTests` | ❌ W0 | ⬜ pending |
| 05-03-02 | 03 | 2 | — | — | N/A | smoke | `hdiutil attach Dicticus.dmg && ls /Volumes/Dicticus/` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `DicticusTests/ModifierHotkeyListenerTests.swift` — stubs for flag transition logic (pure function)
- [ ] `DicticusTests/SettingsSectionTests.swift` — verify settings section contains launch-at-login toggle
- [ ] `scripts/build-dmg.sh` — build + DMG creation script
- [ ] `scripts/verify-dmg.sh` — smoke test that mounts DMG and checks contents
- [ ] Install `create-dmg`: `brew install create-dmg`

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Memory under 3 GB with both models loaded | INFRA-04 | Requires running app with real models; `footprint` measures live process | 1. Launch app. 2. Wait for warmup. 3. Run `footprint -p Dicticus`. 4. Verify total < 3 GB. |
| DMG install on clean system | — | Requires clean macOS install or separate user account | 1. Mount DMG. 2. Drag to Applications. 3. Launch. 4. Grant permissions. 5. Verify dictation works. |

*If none: "All phase behaviors have automated verification."*

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
