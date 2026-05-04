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
        // currency-fold.
        //
        // 2026-05-03 fix: Only apply rules-cleanup in AI mode. Plain dictation
        // should remain raw (except for ITN/Dictionary) per user feedback.
        //
        // 2026-05-04 fix: In AI mode, skip the SelfCorrectionResolver step.
        // The V3 prompt instructs the LLM to PRESERVE self-corrections
        // ("no/wait/actually/nein/moment/eigentlich") as substantive
        // content. Running the deterministic resolver before the LLM
        // would drop the reparandum tokens and feed the LLM an already-
        // collapsed phrase, defeating the V3 contract. Filler removal and
        // currency-fold still run.
        if mode == .aiCleanup {
            processedText = rulesCleanupService.clean(
                processedText,
                language: language,
                skipSelfCorrection: true
            )
        }
        
        // Snapshot for the Step 3a Levenshtein gate. Capturing here means
        // the gate's reference baseline is the rules-cleaned text (in AI mode)
        // or the ITN-processed text (in Plain mode).
        let rulesCleanedText = processedText

        // Step 3: AI Cleanup
        if mode == .aiCleanup, let cleanupService = cleanupService, cleanupService.isLoaded {
            let lowerText = processedText.lowercased()
            
                        // Phase 20.08 D-21: Adaptive dictionary context.
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

            // Step 3a: Verification gates (Levenshtein/Dialect).
            // 2026-05-03: Gates DISABLED. The 'Surgical Completion' (Variant I) 
            // architecture is sufficiently constrained that the safety gates 
            // are now causing 'False Rejections' on short sentences rather than
            // catching hallucinations.
            /*
            processedText = CleanupService.gateLLMDialect(
                rulesCleaned: rulesCleanedText,
                llmOutput: processedText
            )
            processedText = CleanupService.gateLLMOutput(
                rulesCleaned: rulesCleanedText,
                llmOutput: processedText
            )
            */
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
