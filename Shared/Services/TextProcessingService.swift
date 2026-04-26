import Foundation

/// Central orchestrator for the text processing pipeline.
///
/// Per TEXT-03: ASR -> Dictionary -> Rule-based ITN -> [LLM Cleanup] -> Injection.
///
/// This service coordinates the individual processing steps to ensure consistency
/// and correct ordering between plain and AI cleanup modes.
@MainActor
class TextProcessingService: ObservableObject {

    private let dictionaryService: DictionaryService
    private let cleanupService: CleanupProvider?
    private let historyService: HistoryService

    /// Initialize with required services.
    init(
        dictionaryService: DictionaryService = .shared,
        cleanupService: CleanupProvider?,
        historyService: HistoryService = .shared
    ) {
        self.dictionaryService = dictionaryService
        self.cleanupService = cleanupService
        self.historyService = historyService
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

        // Step 3b: Swiss number formatting (D-C1/D-C2/D-C3) — runs AFTER any
        // LLM cleanup so Gemma's German-decimal output (e.g. "2,5 Kilo",
        // "1.250,70") gets normalized to Swiss form. Runs whenever the toggle
        // is ON regardless of cleanup mode, so:
        //   • plain dictation also gets `1.250 → 1'250` and `2,5 → 2.5`
        //   • LLM timeout / failure (CleanupService returns raw text on catch)
        //     does not silently lose Swiss number formatting
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
