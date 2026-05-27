// DebugRecorder — local-only engineering diagnostics for the cleanup pipeline.
//
// COMPILED OUT in any build that doesn't pass `-D DEBUG_RECORDER` (i.e. the
// public `Dicticus` scheme used by `scripts/build-dmg.sh` and the GitHub
// Release artifact). The whole file becomes empty when the flag is absent;
// no symbols, no JSON encoder, no Application Support directory access.
//
// Captures full LLM payloads (assembled prompt, raw pre-gate output, sampler
// params, per-step intermediates and latencies) to JSONL on disk for offline
// replay of failures like the "T"/"W" degenerate-collapse bug. Distinct from
// HistoryService, which persists user-facing transcripts only.
//
// Output: ~/Library/Application Support/Dicticus/DebugRecordings/cleanup-YYYY-MM-DD.jsonl
// Retention: 14 days, purged once per launch.

#if DEBUG_RECORDER

import Foundation

// MARK: - Record schema

public struct DebugCleanupRecord: Codable, Sendable {
    public let ts: String
    public let session_id: String
    public let lang: String
    public let lang_used: String            // Phase 25.1-01: alias of `lang` so jq queries against either field name produce correct results (closes 25-04 §Gap 1)
    public let mode: String
    public let model: ModelInfo
    public let sampler: SamplerInfo
    public let steps: Steps
    /// LLM context targeting hints (input-side dictionary key matches). Narrowed in Phase 27: no longer overloaded with actually-applied replacements — see dictionary_replacements.
    public let dictionary_context_keys: [String]
    public let dictionary_replacements: [DictionaryReplacementEntry]
    public let dictionary_blocked: [DictionaryBlockedEntry]
    public let anomaly: Anomaly
    public let emission_counter: Int        // Phase 25.1-01: monotonic per process — multi-day capture can prove dual-emission fired on every cycle (closes 25-04 §Gap 2)
    public let prompt_version: String       // Phase 28 R3 (Plan 28-01): prompt variant tag for JSONL analysis; defaults to "v19d" on new records.

    // Phase 27 WR-02: custom decoder tolerates pre-Phase-27 JSONL where the
    // dictionary_replacements / dictionary_blocked keys are absent. Both
    // default to `[]` on missing-key, matching the encode-as-`[]` contract
    // pinned by DebugCleanupRecordCodableTests.testDebugCleanupRecordCodableRoundTrip_DefaultEmpty.
    // Synthesized encoder (Codable) is unchanged and continues to emit the
    // fields explicitly — only decode is relaxed.
    private enum CodingKeys: String, CodingKey {
        case ts, session_id, lang, lang_used, mode, model, sampler, steps
        case dictionary_context_keys, dictionary_replacements, dictionary_blocked
        case anomaly, emission_counter, prompt_version
    }

    public init(
        ts: String,
        session_id: String,
        lang: String,
        lang_used: String,
        mode: String,
        model: ModelInfo,
        sampler: SamplerInfo,
        steps: Steps,
        dictionary_context_keys: [String],
        dictionary_replacements: [DictionaryReplacementEntry],
        dictionary_blocked: [DictionaryBlockedEntry],
        anomaly: Anomaly,
        emission_counter: Int,
        prompt_version: String = "v19d"
    ) {
        self.ts = ts
        self.session_id = session_id
        self.lang = lang
        self.lang_used = lang_used
        self.mode = mode
        self.model = model
        self.sampler = sampler
        self.steps = steps
        self.dictionary_context_keys = dictionary_context_keys
        self.dictionary_replacements = dictionary_replacements
        self.dictionary_blocked = dictionary_blocked
        self.anomaly = anomaly
        self.emission_counter = emission_counter
        self.prompt_version = prompt_version
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.ts = try c.decode(String.self, forKey: .ts)
        self.session_id = try c.decode(String.self, forKey: .session_id)
        self.lang = try c.decode(String.self, forKey: .lang)
        self.lang_used = try c.decode(String.self, forKey: .lang_used)
        self.mode = try c.decode(String.self, forKey: .mode)
        self.model = try c.decode(ModelInfo.self, forKey: .model)
        self.sampler = try c.decode(SamplerInfo.self, forKey: .sampler)
        self.steps = try c.decode(Steps.self, forKey: .steps)
        self.dictionary_context_keys = try c.decode([String].self, forKey: .dictionary_context_keys)
        // Phase 27 WR-02: tolerate missing keys in pre-Phase-27 JSONL.
        self.dictionary_replacements = try c.decodeIfPresent([DictionaryReplacementEntry].self, forKey: .dictionary_replacements) ?? []
        self.dictionary_blocked = try c.decodeIfPresent([DictionaryBlockedEntry].self, forKey: .dictionary_blocked) ?? []
        self.anomaly = try c.decode(Anomaly.self, forKey: .anomaly)
        self.emission_counter = try c.decode(Int.self, forKey: .emission_counter)
        // Phase 28 R3 (Plan 28-01): backward-compat decode for pre-Phase-28 JSONL — default to "v19c" when key absent. Mirrors Phase 27 WR-02 pattern at L91-93.
        self.prompt_version = try c.decodeIfPresent(String.self, forKey: .prompt_version) ?? "v19c"
    }

    public struct ModelInfo: Codable, Sendable {
        public let name: String
        public let sha256_prefix: String?
    }

    public struct SamplerInfo: Codable, Sendable {
        public let temp: Double
        public let top_k: Int
        public let top_p: Double
        public let max_tokens: Int
        public let seed: UInt32?
    }

    public struct StepEntry: Codable, Sendable {
        public let text: String
        public let ms: Double
    }

    public struct LLMPromptEntry: Codable, Sendable {
        public let text: String
        public let tokens_est: Int
    }

    public struct LLMRawEntry: Codable, Sendable {
        public let text: String
        public let ms: Double
    }

    public struct GateEntry: Codable, Sendable {
        public let text: String
        public let verdict: String
        public let edit_distance: Double?
        public let ms: Double
    }

    public struct Steps: Codable, Sendable {
        public let raw: StepEntry
        public let post_dict: StepEntry
        public let post_itn: StepEntry
        public let post_swiss: StepEntry
        public let post_rules: StepEntry
        public let llm_prompt: LLMPromptEntry?
        public let llm_raw: LLMRawEntry?
        public let post_gate: GateEntry?
        public let post_swiss_num: StepEntry
    }

    public struct Anomaly: Codable, Sendable {
        public let degenerate_collapse: Bool
        public let very_short_output: Bool
    }

    public struct DictionaryReplacementEntry: Codable, Sendable {
        public let key: String
        public let from: String
        public let to: String

        public init(key: String, from: String, to: String) {
            self.key = key
            self.from = from
            self.to = to
        }
    }

    public struct DictionaryBlockedEntry: Codable, Sendable {
        public let key: String
        public let from: String
        public let to: String
        public let ratio: Double

        public init(key: String, from: String, to: String, ratio: Double) {
            self.key = key
            self.from = from
            self.to = to
            self.ratio = ratio
        }
    }
}

// MARK: - Recorder actor

public actor DebugRecorder {

    public static let shared = DebugRecorder()

    private let directoryURL: URL
    private let retentionDays: Int = 14
    private var hasPurgedThisLaunch = false
    private var emissionCounter: Int = 0

    /// Test-only — last record handed to record(_:). Always nil in production builds (file is fully gated by #if DEBUG_RECORDER).
    public private(set) var lastRecordForTests: DebugCleanupRecord?

    private init() {
        let fm = FileManager.default
        let appSupport = (try? fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library/Application Support")

        self.directoryURL = appSupport
            .appendingPathComponent("Dicticus", isDirectory: true)
            .appendingPathComponent("DebugRecordings", isDirectory: true)
    }

    public func nextEmissionCounter() -> Int {
        emissionCounter += 1
        return emissionCounter
    }

    public func record(_ rec: DebugCleanupRecord) {
        lastRecordForTests = rec
        ensureDirectory()
        purgeIfNeeded()

        let url = currentFileURL()
        guard let line = encodeLine(rec) else { return }
        appendLine(line, to: url)
    }

    private func ensureDirectory() {
        try? FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )
    }

    private func currentFileURL() -> URL {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(secondsFromGMT: 0)
        let day = f.string(from: Date())
        return directoryURL.appendingPathComponent("cleanup-\(day).jsonl")
    }

    private func encodeLine(_ rec: DebugCleanupRecord) -> Data? {
        let enc = JSONEncoder()
        enc.outputFormatting = [.withoutEscapingSlashes]
        guard var data = try? enc.encode(rec) else { return nil }
        data.append(0x0A)  // newline (JSONL)
        return data
    }

    private func appendLine(_ data: Data, to url: URL) {
        let fm = FileManager.default
        if fm.fileExists(atPath: url.path) {
            if let h = try? FileHandle(forWritingTo: url) {
                defer { try? h.close() }
                try? h.seekToEnd()
                try? h.write(contentsOf: data)
            }
        } else {
            try? data.write(to: url)
        }
    }

    private func purgeIfNeeded() {
        guard !hasPurgedThisLaunch else { return }
        hasPurgedThisLaunch = true

        let cutoff = Date().addingTimeInterval(-Double(retentionDays * 86_400))
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [.contentModificationDateKey]
        ) else { return }

        for entry in entries where entry.pathExtension == "jsonl" {
            if let mod = try? entry.resourceValues(forKeys: [.contentModificationDateKey])
                .contentModificationDate,
               mod < cutoff {
                try? fm.removeItem(at: entry)
            }
        }
    }

    public nonisolated static func iso8601Timestamp(_ date: Date = Date()) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.string(from: date)
    }
}

// MARK: - In-process trace handed from CleanupService → TextProcessingService.

/// Captured by CleanupService at the end of `cleanup(...)`; consumed by
/// TextProcessingService to build the on-disk record. Sendable across the
/// MainActor → actor hop into DebugRecorder.
public struct CleanupServiceTrace: Sendable {
    public let prompt: String
    public let llmRaw: String
    public let llmMs: Double
    public let modelName: String
    public let samplerTemp: Double
    public let samplerTopK: Int
    public let samplerTopP: Double
    public let samplerMaxTokens: Int

    public init(
        prompt: String,
        llmRaw: String,
        llmMs: Double,
        modelName: String,
        samplerTemp: Double,
        samplerTopK: Int,
        samplerTopP: Double,
        samplerMaxTokens: Int
    ) {
        self.prompt = prompt
        self.llmRaw = llmRaw
        self.llmMs = llmMs
        self.modelName = modelName
        self.samplerTemp = samplerTemp
        self.samplerTopK = samplerTopK
        self.samplerTopP = samplerTopP
        self.samplerMaxTokens = samplerMaxTokens
    }
}

#endif
