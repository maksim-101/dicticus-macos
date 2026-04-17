# Phase 4: AI Cleanup - Context

**Gathered:** 2026-04-17
**Status:** Ready for planning

<domain>
## Phase Boundary

Deliver AI-enhanced dictation: when the user holds the AI cleanup hotkey (already registered in Phase 3), transcribed text is automatically cleaned up by a local LLM before being pasted at cursor. This phase integrates Gemma 3 1B via llama.cpp into the existing dictation pipeline, adds language-specific cleanup prompts for German and English, extends the warmup infrastructure to load the LLM at startup, and validates that total ASR + LLM latency stays under 4 seconds.

</domain>

<decisions>
## Implementation Decisions

### Cleanup Behavior
- **D-01:** Conservative cleanup only — grammar correction, punctuation, capitalization, and filler word removal (uh, um, also, ähm, halt, etc.). No sentence restructuring, no rephrasing, no content changes. Preserves the user's original words and meaning per AICLEAN-02.
- **D-02:** Language-specific prompt templates — use the detected language from NLLanguageRecognizer (already available in DicticusTranscriptionResult.language) to select a German or English cleanup prompt. German grammar rules (cases, verb conjugation, compound nouns, comma rules) differ significantly from English and require tailored instructions.
- **D-03:** Output must be plain text only — no markdown, no formatting, no explanations. The LLM returns cleaned text and nothing else.

### Model & Inference
- **D-04:** Gemma 3 1B IT (QAT Q4_0 GGUF) as the cleanup model — ~1 GB on disk, small enough to coexist with Parakeet TDT v3 in memory on 16 GB Apple Silicon. Instruction-tuned with 140+ language support including German.
- **D-05:** llama.cpp as the inference runtime — Swift-callable via C API, Metal backend for Apple Silicon GPU acceleration, supports GGUF format natively.
- **D-06:** No network calls during inference — model runs fully locally. Hard privacy constraint per AICLEAN-04.

### Model Loading
- **D-07:** Load LLM at startup alongside ASR models — extend existing ModelWarmupService to initialize llama.cpp context after FluidAudio warmup completes. Consistent with INFRA-02 ("LLM model loads at startup, stays warm").
- **D-08:** Single warmup flow — warmup UI shows combined progress for both ASR and LLM initialization. LLM loading is sequential after ASR (not parallel) to avoid memory pressure spikes on first run.

### Model Distribution
- **D-09:** Download GGUF model on first run — same pattern as FluidAudio/Parakeet HuggingFace download. Keeps initial app size small. Warmup UI already handles download progress indication.
- **D-10:** Cache model in Application Support directory — follow the same convention as FluidAudio models for consistent disk management.

### Pipeline Integration
- **D-11:** Wire AI cleanup in HotkeyManager.handleKeyUp — when mode is .aiCleanup, pass ASR result through a CleanupService before TextInjector. Pipeline: record → ASR → LLM cleanup → paste. Plain dictation path unchanged.
- **D-12:** New CleanupService as @MainActor ObservableObject — follows established service pattern (TranscriptionService, ModelWarmupService). Encapsulates llama.cpp context, prompt construction, and inference.
- **D-13:** Language auto-selection — CleanupService reads DicticusTranscriptionResult.language to pick the German or English prompt template automatically. No manual language switching.

### State Feedback
- **D-14:** Extend icon state machine with cleanup state — add a visual indicator during LLM processing (after ASR transcription completes, before text injection). Reuse the pulsing pattern established for transcribing state.
- **D-15:** TranscriptionService.State or HotkeyManager state extended — add a .cleaning state (or equivalent) so DicticusApp.iconName can distinguish ASR processing from LLM cleanup visually.
- **D-16:** No separate notification for cleanup — the icon state machine provides sufficient feedback. Notification only on error (LLM failure, timeout).

### Latency Budget
- **D-17:** 4-second total latency target for ASR + LLM on typical utterances (< 30s speech). ASR typically takes ~1s on ANE, leaving ~3s for LLM inference. Gemma 3 1B at Q4_0 on Metal should produce short cleanup responses well within budget.
- **D-18:** Timeout guard on LLM inference — if cleanup exceeds 5 seconds, paste the raw ASR text as fallback and notify user. Better to paste uncleaned text than to hang.

### Error Handling
- **D-19:** LLM failure fallback — if cleanup fails for any reason (model error, timeout, empty output), paste the raw ASR transcription and post a notification. Never lose the user's dictation.
- **D-20:** Model not loaded fallback — if AI cleanup hotkey is pressed before LLM warmup completes, show "Model loading..." notification (same pattern as D-17 in Phase 3 for ASR).

### Claude's Discretion
- llama.cpp SPM integration approach (C API bridging header vs. Swift wrapper package)
- Specific prompt wording for German and English cleanup templates
- llama.cpp inference parameters (temperature, top-k, max tokens, etc.)
- Exact SF Symbol choice for cleanup state icon
- GGUF model download implementation details (HuggingFace URL, caching logic)
- CleanupService internal architecture (sync vs async inference, threading)
- Whether to extend TranscriptionService.State enum or use a separate state in HotkeyManager

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project Context
- `.planning/PROJECT.md` — Core value, privacy constraints, key decisions
- `.planning/REQUIREMENTS.md` — AICLEAN-01 through AICLEAN-04, INFRA-02 are this phase's requirements
- `.planning/ROADMAP.md` — Phase 4 success criteria, dependency on Phase 3

### Technology Decisions
- `CLAUDE.md` §Local LLM for Text Cleanup — Gemma 3 1B IT (QAT Q4_0 GGUF), llama.cpp, prompt design rationale
- `CLAUDE.md` §ASR Engine — FluidAudio SDK + Parakeet TDT v3 (ASR pipeline this phase builds upon)

### Prior Phase Context
- `.planning/phases/03-system-wide-dictation/03-CONTEXT.md` — Hotkey routing (D-12, D-13: AI cleanup stub), icon state machine (D-09, D-11), error handling patterns (D-15 through D-19)
- `.planning/phases/02.1-asr-engine-swap-whisperkit-to-fluidaudio-parakeet-tdt-v3/02.1-CONTEXT.md` — FluidAudio warmup pattern, service API shape

### Existing Code (Phase 4 integration points)
- `Dicticus/Dicticus/Services/HotkeyManager.swift` — DictationMode.aiCleanup stub at lines 71-79, handleKeyUp mode parameter ready for routing
- `Dicticus/Dicticus/Services/TranscriptionService.swift` — DicticusTranscriptionResult with .text and .language, pipeline this phase extends
- `Dicticus/Dicticus/Services/ModelWarmupService.swift` — Startup loading pattern to extend for LLM, warmupTask/watchdog pattern
- `Dicticus/Dicticus/DicticusApp.swift` — Icon state machine (iconName computed property), service wiring via onChange
- `Dicticus/Dicticus/Services/NotificationService.swift` — Error notification posting pattern
- `Dicticus/Dicticus/Services/TextInjector.swift` — Clipboard paste-at-cursor (final step after cleanup)
- `Dicticus/project.yml` — SPM package declarations (add llama.cpp here)

### Model References
- Gemma 3 1B IT QAT GGUF: https://huggingface.co/google/gemma-3-1b-it-qat-q4_0-gguf
- llama.cpp: https://github.com/ggerganov/llama.cpp — C API, Metal backend, Swift bridging

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `HotkeyManager` — Already has DictationMode.aiCleanup case and stub event loop (lines 71-79). Wire cleanup pipeline into handleKeyUp when mode is .aiCleanup.
- `ModelWarmupService` — Established pattern for background model init with watchdog timeout. Extend to initialize llama.cpp context after FluidAudio warmup.
- `TranscriptionService` — Delivers DicticusTranscriptionResult with .text and .language. Cleanup service consumes this directly.
- `TextInjector` — Clipboard + Cmd+V paste. Final step in both plain and cleanup pipelines.
- `NotificationService` — Error notification posting. Reuse for LLM failures.
- `DicticusApp.iconName` — Three-state icon computation. Extend with cleanup state.

### Established Patterns
- `@MainActor` ObservableObject services with `@Published` state — CleanupService should follow this
- `.environmentObject()` injection from DicticusApp — CleanupService wired the same way
- `Task.detached(priority: .utility)` for background init with `[weak self]` — LLM warmup follows this
- Timeout watchdog pattern in ModelWarmupService — reuse for LLM inference timeout
- Sequential warmup with combined UI feedback — extend, don't duplicate

### Integration Points
- `HotkeyManager.handleKeyUp(mode:)` — Branch on .aiCleanup to invoke CleanupService after ASR
- `ModelWarmupService.warmup()` — Add LLM initialization as step 4 (after ASR + VAD)
- `DicticusApp.body` onChange — Wire CleanupService creation after warmup completes
- `DicticusApp.iconName` — Add cleanup state visual indicator
- `project.yml` packages — Add llama.cpp SPM dependency

</code_context>

<specifics>
## Specific Ideas

- The AI cleanup hotkey (Fn+Control) is already registered and listening in HotkeyManager — Phase 4 replaces the `break` stubs with actual pipeline calls.
- ModelWarmupService already has the ASR + VAD loading sequence — LLM loading slots in as the next step in the same warmup() method.
- DicticusTranscriptionResult.language ("de" or "en") is ready to be consumed for language-specific prompt selection — no new language detection needed.
- The fallback behavior (paste raw ASR text on LLM failure) ensures the user never loses their dictation — the cleanup is purely additive.

</specifics>

<deferred>
## Deferred Ideas

- **Heavy rewrite mode** (EMODE-01) — Phi-3 Mini 3.8B for sentence restructuring and formal register. Deferred to v2 per REQUIREMENTS.md.
- **Prompt customization** (EMODE-02) — User-configurable cleanup behavior. Deferred to v2.
- **Streaming LLM output** — Show cleanup text appearing token-by-token. Unnecessary for short cleanup outputs.

</deferred>

---

*Phase: 04-ai-cleanup*
*Context gathered: 2026-04-17*
