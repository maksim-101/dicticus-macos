# Phase 2: ASR Pipeline - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-15
**Phase:** 02-asr-pipeline
**Areas discussed:** Audio capture, VAD strategy, Model pinning, Transcription architecture
**Mode:** --auto (all decisions auto-selected as recommended defaults)

---

## Audio Capture

| Option | Description | Selected |
|--------|-------------|----------|
| AVAudioEngine with installTap | Standard macOS audio capture, real-time buffer access, format conversion at tap level | x |
| AVCaptureDevice session | Higher-level API, less control over buffer format and timing | |

**User's choice:** [auto] AVAudioEngine with installTap (recommended default)
**Notes:** AVAudioEngine provides direct control over sample rate conversion (16kHz mono for WhisperKit) and buffer accumulation. AVCaptureDevice is more suited for video/photo capture workflows.

---

## VAD Strategy

| Option | Description | Selected |
|--------|-------------|----------|
| WhisperKit built-in VAD + energy pre-filter | Use WhisperKit's native VAD, add RMS energy gate before inference | x |
| External WebRTC VAD | Well-tested VAD library, requires additional dependency | |
| Energy-only VAD | Simple RMS threshold, no ML-based speech detection | |

**User's choice:** [auto] WhisperKit built-in VAD + energy pre-filter (recommended default)
**Notes:** Combines WhisperKit's ML-based VAD with a simple energy gate to avoid sending silence to inference. Sub-0.3s minimum duration filter per TRNS-04.

---

## Model Pinning

| Option | Description | Selected |
|--------|-------------|----------|
| Pin large-v3-turbo in WhisperKitConfig | Explicit model selection for predictable quality | x |
| Keep auto-selection | Let WhisperKit choose based on hardware | |

**User's choice:** [auto] Pin large-v3-turbo (recommended default)
**Notes:** Phase 1 used auto-selection as a placeholder. Phase 2 pins the specific model to ensure consistent transcription quality matching the Parakeet V3 baseline the user is accustomed to.

---

## Transcription Architecture

| Option | Description | Selected |
|--------|-------------|----------|
| New TranscriptionService consuming warmup instance | Clean separation — warmup owns init, transcription owns pipeline | x |
| Extend ModelWarmupService with transcription methods | Simpler but mixes concerns | |

**User's choice:** [auto] New TranscriptionService (recommended default)
**Notes:** TranscriptionService gets the WhisperKit instance from ModelWarmupService.whisperKitInstance. Exposes async transcribe() API that Phase 3 will call.

---

## Claude's Discretion

- Buffer management strategy
- Energy threshold values for silence detection
- Error handling for failed transcriptions
- Exact WhisperKit API configuration

## Deferred Ideas

None
