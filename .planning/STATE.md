---
gsd_state_version: 1.0
milestone: v2.3
milestone_name: Live-Capture Quality Pass
status: executing
stopped_at: Completed 30-01-PLAN.md
last_updated: "2026-06-05T18:17:27.924Z"
last_activity: 2026-06-05
progress:
  total_phases: 4
  completed_phases: 3
  total_plans: 12
  completed_plans: 12
  percent: 75
---

# Project State: Dicticus

**Last Updated:** 2026-05-26 (v2.3 roadmap created)
**Milestone:** v2.3 Live-Capture Quality Pass — Roadmap created from `.planning/debug/log-analysis-2026-05-26.md`
**Previous milestone:** v2.2 Adaptive Cleanup & Stability — shipped 2026-05-22 (V19C UAT pass, 90.2% clean rate; Phase 26 ITN hardening)

## Current Position

Phase: 30 (ptt-media-auto-pause-macos) — EXECUTING
Plan: 3 of 3
Status: Ready to execute
Last activity: 2026-06-05

### Next Action

**`/gsd-execute-phase 30`** — Phase 30 re-planned (3 waves) around the Spike-003 ScriptingBridge design,
plan-checked PASS. **Wave 1 (30-01):** rewrite `MediaController.swift` — drop MediaRemote, use
`NSWorkspace` running-check + `NSAppleScript` `player state`/pause/play for Apple Music + Spotify, per-app
latch; add `com.apple.security.automation.apple-events` entitlement + `NSAppleEventsUsageDescription`; keep
public API + HotkeyManager wiring + default-ON toggle. **Wave 2 (30-02):** mute-output fallback — when no
scriptable player was paused, mute default system output for the hold (CoreAudio `kAudioDevicePropertyMute`,
restore-only-what-we-muted) so browser/YouTube/podcast audio is covered. **Wave 3 (30-03):** signed
Debug-Recorder build + human UAT of BOTH tiers + Automation TCC grant.
Plans: `.planning/phases/30-ptt-media-auto-pause-macos/30-0{1,2,3}-PLAN.md`.

**Why the change:** original MediaRemote design FAILED signed-app UAT (now-playing read entitlement-gated).
Spike 003 → ScriptingBridge per-app validated; system-level detection all gated. User added the mute
fallback wave + formalized MEDIA-PAUSE-02/-03. Superseded MediaRemote artifacts under
`_superseded-mediaremote/`. Full design: `.planning/spikes/003-send-based-media-pause/README.md`.

**Accepted trade-offs:** mute fallback is system-wide (briefly mutes ALL output incl. a video call during
a hold; restored on release); mute ≠ pause for non-scriptable sources.

**Next action: `/gsd-plan-phase 30` (re-plan)** around ScriptingBridge — replaces 30-01's gated-read
MediaController. Design: on press, pause whichever of Music/Spotify is `player state == "playing"`
(via NSWorkspace running-check + AppleScript), latch the app; on release, play it. App needs
`com.apple.security.automation.apple-events` entitlement + `NSAppleEventsUsageDescription` (Automation
TCC). Covers Apple Music + Spotify; browser media uncovered → mute-output universal fallback.

30-01 code ships as a safe guarded no-op. Installed app = clean signed Debug-Recorder build (c588fec).

**After Phase 30 resolves → `/gsd-complete-milestone v2.3` → `/gsd-new-milestone v2.4` (theme:
public-release readiness + dictionary as platform; see v2.4 backlog cluster below).**

### Roadmap Evolution

- 2026-05-29: Phases 29 & 30 added to v2.3 from V19D live-UAT findings. Phase 29 = deterministic post-ASR text fixes (acronym collapse, spoken-letter lexicon, `"the set."→"Zed."` dict entry from Spike 001), cross-platform Shared/. Phase 30 = macOS-only PTT media auto-pause (MacWhisper parity), spike-first because macOS 15.4+ entitlement-gated MediaRemote play-state reads; mute-output fallback agreed. K4 prose number-word promotion explicitly deferred to a separate future ITN/prose phase (not 29/30).
- 2026-05-26: Milestone v2.3 opened. Roadmap created from 118-record live-capture analysis (`.planning/debug/log-analysis-2026-05-26.md`). Two phases: Phase 27 (dictionary hallucination guard + recorder enrichment + K7 brand adds) and Phase 28 (V19D prompt iteration). Phase 28 depends on Phase 27 so recorder enrichment gives V19D UAT better per-replacement attribution.

## v2.3 Phase Progress

- [x] Phase 27 — Dictionary Hallucination Guard + Recorder Enrichment + K7 Brand Adds (DICT-SAFE-01, DICT-SAFE-02, DICT-EXPAND-01, OBS-DICT-01) — complete 2026-05-27
- [x] Phase 28 — V19D Prompt Iteration (LLM-CLAUSE-01, LLM-CONTR-01, LLM-DEDUP-01, LLM-NUM-01, LLM-PROMPT-AUDIT-01) — complete; UAT closed 2026-05-29 via debug-log evidence
- [x] Phase 29 — Acronym-collapse + spoken-letter lexicon + `the set.`→Zed dict entry (ACRONYM-COLLAPSE-01, SPOKEN-LETTER-01, DICT-ZED-01) — complete 2026-05-29; post-deploy UAT 2026-06-04 confirmed no regressions (paths not exercised in 139-record window but pipeline GREEN)
- [ ] Phase 30 — PTT Media Auto-Pause macOS (MEDIA-PAUSE-01) — BLOCKED: 30-01 built (guarded no-op), 30-02 signed-app UAT FAILED 2026-06-05 (MediaRemote read entitlement-gated in signed app). Follow-up: send-based spike (`.planning/backlog/ptt-media-pause-send-based-spike.md`).

## v2.4 Backlog Cluster (seeded 2026-06-04, formalize via /gsd-new-milestone after Phase 30 ships)

**Theme:** Public-release readiness + dictionary as first-class platform.

Tightly coupled cluster (likely 1–2 phases):

- `.planning/backlog/personal-vs-default-dictionary-split.md` — **PUBLIC-RELEASE BLOCKER** — extract personal lexicon, ship empty/minimal default
- `.planning/backlog/dictionary-import-export.md` — CSV + JSON; the enabler that makes the split viable
- `.planning/backlog/spoken-punctuation-commands.md` — deterministic pre-LLM punctuation pass (`hyphen` → `-`, conditional `minus`)
- `.planning/backlog/asr-tech-term-mishearing-recovery.md` — mostly docs once the above ships
- `.planning/backlog/ui-reorg-macos-ios.md` — find-ability is the dictionary UX pain point

Independent track:

- `.planning/backlog/v19e-r8-over-promotion-and-content-word-gate.md` — prompt + gate quality work (K3/K4/K-prose bug family)

Full session writeup: `.planning/debug/log-analysis-2026-06-04.md`

## Carried Items (from v2.2)

- Phase 23 (Decimal Words & Digit Grouping) — absorbed into Phase 26, no further action.
- Phase 25.1-06 (NLD/Jaccard deterministic gates) — DEPRIORITIZED (gate at 0.45 never triggered in 153 records; V19C has 0% damage rate).
- Branch `feature/debug-recording-and-cleanup` carrying v2.2 work — confirm sync state before Phase 27 work begins.

## Session Continuity

Last session: 2026-06-05T18:16:02.403Z
Stopped at: Completed 30-01-PLAN.md
Previous: 2026-06-04 (Post-Phase-29 live-UAT debug-log review + v2.4 backlog seeding). Phase 29 confirmed complete. 139-record live UAT showed pipeline GREEN on tracked metrics (0 anomalies, 99.3% gate-pass, 0 R5/R6 violations, 13.7% dict-fire rate above 9.3% baseline). Phase 29's three new code paths (acronym collapse, spoken-letter lexicon, "the set."→Zed) had ZERO triggers in window — not a regression, just absence of conditions. Live repros mid-session uncovered 6 new findings, all routed to v2.4 backlog: V19D R8 over-promotion (kink three→K3, King Four→K4), public-release dictionary leakage, ASR tech-term mishearings (1080p→one thousand ADP), spoken-punctuation non-determinism (Claude minus ops), Qwen brand misses (patch reverted), UI find-ability. Phase 30 (PTT media auto-pause macOS) is the last open v2.3 phase — spike-first.
Previous: 2026-05-29 — V19D live-UAT review; Phases 27/28 closed; Phase 29 created and executed same-day.

### Next Action (2026-06-04)

`/gsd-resume-work` → recommended sequence:

1. `/gsd-spike 30` (or manual `.planning/spikes/002-…/`) — feasibility check for MediaRemote `getNowPlayingInfo` on installed macOS. See `project_ptt_media_autopause` memory for the gating constraint.
2. If MediaRemote path is feasible → `/gsd-plan-phase 30` (proper plan with pause/resume design).
3. If not feasible → adopt the pre-agreed mute-output fallback; abbreviated `/gsd-plan-phase 30`.
4. After Phase 30 ships → `/gsd-complete-milestone v2.3`.
5. Then `/gsd-new-milestone v2.4` — theme already drafted in this STATE.md ("v2.4 Backlog Cluster" section above) and in `log-analysis-2026-06-04.md`.

Key constraints carried forward:

- Cross-platform parity per `feedback_cleanup_cross_platform_parity` — all Shared/ changes ship macOS + iOS together. (Phase 30 is macOS-only by scope — iOS sibling deferred.)
- `.planning/` is gitignored — no GSD commits target `.planning/*` files.
- No German-parity gating per `project_usage_pattern_english_dominant`.
- v2.4 public-release readiness work has a hard precondition: empty (or minimal-universal) default dictionary before any public release — see `personal-vs-default-dictionary-split.md` backlog item.
- Currently installed macOS app is build `addc5c2` (2026-05-30, Debug-Recorder) — no rebuild scheduled until Phase 30 work produces something material, per user decision 2026-06-04.
