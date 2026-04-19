# Phase 10: Text Processing Pipeline - Context

## Goal
Implement a robust text processing pipeline that converts spoken numbers to digits (ITN) and applies user-defined dictionary corrections.

## Requirements
- **TEXT-01**: Cardinal numbers appear as digits in both plain and cleanup modes.
- **TEXT-02**: User can define find-replace pairs in a separate "Manage Dictionary" window.
- **TEXT-03**: Pipeline order: ASR -> Dictionary -> [Rule-based ITN] -> [LLM Cleanup] -> Injection.

## Decisions

### 1. Architecture: `TextProcessingService`
A central service will orchestrate the transformation pipeline. It will be initialized with a `DictionaryService` and `CleanupService`.

### 2. ITN Strategy: Rule-based Swift (Both Modes)
A Swift utility will handle number-to-digit conversion for both Plain and AI Cleanup modes.
- **Why**: Ensures consistent output regardless of mode. Rule-based is fast and sufficient for cardinal numbers.
- **Scope**: Cardinal numbers (e.g., "twenty three" -> "23", "dreiundzwanzig" -> "23").

### 3. Custom Dictionary: Separate Window
The UI for managing dictionary pairs will be a standard macOS window accessible from the Settings section in the Menu Bar dropdown.
- **Storage**: Persisted via `UserDefaults` as a dictionary of `[String: String]`.

### 4. Pipeline Ordering
1. **ASR** (`TranscriptionService`) -> `Raw Text`
2. **Dictionary** (`DictionaryService`) -> `Corrected Text`
3. **ITN** (`ITNUtility`) -> `Normalized Text` (Applied to both modes)
4. **Cleanup** (`CleanupService`) -> `Cleaned Text` (Only in AI Cleanup mode)
5. **Injection** (`TextInjector`) -> `Final Output`

## Approach
1. **Service Creation**:
   - `DictionaryService`: Handles loading/saving/applying find-replace pairs.
   - `ITNUtility`: Rule-based parser for de/en cardinal numbers.
   - `TextProcessingService`: Orchestrates the flow.
2. **UI Implementation**:
   - `DictionaryWindow`: Table view for editing pairs.
   - Update `SettingsSection` to include a "Manage Dictionary..." button.
3. **Integration**:
   - Update `HotkeyManager` to use `TextProcessingService` instead of calling `CleanupService` directly.
   - Ensure `CleanupService` prompt still supports ITN as a secondary layer.

## Verification Plan
- **Unit Tests**:
  - `DictionaryServiceTests`: Verify find-replace with various cases.
  - `ITNUtilityTests`: Verify number conversion for English and German.
  - `TextProcessingServiceTests`: Verify end-to-end pipeline logic.
- **Manual UAT**:
  - Add "cloud" -> "Claude" to dictionary; dictate "I love the cloud" -> verify "I love Claude".
  - Dictate "one hundred twenty three" -> verify "123".
  - Dictate "einhundertdreiundzwanzig" -> verify "123".
