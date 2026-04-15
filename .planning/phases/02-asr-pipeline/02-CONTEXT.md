# Phase 2: ASR Pipeline - Context

**Gathered:** 2026-04-15
**Status:** Ready for planning

<domain>
## Phase Boundary

Deliver the core speech-to-text inference engine: capture microphone audio, apply Voice Activity Detection to discard silence, transcribe via Whisper large-v3-turbo, and auto-detect German/English. Phase 2 does NOT add hotkeys, paste-at-cursor, or UI beyond what exists — it builds the pipeline that Phase 3 will wire to user-facing controls.

</domain>

<decisions>
## Implementation Decisions

### Audio Capture
- **D-01:** Use AVAudioEngine with `installTap(onBus:bufferSize:format:)` for microphone input — standard macOS audio capture, supports real-time buffer access needed for WhisperKit
- **D-02:** Convert audio to 16kHz mono Float32 at the tap level (AVAudioEngine format conversion) — WhisperKit requires this format, converting at source avoids downstream resampling
- **D-03:** Accumulate audio buffers in memory during recording, then pass the full buffer to WhisperKit for batch transcription — no streaming needed per project constraints (batch processing acceptable)

### Voice Activity Detection
- **D-04:** Use WhisperKit's built-in VAD capabilities as primary VAD — avoids adding external dependencies
- **D-05:** Add energy-based pre-filter before inference: compute RMS of audio buffer, skip transcription if below silence threshold — prevents WhisperKit from processing pure silence
- **D-06:** Discard recordings shorter than 0.3 seconds (TRNS-04) — sub-0.3s clips are noise, not speech
- **D-07:** VAD threshold should be configurable internally (not user-facing in v1) for tuning during development

### Model Selection
- **D-08:** Pin Whisper large-v3-turbo explicitly in WhisperKitConfig — Phase 1 used auto-selection, Phase 2 pins the specific model for predictable quality
- **D-09:** Use WhisperKit's default model download/caching (HuggingFace Hub) — no custom model management needed, WhisperKit handles storage in its standard cache location
- **D-10:** Model stays warm in memory after initial load (INFRA-01) — consume `ModelWarmupService.whisperKitInstance` directly, no re-initialization per transcription

### Language Detection
- **D-11:** Use WhisperKit's built-in language detection, restricted to German (de) and English (en) — prevents misdetection to other languages
- **D-12:** Language detection happens per-transcription automatically — no manual language switching UI needed (TRNS-03)

### Service Architecture
- **D-13:** New `TranscriptionService` class that consumes `ModelWarmupService.whisperKitInstance` — clean separation: warmup owns init lifecycle, transcription service owns the audio→text pipeline
- **D-14:** TranscriptionService exposes a simple async API: `func transcribe(audioBuffer: AVAudioPCMBuffer) async throws -> TranscriptionResult` — result includes text, detected language, and confidence
- **D-15:** TranscriptionService is @MainActor ObservableObject so UI can observe transcription state (idle, recording, transcribing)

### Claude's Discretion
- Internal buffer management strategy (pre-allocated vs dynamic)
- Specific energy threshold values for silence detection
- Error handling and retry behavior for failed transcriptions
- Exact WhisperKit API calls and configuration parameters

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project Context
- `.planning/PROJECT.md` — Core value, constraints, key decisions
- `.planning/REQUIREMENTS.md` — TRNS-02, TRNS-03, TRNS-04, INFRA-01 are this phase's requirements
- `.planning/ROADMAP.md` — Phase 2 success criteria and dependency chain

### Technology Decisions
- `CLAUDE.md` §Technology Stack — WhisperKit, whisper-large-v3-turbo model, AVFoundation audio capture decisions

### Phase 1 Foundation
- `Dicticus/Dicticus/Services/ModelWarmupService.swift` — WhisperKit initialization and `whisperKitInstance` handoff point
- `Dicticus/Dicticus/Services/PermissionManager.swift` — Microphone permission checking (already implemented)
- `.planning/phases/01-foundation-app-shell/01-CONTEXT.md` — Phase 1 decisions including D-03 (warmup at launch), D-08 (SPM dependencies)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `ModelWarmupService.whisperKitInstance` — Initialized WhisperKit instance ready for transcription
- `PermissionManager.microphoneStatus` — Microphone permission state (already checks AVCaptureDevice authorization)
- WhisperKit SPM dependency already in project.yml

### Established Patterns
- `@MainActor` ObservableObject services with `@Published` state (ModelWarmupService, PermissionManager)
- `Task.detached(priority: .utility)` for background work with `[weak self]` and `MainActor.run` for UI updates
- `.environmentObject()` injection from DicticusApp into MenuBarView

### Integration Points
- `ModelWarmupService.whisperKitInstance` is the handoff — TranscriptionService reads this, does NOT create its own WhisperKit
- Phase 3 will call `TranscriptionService.transcribe()` when hotkey is released
- Menu bar dropdown may need a minimal status indicator for transcription state (but no new UI required in Phase 2)

</code_context>

<specifics>
## Specific Ideas

- WhisperKit's `transcribe(audioPath:)` and `transcribe(audioArray:)` APIs should be evaluated — audioArray avoids file I/O
- The transcription pipeline should be testable without the full app running (unit tests with synthetic audio buffers)
- Language detection should be silent to the user — no UI indicator for detected language in Phase 2 (Phase 3 may surface this)

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 02-asr-pipeline*
*Context gathered: 2026-04-15*
