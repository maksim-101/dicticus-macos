---
phase: 19
slug: ai-cleanup-ios
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-24
---

# Phase 19 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Sourced from 19-RESEARCH.md §Validation Architecture.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest (iOS — `DicticusTests` target in `iOS/project.yml`) |
| **Config file** | `iOS/project.yml` |
| **Quick run command** | `xcodebuild test -project iOS/Dicticus.xcodeproj -scheme Dicticus -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:DicticusTests/CleanupServiceTests -only-testing:DicticusTests/ITNUtilityTests -only-testing:DicticusTests/IOSModelDownloadServiceTests` |
| **Full suite command** | `xcodebuild test -project iOS/Dicticus.xcodeproj -scheme Dicticus -destination 'platform=iOS Simulator,name=iPhone 15'` |
| **Estimated runtime** | ~30 s (quick) / ~2 min (full) |

---

## Sampling Rate

- **After every task commit:** Run quick command (unit-only, <30 s)
- **After every plan wave:** Run full `DicticusTests` suite on iPhone 15 simulator
- **Before `/gsd-verify-work`:** Full suite must be green + physical iPhone 14/15 smoke with real Gemma 4 E2B GGUF
- **Max feedback latency:** 30 seconds (quick) / 120 seconds (full)

---

## Per-Task Verification Map

> Populated by planner as plans are created; tasks inherit the Req → Test mapping below.

| Req ID | Behavior | Test Type | Automated Command | File Exists | Status |
|--------|----------|-----------|-------------------|-------------|--------|
| CLEAN-01 | Settings toggle enables AI cleanup path | unit | `-only-testing:DicticusTests/SettingsToggleTests` | ❌ W0 | ⬜ pending |
| CLEAN-01 | TextProcessingService routes to cleanup when mode = .aiCleanup && service loaded | unit | `-only-testing:DicticusTests/TextProcessingServiceTests/testCleanupPath` | ❌ W0 | ⬜ pending |
| CLEAN-01 | RAM gating hides toggle on <5 GB device | unit | `-only-testing:DicticusTests/DeviceEligibilityTests` | ❌ W0 | ⬜ pending |
| CLEAN-02 | CleanupService loads GGUF and returns non-empty cleaned text | integration (gated on `DICTICUS_TEST_MODEL_PATH`) | `-only-testing:DicticusTests/CleanupServiceTests/testRealModelInference` | ❌ W0 | ⬜ pending |
| CLEAN-02 / D-04 | Cleanup returns raw text on timeout | unit (mock slow inference) | `-only-testing:DicticusTests/CleanupServiceTests/testTimeoutFallback` | ❌ W0 | ⬜ pending |
| CLEAN-02 / D-28 | Cleanup returns raw text on concurrent call | unit | `-only-testing:DicticusTests/CleanupServiceTests/testConcurrentCallGuard` | ❌ W0 | ⬜ pending |
| D-16 | ß → ss deterministic | unit | `-only-testing:DicticusTests/ITNUtilityTests/testSwissGermanEszett` | ❌ W0 | ⬜ pending |
| D-17 | ẞ → SS (capital) | unit | `-only-testing:DicticusTests/ITNUtilityTests/testSwissGermanCapitalEszett` | ❌ W0 | ⬜ pending |
| D-19 | Post-LLM safety-net regex gated by Swiss toggle | unit | `-only-testing:DicticusTests/CleanupServiceTests/testSwissSafetyNetGating` | ❌ W0 | ⬜ pending |
| D-06 | KV cache cleared between back-to-back calls | integration | `-only-testing:DicticusTests/CleanupServiceTests/testBackToBackCallsIndependent` | ❌ W0 | ⬜ pending |
| D-27 | Control tokens sanitized before prompt build | unit | `-only-testing:DicticusTests/CleanupPromptTests/testSanitizeControlTokens` | ⚠ verify iOS target includes `Shared/` test | ⬜ pending |
| D-10 | Download delegate reports progress over ≥3 chunks | unit (mock URLProtocol) | `-only-testing:DicticusTests/IOSModelDownloadServiceTests/testProgressCallbacks` | ❌ W0 | ⬜ pending |
| D-10 | Pause produces resume data; resume restarts from checkpoint | unit (mock URLProtocol + Range assertion) | `-only-testing:DicticusTests/IOSModelDownloadServiceTests/testPauseResume` | ❌ W0 | ⬜ pending |
| Q6 | GGUF marked `isExcludedFromBackup` after download | unit (resource-value query) | `-only-testing:DicticusTests/IOSModelDownloadServiceTests/testBackupExclusion` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `iOS/DicticusTests/CleanupServiceTests.swift` — CLEAN-02, D-04, D-06, D-19, D-28
- [ ] `iOS/DicticusTests/SettingsToggleTests.swift` — CLEAN-01, D-08, D-15
- [ ] `iOS/DicticusTests/DeviceEligibilityTests.swift` — D-03 (inject `ProcessInfo` mock)
- [ ] `iOS/DicticusTests/ITNUtilityTests.swift` — D-16, D-17 (extend existing German ITN test if present)
- [ ] `iOS/DicticusTests/IOSModelDownloadServiceTests.swift` — D-10, Q6 (backup exclusion)
- [ ] `iOS/DicticusTests/TextProcessingServiceTests.swift` — D-13, D-23
- [ ] `iOS/DicticusTests/Fixtures/SwissGerman.fixtures.json` — ß/ẞ corpus (input/expected pairs)
- [ ] `iOS/DicticusTests/Fixtures/CanaryPrompts.json` — 3–5 German + 3–5 English inputs with hand-verified cleanup outputs (fuzzy equality)
- [ ] `iOS/DicticusTests/Helpers/MockURLProtocol.swift` — reusable mock for download tests (pause/resume, progress chunks, Range headers)
- [ ] Real-model integration test gate: `DICTICUS_TEST_MODEL_PATH` env var → skip with clear message when absent (CI passes without the 3 GB GGUF)

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Toggle flip triggers download UI | CLEAN-01 / D-10 | Settings-sheet interaction + URLSession against real CDN | In Settings, flip AI Cleanup ON → confirm inline sheet shows size warning + Download button; tap Download → progress bar advances; pause/resume survives backgrounding |
| Warmup Step 4 loads GGUF on launch when toggle ON | D-12 | Requires real device boot + 3 GB model | Kill and relaunch app with toggle ON → `IOSModelWarmupService` reports Step 4 complete within ~15 s on iPhone 14/15; `isLoaded = true` |
| End-to-end German cleanup | CLEAN-01 / CLEAN-02 | Requires ASR + LLM stack + real mic | Dictate "hallo velt das ist ein test" → cleaned output is "Hallo Welt, das ist ein Test." (or equivalent). Compare to raw for regression. |
| Swiss German orthography end-to-end | D-16..D-20 | Real ASR + LLM | Swiss toggle ON, dictate a sentence containing "ß" → output contains only "ss"; thousands separator renders as `1'250` when AI cleanup also ON |
| Timeout fallback delivers raw ASR | D-04 / D-26 | Requires long real transcription | Dictate ≥30 s of text → cleanup hits 8 s timeout → raw ASR text inserted, no error UI |
| Memory profile stays under ceiling | D-03 / D-07 | Requires Instruments on iPhone 14 | Peak RSS during active cleanup < 4.5 GB on iPhone 14; no jetsam over 10 consecutive dictations |
| GGUF backup exclusion persists | Q6 | Requires iCloud backup inspection | Confirm `isExcludedFromBackup = true` via resource-value query after download and after app relaunch |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies listed
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references above
- [ ] No watch-mode flags in quick/full commands
- [ ] Feedback latency < 30 s (quick) / 120 s (full)
- [ ] `nyquist_compliant: true` set in frontmatter after planner + executor confirm coverage

**Approval:** pending
