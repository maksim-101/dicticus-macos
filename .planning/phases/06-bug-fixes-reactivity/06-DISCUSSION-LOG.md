# Phase 6: Bug Fixes & Reactivity - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-19
**Phase:** 06-bug-fixes-reactivity
**Areas discussed:** Quote stripping strategy, Icon reactivity approach, Testing & validation

---

## Quote Stripping Strategy

| Option | Description | Selected |
|--------|-------------|----------|
| Strip ALL quotes | Remove every quotation mark unconditionally. Dictation rarely needs literal quotes, and the model injects them unpredictably. Simplest fix. | ✓ |
| Strip surrounding + internal pairs | Strip quotes wrapping entire output OR matched pairs around phrases. Preserves intentionally dictated quotes but risks missing unpaired injected quotes. | |
| Prompt-only fix | Strengthen the prompt instruction without changing post-processing. Relies on model compliance — unreliable with Gemma 3 1B. | |

**User's choice:** Strip ALL quotes
**Notes:** User confirmed dictation doesn't need literal quotes. All Unicode quote variants covered (ASCII, smart quotes, German low-9, guillemets, single curly).

---

## Icon Reactivity Approach

| Option | Description | Selected |
|--------|-------------|----------|
| Relay via HotkeyManager | Add @Published pipelineState to HotkeyManager (already @StateObject). Observe TranscriptionService/CleanupService state via Combine. Minimal architectural change. | ✓ |
| @StateObject wrapper | Wrap services in new ObservableObject created at init time. Requires refactoring warmup flow. More invasive. | |
| Combine sink in label | Subscribe to service $state directly in MenuBarExtra label closure using .onReceive(). Keeps @State but feels like a workaround. | |

**User's choice:** Relay via HotkeyManager
**Notes:** HotkeyManager already owns pipeline lifecycle and is @StateObject in DicticusApp. Natural place for state relay. PipelineState enum with idle/recording/transcribing/cleaning cases.

---

## Testing & Validation

| Option | Description | Selected |
|--------|-------------|----------|
| Unit tests + manual UAT | Unit tests for quote stripping edge cases. Manual UAT for icon reactivity (visual states can't be unit tested meaningfully). Matches v1.0 pattern. | ✓ |
| Unit tests only | Cover quote stripping only. Skip manual UAT for icon. Faster but leaves icon fix unverified visually. | |
| You decide | Claude's discretion on testing strategy. | |

**User's choice:** Unit tests + manual UAT
**Notes:** UAT checklist: plain dictation → mic.fill → waveform.circle → mic; cleanup dictation → mic.fill → waveform.circle → sparkles → mic.

---

## Claude's Discretion

- Whether to remove existing surrounding-quote strip code or keep as defense-in-depth
- Combine wiring pattern (sink vs assign) for HotkeyManager state relay
- PipelineState enum file placement

## Deferred Ideas

None — discussion stayed within phase scope.
