# Phase 19: AI Cleanup iOS - Context

**Gathered:** 2026-04-24
**Status:** Ready for planning

<domain>
## Phase Boundary

Port the proven macOS AI cleanup pipeline (llama.cpp + Metal + Gemma 4 E2B) to iOS, integrated into the existing iOS dictation pipeline (`DictationViewModel` → `TextProcessingService`). Delivers CLEAN-01 (user can enable AI cleanup for grammar/punctuation correction on iOS) and CLEAN-02 (cleanup runs fully locally via llama.cpp Metal on iPhone).

Out of scope: any new cleanup capabilities beyond what macOS already does (no structural rewrites, no translation, no multi-model selection, no per-utterance mode). Cleanup is a polish layer over the existing transcription pipeline — not a rewrite of it.

Not in scope: keyboard-extension integration. The keyboard extension was removed in commit `8f21760` (iOS 26 blocks URL-opening from extensions). All iOS dictation now flows through the main app via Siri Shortcut / Action Button / in-app record button. AI cleanup therefore integrates at the single main-app pipeline point and does not cross any IPC boundary.

</domain>

<decisions>
## Implementation Decisions

### Model, runtime, and memory
- **D-01:** Ship **Gemma 4 E2B IT Q4_K_M** on iOS, same model as macOS. Source: `unsloth/gemma-4-E2B-it-GGUF/resolve/main/gemma-4-E2B-it-Q4_K_M.gguf` (~3.1 GB). Matches macOS quality and avoids divergent prompts.
- **D-02:** llama.cpp via `mattt/llama.swift` SPM package, Metal backend, `n_gpu_layers = 99` (all layers on Metal). Same config as macOS `CleanupService`.
- **D-03:** **Gate AI cleanup by device RAM.** Read `ProcessInfo.processInfo.physicalMemory` at launch. On devices with `<5 GB` total RAM (iPhone 12/13 and earlier, 4 GB A14), hide/disable the AI cleanup toggle with an explainer ("AI cleanup requires an iPhone 14 or newer"). Do not attempt inference on under-spec devices — OOM risk when combined with 2.7 GB Parakeet.
- **D-04:** Inference timeout **8 s** on iOS (vs 5 s on macOS). iPhone Neural Engine / GPU is slower than M-series. Beyond 8 s, fall back to raw ASR text. Same fallback contract as macOS `D-18`/`D-19`.
- **D-05:** Sampling config **matches macOS**: `temp=0.2`, `top_k=40`, `top_p=0.9`, random seed per call. Context window `n_ctx=2048`, batch 512, 4 CPU threads. Max output 512 tokens.
- **D-06:** KV cache cleared between calls via `llama_memory_clear(llama_get_memory(ctx), false)` — same pattern as macOS, prevents context bleed (Pitfall 5 from macOS phase 4 research).
- **D-07:** `com.apple.developer.kernel.increased-memory-limit` entitlement is already present on the iOS target (set in Phase 13 for ASR) — it also covers the LLM budget. No new entitlement work needed.

### Activation UX & download
- **D-08:** **"AI Cleanup" toggle in Settings**, default **OFF**. Matches macOS pattern. Toggle state is orthogonal to the Swiss German toggle.
- **D-09:** **Do NOT bundle the LLM download into onboarding.** First-launch download stays at 2.7 GB (Parakeet only) to minimize onboarding drop-off. The LLM download is triggered only when the user first flips the AI cleanup toggle ON.
- **D-10:** **Download UI lives inline in Settings**, next to the toggle. Flow: user flips toggle → sheet/inline panel shows size warning ("~3 GB, Wi-Fi recommended"), Download button, progress bar, pause/resume. Toggle stays in a "pending" state until download completes. No full-screen modal, no background URLSession (deferred).
- **D-11:** **Download path:** `Application Support/Dicticus/Models/gemma-4-E2B-it-Q4_K_M.gguf`. Mirrors the macOS path (`D-10` in macOS phase 4) for cross-platform consistency.
- **D-12:** **Warm up on app launch when toggle is ON.** Extend `IOSModelWarmupService` with a new Step 4 (LLM load) that runs only if the AI cleanup setting is enabled. Same actor-based pattern as the existing ASR/VAD warmup. Idle RAM increases by ~3 GB — acceptable on gated devices.
- **D-13:** **Block dictation result delivery until cleanup completes.** Match macOS behavior. No raw-then-replace UX. Keeps the state machine simple and matches user expectation that "cleaned" means "cleaned when I see it". 8 s timeout bounds the wait.
- **D-14:** **No keyboard extension path.** Dictation enters the pipeline exclusively via Siri Shortcut / Action Button / in-app record button. Cleanup hooks in at the main-app `DictationViewModel` / `TextProcessingService` seam only.

### Swiss German
- **D-15:** **Dedicated "Swiss German spelling" toggle in Settings**, default **OFF**, independent of the AI cleanup toggle. This toggle affects plain dictation and AI-cleaned dictation equally. Two orthogonal toggles: AI Cleanup (feature) × Swiss German (locale).
- **D-16:** **ß → ss enforced deterministically** via a regex pass in `Shared/Utilities/ITNUtility.swift` (ITN layer). Runs whenever the Swiss German toggle is ON, regardless of AI cleanup state. Applies to plain dictation too. Sub-millisecond cost — runs for every transcription when enabled.
- **D-17:** **Capital Eszett (ẞ) → SS** also handled. Respect case (lowercase → lowercase ss, uppercase → uppercase SS). Single Unicode-aware regex; no extra complexity.
- **D-18:** **LLM prompt is extended** when both toggles are ON: append "Use Swiss German orthography (never use ß, always ss). Use Swiss thousands separator style (e.g. 1'250, not 1.250)." to `CleanupPrompt.build()`. Prompt extension is gated by the Swiss toggle so standard-German users aren't affected.
- **D-19:** **Post-LLM safety-net regex for ß → ss** runs after cleanup when AI cleanup is ON. Catches any residual ß the LLM slipped in. Same regex as D-16, applied at a different call site.
- **D-20:** **Thousands separator (1'250) is LLM-only.** No regex attempt to deterministically convert `1.250 → 1'250` — distinguishing thousands from decimals without semantic context is unreliable. The prompt instruction in D-18 handles it when AI cleanup is on; plain-dictation Swiss users see whatever the raw ASR produced (acceptable v2.1 scope).
- **D-21:** **Vocabulary substitutions (Velo/Fahrrad, Tram/Straßenbahn, etc.) are the user's responsibility** via the existing Custom Dictionary (`DictionaryService` on iOS, DICT-01/02). No hardcoded Swiss vocab list. Forcing translations globally would break users who deliberately dictate standard German.

### Prompt, pipeline, and integration
- **D-22:** **Reuse `Shared/Models/CleanupPrompt.swift` unchanged.** Already cross-platform; the same `<start_of_turn>` template works. The Swiss-prompt extension (D-18) is a conditional additional line inside `build()`, not a new prompt.
- **D-23:** **Reuse `Shared/Protocols/CleanupProvider.swift`** — the new iOS service conforms to the existing protocol. `Shared/Services/TextProcessingService.swift` already accepts an injected `CleanupProvider?` and needs no change.
- **D-24:** **Custom Dictionary passed to LLM same as macOS** (`cleanup(text:, language:, dictionaryContext:)`). The LLM receives dictionary entries as `DICTIONARY:` lines in the prompt. No iOS-specific dictionary plumbing.
- **D-25:** **Language auto-detected** from `DicticusTranscriptionResult.language` — same as macOS. No user-facing language toggle for cleanup.
- **D-26:** **Fallback to raw ASR text on any failure** (timeout, load failure, inference error, concurrent-call rejection). Never lose the user's dictation. Same contract as macOS `D-19`.
- **D-27:** **Control token sanitization** (`CleanupPrompt.sanitizeControlTokens`) reused unchanged — prompt-injection guard from macOS phase 4 research applies equally on iOS.
- **D-28:** **Concurrent-call guard** — follow macOS `isInferring` pattern. C pointers (`model`, `context`, `sampler`) are not thread-safe; reject overlapping cleanup calls and return raw text.
- **D-29:** **Backend init once at app launch** (`llama_backend_init()`), consistent with macOS `CleanupService.initializeBackend()`. Never called from `deinit`.

### Claude's Discretion
- Whether to extract the current macOS `CleanupService.swift` into `Shared/Services/CleanupService.swift` (since the logic is platform-independent and only the warmup wiring differs) vs keep two near-identical services. The planner should evaluate diff size and risk; either is acceptable.
- Exact Settings UI layout (toggle order, explainer copy, download sheet vs inline expander) — follow iOS Settings idioms and the existing `SettingsView.swift` patterns.
- Error messages and explainer copy (device-unsupported, download-failed, timeout-hit). Use tone consistent with existing iOS onboarding/settings copy.
- Whether to show a "Reset AI Cleanup" affordance to delete the GGUF and free 3 GB — nice-to-have, not required.
- Whether the LLM warmup progress is shown to the user (reusing `IOSModelWarmupService.downloadProgress` UI) or silent.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project & scope
- `CLAUDE.md` — Project stack, Gemma 4 E2B choice, llama.cpp Metal, privacy constraints
- `.planning/PROJECT.md` — Vision, principles, non-negotiables
- `.planning/REQUIREMENTS.md` — CLEAN-01, CLEAN-02 definitions
- `.planning/ROADMAP.md` §Phase 19 — Goal statement
- `.planning/milestones/v1.0-ROADMAP.md` §Phase 4 — macOS AI cleanup reference (completed 2026-04-17, this is the source of truth for existing behavior)

### Existing cross-platform code (reuse unchanged or extend)
- `Shared/Models/CleanupPrompt.swift` — Prompt builder, control-token sanitizer, mixed-language detection. Reuse unchanged; extend `build()` only for Swiss prompt line (D-18).
- `Shared/Protocols/CleanupProvider.swift` — Protocol the new iOS cleanup service must conform to. Do not change.
- `Shared/Services/TextProcessingService.swift` — Pipeline orchestrator: `ASR → Dictionary → ITN → [LLM Cleanup] → Injection`. Already accepts `cleanupService: CleanupProvider?`. No changes beyond wiring.
- `Shared/Services/DictionaryService.swift` — Dictionary entries used as cleanup prompt context.
- `Shared/Utilities/ITNUtility.swift` — Where the Swiss ß→ss regex pass (D-16, D-17) lands.
- `Shared/Models/DictationMode.swift` — `plain` vs `aiCleanup` enum, drives pipeline branching.
- `Shared/Models/TranscriptionResult.swift` — `DicticusTranscriptionResult.language` used for prompt language hint.

### macOS reference implementation (mirror on iOS)
- `macOS/Dicticus/Services/CleanupService.swift` — Full reference implementation of the llama.cpp pipeline, sampler chain, KV-cache hygiene, timeout/fallback, preamble stripping. iOS service mirrors this (D-01 through D-06, D-26 through D-29).
- `macOS/Dicticus/Services/ModelDownloadService.swift` — GGUF download pattern. Port or share with iOS. See D-11 for path.
- `macOS/Dicticus/Services/ModelWarmupService.swift` — macOS warmup orchestration (reference for D-12).
- `macOS/Dicticus/Views/AiCleanupInfoView.swift` — macOS cleanup Settings UI reference for explainer copy.
- `macOS/project.yml` §packages, §targets — `llama` package dependency + `LlamaSwift` product + `OTHER_LDFLAGS: "-framework llama"`. Mirror in `iOS/project.yml`.

### iOS integration points
- `iOS/project.yml` — Add `llama` package + `LlamaSwift` product to the iOS target. See macOS `project.yml` for config.
- `iOS/Dicticus/Services/IOSModelWarmupService.swift` — Add conditional Step 4 (LLM warmup) per D-12. Current file explicitly says "NOTE: No Step 4 (LLM) on iOS v2.0 — locked decision" — this phase reverses that.
- `iOS/Dicticus/Services/IOSTranscriptionService.swift` — Stays as-is; cleanup lives one layer up in `TextProcessingService`.
- `iOS/Dicticus/DictationViewModel.swift` — The `TextProcessingService` consumer. Ensure it's injecting the new iOS cleanup provider when the toggle is on.
- `iOS/Dicticus/Settings/SettingsView.swift` — Hosts the two new toggles (AI Cleanup, Swiss German) and the LLM download UI (D-10).
- `iOS/Dicticus/Onboarding/OnboardingView.swift` — Do NOT change (D-09 keeps LLM out of onboarding).
- `iOS/Dicticus/Dicticus.entitlements` — `com.apple.developer.kernel.increased-memory-limit` already set; no change.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **`Shared/Models/CleanupPrompt.swift`** — Full prompt builder with `<start_of_turn>`/`<end_of_turn>` template, dictionary injection, control-token sanitization, mixed-language detection. Works identically on iOS. Only the Swiss-prompt extension (D-18) is new.
- **`Shared/Protocols/CleanupProvider.swift`** — Interface seam. New `IOSCleanupService` conforms to it; `TextProcessingService` needs zero changes.
- **`Shared/Services/TextProcessingService.swift`** — Pipeline is already written to accept `cleanupService: CleanupProvider?`. Just inject the iOS service when the toggle is on.
- **`macOS/Dicticus/Services/CleanupService.swift`** — Reference llama.cpp implementation. ~460 LOC of battle-tested pattern: backend init, model load, sampler chain, batched decode, token-by-token sampling with cancellation, timeout task group, preamble stripping (`stripPreamble`), resource deinit. iOS service can be nearly a copy; planner decides whether to extract to `Shared/`.
- **`macOS/Dicticus/Services/ModelDownloadService.swift`** — Clean URLSession download-and-cache pattern with `isModelCached()` / `downloadIfNeeded()`. iOS needs the same, possibly with progress-reporting delegate added (macOS doesn't expose progress mid-download).
- **`iOS/Dicticus/Services/IOSModelWarmupService.swift`** — Existing 3-step warmup (Parakeet + VAD). Adding Step 4 follows the established `@MainActor` + `Task.detached` + watchdog pattern.
- **`Shared/Utilities/ITNUtility.swift`** — Where the Swiss regex lands. Already the right home for rule-based text transforms.

### Established Patterns
- **Service lifecycle:** `@MainActor` `ObservableObject` with `@Published` state — `CleanupService` (macOS) and `IOSModelWarmupService` both follow this. New iOS cleanup service should too.
- **llama.cpp pointer hygiene:** `nonisolated(unsafe)` for C pointers accessed from `deinit` and detached tasks. Already proven in macOS `CleanupService`.
- **Memory entitlement:** `com.apple.developer.kernel.increased-memory-limit` already set on iOS target — no new entitlement.
- **Model files:** Application Support directory, separate subdirectories per provider (`FluidAudio/Models/...` for ASR, `Dicticus/Models/` for LLM).
- **Graceful degradation:** Any cleanup failure (timeout, load failure, concurrency) returns raw ASR text. Never lose user dictation. Established in macOS D-19.
- **Settings toggles:** iOS `SettingsView.swift` uses `@AppStorage`-backed toggles (see existing dictionary/setup guides); new toggles follow the same idiom.

### Integration Points
- **`TextProcessingService` seam** (`cleanupService: CleanupProvider?`) — single injection point. Already built.
- **`IOSModelWarmupService` Step 4** — where LLM loads. Conditional on the AI cleanup setting.
- **`SettingsView`** — toggles + download sheet live here.
- **`iOS/project.yml`** — adds `llama` package; requires `xcodegen generate` run.
- **`IOSCleanupService` (new)** — mirrors `macOS/Dicticus/Services/CleanupService.swift`. Planner decides: extract to `Shared/Services/CleanupService.swift` (recommended if diff is purely constants/timeout) or keep iOS-specific copy.

### Constraints discovered
- **Device RAM gating requires a runtime read** (`ProcessInfo.processInfo.physicalMemory`) — no Info.plist key exists to declare it. Planner should surface this in the device-check code path.
- **No iOS ModelDownloadService exists yet.** The macOS one is in `macOS/Dicticus/Services/` — either extract to `Shared/` (cross-platform, needs progress delegate) or mirror in `iOS/Dicticus/Services/`.
- **LLM warmup takes meaningful time** (~5–15 s on iPhone for first load) — reuse `IOSModelWarmupService.downloadProgress` / `downloadStatus` UI for transparency.
- **`IOSModelWarmupService` currently comments "No Step 4 (LLM) on iOS v2.0 — locked decision"** — that note must be updated/removed in this phase.

</code_context>

<specifics>
## Specific Ideas

- **Model URL is the same as macOS:** `https://huggingface.co/unsloth/gemma-4-E2B-it-GGUF/resolve/main/gemma-4-E2B-it-Q4_K_M.gguf` (unsloth, ungated, no auth).
- **Memory cutoff: 5 GB total RAM** (D-03). Practical effect: iPhone 14 / 14 Plus / 14 Pro / 14 Pro Max and newer, iPad M1 / M2 / Pro. Excludes iPhone 12 and 13 families.
- **Sampler preserved exactly:** `llama_sampler_init_temp(0.2)` → `top_k(40)` → `top_p(0.9, 1)` → `dist(random seed)`. No iOS-specific tuning unless benchmarks show regression.
- **`stripPreamble` is carried over** — same preamble patterns ("Here's the polished text:", "Hier ist der korrigierte Text:", etc.). Swiss German variants may need to be added (e.g. "Hier ist der korrigierte Text:" works for Swiss too, no ß in that phrase).
- **Two toggles, not one:** "AI Cleanup" (feature gate) and "Swiss German spelling" (locale rule). Intentionally orthogonal — Swiss users who don't want an LLM still get ß→ss.

</specifics>

<deferred>
## Deferred Ideas

- **Phi-3 Mini "heavier rewrite mode"** — mentioned in `CLAUDE.md` as a future option for structural rewrites. Not in v2.1 scope.
- **Per-dictation raw/cleaned choice (long-press mic, etc.)** — considered and rejected for v2.1. Current activation model is the persistent Settings toggle.
- **Streaming / per-word replace cleanup UI** ("show raw, replace when ready") — rejected for v2.1 in favor of block-until-cleaned. Revisit if user feedback is that the 1–3 s perceived latency is too high.
- **Background URLSession for LLM download** — considered and rejected for v2.1. Foreground Settings-panel download is sufficient. Revisit if users complain about having to keep the app open.
- **Adaptive timeout based on first-inference measurement** — rejected; fixed 8 s is simpler and good enough.
- **Swiss thousands separator as deterministic regex** — rejected as brittle (distinguishing thousands from decimals without semantic context is unreliable). LLM prompt handles it when AI cleanup is on.
- **Built-in Swiss vocab list (Velo/Fahrrad, etc.)** — rejected as translation-not-orthography. Users can add personal entries via Custom Dictionary.
- **Mixed-language cleanup improvements** — accepted limitation (Gemma translates the minority language). Not fixed here.
- **"Reset AI Cleanup" UI to delete GGUF and reclaim 3 GB** — left to Claude's discretion; nice-to-have.
- **Full-screen / modal LLM download UX** — rejected in favor of inline Settings panel.
- **Gating by device allowlist (iPhone 14 Pro+, etc.)** — rejected in favor of RAM-based gating (D-03), simpler to maintain.

</deferred>

---

*Phase: 19-ai-cleanup-ios*
*Context gathered: 2026-04-24*
