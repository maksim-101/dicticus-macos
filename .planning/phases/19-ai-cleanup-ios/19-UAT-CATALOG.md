---
phase: 19
slug: ai-cleanup-ios
type: uat-catalog
created: 2026-04-24
branch: feature/phase-19-ai-cleanup-ios
requirements: [CLEAN-01, CLEAN-02]
status: awaiting_user_signoff
---

# Phase 19 — UAT Catalog

Physical-device user acceptance testing for the iOS AI Cleanup feature. All automation (unit + integration tests on simulator) is green: **70 tests / 62 passed / 8 skipped (4 pre-existing FluidAudio cache + 4 env-gated on `DICTICUS_TEST_MODEL_PATH`) / 0 failed**, iPhone 17 simulator, zero Swift 6 concurrency warnings. Two targets (iOS + macOS) build clean.

The items below can only be verified on a physical iPhone 14+ because:
- RAM gate (`ProcessInfo.physicalMemory >= 5 GiB`) fails on simulator
- Real Metal inference against a 3 GB GGUF cannot run on simulator
- Mic + clipboard + Dynamic Island behavior requires hardware
- iCloud backup-exclusion only observable on a real device

---

## 0. Pre-UAT Setup

| # | Step | Expected |
|---|------|----------|
| 0.1 | `git checkout feature/phase-19-ai-cleanup-ios` | HEAD at `f7e620c` (docs: Wave 5 complete) |
| 0.2 | Open `iOS/Dicticus.xcodeproj` in Xcode | Builds clean |
| 0.3 | Select a physical iPhone 14 / 15 / 16 / 17 as destination | Device detected; entitlements signed |
| 0.4 | Build + install (⌘R) | App launches; onboarding skippable if already seeded |
| 0.5 | Open Settings app → Dicticus permissions | Mic + Notifications granted |

If anything in §0 fails, STOP and fix before touching §1–§9. The catalog assumes a clean install on a supported device.

---

## 1. Settings UI — AiCleanupSection (CLEAN-01, D-08, D-10, D-15, D-20, D-35, D-36)

**Goal:** The Settings screen exposes the two toggles + inline download panel with correct gating.

| # | Action | Expected |
|---|--------|----------|
| 1.1 | App → Settings | "AI Cleanup" section visible between Transcriptions and Integration |
| 1.2 | Read section footer | "Gemma 4 E2B (Q4_K_M) runs entirely on-device — no audio is sent to any server. Swiss German spelling applies to plain dictation independently of AI Cleanup." |
| 1.3 | Flip **Swiss German Spelling** ON, dismiss Settings, reopen | Toggle persists ON (AppGroup `group.com.dicticus` key `useSwissGerman`) |
| 1.4 | Flip **AI Cleanup** ON | Inline download panel appears with label "Download Required", subtitle "Gemma 4 E2B ≈ 3 GB. Wi-Fi recommended.", and a `.borderedProminent` "Download Model" button. Swiss toggle stays visible and operable. |
| 1.5 | On a RAM-ineligible device (iPhone 12/13) | AI Cleanup toggle row is REPLACED with "AI Cleanup — Unavailable" + explainer "Requires iPhone 14 or newer (at least 5 GB of RAM)." Swiss toggle unaffected (D-15 orthogonality). |

**Fail-kill:** Toggle persistence fails → AppGroup read/write bug. Swiss toggle disappears on RAM-ineligible device → D-15 violation.

---

## 2. Model Download — IOSModelDownloadService (D-10, Q6, D-35)

**Goal:** 3 GB GGUF download with progress, pause, resume, and backup-exclusion — all inline in Settings.

| # | Action | Expected |
|---|--------|----------|
| 2.1 | In Settings with AI Cleanup ON + no cached model, tap **Download Model** | Progress bar advances within 2–3 s; percentage readout updates; throughput reads "X.X MB/s"; "Pause" button visible. Download URL resolves to unsloth HF `gemma-4-e2b-it-q4_0-gguf` repo (D-14). |
| 2.2 | Tap **Pause** at ~30 % | State flips to "Paused · 30 %"; progress bar freezes; "Resume" button appears. |
| 2.3 | Tap **Resume** | Download continues from checkpoint (HTTP `Range` header; confirm via Proxyman or Console logs if available). No restart from 0 %. |
| 2.4 | Background the app mid-download (home-swipe), return after 10 s | `waitsForConnectivity = true` preserves the task; progress resumes on foreground without reset. |
| 2.5 | Force-quit mid-download | Resume data is NOT persisted across app restarts (T-19-05-03 scope). Reopen Settings → panel returns to initial state ("Download Model" button). Tap again → restarts from 0 %. This is the accepted Wave 4 scope — background continuation is deferred. |
| 2.6 | Let download complete | Panel swaps to "Download Complete — relaunch Dicticus to enable" with a green checkmark. No "Download Model" button shown. |
| 2.7 | Verify backup exclusion via Settings → General → iPhone Storage → Dicticus | "Documents & Data" should NOT grow by 3 GB; GGUF lives in an `isExcludedFromBackup=true` resource (Q6). |
| 2.8 | Plug device into Finder/iTunes → back up to local | GGUF is excluded from backup (size delta roughly matches non-GGUF app data only). |

**Fail-kill:**
- "Pause" clears to 0 % → `resumeData` bug in `IOSModelDownloadService`.
- Resume data survives force-quit → unexpected; worth logging (not a regression, but the accepted scope says it should not).
- Storage grows under iCloud Backup → backup-exclusion resource value not applied.

---

## 3. Warmup Step 4 — IOSModelWarmupService (D-02, D-12, D-33, D-34)

**Goal:** On next launch after download, Step 4 loads the GGUF onto Metal and publishes `isLlmReady = true`.

| # | Action | Expected |
|---|--------|----------|
| 3.1 | After completing §2, force-quit app and relaunch | Warmup UI shows a "Loading model…" banner / spinner for Step 4 (iPhone 14: ~15 s; iPhone 15 Pro / 16+: ~8–10 s; iPhone 17 Pro: ~5–7 s). |
| 3.2 | Watch Xcode console (optional) | Step 4 logs once; `llmStatus: .loading` → `.ready`; `isLlmReady = true`; no errors. |
| 3.3 | Kill + relaunch with AI Cleanup toggle OFF | Step 4 skipped silently (D-34: `.idle` stays, no "downloading" state on iOS). App is usable immediately. |
| 3.4 | Kill + relaunch with GGUF manually deleted from `Application Support` | Step 4 skipped silently; `llmStatus` stays `.idle`; Settings eventually reflects that the download panel is back. |
| 3.5 | On RAM-ineligible device (iPhone 12/13) with AI Cleanup toggle somehow ON | Step 4 skipped silently; `isLlmReady` stays false; no crash; Settings shows the "Unavailable" row on next visit. |

**Fail-kill:**
- Step 4 takes > 30 s on iPhone 14 → investigate `n_gpu_layers=99` Metal backend (D-02).
- Step 4 runs twice per launch → `backendInitToken` dispatch_once guard (D-33) broken.
- App crashes on launch with AI Cleanup ON → Rule 4 escalation.

---

## 4. End-to-End German Cleanup (CLEAN-01, CLEAN-02, D-04, D-05, D-13, D-23, D-26, D-38)

**Goal:** Dictated German audio is cleaned via on-device LLM; output lands at the cursor / clipboard.

| # | Action | Expected |
|---|--------|----------|
| 4.1 | AI Cleanup ON, Swiss OFF. Start dictation and say: "hallo velt das ist ein test eins zwei drei". Stop. | Clipboard receives a cleaned version: e.g. "Hallo Welt, das ist ein Test, 1, 2, 3." (exact capitalization/punctuation may vary slightly by sampler draw). No "ß" edits yet. |
| 4.2 | Open Dicticus history | Newest row's `text` column is the POST-pipeline cleaned output (D-38). `rawText` column is the raw ASR ("hallo velt…"). |
| 4.3 | Repeat §4.1 two more times back-to-back (~5 s apart) | Every output is cleaned independently; no output bleed between calls; KV cache cleared per D-06. |
| 4.4 | Repeat §4.1 with AI Cleanup OFF | Output is raw ASR (with dictionary + ITN only). Demonstrates the toggle actually gates LLM routing (D-13). |
| 4.5 | Dictate a number-heavy sentence: "der betrag ist tausend zweihundertfünfzig euro und dreiundvierzig cent" | Output uses digit formatting: e.g. "Der Betrag ist 1.250 Euro und 43 Cent." (or "1'250" with Swiss ON — see §5). |

**Fail-kill:**
- Output equals raw ASR even though `isLlmReady = true` → TextProcessingService not reading `aiCleanupEnabled` or CleanupProvider `isLoaded` gate broken (D-13/D-23).
- Output is echoed twice or mixed with the previous dictation → KV cache hygiene (D-06) broken.
- Clipboard untouched → clipboard-write path regressed; compare against v2.0 behavior.

---

## 5. Swiss German Orthography (D-15, D-16, D-17, D-18, D-19, D-20)

**Goal:** Swiss toggle forces ß → ss in both plain and AI modes; thousands separator follows Swiss convention when AI Cleanup is also on.

| # | Action | Expected |
|---|--------|----------|
| 5.1 | AI Cleanup ON, Swiss ON. Dictate: "draussen war es grossartig und ich habe weisswurst gegessen" (use ß-bearing words). | Clipboard contains only "ss" — no "ß" at all. E.g. "Draussen war es grossartig und ich habe Weisswurst gegessen." |
| 5.2 | AI Cleanup OFF, Swiss ON, same sentence | Clipboard still has only "ss" (deterministic `ITNUtility.applySwissITN` fires even without the LLM). Capitalization/punctuation is whatever raw ASR produced. |
| 5.3 | AI Cleanup ON, Swiss OFF, same sentence | Output may contain "ß" (standard German) and proper capitalization. Swiss rule is NOT applied. |
| 5.4 | AI Cleanup ON, Swiss ON. Dictate: "der preis ist tausend zweihundertfünfzig franken" | Thousands separator renders as Swiss apostrophe: "1'250 Franken" (not "1.250" and not "1,250"). |
| 5.5 | Type the capital-ẞ case: dictate a sentence where ASR produces a capital "ẞ" | Output converts ẞ → "SS" (D-17). |

**Fail-kill:**
- Any "ß" in clipboard with Swiss ON → D-16 regex miss.
- Swiss toggle has no effect → prompt line not injected (D-18) or safety-net regex not gated (D-19).
- Thousands separator wrong → prompt tuning regression; compare to macOS baseline.

---

## 6. Timeout Fallback & Concurrency (D-04, D-26, D-28)

**Goal:** Long or overlapping dictations degrade gracefully, never error out.

| # | Action | Expected |
|---|--------|----------|
| 6.1 | Dictate a 30-second continuous passage with AI Cleanup ON. | After the 8 s cleanup timeout the raw ASR lands in the clipboard (D-26). No error alert, no crash, no hang. |
| 6.2 | On fast hardware (iPhone 15 Pro / 16+ / 17 Pro), 30 s may not trigger the timeout. Dictate ≥ 60 s and record actual cleanup duration via Xcode console. | Captures a data point for D-04 retuning. Log it in the phase SUMMARY if ≥ 7 s consistently. |
| 6.3 | Start one dictation, wait for "Processing…", immediately start a second dictation while the first is still being cleaned. | Neither result is mangled. Per D-28: concurrent-call guard returns raw for the second (or queues it). No clipboard corruption, no crash. |
| 6.4 | Toggle AI Cleanup OFF mid-dictation (e.g. drag down Settings during recording). | No crash. Either current dictation uses the last-known toggle value or falls back to raw — either is acceptable, but the app must not crash. |

**Fail-kill:**
- Timeout produces empty clipboard → fallback path (D-26) not wired.
- Crash or UI lock on concurrent call → D-28 guard missing.
- Error alert shown to user on timeout → UX regression (D-26 says no error UI).

---

## 7. Memory & Thermals (D-03, D-07)

**Goal:** Peak memory stays within jetsam budget on iPhone 14; no thermal throttling after sustained use.

| # | Action | Expected |
|---|--------|----------|
| 7.1 | iPhone 14 (4.99 GB usable RAM, but PhysicalMemory reports 6 GB → passes gate). Attach Xcode Instruments → Allocations. Warm up model + run 5 back-to-back AI-cleaned dictations. | Peak RSS < 4.5 GB. No jetsam events. |
| 7.2 | Run 10 consecutive AI dictations without killing the app. | Memory is flat (no monotonic growth > ~50 MB). RSS returns to baseline between dictations. |
| 7.3 | Touch the back of the device after 5 dictations. | Warm but not hot. No iOS thermal banner. |
| 7.4 | Let the app sit idle with model loaded for 15 min. | RSS stays roughly constant; iOS may page some of the GGUF out — acceptable. Next dictation may take 1–2 s longer on cold re-page. |

**Fail-kill:**
- Jetsam event or OOM crash → RAM budget blown; consider lowering `n_gpu_layers` or gating at 6 GB minimum.
- Monotonic memory growth across dictations → KV cache leak (D-06).

---

## 8. History, Clipboard, and Cursor Integration (D-38)

**Goal:** Cleaned output integrates correctly with existing dictation surfaces (History, clipboard, Shortcut auto-return).

| # | Action | Expected |
|---|--------|----------|
| 8.1 | After §4.1, open Dicticus → History tab | Newest row: `text` = cleaned output, `rawText` = raw ASR, timestamp correct, language auto-detected. |
| 8.2 | Tap the history row | Full cleaned text visible; no double-saves (D-38 removed direct `HistoryService.save` from DictationViewModel — `TextProcessingService` is the sole save site). |
| 8.3 | Dictate via the iOS Shortcut ("Start Dicticus Dictation") instead of in-app. | Shortcut auto-return flow still works; cleaned output lands at the cursor of the invoking app (Notes, Mail, Safari form, etc.). |
| 8.4 | Dictate into a multi-line text field. Check cursor position after paste. | Cursor lands at end of inserted text. No duplicated or interleaved characters. |

**Fail-kill:**
- History shows raw text in `text` column → D-38 regression.
- Shortcut returns raw text when AI Cleanup is ON → `TextProcessingService` not reached from the Shortcut flow (check Phase 17.5 bridge).
- Two history rows per dictation → double-save reintroduced.

---

## 9. Regression Sweep — v2.0/v2.1 Features Still Work

**Goal:** Phase 19 did not break anything shipped in earlier milestones.

| # | Action | Expected |
|---|--------|----------|
| 9.1 | AI Cleanup OFF. Dictate normally (Shortcut and in-app). | Identical behavior to v2.1 before Phase 19. |
| 9.2 | Open History; search for an old entry via FTS5 | Phase 15 Full-Text Search still works. |
| 9.3 | Open Dictionary; add + remove an entry | Phase 15 Dictionary still works. Corrections still apply in dictation. |
| 9.4 | iPad: rotate portrait ↔ landscape; test sidebar | Phase 16 `NavigationSplitView` layout unchanged. |
| 9.5 | Live Activity + Dynamic Island | Phase 17 Stop button still works during dictation. |
| 9.6 | Shortcut auto-return + mic button on Dicticus keyboard | Phase 17.5 Darwin IPC path still works (mic button triggers host app, transcription inserts at cursor). |
| 9.7 | "What's New" on first launch post-update | Phase 16 "What's New" content ideally updated to mention AI Cleanup (or confirm gracefully skipped if no update). |
| 9.8 | macOS app smoke test (build and run macOS target) | macOS AI Cleanup path unchanged (this phase extracted `CleanupService` to `Shared/` without behavior changes); verify a single macOS dictation still cleans. |

**Fail-kill:** ANY regression in §9 blocks the merge. Phase 19 must be fully additive for non-iOS-AI surfaces.

---

## Exit Criteria — Sign-off

Mark each block with ✅ / ❌ after running on the target device:

- [ ] §0 Pre-UAT setup
- [ ] §1 Settings UI (5 steps)
- [ ] §2 Model download (8 steps)
- [ ] §3 Warmup Step 4 (5 steps)
- [ ] §4 End-to-end German cleanup (5 steps)
- [ ] §5 Swiss German orthography (5 steps)
- [ ] §6 Timeout & concurrency (4 steps)
- [ ] §7 Memory & thermals (4 steps)
- [ ] §8 History, clipboard, cursor (4 steps)
- [ ] §9 Regression sweep (8 steps)

**Device used:** ____________________ (model + iOS version + RAM)
**Tester:** __________________________
**Date:** ____________________________
**Overall verdict:** ☐ Approved — ready to merge & ship | ☐ Conditional — fix list below | ☐ Rejected — re-plan

**Issues found:**
1.
2.
3.

---

## Known Gaps (documented limitations — NOT bugs)

| # | Behavior | Owner | Reference |
|---|----------|-------|-----------|
| G-1 | Force-quit mid-download → download restarts from 0 % (resume data not persisted across app restarts) | Future wave | D-35, T-19-05-03 |
| G-2 | Settings view owns its own `IOSModelDownloadService` instance; dismissing Settings cancels in-flight download | Accepted scope | D-35 |
| G-3 | `appGroupBinding` helper duplicated in AiCleanupSection (not shared with SettingsView) | 11 LOC, future cleanup | D-36 |
| G-4 | iOS `LlmStatus` has no `.downloading` state (iOS download is Settings-driven, not warmup-driven) | By design | D-34 |
| G-5 | 2 CleanupService tests (`testConcurrentCallGuard`, `testSwissSafetyNetGating`) need a real GGUF + slow-inference seam; currently env-gated on `DICTICUS_TEST_MODEL_PATH` | Future test infrastructure | 19-06-SUMMARY scope decision A |
| G-6 | Pre-existing macOS `testMixedText` failure (unrelated to Phase 19) | Outside scope | `deferred-items.md` |

---

## Reference — Phase 19 Artifacts

- Plans: `19-01..19-06-PLAN.md`
- Summaries: `19-01..19-06-SUMMARY.md`
- Research: `19-RESEARCH.md` (~830 lines)
- Context (29 locked decisions D-01..D-29, extended to D-39 during execution): `19-CONTEXT.md`
- Validation contract: `19-VALIDATION.md`
- Pattern mapping: `19-PATTERNS.md`
- Deferred items: `deferred-items.md`

**Branch:** `feature/phase-19-ai-cleanup-ios`
**Top commit:** `f7e620c` (`docs(19-06): complete Wave 5 — DictationViewModel + DicticusApp pipeline integration plan`)
**Tests:** 70 iOS / 62 pass / 8 skip / 0 fail on iPhone 17 simulator. Zero Swift 6 concurrency warnings. Both targets build.
