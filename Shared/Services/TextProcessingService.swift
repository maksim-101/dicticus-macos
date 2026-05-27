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
///
/// Phase 25-02 (2026-05-16) — plain-mode logging parity:
/// The `#if DEBUG_RECORDER` write block at the bottom of `process(...)` is
/// scope-level (NOT inside the `if mode == .aiCleanup` branch), so it
/// emits one JSONL record per call regardless of mode. For plain-mode
/// records, `steps.llm_prompt`, `steps.llm_raw`, `steps.post_gate` are
/// all nil (no LLM ran), `dictionary_context_keys` is `[]` (plain mode
/// never builds the targeted context), and `steps.post_rules` equals
/// `steps.post_swiss` (plain mode skips the rules-cleanup branch at
/// L114-120). Mode discrimination happens via the top-level `mode`
/// field, which carries `DictationMode.plain.rawValue == "plain"` or
/// `aiCleanup`. Same daily file (`cleanup-YYYY-MM-DD.jsonl`), same 14-day
/// retention — plain and aiCleanup records interleave in one stream.
/// Enables Phase 25-04's capture-window v2 to do plain-vs-AI A/B from
/// production data without a second log path.
///
/// Phase 25.1-01 (2026-05-17) — telemetry parity:
/// The `DebugCleanupRecord` now carries `lang_used` (mirror of `lang`) and
/// `emission_counter` (DebugRecorder-actor-monotonic per process). Both close
/// the 25-04 telemetry gaps (`jq` for `lang_used` returned null because the
/// field didn't exist; plain-mode emission near-zero couldn't be distinguished
/// from "user dictates AI mode only" without a monotonic counter). No
/// detection-layer change: TranscriptionService.detectLanguage (D-13) is
/// still the sole source — Parakeet TDT v3 emits no language code per
/// `macOS/Dicticus/Services/TranscriptionService.swift:395`.
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
        #if DEBUG_RECORDER
        if let cs = cleanupService as? CleanupService {
            cs.lastDebugTrace = nil
        }
        #endif

        let rawText = text

        #if DEBUG_RECORDER
        let dbgRawStart = Date()
        let dbgRawText = text
        #endif

        // Step 1: Dictionary replacements
        #if DEBUG_RECORDER
        var dbgReplacements: [DictionaryService.Replacement] = []
        var dbgBlocked: [DictionaryService.BlockedMatch] = []
        let dictTrace = dictionaryService.applyWithTrace(to: text)
        var processedText = dictTrace.text
        dbgReplacements = dictTrace.replacements
        dbgBlocked = dictTrace.blocked
        let dbgPostDict = processedText
        let dbgPostDictMs = Date().timeIntervalSince(dbgRawStart) * 1000.0
        let dbgItnStart = Date()
        #else
        var processedText = dictionaryService.apply(to: text)
        #endif

        // Step 2: Rule-based ITN
        processedText = ITNUtility.applyITN(to: processedText, language: language)

        #if DEBUG_RECORDER
        let dbgPostItn = processedText
        let dbgPostItnMs = Date().timeIntervalSince(dbgItnStart) * 1000.0
        let dbgSwissStart = Date()
        #endif

        // Step 2b: Swiss German ß → ss (D-16) — runs on both plain AND AI-cleanup
        // paths whenever the useSwissGerman toggle is ON. Intentionally applies
        // regardless of language so users who dictate mixed de/en don't have
        // rogue Eszett slip through when Swiss orthography is selected.
        let swissDefaults = UserDefaults(suiteName: "group.com.dicticus") ?? UserDefaults.standard
        if swissDefaults.bool(forKey: "useSwissGerman") {
            processedText = ITNUtility.applySwissITN(to: processedText)
        }

        #if DEBUG_RECORDER
        let dbgPostSwiss = processedText
        let dbgPostSwissMs = Date().timeIntervalSince(dbgSwissStart) * 1000.0
        let dbgRulesStart = Date()
        #endif

        // Step 2c (Phase 20 D-02): rules-first deterministic cleanup.
        // Filler removal, self-correction (comma-prefixed connectors only),
        // currency-fold.
        //
        // 2026-05-03 fix: Only apply rules-cleanup in AI mode. Plain dictation
        // should remain raw (except for ITN/Dictionary) per user feedback.
        //
        // 2026-05-06 fix: In AI mode, RUN the SelfCorrectionResolver again.
        //
        // The 2026-05-04 disable was based on the (incorrect) assumption that
        // pre-collapsing self-corrections would "defeat the V5 prompt
        // contract." In practice the inverse holds: V5 is strict-verbatim, so
        // the LLM is a passthrough — pre-collapsing here means the LLM gets
        // a clean phrase to capitalize/punctuate, no paraphrase risk. This
        // restores the auto-resolve behavior ("8 o'clock, no actually 7" →
        // "7 o'clock") without inheriting V4's over-generalization (V4
        // collapsed "I would say, and..." and "and so in between..." because
        // the model itself was tasked with the resolution; the rules
        // resolver is much narrower — comma-anchored connector + 3-token
        // backward window cap + abort-on-pronoun).
        if mode == .aiCleanup {
            processedText = rulesCleanupService.clean(
                processedText,
                language: language,
                skipSelfCorrection: false
            )
        }
        
        // Snapshot for the Step 3a Levenshtein gate. Capturing here means
        // the gate's reference baseline is the rules-cleaned text (in AI mode)
        // or the ITN-processed text (in Plain mode).
        let rulesCleanedText = processedText

        #if DEBUG_RECORDER
        let dbgPostRules = processedText
        let dbgPostRulesMs = Date().timeIntervalSince(dbgRulesStart) * 1000.0
        var dbgGateEntry: DebugCleanupRecord.GateEntry? = nil
        var dbgDictKeys: [String] = []
        #endif

        // Step 3: AI Cleanup
        if mode == .aiCleanup, let cleanupService = cleanupService, cleanupService.isLoaded {
            let lowerText = processedText.lowercased()

            // 2026-05-06 fix: Targeted-only dictionary context.
            //
            // Was: Phase 20.08 D-21 "adaptive phonetic matching" — every
            // dictionary REPLACEMENT target was included unconditionally as a
            // Known Term on every cleanup call. Intent: let Gemma recover
            // phonetic variants not explicitly listed (e.g. "Phasern" → ?).
            //
            // Cost: ~70 brand-name targets shipped on every prompt as a
            // substitution menu. Empirically (harness V5 vs V5T, 2026-05-06,
            // F46-F47), this caused the model to substitute *unfamiliar*
            // input tokens with plausibly-shaped menu entries —
            // "lm cleanup" → "AI Cleanup", "GSD" → "AI Cleanup", etc. —
            // exactly the over-eager substitution the user reported.
            //
            // Now: only surface a known term when its literal mishearing
            // KEY appears in the input. The dictionary still pre-passes
            // (Step 1) and deterministically replaces variants there;
            // the LLM gets a clean input plus a *targeted* hint only when
            // an explicit dictionary key matched. With the buffet gone the
            // model relies on context, which empirically recovers common
            // tech acronyms (LLM/API/etc.) better than the menu did.
            let filteredContext = dictionaryService.dictionary.reduce(into: [String: String]()) { result, pair in
                let original = pair.key
                let replacement = pair.value.replacement
                if lowerText.contains(original.lowercased()) {
                    result[original] = replacement
                }
            }

            #if DEBUG_RECORDER
            dbgDictKeys = Array(filteredContext.keys).sorted()
            #endif

            processedText = await cleanupService.cleanup(
                text: processedText,
                language: language,
                dictionaryContext: filteredContext
            )

            #if DEBUG_RECORDER
            let dbgPreGate = processedText
            let dbgGateStart = Date()
            #endif

            // Step 3a: Verification gates (Dialect / Levenshtein).
            //
            // 2026-05-04 RE-ENABLED. The V3 prompt (CleanupPrompt 2026-05-04
            // refactor) is content-preserving — fixtures show normalized
            // edit-distance well under threshold for typical inputs. With
            // V3 in place, the gates resume their role as a backstop
            // against rare model regressions (paraphrase, hallucination,
            // unsolicited Swiss dialect).
            //
            // Short-input bypass: for inputs ≤ 3 words the normalized
            // distance metric is lossy (a single token edit pushes ratios
            // past 0.45). The original 2026-05-03 disable was driven by
            // false rejections on short utterances; we side-step that here
            // by skipping the gate for very short inputs while keeping it
            // active where it matters (multi-sentence dictations where
            // hallucination has room to grow).
            let baselineWordCount = rulesCleanedText
                .split(whereSeparator: { $0.isWhitespace })
                .count
            if baselineWordCount > 3 {
                processedText = CleanupService.gateLLMDialect(
                    rulesCleaned: rulesCleanedText,
                    llmOutput: processedText
                )
                processedText = CleanupService.gateLLMOutput(
                    rulesCleaned: rulesCleanedText,
                    llmOutput: processedText
                )
            }

            #if DEBUG_RECORDER
            let dbgGateMs = Date().timeIntervalSince(dbgGateStart) * 1000.0
            let verdict: String = (processedText == dbgPreGate) ? "passed" : "rejected"
            dbgGateEntry = DebugCleanupRecord.GateEntry(
                text: processedText,
                verdict: verdict,
                edit_distance: nil,
                ms: dbgGateMs
            )
            #endif
        }

        #if DEBUG_RECORDER
        let dbgSwissNumStart = Date()
        #endif

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

        #if DEBUG_RECORDER
        let dbgPostSwissNumMs = Date().timeIntervalSince(dbgSwissNumStart) * 1000.0
        let dbgPostSwissNum = processedText
        #endif

        // Step 4: Save to History (UX-02)
        let entry = TranscriptionEntry(
            text: processedText,
            rawText: rawText,
            language: language,
            mode: mode.rawValue,
            confidence: confidence
        )
        historyService.save(entry)

        #if DEBUG_RECORDER
        // Phase 25-02: this record-assembly block runs for BOTH `mode == .plain`
        // AND `mode == .aiCleanup`. For plain-mode records: `cleanupTrace` is
        // nil (LLM never ran), so `llm_prompt`/`llm_raw` resolve to nil; the
        // `dbgGateEntry` variable stays at its outer-scope default of `nil`
        // (the AI branch above is the only thing that overwrites it), so
        // `post_gate` is nil too. `dbgDictKeys` stays `[]` (only the AI
        // branch populates it from the targeted dictionary context). The
        // resulting record carries `mode: "plain"` and the three LLM-section
        // keys are absent/null when JSON-encoded — exactly the schema Plan
        // 25-04's capture-window v2 expects for plain-vs-AI A/B.
        //
        // Capture trace from CleanupService (populated in cleanup() under
        // DEBUG_RECORDER). May be nil if mode != .aiCleanup, the model
        // wasn't loaded, or cleanup() threw before recording.
        let cleanupTrace: CleanupServiceTrace?
        if let cs = cleanupService as? CleanupService {
            cleanupTrace = cs.lastDebugTrace
        } else {
            cleanupTrace = nil
        }

        let llmPromptEntry: DebugCleanupRecord.LLMPromptEntry?
        let llmRawEntry: DebugCleanupRecord.LLMRawEntry?
        if let t = cleanupTrace {
            llmPromptEntry = DebugCleanupRecord.LLMPromptEntry(
                text: t.prompt,
                tokens_est: max(1, t.prompt.count / 4)
            )
            llmRawEntry = DebugCleanupRecord.LLMRawEntry(text: t.llmRaw, ms: t.llmMs)
        } else {
            llmPromptEntry = nil
            llmRawEntry = nil
        }

        let degenerateCollapse: Bool = {
            guard let raw = llmRawEntry else { return false }
            return raw.text.count < 5 && dbgRawText.count > 30
        }()
        let veryShort: Bool = processedText.count < 5 && dbgRawText.count > 30
        let emissionCounter = await DebugRecorder.shared.nextEmissionCounter()

        // Phase 28 R3 / WR-02: thread prompt_version explicitly from the
        // CleanupPrompt.currentVersion single source of truth so any future
        // version bump (V19E etc) carries through to JSONL without a silent
        // init-default drift.
        let record = DebugCleanupRecord(
            ts: DebugRecorder.iso8601Timestamp(),
            session_id: UUID().uuidString,
            lang: language,
            lang_used: language,    // Phase 25.1-01: alias of `lang` so jq queries against either field name produce correct results (closes 25-04 §Gap 1)
            mode: mode.rawValue,
            model: DebugCleanupRecord.ModelInfo(
                name: cleanupTrace?.modelName ?? "n/a",
                sha256_prefix: nil
            ),
            sampler: DebugCleanupRecord.SamplerInfo(
                temp: cleanupTrace?.samplerTemp ?? 0.1,
                top_k: cleanupTrace?.samplerTopK ?? 40,
                top_p: cleanupTrace?.samplerTopP ?? 0.9,
                max_tokens: cleanupTrace?.samplerMaxTokens ?? 512,
                seed: nil
            ),
            steps: DebugCleanupRecord.Steps(
                raw: .init(text: dbgRawText, ms: 0),
                post_dict: .init(text: dbgPostDict, ms: dbgPostDictMs),
                post_itn: .init(text: dbgPostItn, ms: dbgPostItnMs),
                post_swiss: .init(text: dbgPostSwiss, ms: dbgPostSwissMs),
                post_rules: .init(text: dbgPostRules, ms: dbgPostRulesMs),
                llm_prompt: llmPromptEntry,
                llm_raw: llmRawEntry,
                post_gate: dbgGateEntry,
                post_swiss_num: .init(text: dbgPostSwissNum, ms: dbgPostSwissNumMs)
            ),
            dictionary_context_keys: dbgDictKeys,
            dictionary_replacements: dbgReplacements.map { DebugCleanupRecord.DictionaryReplacementEntry(key: $0.key, from: $0.from, to: $0.to) },
            dictionary_blocked: dbgBlocked.map { DebugCleanupRecord.DictionaryBlockedEntry(key: $0.key, from: $0.from, to: $0.to, ratio: $0.ratio) },
            anomaly: DebugCleanupRecord.Anomaly(
                degenerate_collapse: degenerateCollapse,
                very_short_output: veryShort
            ),
            emission_counter: emissionCounter,   // Phase 25.1-01: monotonic per process — multi-day capture can prove dual-emission fired on every cycle (closes 25-04 §Gap 2)
            prompt_version: CleanupPrompt.currentVersion   // Phase 28 WR-02: explicit pass from single source of truth
        )
        await DebugRecorder.shared.record(record)
        #endif

        return processedText
    }
}
