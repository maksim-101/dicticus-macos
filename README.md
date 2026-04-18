# Dicticus

A fully local macOS dictation app. Hold a hotkey, speak, release — accurate text appears at your cursor instantly. Fully private, no cloud dependency.

## Features

- **System-wide push-to-talk** — works in any text field: browsers, native apps, terminal
- **On-device ASR** — Parakeet TDT v3 via FluidAudio on Apple Neural Engine (~200x realtime)
- **AI cleanup mode** — grammar, punctuation, and filler word correction via Gemma 3 1B (llama.cpp)
- **Auto language detection** — German and English, no manual switching
- **Configurable hotkeys** — standard key combos (KeyboardShortcuts) + modifier-only combos (Fn+Shift, Fn+Control)
- **Menu bar app** — minimal footprint, 170 MB memory with both models loaded
- **Launch at login** — optional, configurable in settings

## Requirements

- macOS 15+ (Sequoia)
- Apple Silicon Mac
- ~1.3 GB disk for ASR model (Parakeet TDT v3 CoreML) + ~1 GB for LLM model (Gemma 3 1B GGUF)

## Installation

1. Download `Dicticus.dmg` from [Releases](../../releases)
2. Open the DMG and drag Dicticus to Applications
3. On first launch: **System Settings > Privacy & Security > Open Anyway** (app is ad-hoc signed)
4. Follow the onboarding flow to grant Microphone and Accessibility permissions
5. Models download automatically on first launch

## Usage

1. **Plain dictation**: Hold your configured hotkey (default: Fn+Shift), speak, release — text appears at cursor
2. **AI cleanup**: Hold the cleanup hotkey (default: Fn+Control), speak, release — cleaned text appears at cursor
3. Configure hotkeys via the menu bar dropdown

## Privacy

All processing happens on-device. No audio or text is ever sent to any server. The app makes zero network calls during operation (model downloads happen once on first launch).

## Tech Stack

| Component | Technology |
|-----------|-----------|
| App shell | Swift 6 + SwiftUI, MenuBarExtra |
| ASR | FluidAudio + Parakeet TDT v3 (CoreML, Apple Neural Engine) |
| LLM | llama.cpp + Gemma 3 1B IT QAT Q4_0 (Metal) |
| Hotkeys | KeyboardShortcuts (sindresorhus) + NSEvent global monitor |
| Text injection | NSPasteboard + CGEvent (Cmd+V synthesis) |
| Distribution | Ad-hoc signed DMG via create-dmg |

## Building from Source

```bash
# Prerequisites: Xcode 16+, xcodegen, create-dmg
brew install xcodegen create-dmg

# Clone and build
git clone https://github.com/maksim-101/dicticus.git
cd dicticus/Dicticus
xcodegen generate
xcodebuild -scheme Dicticus -configuration Release build

# Or build the DMG
cd ..
bash scripts/build-dmg.sh
```

## License

Private project. All rights reserved.
