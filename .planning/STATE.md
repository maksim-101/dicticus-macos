# Project State: Dicticus

**Last Updated:** 2026-04-20
**Current Version:** 0.1.1 (Internal Test)
**Milestone:** ✅ v1.1 Cleanup Intelligence & Distribution COMPLETE

## Recent Progress
- **Phase 10**: Implemented `TextProcessingService`, `DictionaryService` (pre-populated with 35+ entries), and `ITNUtility`.
- **Phase 11**: Implemented `HistoryService` (GRDB + FTS5) and `HistoryView` with search highlighting and copy feedback.
- **Model Upgrade**: Officially moved to **Gemma 4 E2B (Q4_K_M)**. Prompt overhauled for better context handling and zero truncation.
- **UI/UX**: Fixed alignment and symmetry in Dictionary/History windows.

## Current Technical Stack
- **ASR**: Parakeet TDT v3 (FluidAudio)
- **LLM**: Gemma 4 E2B (llama.cpp)
- **Database**: SQLite / GRDB
- **UI**: SwiftUI (macOS 15+)

## Next Milestone: v1.2 Advanced Normalization & Rules
- **Phase 12**: Advanced ITN (Ordinal numbers, Date/Currency formatting).
- **Phase 13**: Per-language dictionary rules.
- **Phase 14**: History Export functionality.

## Known Issues / Technical Debt
- `NumberFormatter` remains sensitive to some complex German compound words.
- AI cleanup is highly reliable but adds ~1-2s of latency.
