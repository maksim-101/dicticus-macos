# Architecture: v1.1 Feature Integration

**Domain:** Local macOS dictation app -- feature integration into existing pipeline
**Researched:** 2026-04-19
**Overall confidence:** HIGH (well-understood codebase, proven patterns, standard frameworks)

---

## Existing Architecture (v1.0)

```
User presses hotkey
  -> HotkeyManager / ModifierHotkeyListener
    -> TranscriptionService.startRecording() [AVFoundation]
      -> Audio buffer accumulates

User releases hotkey
  -> TranscriptionService.stopRecordingAndTranscribe()
    -> Resample to 16kHz
    -> Silero VAD filter
    -> FluidAudio AsrManager.transcribe() [Parakeet TDT v3 on ANE]
    -> NLLanguageRecognizer detects language
    -> DicticusTranscriptionResult

  If cleanup hotkey was used:
    -> CleanupService.cleanup(text, language)
      -> CleanupPrompt.build() [Gemma 3 chat format]
      -> llama.cpp inference [Metal GPU]
      -> stripPreamble() post-processing
      -> Cleaned text

  -> TextInjector.inject(text) [NSPasteboard + CGEvent Cmd+V]
```

**Key services (all @MainActor ObservableObject):**
- `TranscriptionService` -- audio capture, VAD, ASR
- `CleanupService` -- LLM inference
- `HotkeyManager` -- KeyboardShortcuts registration
- `ModifierHotkeyListener` -- NSEvent global monitor for modifier combos
- `ModelWarmupService` -- startup model loading
- `ModelDownloadService` -- GGUF model download
- `PermissionManager` -- macOS permission checks
- `TextInjector` -- paste-at-cursor
- `NotificationService` -- user notifications

---

## v1.1 Architecture Changes

### 1. Custom Dictionary: New Post-ASR Pre-Cleanup Step

**Where it fits:** Between ASR output and CleanupService input.

```
TranscriptionService output
  -> CustomDictionary.apply(text) [NEW -- string replacement]
  -> CleanupService.cleanup(correctedText, language) [if cleanup mode]
  -> TextInjector.inject(finalText)
```

**New component:**
```swift
/// Applies user-defined find-and-replace corrections to ASR output.
/// Runs BEFORE AI cleanup so the LLM sees correct proper nouns.
struct CustomDictionary {
    static let storageKey = "customDictionary"

    /// Apply all dictionary replacements (case-insensitive).
    static func apply(_ text: String) -> String {
        let entries = UserDefaults.standard.array(forKey: storageKey)
            as? [[String: String]] ?? []
        var result = text
        for entry in entries {
            guard let find = entry["find"], let replace = entry["replace"] else { continue }
            result = result.replacingOccurrences(
                of: find, with: replace,
                options: [.caseInsensitive]
            )
        }
        return result
    }
}
```

**Integration point:** `DicticusApp.swift` pipeline, between ASR result and cleanup call.

---

### 2. ITN + Intelligent Cleanup: Prompt Changes Only

**Where it fits:** Inside `CleanupPrompt.swift` -- no architectural change.

**Current flow (unchanged):**
```
CleanupPrompt.build(text, language)
  -> Gemma 3 chat format prompt
  -> CleanupService.runInference()
```

**What changes:** The prompt text in `CleanupPrompt.defaultInstruction`. The ITN instruction gets appended. Optionally, a second prompt variant for "intelligent" mode.

**No new services. No new data flow. No new dependencies.**

If a two-tier system is desired (light vs intelligent cleanup):
```swift
enum CleanupMode: String, Sendable {
    case light      // Current: grammar + punctuation + ITN
    case intelligent // New: full reconstruction for non-native speech
}
```
This would be a property on CleanupPrompt.build(), not a new service.

---

### 3. Transcription History: New Service + Database

**Where it fits:** After text injection, as a logging step.

```
TextInjector.inject(finalText)
  -> HistoryService.save(record) [NEW -- async, non-blocking]
```

**New components:**

```
HistoryService (@MainActor ObservableObject)
  |-- DatabaseManager (GRDB DatabaseQueue)
  |     |-- transcriptions table
  |     |-- transcriptions_ft FTS5 virtual table (synced)
  |-- TranscriptionRecord (Codable, FetchableRecord, PersistableRecord)
```

**HistoryService responsibilities:**
- Initialize GRDB DatabaseQueue at `~/Library/Application Support/Dicticus/history.sqlite`
- Run migrations on first launch
- Save transcription records after each dictation
- Query records with FTS5 full-text search
- Expose results for UI via @Published

**Database location:** Same `Application Support/Dicticus/` directory used by model files. Consistent with macOS conventions for non-sandboxed apps.

**UI integration:** New `HistoryView` accessible from MenuBarExtra menu, showing:
- Scrollable list of past transcriptions (newest first)
- Search bar using FTS5 pattern matching
- Copy-to-clipboard on click
- Delete individual entries

**Data model:**
```swift
struct TranscriptionRecord: Codable, FetchableRecord, PersistableRecord, Identifiable {
    var id: Int64?
    var text: String           // Final output (cleaned or raw)
    var rawText: String        // Original ASR output
    var language: String       // "de" or "en"
    var mode: String           // "raw" or "cleanup"
    var timestamp: Date
    var durationSeconds: Float

    static let databaseTableName = "transcriptions"
}
```

---

### 4. Sparkle Auto-Update: App Initialization Addition

**Where it fits:** `DicticusApp.swift` init, alongside existing warmup.

```swift
// DicticusApp.swift
import Sparkle

@main
struct DicticusApp: App {
    private let updaterController: SPUStandardUpdaterController

    init() {
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        // ... existing warmup code ...
    }
}
```

**Menu integration:** Add "Check for Updates..." button in MenuBarExtra menu.

**Info.plist additions:**
```xml
<key>SUFeedURL</key>
<string>https://your-host.com/appcast.xml</string>
<key>SUPublicEDKey</key>
<string>YOUR_ED25519_PUBLIC_KEY</string>
```

---

### 5. Signing & Notarization: Build Script Only

**No architecture change.** This is a distribution script that runs after `xcodebuild`:

```bash
#!/bin/bash
# scripts/sign-and-notarize.sh
set -e

APP_PATH="build/Release/Dicticus.app"
DMG_PATH="dist/Dicticus.dmg"
IDENTITY="Developer ID Application: ..."
PROFILE="dicticus-notary"

# Sign
codesign -f -s "$IDENTITY" -o runtime --timestamp "$APP_PATH"

# Create DMG
hdiutil create -volname "Dicticus" -srcfolder "$APP_PATH" \
  -ov -format UDZO "$DMG_PATH"

# Sign DMG
codesign -f -s "$IDENTITY" --timestamp "$DMG_PATH"

# Notarize
xcrun notarytool submit "$DMG_PATH" \
  --keychain-profile "$PROFILE" --wait

# Staple
xcrun stapler staple "$DMG_PATH"

# Generate Sparkle appcast
./Sparkle/bin/generate_appcast dist/
```

---

## Component Boundaries (Updated for v1.1)

| Component | Responsibility | Communicates With | New in v1.1? |
|-----------|---------------|-------------------|--------------|
| TranscriptionService | Audio capture, VAD, ASR | ModelWarmupService, DicticusApp | No |
| CleanupService | LLM inference | ModelWarmupService, DicticusApp | No (prompt changes only) |
| CleanupPrompt | Prompt construction | CleanupService | No (content changes) |
| CustomDictionary | Find-and-replace corrections | DicticusApp pipeline | YES |
| HistoryService | Transcription logging + search | DatabaseManager, DicticusApp | YES |
| DatabaseManager | GRDB DatabaseQueue lifecycle | HistoryService | YES |
| TranscriptionRecord | Data model for history | HistoryService, HistoryView | YES |
| SPUStandardUpdaterController | Sparkle update lifecycle | DicticusApp | YES |
| CheckForUpdatesViewModel | Update button state | MenuBarView | YES |
| HotkeyManager | KeyboardShortcuts registration | DicticusApp | No |
| TextInjector | Paste-at-cursor | DicticusApp | No |
| ModelWarmupService | Startup model loading | TranscriptionService, CleanupService | No |

---

## Data Flow (v1.1 Complete)

```
Hotkey press -> HotkeyManager
  -> TranscriptionService.startRecording()
    -> AVAudioEngine tap accumulates samples

Hotkey release -> HotkeyManager
  -> TranscriptionService.stopRecordingAndTranscribe()
    -> Resample 16kHz -> VAD filter -> Parakeet ASR -> Language detect
    -> DicticusTranscriptionResult { text, language, confidence }

  -> CustomDictionary.apply(result.text)         [NEW: fix known ASR errors]

  If cleanup mode:
    -> CleanupPrompt.build(correctedText, language)  [UPDATED: +ITN, +intelligent mode]
    -> CleanupService.cleanup()
      -> llama.cpp inference -> stripPreamble()
    -> cleanedText

  -> TextInjector.inject(finalText)

  -> HistoryService.save(TranscriptionRecord)    [NEW: async logging]
    -> GRDB insert + FTS5 auto-sync
```

---

## Patterns to Follow

### Pattern 1: Service as @MainActor ObservableObject
All existing services follow this pattern. New services (HistoryService) should too.

### Pattern 2: Non-blocking post-pipeline operations
History logging should be fire-and-forget after text injection. The user should not wait for a database write.

### Pattern 3: UserDefaults for simple config
Custom dictionary entries (< 100 items) belong in UserDefaults, not the database. Consistent with existing hotkey and setting storage.

### Pattern 4: Database in Application Support
`~/Library/Application Support/Dicticus/history.sqlite` -- same directory as model files.

## Anti-Patterns to Avoid

### Anti-Pattern 1: Database for everything
Don't move settings, custom dictionary, or preferences into GRDB. UserDefaults is the right tool for config. GRDB is for structured, searchable, growing data (history).

### Anti-Pattern 2: Synchronous database writes in the pipeline
Never block text injection on a history write. If the DB write fails, the dictation should still work.

### Anti-Pattern 3: Separate ITN pipeline
Don't build a separate text processing stage between ASR and cleanup for number conversion. Let the LLM handle it in the same prompt pass. Adding a pipeline stage adds latency and complexity.
