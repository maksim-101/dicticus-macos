import Foundation

/// Central orchestrator for the text processing pipeline.
///
/// Phase 20 D-02 pipeline shape:
///   Step 1   — Dictionary replacements
///   Step 2   — Rule-based ITN
///   Step 2b  — Swiss German ß → ss (Helvetisms, gated on useSwissGerman)
///   Step 2c  — RulesCleanupService (filler / self-correction / currency-fold)
///              [snapshot `rulesCleanedText` here for the Step 3a gate]
///   Step 3   — LLM cleanup (only when mode == .aiCleanup AND provider loaded)
///   Step 3a  — Levenshtein verification gate against the Step 2c snapshot
///              (only when the LLM call succeeded — D-19 fallback path is
///              additive: a thrown LLM returns its input unchanged, which
///              equals `rulesCleanedText`, so the gate is the identity).
///   Step 3b  — Swiss number formatter (post-pass canonicalization)
///   Step 4   — HistoryService.save (D-38 — `text` post-pipeline,
///              `rawText` pre-pipeline)
///
/// Cross-platform parity (CLAUDE.md memory `feedback_cleanup_cross_platform_parity`):
/// every change ships on macOS and iOS together via `Shared/`.
@MainActor
class TextProcessingService: ObservableObject {

    private let dictionaryService: DictionaryService
    private let cleanupService: CleanupProvider?
    private let historyService: HistoryService
    /// Phase 20 D-02 — deterministic rules-first cleanup. Defaulted so
    /// existing call sites (DicticusApp, DictationViewModel) compile
    /// without modification.
    private let rulesCleanupService: RulesCleanupService

    /// Initialize with required services.
    init(
        dictionaryService: DictionaryService = .shared,
        cleanupService: CleanupProvider?,
        historyService: HistoryService = .shared,
        rulesCleanupService: RulesCleanupService = RulesCleanupService()
    ) {
        self.dictionaryService = dictionaryService
        self.cleanupService = cleanupService
        self.historyService = historyService
        self.rulesCleanupService = rulesCleanupService
    }

    /// Process the transcribed text based on the mode and language.
    func process(text: String, language: String, mode: DictationMode, confidence: Double = 1.0) async -> String {
        let rawText = text
        // Step 1: Dictionary replacements
        var processedText = dictionaryService.apply(to: text)

        // Step 2: Rule-based ITN
        processedText = ITNUtility.applyITN(to: processedText, language: language)

        // Step 2b: Swiss German ß → ss (D-16) — runs on both plain AND AI-cleanup
        // paths whenever the useSwissGerman toggle is ON. Intentionally applies
        // regardless of language so users who dictate mixed de/en don't have
        // rogue Eszett slip through when Swiss orthography is selected.
        let swissDefaults = UserDefaults(suiteName: "group.com.dicticus") ?? UserDefaults.standard
        if swissDefaults.bool(forKey: "useSwissGerman") {
            processedText = ITNUtility.applySwissITN(to: processedText)
        }

        // Step 2c (Phase 20 D-02): rules-first deterministic cleanup.
        // Filler removal, self-correction (comma-prefixed connectors only),
        // currency-fold. Runs on BOTH plain and AI-cleanup paths so the
        // rules pass is the new primary cleanup layer regardless of mode.
        processedText = rulesCleanupService.clean(processedText, language: language)
        // Snapshot for the Step 3a Levenshtein gate. Capturing here means
        // the gate's reference baseline is the rules-cleaned text — not the
        // raw ASR. This is the contract that makes the gate a fail-safe
        // for LLM hallucination over the rules-cleaned ground truth.
        let rulesCleanedText = processedText

        // Step 3: AI Cleanup
        if mode == .aiCleanup, let cleanupService = cleanupService, cleanupService.isLoaded {
            let lowerText = processedText.lowercased()
            
            // Phase 20.08 D-21: Adaptive dictionary context.
            // 1. Include all exact mishearing matches (original -> replacement) found in text.
            // 2. Include all "Target Terms" (the replacements) as Known Terms in the 
            //    glossary, even if their specific mishearing isn't in the raw text. 
            //    This allows the LLM to perform adaptive phonetic mapping (e.g., 
            //    "Dr. Chi" -> "Dockge" or "TrueNorth" -> "TrueNAS").
            let filteredContext = dictionaryService.dictionary.reduce(into: [String: String]()) { result, pair in
                let original = pair.key
                let replacement = pair.value.replacement
                
                if lowerText.contains(original.lowercased()) {
                    // It's a specific mishearing match found in text
                    result[original] = replacement
                }
                
                // Always include the target term itself as a "Known Term" 
                // to enable the LLM's adaptive phonetic matching.
                if result[replacement] == nil {
                    result[replacement] = replacement
                }
            }

            processedText = await cleanupService.cleanup(
                text: processedText,
                language: language,
                dictionaryContext: filteredContext
            )

            // Step 3a-pre (Phase 20.08 D-08): dialect-suppression gate. Runs
            // BEFORE the Levenshtein gate so a Swiss-ified LLM output is
            // demoted on the cheap token-set check before the more expensive
            // distance comparison. Both gates demote to the same target
            // (rulesCleanedText), so stacking is safe — if the dialect gate
            // demotes, the Levenshtein gate trivially passes (dist == 0
            // against itself, well under the 0.30 threshold). Identity
            // pass-through, no double-demotion artefact.
            processedText = CleanupService.gateLLMDialect(
                rulesCleaned: rulesCleanedText,
                llmOutput: processedText
            )
            // Step 3a (Phase 20 D-01): Levenshtein verification gate.
            // Reject LLM output as hallucination if it diverges too far from
            // the rules-cleaned baseline. The gate is ADDITIVE to D-19's
            // existing LLM-failure fallback: when CleanupService.cleanup
            // throws or times out it returns its input unchanged, i.e.
            // `processedText == rulesCleanedText` here, so the normalized
            // distance is 0 and the gate trivially passes (identity).
            processedText = CleanupService.gateLLMOutput(
                rulesCleaned: rulesCleanedText,
                llmOutput: processedText
            )
        }

        // Step 3b: Swiss number formatting (D-C2/D-C3) — runs AFTER any
        // LLM cleanup so Gemma's German-decimal output (e.g. "2,5 Kilo",
        // "1.250,70") gets normalized to Swiss form. Runs whenever the toggle
        // is ON regardless of cleanup mode, so:
        //   • plain dictation also gets `1.250 → 1250` and `2,5 → 2.5`
        //   • LLM timeout / failure (CleanupService returns raw text on catch)
        //     does not silently lose Swiss number formatting
        // Phase 20.08: thousands grouping was struck (year-bug fix).
        // Idempotent on already-Swiss output, so a future re-introduction of
        // the post-LLM call inside CleanupService would not double-format.
        if swissDefaults.bool(forKey: "useSwissGerman") {
            processedText = SwissNumberFormatter.format(processedText)
        }

        // Step 4: Save to History (UX-02)
        let entry = TranscriptionEntry(
            text: processedText,
            rawText: rawText,
            language: language,
            mode: mode.rawValue,
            confidence: confidence
        )
        historyService.save(entry)

        return processedText
    }
}
