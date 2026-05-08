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
    public let mode: String
    public let model: ModelInfo
    public let sampler: SamplerInfo
    public let steps: Steps
    public let dictionary_context_keys: [String]
    public let anomaly: Anomaly

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
}

// MARK: - Recorder actor

public actor DebugRecorder {

    public static let shared = DebugRecorder()

    private let directoryURL: URL
    private let retentionDays: Int = 14
    private var hasPurgedThisLaunch = false

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

    public func record(_ rec: DebugCleanupRecord) {
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
