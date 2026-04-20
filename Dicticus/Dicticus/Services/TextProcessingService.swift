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
    private let cleanupService: CleanupService?
    private let historyService: HistoryService

    /// Initialize with required services.
    init(
        dictionaryService: DictionaryService = .shared,
        cleanupService: CleanupService?,
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
