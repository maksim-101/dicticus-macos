# Phase 19: AI Cleanup iOS - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-24
**Phase:** 19-ai-cleanup-ios
**Areas discussed:** Model budget & device support, Activation UX & download gating, Swiss German + ITN guarantees, Latency/result delivery, LLM warmup/download lifecycle

---

## Gray Area Selection

| Area | Description | Selected |
|------|-------------|----------|
| Model budget & device support | Gemma 4 E2B vs Gemma 3 1B vs device-gated | ✓ |
| Keyboard-extension reach | Run cleanup for keyboard-IPC dictation? | ✓ (pre-answered — keyboard removed in commit 8f21760; cleanup only at main-app seam) |
| Activation UX & download gating | Settings toggle, onboarding, per-dictation | ✓ |
| Swiss German + ITN guarantees | Deterministic regex vs prompt-only | ✓ |
| Latency / result delivery | Block until cleaned vs show raw, replace | ✓ |

**User note on keyboard extension:** "I was under the impression that we reverted the keyboard and we're now solely focusing on the shortcut." Confirmed — keyboard removed in commit 8f21760. Cleanup integrates only at main-app `DictationViewModel` / `TextProcessingService` seam.

---

## Model

| Option | Description | Selected |
|--------|-------------|----------|
| Gemma 4 E2B Q4_K_M (Recommended) | ~3.1 GB disk, ~3 GB peak RAM, matches macOS, best German quality | ✓ |
| Gemma 3 1B Q4_K_M | ~1 GB disk, weaker German | |
| Ship both, let user choose | Two downloads, doubles maintenance | |

**User's choice:** Gemma 4 E2B Q4_K_M — matches macOS.

---

## Device Gating

| Option | Description | Selected |
|--------|-------------|----------|
| Gate by total RAM (Recommended) | `ProcessInfo.physicalMemory`, <5 GB disables toggle | ✓ |
| Allow all iOS 17+ devices | No gating, OOM risk on 4 GB devices | |
| Hardcoded device allowlist | Deterministic but needs maintenance | |

**User's choice:** Gate by total RAM.

---

## Activation & Download

| Option | Description | Selected |
|--------|-------------|----------|
| Settings toggle, download on first enable (Recommended) | Matches macOS, onboarding stays at 2.7 GB, Settings hosts the LLM download | ✓ |
| Bundle in onboarding | Add fourth onboarding step | |
| Per-dictation long-press | No persistent toggle | |

**User's choice:** Settings toggle, download on first enable.

---

## Latency / Result Delivery

| Option | Description | Selected |
|--------|-------------|----------|
| Block until cleaned (Recommended) | Match macOS, 1–3 s wait, simpler state | ✓ |
| Show raw, replace when ready | Faster perceived latency, jarring UX | |
| You decide | Claude's discretion | |

**User's choice:** Block until cleaned.

---

## Swiss German ß→ss (First Pass)

| Option | Description | Selected |
|--------|-------------|----------|
| Deterministic regex post-pass (Recommended) | Enforced regardless of LLM | |
| Prompt-only | Tell Gemma to use Swiss rules | |
| Both | Prompt AND post-pass | |

**User's response:** "So if it were a deterministic Ragex post pass would this also apply for plain dictation or only to the AI cleanup? And how much overhead or additional processing would this add? and shouldn't LLM be capable of that? and what about plain dictation? could we install some rules directly there or I need a little bit more context here please"

**Context provided:** Explained the pipeline (ASR → Dictionary → ITN → [LLM] → Injection), the cost of a regex pass (sub-millisecond), why deterministic > LLM for hard rules (LLMs are stochastic), and that plain-dictation users would also benefit from rules at the ITN layer. Clarified that numbers/currencies are better left to the LLM (semantic context) while orthography fits a regex.

---

## Swiss German Scope (Second Pass, After Context)

| Option | Description | Selected |
|--------|-------------|----------|
| ITN + prompt + post-LLM safety net (Recommended) | Full coverage at all stages | ✓ |
| ITN only | No prompt change | |
| AI-only | Don't touch plain dictation | |

**User's choice:** ITN layer + prompt + post-LLM safety net — covers plain dictation and AI-cleaned output.

---

## Swiss German Toggle

| Option | Description | Selected |
|--------|-------------|----------|
| Dedicated toggle in Settings (Recommended) | Explicit, user-controlled, default OFF | ✓ |
| Auto-enable from device locale (de-CH) | "Magic" default | |
| Always on | No toggle, forced on all users | |

**User's choice:** Dedicated Settings toggle.

---

## Additional Swiss Rules

| Option | Description | Selected |
|--------|-------------|----------|
| Just ß→ss (Recommended) | Start with the hard rule | ✓ (via follow-up) |
| Thousands separator regex | Brittle (decimal vs thousands) | (rejected as regex, kept via LLM prompt) |
| Swiss vocab substitutions | Translation, not orthography | (rejected; Custom Dictionary covers it) |

**First pass:** User selected all three (conflicting). **Follow-up clarified:** picked "ß→ss deterministic + LLM prompt mentions Swiss for everything else" — thousands handled via LLM, vocab via Custom Dictionary.

---

## LLM Warmup

| Option | Description | Selected |
|--------|-------------|----------|
| On app launch if toggle is on (Recommended) | Match macOS, extends IOSModelWarmupService | ✓ |
| Lazy on first dictation | Load at first use, ~5–8 s first-run latency | |
| Lazy + unload when idle | Minimum memory, load cost every "first" | |

**User's choice:** On app launch if toggle is on.

---

## Download UI Location

| Option | Description | Selected |
|--------|-------------|----------|
| Inline in Settings (Recommended) | Next to toggle, reuses existing patterns | ✓ |
| Full-screen modal | Blocking UI | |
| Background + notification | Background URLSession required | |

**User's choice:** Inline in Settings.

---

## Inference Timeout

| Option | Description | Selected |
|--------|-------------|----------|
| 8 s on iOS (Recommended) | Buffer for slower Neural Engine | ✓ |
| Match macOS 5 s | Same value everywhere | |
| Adaptive | Measure first inference, adjust | |

**User's choice:** 8 s on iOS.

---

## Claude's Discretion

- Whether to extract the current macOS `CleanupService.swift` into `Shared/` or keep two services (planner's call).
- Exact Settings UI layout (toggle order, explainer copy, download sheet vs inline expander).
- Error messages and explainer copy.
- Whether to show a "Reset AI Cleanup" affordance to delete the GGUF.
- Whether the LLM warmup progress is shown to the user or silent.

## Deferred Ideas

- Phi-3 Mini heavier rewrite mode (future phase).
- Per-dictation raw/cleaned choice (long-press).
- Streaming / per-word replace cleanup UI.
- Background URLSession for LLM download.
- Adaptive timeout.
- Swiss thousands separator as deterministic regex.
- Built-in Swiss vocab list (Velo/Fahrrad).
- Mixed-language cleanup improvements (accepted limitation).
- "Reset AI Cleanup" UI (nice-to-have, discretion).
- Full-screen / modal LLM download UX.
- Device allowlist gating (in favor of RAM-based).
