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

    /// Initialize with required services.
    /// - Parameters:
    ///   - dictionaryService: Shared DictionaryService instance.
    ///   - cleanupService: CleanupService instance for LLM-based processing.
    init(dictionaryService: DictionaryService = .shared, cleanupService: CleanupService?) {
        self.dictionaryService = dictionaryService
        self.cleanupService = cleanupService
    }

    /// Process the transcribed text based on the mode and language.
    ///
    /// Pipeline Flow:
    /// 1. Dictionary replacements (find-replace recurring ASR errors)
    /// 2. Rule-based ITN (convert spelled-out numbers to digits)
    /// 3. AI Cleanup (if mode == .aiCleanup and service is available)
    ///
    /// - Parameters:
    ///   - text: Raw transcribed text from ASR.
    ///   - language: Detected language ("de" or "en").
    ///   - mode: Dictation mode (.plain or .aiCleanup).
    /// - Returns: Fully processed text ready for injection.
    func process(text: String, language: String, mode: DictationMode) async -> String {
        // Step 1: Dictionary replacements (TEXT-02, TEXT-03)
        // Correct errors like "cloud" -> "Claude" early so downstream logic sees correct words.
        var processedText = dictionaryService.apply(to: text)

        // Step 2: Rule-based ITN (TEXT-01)
        // Convert numbers in both modes to ensure consistency.
        processedText = ITNUtility.applyITN(to: processedText, language: language)

        // Step 3: AI Cleanup (Optional, based on mode)
        if mode == .aiCleanup, let cleanupService = cleanupService, cleanupService.isLoaded {
            // CleanupService handles grammar, filler removal, etc.
            // Note: CleanupService prompt (CleanupPrompt) also instructs LLM to use digits for numbers,
            // serving as a secondary layer of ITN.
            processedText = await cleanupService.cleanup(text: processedText, language: language)
        }

        return processedText
    }
}
