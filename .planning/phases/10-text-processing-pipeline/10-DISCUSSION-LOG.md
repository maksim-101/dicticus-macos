# Phase 10: Text Processing Pipeline - Discussion Log

**Date:** 2026-04-19
**Phase:** 10-text-processing-pipeline
**Areas discussed:** ITN Strategy, Custom Dictionary implementation, Pipeline Ordering, UI for Dictionary

---

## Inverse Text Normalization (ITN) Strategy

| Option | Description | Rationale |
|--------|-------------|-----------|
| Rule-based Swift (Both) | Implement a Swift utility that converts spoken numbers to digits for both Plain and AI Cleanup modes. | Ensures consistency. Requirement "rule-based Swift covers 99% of cases" avoids heavy dependencies. |
| Rule-based (Plain) + LLM (Cleanup) | Use rule-based for speed in Plain mode; rely on LLM instructions in Cleanup mode. | LLM (Gemma 4 E2B) is very capable of ITN in context. |
| LLM for both | Use a tiny model or fast inference for ITN even in plain mode. | Too much latency for "Plain" mode which should be near-instant. |

---

## Custom Dictionary Implementation

| Option | Description | Rationale |
|--------|-------------|-----------|
| Central `TextProcessingService` | A new service that orchestrates Dictionary + ITN + LLM Cleanup. | Cleanest architecture. Encapsulates the pipeline logic. |
| Extension on `String` | Add `.applyingDictionary()` and `.applyingITN()` to String. | Simple but harder to manage state (dictionary pairs). |
| Integrated into `HotkeyManager` | Add dictionary logic directly to HotkeyManager. | Quickest but increases HotkeyManager complexity. |

---

## Pipeline Ordering (TEXT-03)

The requirement states: **ASR -> Dictionary -> LLM cleanup (with ITN) -> Text Injection**.

**Proposed Flow:**
1. **ASR** (`TranscriptionService`) -> Raw Text
2. **Dictionary** (`DictionaryService`) -> Corrected Text
3. **Mode Check**:
   - If **Plain**:
     - Apply **Rule-based ITN** -> Final Text
   - If **AI Cleanup**:
     - **LLM Cleanup** (which handles ITN via prompt) -> Final Text
4. **Text Injection** (`TextInjector`)

---

## UI for Custom Dictionary (TEXT-02)

| Option | Description | Rationale |
|--------|-------------|-----------|
| Inline List in Settings | Small list of pairs directly in the menu bar dropdown. | Convenient for few pairs. Can get cramped. |
| Separate "Manage Dictionary" Window | Button in Settings opens a standard macOS window with a table. | Best for managing many pairs. Professional feel. |
| Sheet/Popover | Popover attached to the menu bar. | Good middle ground. |

---
