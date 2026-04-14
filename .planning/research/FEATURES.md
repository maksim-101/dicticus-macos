# Feature Landscape: Local Dictation / Voice-Typing Apps

**Domain:** Dictation and voice-typing productivity tools (local/offline focus)
**Researched:** 2026-04-14
**Confidence:** MEDIUM — based on training knowledge (cutoff Aug 2025); WebSearch/WebFetch unavailable. Products surveyed: MacWhisper, Superwhisper, Whisper Transcription (iOS), Dragon NaturallySpeaking / Dragon for Mac, Apple Dictation (Enhanced), Google Voice Typing, Talon Voice, Wispr Flow.

---

## Table Stakes

Features users expect from any serious dictation tool. Missing = product feels incomplete or broken.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Accurate transcription (ASR quality) | Core value prop — inaccurate transcription is unusable | High | Parakeet V3 / Whisper large-v3 set the quality bar; users have internalized this quality level from MacWhisper |
| Push-to-talk or toggle activation | Nobody wants always-listening; hotkey is the universal pattern | Low | MacWhisper, Superwhisper, Wispr Flow all use hotkeys; Dragon uses voice commands |
| System-wide text insertion | Dictation limited to one app is a non-starter for power users | Medium | Paste-at-cursor via clipboard or accessibility API; macOS requires Accessibility permission |
| Configurable hotkey | Users have wildly different keyboard setups; hardcoded keys cause conflicts | Low | Simple preferences pane or settings file; table stakes for any Mac utility |
| Low latency from release to paste | > 3–4 s feels broken for short utterances; users abandon slow tools | Medium | Model size, hardware, and pipeline design all matter; Apple Silicon makes <2s achievable for Parakeet-class models |
| Works offline / no cloud dependency | Privacy-conscious users (the target market) specifically seek this | High | Core architectural constraint, not just a feature; model bundling / download-on-first-run required |
| Menu bar or tray presence | Dictation tools live in the background; windowed apps create friction | Low | macOS menu bar extra; Windows system tray icon |
| Visual feedback during recording | Users need to know the mic is active; silent recording = uncertainty | Low | Animated icon, pulsing indicator, or waveform; prevents double-activations and silence errors |
| Basic punctuation handling | Transcription without punctuation is unreadable for anything beyond quick notes | Medium | Can be rule-based (Dragon legacy) or LLM-assisted (modern approach); users expect at minimum sentence-ending periods |
| Multiple language support | Monolingual tools exclude large user segments; bilingual users exist everywhere | Medium | Whisper models handle 90+ languages natively; the constraint is which languages get quality attention |

---

## Differentiators

Features that set a product apart. Not universally expected, but create strong loyalty when present.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| AI cleanup / light grammar polish | Removes filler words, fixes grammar, adds punctuation — turns spoken text into written text without changing meaning | Medium | The gap MacWhisper partly fills; Superwhisper and Wispr Flow make this central; requires local LLM (Llama 3 / Mistral class) or cloud (OpenAI) |
| Heavier rewrite mode (prose transformation) | Transforms rambling speech into polished paragraphs; useful for emails, documents, Slack messages | Medium-High | Needs a capable local LLM (7B+ parameter); prompt engineering critical for quality; separate hotkey pattern is elegant |
| Auto language detection | Bilingual users don't want to switch modes; German + English codeswitching is common in Swiss/German contexts | Medium | Whisper natively detects language per segment; Parakeet V3 also supports this; the trick is reliability at utterance level, not just document level |
| Per-mode hotkeys (plain / light / heavy) | Eliminates modal UI — user declares intent at activation, not after | Low | Key UX differentiator vs. Superwhisper's context-based approach; simple to implement once modes exist |
| Fully local LLM for AI polish | Privacy guarantee extends to the AI layer, not just ASR | High | Requires bundling or downloading a 3–8B model; significant disk and RAM impact; but trust differentiator vs. Wispr Flow (cloud LLM) |
| iOS dictation replacement | Most iOS dictation tools are cloud-based or limited to their own app; local iOS voice input is rare | High | Custom keyboard approach requires iOS Keyboard Extension (significant sandboxing constraints); Siri Shortcut approach is simpler but less seamless |
| Custom AI instructions / persona | Power users want the AI to know their writing style, terminology, or context (e.g., "always use formal German") | Medium | Superwhisper supports custom prompts per mode; useful for professional niches |
| Transcription history | Recover what you said, review or re-paste previous clips | Low | Local SQLite log; privacy-safe since everything is local; Superwhisper has this |
| Vocabulary / custom word list | Domain-specific terms (medical, legal, code) have poor ASR accuracy without hints | Medium | Whisper does not natively support hot-word boosting; workaround via post-processing or custom prompting |
| Sound effects / haptic feedback | Satisfying confirmation audio on record-start, record-stop, and paste-complete | Low | Small but impactful UX detail; Superwhisper does this well |
| Waveform / transcript preview | Show what was captured before pasting, allow editing | Medium | Adds latency to the happy path; optional preview mode vs. auto-paste mode |
| Multiple microphone / input device selection | Users with USB mics, AirPods, or studio interfaces want control | Low | CoreAudio on macOS; AVFoundation on iOS; straightforward settings |
| Context-aware mode selection | Detect active app and automatically use appropriate mode (e.g., coding context vs. prose) | High | Superwhisper experiments with this; requires accessibility API introspection of frontmost app; complex and fragile |
| Streaming / real-time transcription | See words appear as you speak, not just after releasing the key | High | Requires streaming ASR (Whisper streaming / faster-whisper with VAD); higher complexity, higher latency variability; nice-to-have not required |
| Windows client with feature parity | Cross-platform reach; corporate users often Windows-only | High | Separate implementation unless using Electron/Tauri shared UI; Win32 hotkeys and clipboard API differ from macOS |
| Keyboard shortcut for re-paste | Re-insert the last transcription without re-recording | Low | Useful when paste fails or focus moves; simple clipboard management |

---

## Anti-Features

Features to explicitly NOT build in this product.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| Always-listening / wake word activation | Privacy-destroying, battery-draining, socially unacceptable in shared spaces; contradicts the product's privacy core value | Push-to-talk only; toggle mode for mobile where single hand is the constraint |
| Cloud ASR / LLM fallback | Breaks the privacy guarantee the target user explicitly chose this product for; trust once lost is gone | Invest in model optimization (quantization, Metal/CoreML acceleration) to make local fast enough |
| GUI-heavy windowed app as primary interface | Dictation is a background utility; opening a window on every use is disruptive to the workflow it's supposed to support | Menu bar / tray as the permanent home; settings in a separate preferences window opened rarely |
| Custom voice training | Single-user tool doesn't need per-user acoustic models; modern Whisper-class models generalize well without training | Accept default model quality; let vocabulary hints handle edge cases |
| Subscription pricing for local-only features | Users paying for local tools expect to own what they install; subscription on local processing creates resentment | One-time purchase or perpetual license; optional subscription only for cloud-value-add features (which this product avoids) |
| Built-in email / calendar integration | Scope creep; these integrations have high maintenance cost (API changes) and low usage relative to general-purpose dictation | Keep as pure text output; let the user paste into any app they want |
| Speaker diarization / multi-speaker support | Single-user push-to-talk tool; diarization adds latency and complexity for zero user benefit | Explicitly single-speaker; document this as a non-goal |
| Real-time collaboration or shared transcripts | Antithetical to local-first, privacy-first design; requires a server | Out of scope by architecture |
| Aggressive onboarding / tutorial flows | Power users (the target) find these patronizing; dictation tool users know what they want | First-run: one permission dialog (Accessibility + Microphone), one hotkey confirmation, done |

---

## Feature Dependencies

```
ASR engine (Parakeet V3 / Whisper)
  └── Plain transcription mode
        └── Paste-at-cursor
              └── System-wide insertion (Accessibility API permission)
        └── Transcription history (optional, depends on plain transcription working)

Plain transcription mode
  └── AI cleanup mode (light)
        └── Local LLM integration
              └── Heavier rewrite mode (heavy)
                    └── Per-mode hotkey routing
                          └── Custom AI instructions per mode (optional)

Multi-language support (Whisper auto-detect)
  └── Auto language detection (no manual switching needed)

Microphone input
  └── Visual recording indicator (feedback loop)
  └── Input device selection (optional)

macOS menu bar presence
  └── Push-to-talk hotkey listener
  └── Settings / preferences (rare access)
  └── Sound effects (optional)

iOS: separate dependency tree
  Keyboard Extension
    └── Toggle-to-talk on iPhone
          └── ASR (on-device, limited by iOS sandbox)
                └── AI cleanup (on-device LLM — constrained by iOS RAM limits)
  OR
  Siri Shortcut / iOS Share Sheet
    └── Simpler but less seamless than keyboard extension
```

---

## Competitor Feature Matrix

Products surveyed and their notable patterns:

| Feature | MacWhisper | Superwhisper | Wispr Flow | Dragon Mac | Apple Dictation | Talon Voice |
|---------|------------|--------------|------------|------------|-----------------|-------------|
| Local ASR | Yes (Whisper) | Yes (Whisper) | No (cloud) | No (cloud) | Optional (Enhanced mode) | Yes (Conformer) |
| System-wide paste | No (app-scoped) | Yes | Yes | Yes | Yes | Yes |
| Push-to-talk hotkey | Yes | Yes | Yes | Partial | Yes | No (always-listening) |
| AI cleanup | No | Yes | Yes | No | No | No |
| Multiple modes/hotkeys | No | Partial (contexts) | No | No | No | Via scripting |
| Auto language detect | Yes | Yes | Partial | Manual | Manual | No |
| iOS support | No | No | Yes (cloud) | No | OS-level | No |
| Windows support | No | No | Yes | Yes | No | Yes (limited) |
| Transcription history | Yes | Yes | Partial | No | No | No |
| Custom vocabulary | No | Partial (prompts) | No | Yes | No | Via scripting |
| Privacy (fully local) | Yes | Yes | No | No | Optional | Yes |
| One-time purchase | Yes | Yes | Subscription | Subscription | Free (OS) | Free (OSS) |

**Key gap MacWhisper has that Dicticus must fill:** system-wide paste. MacWhisper requires the user to manually paste — it copies to clipboard but does not insert at cursor. This is the #1 user complaint in MacWhisper reviews and the core reason to build Dicticus.

**Key gap Superwhisper has that Dicticus can exploit:** Superwhisper's AI modes use cloud LLMs by default; local LLM option exists but is secondary. Dicticus makes fully local the only option — trust story is cleaner.

---

## MVP Recommendation

The minimum viable product that delivers the core value and beats MacWhisper's limitation:

**Must ship in v1:**
1. Push-to-talk hotkey with plain transcription (Parakeet V3 / Whisper large)
2. System-wide paste-at-cursor (the gap MacWhisper doesn't fill)
3. Menu bar presence with recording indicator
4. AI cleanup mode via separate hotkey (local LLM, light grammar/punctuation)
5. Auto-detect German/English
6. Configurable hotkeys

**Ship in v1 if low effort, defer if not:**
- Transcription history (SQLite log)
- Sound effects on record/paste
- Heavier rewrite mode (third hotkey, more aggressive LLM prompt)

**Defer to later milestones:**
- iOS dictation (high complexity, separate architecture)
- Windows support (separate implementation)
- Custom AI instructions per mode
- Streaming transcription
- Input device selection (start with system default)

---

## Sources

Note: WebSearch and WebFetch were unavailable during this research session. All findings are from training knowledge (cutoff August 2025).

- MacWhisper by Jordi Bruin — personal use and community reports; confidence MEDIUM
- Superwhisper — documentation and feature pages known from training; confidence MEDIUM
- Wispr Flow — product positioning known from training; confidence MEDIUM
- Dragon NaturallySpeaking / Dragon for Mac (Nuance/Microsoft) — long-established product, feature set stable; confidence HIGH
- Apple Dictation Enhanced Mode — official Apple documentation patterns; confidence HIGH
- Talon Voice — open source / community-maintained; confidence MEDIUM
- General Whisper ecosystem knowledge — confidence HIGH (well-documented open source)

**Validation recommended before roadmap finalization:**
- Verify Superwhisper's current local LLM support status (may have changed post-training-cutoff)
- Verify MacWhisper's current system-wide paste status (may have been added in recent versions)
- Check Wispr Flow's iOS feature set (was evolving rapidly in 2024–2025)
