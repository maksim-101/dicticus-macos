import FluidAudio

enum AsrModelLoader {
    /// `AsrModels.downloadAndLoad` with bounded retry. The Parakeet v3 download is
    /// ~2.7 GB across 23 files from HuggingFace; a single transient "Connection
    /// reset by peer" mid-transfer otherwise fails the whole warmup. FluidAudio
    /// caches already-fetched files, so each retry resumes rather than restarts.
    static func downloadAndLoadV3(maxAttempts: Int = 3) async throws -> AsrModels {
        var lastError: Error?
        for attempt in 1...maxAttempts {
            do {
                return try await AsrModels.downloadAndLoad(version: .v3)
            } catch {
                lastError = error
                if attempt < maxAttempts {
                    try? await Task.sleep(nanoseconds: UInt64(attempt) * 2_000_000_000)
                }
            }
        }
        throw lastError!
    }
}
