---
title: Dictation appears to cut off around 30s on macOS
captured: 2026-05-01
source: user-feedback (post-macos-v1.2.0 production usage)
status: backlog
priority: medium
platforms: [macOS]
needs_repro: true
---

# Dictation appears to cut off around 30 seconds (macOS)

## Finding

When dictating long-form content with the AI cleanup combo on macOS, the
session appears to abort and transcribe what was spoken so far at roughly
the 30-second mark — even while the user is still speaking and still
holding the push-to-talk hotkey. User reports this is observable enough
to time, but doesn't have a clean reproduction recipe yet.

User's own framing:
> "I feel like there is a timeout so if the dictation goes maybe more
> than 30 seconds, then it will abort and transcribe what I've said
> thus far. While I'm talking, I'm observing maybe the time as well.
> I feel like it's coming from the app and not me moving or releasing
> the finger from the two keys."

## Suspect locations (untriaged — list before diving)

- **AudioCaptureService** — buffer/window limits, AVAudioSession
  interruption handlers, sandbox time limits.
- **HotkeyManager / KeyboardShortcuts integration** — keyDown event
  loss under macOS's CGEventTap quotas (the system can revoke event
  taps from misbehaving processes; 30s is suspiciously round).
- **FluidAudio inference pipeline** — Parakeet TDT v3 has been
  documented as supporting long audio (~24min), but our wrapper may
  chunk or impose its own ceiling.
- **CleanupService streaming** — does the LLM step kick in mid-utterance
  on a timer rather than on hotkey-release?
- **VAD / silence detection** — if any silence threshold is in place,
  pauses for thought could trigger a "you're done" inference.

## Reproduction notes

User cannot reliably reproduce on demand. Suggested capture protocol
when it next happens:
1. Note exact dictation duration (rough seconds).
2. Was AI cleanup ON? Was Swiss German toggle ON?
3. Console.app filter for `process == "Dicticus"` — capture the burst
   of log lines around the cutoff.
4. Activity Monitor — was Dicticus's CPU/RAM usage doing anything
   unusual right before the cutoff?

## When to escalate

- If recurrence rate increases (≥1 per session of long-form use).
- If reproducible recipe emerges.
- Either case → run `/gsd-debug` with this file as the problem
  description.

## Not blocking

macos-v1.2.0 is shipping correctly for short-to-medium utterances
(the 90% case). This is a long-form-only edge case the user is
flagging proactively, not a regression that breaks normal use.
