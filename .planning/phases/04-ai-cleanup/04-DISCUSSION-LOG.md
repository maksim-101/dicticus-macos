# Phase 4: AI Cleanup - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-17
**Phase:** 04-ai-cleanup
**Mode:** --auto (all decisions auto-selected)
**Areas discussed:** Cleanup behavior scope, Model loading strategy, Model distribution, Cleanup state feedback

---

## Cleanup Behavior Scope

| Option | Description | Selected |
|--------|-------------|----------|
| Conservative | Grammar, punctuation, capitalization, filler removal only. No restructuring. | ✓ |
| Moderate | Also smooth awkward spoken phrasing into written form. | |
| Aggressive | Restructure sentences for clarity and flow (heavy rewrite). | |

**User's choice:** [auto] Conservative (recommended default)
**Notes:** Aligns with AICLEAN-02 requirement ("preserves the user's original words and meaning — only fixes form"). Heavy rewrite is explicitly v2 (EMODE-01).

### Follow-up: Language-specific prompting

| Option | Description | Selected |
|--------|-------------|----------|
| Language-specific prompts | Separate German and English prompt templates | ✓ |
| Single multilingual prompt | One prompt that handles both languages | |

**User's choice:** [auto] Language-specific prompts (recommended default)
**Notes:** German grammar (cases, compound nouns, comma rules) differs significantly from English. NLLanguageRecognizer already provides detected language in DicticusTranscriptionResult.language.

---

## Model Loading Strategy

| Option | Description | Selected |
|--------|-------------|----------|
| Load at startup | Initialize llama.cpp context during warmup alongside ASR models | ✓ |
| Lazy-load on first use | Defer LLM init until first AI cleanup hotkey press | |

**User's choice:** [auto] Load at startup (recommended default)
**Notes:** INFRA-02 explicitly requires "LLM model loads at startup, stays warm." Consistent with existing ModelWarmupService pattern. Avoids surprise delay on first cleanup use.

---

## Model Distribution

| Option | Description | Selected |
|--------|-------------|----------|
| Download on first run | Fetch GGUF from HuggingFace, cache in Application Support | ✓ |
| Bundle in app | Include ~1 GB GGUF in app bundle | |

**User's choice:** [auto] Download on first run (recommended default)
**Notes:** Same pattern as FluidAudio/Parakeet CoreML download. Keeps initial app download small. Warmup UI already handles progress indication.

---

## Cleanup State Feedback

| Option | Description | Selected |
|--------|-------------|----------|
| Extend icon state machine | Add cleanup/cleaning state to existing icon progression | ✓ |
| Notification-based | Post system notification during cleanup | |
| No additional feedback | Reuse transcribing state for both ASR and LLM | |

**User's choice:** [auto] Extend icon state machine (recommended default)
**Notes:** Consistent with Phase 3's three-state icon (mic, mic.fill red, waveform.circle). Adding a cleanup state gives clear visual feedback. Pulsing animation pattern already established.

---

## Claude's Discretion

- llama.cpp SPM integration approach
- Specific prompt wording for cleanup templates
- Inference parameters (temperature, top-k, max tokens)
- SF Symbol for cleanup state
- GGUF download/caching implementation
- CleanupService internal threading model

## Deferred Ideas

- Heavy rewrite mode (EMODE-01) — v2 feature
- Prompt customization (EMODE-02) — v2 feature
- Streaming LLM output — unnecessary for short cleanup outputs
