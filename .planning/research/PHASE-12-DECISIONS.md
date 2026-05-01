# Phase 12 Decisions

**Phase:** Phase 12 - Shared Code Extraction & iOS Scaffold
**Date:** 2026-04-21

Based on the discussion regarding Phase 12, the following architectural decisions were made to address the identified gray areas:

### 1. CleanupService Dependency
`TextProcessingService` currently holds a reference to `CleanupService`, which uses large ML models (llama.cpp) not suitable for the iOS target. To extract `TextProcessingService` to `Shared/` without using `#if os()` conditionals:
- **Decision:** Create a `CleanupProvider` protocol in `Shared/`. Make `TextProcessingService` depend on `CleanupProvider?`. macOS will inject the concrete `CleanupService`, while iOS will inject `nil`.

### 2. DictationMode Location
`DictationMode` is currently an enum nested inside `HotkeyManager` (a macOS-specific class). `TextProcessingService` needs access to this enum.
- **Decision:** Extract `DictationMode` from `HotkeyManager` into its own file at `Shared/Models/DictationMode.swift`.

### 3. GRDB Concurrency
The iOS app and the Siri Shortcut Intent (App Intent) will run in separate processes but must both access `History.sqlite` simultaneously from the shared App Group container (`group.com.dicticus`).
- **Decision:** Switch from GRDB's `DatabaseQueue` to `DatabasePool` (WAL mode) in `HistoryService`. This natively supports concurrent cross-process access and prevents `database is locked` (SQLITE_BUSY) errors.

### Next Steps
Proceed with `/gsd-plan-phase 12` to create the execution plan based on these decisions.