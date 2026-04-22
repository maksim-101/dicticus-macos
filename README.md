# Dicticus

A fully local dictation app for macOS and iOS. Hold a key or trigger a shortcut, speak, release — accurate text appears instantly. Fully private, no cloud dependency.

## Features

- **Multi-Platform** — Native apps for macOS (Menu Bar) and iOS (Universal App).
- **System-wide push-to-talk** — Works in any text field on macOS.
- **Siri Shortcuts & Action Button** — Trigger iOS dictation from anywhere, even when locked.
- **On-device ASR** — Parakeet TDT v3 via FluidAudio on Apple Neural Engine (~200x realtime).
- **AI cleanup mode (macOS)** — Grammar, punctuation, and filler word correction via Gemma 3 1B (llama.cpp).
- **Auto language detection** — German and English, no manual switching.
- **Local History & Search** — Browse and search your past transcriptions with FTS5.
- **Custom Dictionary** — Define your own replacements for technical terms or names.

## Requirements

### macOS
- macOS 15+ (Sequoia)
- Apple Silicon Mac
- ~1.3 GB disk for ASR model + ~1 GB for LLM model

### iOS / iPadOS
- iOS 17+
- iPhone 15 Pro or later (for Action Button optimization), or any modern iPhone/iPad.
- ~2.7 GB disk for high-accuracy ASR model.

## Installation

### macOS
1. Download `Dicticus.dmg` from [Releases](../../releases)
2. Open the DMG and drag Dicticus to Applications
3. On first launch: **System Settings > Privacy & Security > Open Anyway** (app is ad-hoc signed)
4. Grant Microphone and Accessibility permissions.

### iOS
1. Build from source using Xcode 26.
2. Grant Microphone permission during onboarding.
3. Download the ASR model (one-time setup).
4. Follow the in-app guides to setup the **Start Dictation** Siri Shortcut.

## Usage

- **macOS**: Hold your configured hotkey (default: Fn+Shift), speak, release.
- **iOS**: Trigger the **Start Dictation** shortcut via voice, Action Button, or Back Tap.
- **Dictionary**: Manage replacements in Settings to improve accuracy for specific terms.
- **History**: Use the History tab on iOS or the Menu Bar on macOS to find past transcriptions.

## Privacy

All processing happens on-device. No audio or text is ever sent to any server. The app makes zero network calls during operation (model downloads happen once on first launch).

## Tech Stack

| Component | Technology |
|-----------|-----------|
| App shell | Swift 6 + SwiftUI, MenuBarExtra (macOS) |
| ASR | FluidAudio + Parakeet TDT v3 (CoreML, Apple Neural Engine) |
| LLM (macOS) | llama.cpp + Gemma 3 1B IT QAT Q4_0 (Metal) |
| Database | GRDB + SQLite (FTS5) |
| Live Activity | ActivityKit (iOS) |
| Text injection | NSPasteboard (macOS) + UIPasteboard (iOS) |

## Building from Source

```bash
# Prerequisites: Xcode 26+, xcodegen
brew install xcodegen

# macOS
cd macOS
xcodegen generate
xcodebuild -scheme Dicticus -configuration Release build

# iOS
cd iOS
xcodegen generate
# Open Dicticus.xcodeproj in Xcode 26 and Run on Device/Simulator
```

## License

Private project. All rights reserved.
