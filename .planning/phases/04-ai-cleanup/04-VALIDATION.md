---
phase: 4
slug: ai-cleanup
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-17
---

# Phase 4 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest (built-in) |
| **Config file** | Dicticus/DicticusTests/ |
| **Quick run command** | `xcodebuild test -project Dicticus/Dicticus.xcodeproj -scheme DicticusTests -destination 'platform=macOS' -only-testing:DicticusTests 2>&1 \| tail -20` |
| **Full suite command** | `xcodebuild test -project Dicticus/Dicticus.xcodeproj -scheme DicticusTests -destination 'platform=macOS' 2>&1 \| tail -40` |
| **Estimated runtime** | ~15 seconds |

---

## Sampling Rate

- **After every task commit:** Run quick test command
- **After every plan wave:** Run full suite command
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 04-01-01 | 01 | 1 | INFRA-02 | T-04-01 | LLM loads locally, no network calls | unit | `xcodebuild test -only-testing:DicticusTests/CleanupServiceTests` | ❌ W0 | ⬜ pending |
| 04-01-02 | 01 | 1 | AICLEAN-04 | T-04-02 | GGUF model cached in Application Support | unit | `xcodebuild test -only-testing:DicticusTests/CleanupServiceTests` | ❌ W0 | ⬜ pending |
| 04-02-01 | 02 | 2 | AICLEAN-01 | — | N/A | unit | `xcodebuild test -only-testing:DicticusTests/CleanupServiceTests` | ❌ W0 | ⬜ pending |
| 04-02-02 | 02 | 2 | AICLEAN-02 | — | N/A | unit | `xcodebuild test -only-testing:DicticusTests/CleanupServiceTests` | ❌ W0 | ⬜ pending |
| 04-02-03 | 02 | 2 | AICLEAN-03 | — | N/A | unit | `xcodebuild test -only-testing:DicticusTests/CleanupServiceTests` | ❌ W0 | ⬜ pending |
| 04-03-01 | 03 | 3 | AICLEAN-01 | — | N/A | integration | manual | N/A | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `DicticusTests/CleanupServiceTests.swift` — stubs for AICLEAN-01 through AICLEAN-04, INFRA-02
- [ ] Test helpers for CleanupService without requiring actual GGUF model download

*Note: Existing test infrastructure (XCTest, xcodegen) covers framework needs. Only new test files needed.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| End-to-end cleanup via hotkey | AICLEAN-01 | Requires physical hotkey press + mic input | Hold AI cleanup hotkey, speak, release — verify cleaned text appears at cursor |
| Cleanup preserves meaning | AICLEAN-02 | Subjective quality assessment | Compare raw ASR output with cleaned output for 5 sample utterances in each language |
| Total latency < 4 seconds | SC-5 | Requires real model inference | Time from hotkey release to text injection with stopwatch |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
