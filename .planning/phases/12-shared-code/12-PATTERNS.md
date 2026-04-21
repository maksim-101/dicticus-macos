# Phase 12: Shared Code Extraction & iOS Scaffold - Pattern Map

**Mapped:** 2026-04-21
**Files analyzed:** 10
**Analogs found:** 9 / 10

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `Shared/Protocols/CleanupProvider.swift` | protocol | request-response | N/A | no-analog |
| `Shared/Models/DictationMode.swift` | model | static-state | `macOS/Dicticus/Services/HotkeyManager.swift` | role-match |
| `Shared/Services/TextProcessingService.swift` | service | transform | `macOS/Dicticus/Services/TextProcessingService.swift` | exact |
| `Shared/Services/HistoryService.swift` | service | CRUD | `macOS/Dicticus/Services/HistoryService.swift` | exact |
| `Shared/Services/DictionaryService.swift` | service | CRUD | `macOS/Dicticus/Services/DictionaryService.swift` | exact |
| `Shared/Utilities/ITNUtility.swift` | utility | transform | `macOS/Dicticus/Utilities/ITNUtility.swift` | exact |
| `Shared/Models/TranscriptionResult.swift` | model | static-state | `macOS/Dicticus/Models/TranscriptionResult.swift` | exact |
| `Shared/Models/CleanupPrompt.swift` | utility | transform | `macOS/Dicticus/Models/CleanupPrompt.swift` | exact |
| `iOS/Dicticus/DicticusApp.swift` | config | startup | `macOS/Dicticus/DicticusApp.swift` | role-match |
| `iOS/Dicticus/ContentView.swift` | component | user-interaction | `macOS/Dicticus/Views/HistoryView.swift` | partial |

## Pattern Assignments

### `Shared/Models/DictationMode.swift` (model, static-state)

**Analog:** `macOS/Dicticus/Services/HotkeyManager.swift`

**Core Pattern** (lines 5-9):
```swift
enum DictationMode: String, Sendable, CaseIterable {
    case plain
    case aiCleanup  // Wired to LLM pipeline in Phase 4
}
```

### `Shared/Services/TextProcessingService.swift` (service, transform)

**Analog:** `macOS/Dicticus/Services/TextProcessingService.swift`

**Imports pattern** (lines 1-1):
```swift
import Foundation
```

**Core Pattern** (lines 10-23):
```swift
@MainActor
class TextProcessingService: ObservableObject {

    private let dictionaryService: DictionaryService
    private let cleanupService: CleanupService? // To be updated to CleanupProvider?
    private let historyService: HistoryService

    init(
        dictionaryService: DictionaryService = .shared,
        cleanupService: CleanupService?, // To be updated to CleanupProvider?
        historyService: HistoryService = .shared
    ) {
        self.dictionaryService = dictionaryService
        self.cleanupService = cleanupService
        self.historyService = historyService
    }
```

**Core Transform Pattern** (lines 26-47):
```swift
    func process(text: String, language: String, mode: DictationMode, confidence: Double = 1.0) async -> String {
        let rawText = text
        // Step 1: Dictionary replacements
        var processedText = dictionaryService.apply(to: text)

        // Step 2: Rule-based ITN
        processedText = ITNUtility.applyITN(to: processedText, language: language)

        // Step 3: AI Cleanup
        if mode == .aiCleanup, let cleanupService = cleanupService, cleanupService.isLoaded {
            let lowerText = processedText.lowercased()
            let filteredContext = dictionaryService.dictionary.reduce(into: [String: String]()) { result, pair in
                if lowerText.contains(pair.key.lowercased()) {
                    result[pair.key] = pair.value.replacement
                }
            }
            
            processedText = await cleanupService.cleanup(
                text: processedText,
                language: language,
                dictionaryContext: filteredContext
            )
        }
```

### `Shared/Services/HistoryService.swift` (service, CRUD)

**Analog:** `macOS/Dicticus/Services/HistoryService.swift`

**Imports pattern** (lines 1-3):
```swift
import Foundation
import GRDB
import os.log
```

**Core Initialization Pattern** (lines 43-52):
```swift
    private init() {
        do {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let dbFolder = appSupport.appendingPathComponent("Dicticus", isDirectory: true)
            try FileManager.default.createDirectory(at: dbFolder, withIntermediateDirectories: true)
            
            let dbURL = dbFolder.appendingPathComponent("History.sqlite")
            self.dbQueue = try DatabaseQueue(path: dbURL.path) // DECISION: Change to DatabasePool
            
            try migrate()
            load()
```

**Core DB Operations Pattern** (lines 111-122):
```swift
    func save(_ entry: TranscriptionEntry) {
        do {
            let entryToSave = entry
            try dbQueue.write { db in
                try entryToSave.insert(db)
            }
            Self.log.info("Saved transcription to history: \(entry.text.prefix(20))...")
            load()
        } catch {
            Self.log.error("Failed to save entry: \(error.localizedDescription)")
        }
    }
```

### `Shared/Services/DictionaryService.swift` (service, CRUD)

**Analog:** `macOS/Dicticus/Services/DictionaryService.swift`

**Imports pattern** (lines 1-2):
```swift
import Foundation
import Combine
```

**Core State Pattern** (lines 12-22):
```swift
@MainActor
class DictionaryService: ObservableObject {

    static let dictionaryKey = "customDictionaryMetadata"
    static let caseSensitiveKey = "dictionaryCaseSensitive"

    @Published private(set) var dictionary: [String: DictionaryMetadata] = [:]
    
    @Published var isCaseSensitive: Bool = false {
        didSet {
            UserDefaults.standard.set(isCaseSensitive, forKey: Self.caseSensitiveKey)
        }
    }
```

### `iOS/Dicticus/DicticusApp.swift` (config, startup)

**Analog:** `macOS/Dicticus/DicticusApp.swift`

**Imports pattern** (lines 1-1):
```swift
import SwiftUI
```

**App initialization pattern** (lines 6-8):
```swift
@main
struct DicticusApp: App {
    // Shared services initialization will go here
```

## Shared Patterns

### GRDB Concurrency
**Source:** `.planning/research/PHASE-12-DECISIONS.md`
**Apply to:** `Shared/Services/HistoryService.swift`
Change GRDB initialization to use `DatabasePool` instead of `DatabaseQueue` for proper cross-process concurrent access.
```swift
self.dbPool = try DatabasePool(path: dbURL.path)
```

### App Groups Container Access
**Source:** `.planning/ROADMAP.md` Phase 12 Success Criteria
**Apply to:** `Shared/Services/HistoryService.swift`, `Shared/Services/DictionaryService.swift`
Switch file system storage root from `FileManager.default.urls(for: .applicationSupportDirectory)` to App Group container:
```swift
let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.dicticus")
```
User defaults switch from `UserDefaults.standard` to App Group suite:
```swift
let defaults = UserDefaults(suiteName: "group.com.dicticus")
```

### Protocol Injection
**Source:** `.planning/research/PHASE-12-DECISIONS.md`
**Apply to:** `Shared/Services/TextProcessingService.swift`
Modify dependencies to rely on `CleanupProvider?` protocol instead of the concrete `CleanupService?` to safely exclude llama.cpp dependencies from iOS.

## No Analog Found

Files with no close match in the codebase (planner should use RESEARCH.md patterns instead):

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `Shared/Protocols/CleanupProvider.swift` | protocol | request-response | New protocol abstraction as per Phase 12 Decisions; no previous generic protocol provider pattern exists. |

## Metadata

**Analog search scope:** `macOS/Dicticus/**/*.swift`
**Files scanned:** 30
**Pattern extraction date:** 2026-04-21
