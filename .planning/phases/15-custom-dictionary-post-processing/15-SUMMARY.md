# Phase 15 Summary: Custom Dictionary & Post-Processing

Integrated advanced text processing and local persistence into the iOS application, bringing it to parity with macOS core functionality.

## Key Changes

### Pipeline Enhancements
- Integrated `DictionaryService` into `IOSTranscriptionService` to automatically apply user-defined text replacements.
- Integrated `ITNUtility` to convert spelled-out numbers to digits based on detected language.
- Added user-facing toggles in `SettingsView` to control these post-processing features.

### Persistence & History
- Implemented transcription saving in `DictationViewModel` using the SQLite-backed `HistoryService`.
- Created `iOS/Dicticus/History/HistoryView.swift` providing a searchable, sortable list of past transcriptions.
- Implemented Full-Text Search (FTS5) integration for instantaneous history lookup.
- Added swipe-to-delete functionality for history management.

### User Interface
- Updated `ContentView.swift` to use a `TabView` architecture, separating the "Dictate" and "History" experiences.
- Added copy-to-clipboard functionality directly within the history list.
- Improved the main dictation UI to show "Copied to clipboard" feedback more clearly.

## Verification Results

### Automated Tests
- Updated `IOSTranscriptionServiceTests.swift` to verify default post-processing settings.
- Confirmed that all 31+ unit tests pass.

### Manual Verification
- Verified that saying "true nest" results in "TrueNAS" using the default dictionary.
- Verified that numbers like "one hundred twenty-three" are converted to "123".
- Confirmed that deleting an entry from history is persistent across app launches.
- Verified that searching in history is case-insensitive and fast.
