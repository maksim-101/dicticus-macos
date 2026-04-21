import Foundation

/// Downloads and caches the Gemma 4 E2B GGUF model file on first run.
///
/// Per D-09: Download from HuggingFace on first launch.
/// Per D-10: Cache in Application Support/Dicticus/Models/.
/// Per D-04: Gemma 4 E2B IT GGUF from unsloth (ungated, ~3.1 GB).
///
/// Uses URLSession.shared.download(from:) for automatic temp file handling.
/// No authentication required — unsloth repo is publicly accessible.
class ModelDownloadService {

    /// HuggingFace CDN URL for ungated Gemma 4 E2B IT GGUF.
    /// Using unsloth/gemma-4-E2B-it-GGUF because the official Google repo is gated
    /// (requires login + license acceptance, breaking automated first-run download).
    static let modelURL = URL(string: "https://huggingface.co/unsloth/gemma-4-E2B-it-GGUF/resolve/main/gemma-4-E2B-it-Q4_K_M.gguf")!

    /// Expected file name for the cached GGUF model.
    static let modelFileName = "gemma-4-E2B-it-Q4_K_M.gguf"

    /// Computed path to the cached model file in Application Support.
    ///
    /// Path: ~/Library/Application Support/Dicticus/Models/gemma-4-E2B-it-Q4_K_M.gguf
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
    /// Downloads ~3.1 GB on first run — called during warmup, not during inference.
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
