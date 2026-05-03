# Phase 21 — Adaptive Cleanup & Stability

**Date:** 2026-05-03
**Status:** SHIPPED
**Branch:** feature/debug-recording-and-cleanup
**Requirement IDs:** CLEAN-03 (Stability), CLEAN-04 (Adaptive)

## Goal
Resolve recording interruptions during long hotkey holds and address the 'literalness' of AI cleanup via an adaptive glossary strategy rather than hard-coded find-replace rules.

## Results
- **Recording Stability:** Increased modifier debounce from 60ms to 100ms in ModifierHotkeyListener. Successfully tested with 1-minute+ continuous dictation on macOS.
- **Adaptive AI Cleanup:** 
    - Implemented a "Project Glossary" architecture in CleanupPrompt.swift.
    - Every 'Target Term' in the dictionary is now passed to the LLM as a known vocabulary word.
    - Updated LLM instructions to perform phonetic mapping (e.g., "Dr. Chi" -> "Dockge") based on the glossary.
- **German Repair Parity:**
    - Expanded SelfCorrectionResolver window from 3 to 6 tokens.
    - Added complex connectors: "ah nein", "ach ein moment", "das war", "wart".
    - Fixed the "time-drop" bug where multi-stage repairs caused data loss.
- **Platform Parity:** Changes successfully propagated to iOS target; navigation bar visibility issue fixed on iPhone.

## Verification (UAT)
- **Long Hold:** 1m 15s dictation without stop (PASS).
- **English Repair:** "Tuesday... oh no... Monday" -> Monday (PASS).
- **German Repair:** "Dienstag um 9 Uhr... ach ein moment das war Montag um 8 Uhr" -> Montag um 8 Uhr (PASS).
- **Phonetic Mapping:** "Sig B" -> Zigbee, "Dr. Chi" -> Dockge, "TrueNorth" -> TrueNAS (PASS via adaptive glossary).
