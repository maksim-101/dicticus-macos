import Foundation

/// Downloads and caches the Gemma 3 1B GGUF model file on first run.
///
/// Per D-09: Download from HuggingFace on first launch.
/// Per D-10: Cache in Application Support/Dicticus/Models/.
/// Per D-04: Gemma 3 1B IT Q4_0 GGUF from unsloth (ungated, 722 MB).
///
/// Uses URLSession.shared.download(from:) for automatic temp file handling.
/// No authentication required — unsloth repo is publicly accessible.
class ModelDownloadService {

    /// HuggingFace CDN URL for ungated Gemma 3 1B IT Q4_0 GGUF.
    /// Using unsloth/gemma-3-1b-it-GGUF because the official Google repo is gated
    /// (requires login + license acceptance, breaking automated first-run download).
    static let modelURL = URL(string: "https://huggingface.co/unsloth/gemma-3-1b-it-GGUF/resolve/main/gemma-3-1b-it-Q4_0.gguf")!

    /// Expected file name for the cached GGUF model.
    static let modelFileName = "gemma-3-1b-it-Q4_0.gguf"

    /// Computed path to the cached model file in Application Support.
    ///
    /// Path: ~/Library/Application Support/Dicticus/Models/gemma-3-1b-it-Q4_0.gguf
    /// Follows the same Application Support convention as FluidAudio models (per D-10).
    static func modelPath() -> URL {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        return appSupport
            .appendingPathComponent("Dicticus")
            .appendingPathComponent("Models")
            .appendingPathComponent(modelFileName)
    }

    /// Check if the GGUF model file is already cached on disk.
    static func isModelCached() -> Bool {
        FileManager.default.fileExists(atPath: modelPath().path)
    }

    /// Download the GGUF model from HuggingFace and cache it in Application Support.
    ///
    /// No-op if model is already cached. Creates intermediate directories if needed.
    /// Downloads ~722 MB on first run — called during warmup, not during inference.
    ///
    /// - Throws: URLSession errors on network failure, FileManager errors on disk write failure.
    static func downloadIfNeeded() async throws {
        guard !isModelCached() else { return }

        let dir = modelPath().deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: dir,
            withIntermediateDirectories: true
        )

        let (tempURL, _) = try await URLSession.shared.download(from: modelURL)
        try FileManager.default.moveItem(at: tempURL, to: modelPath())
    }
}
