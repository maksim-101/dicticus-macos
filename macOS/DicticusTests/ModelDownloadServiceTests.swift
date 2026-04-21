import XCTest
@testable import Dicticus

final class ModelDownloadServiceTests: XCTestCase {

    // MARK: - Model path

    func testModelPathEndsWithGGUFFileName() {
        let path = ModelDownloadService.modelPath()
        XCTAssertTrue(path.lastPathComponent == "gemma-4-E2B-it-Q4_K_M.gguf",
                       "Model path must end with GGUF filename")
    }

    func testModelPathContainsDicticusModelsDirectory() {
        let path = ModelDownloadService.modelPath().path
        XCTAssertTrue(path.contains("Dicticus/Models"),
                       "Model path must be under Dicticus/Models/ in Application Support")
    }

    func testModelPathIsInApplicationSupport() {
        let path = ModelDownloadService.modelPath().path
        XCTAssertTrue(path.contains("Application Support"),
                       "Model must be cached in Application Support directory (D-10)")
    }

    // MARK: - Model URL (D-04: ungated repo)

    func testModelURLPointsToUnslothRepo() {
        let url = ModelDownloadService.modelURL.absoluteString
        XCTAssertTrue(url.contains("unsloth/gemma-4-E2B-it-GGUF"),
                       "Must use ungated unsloth repo, not gated Google repo")
        XCTAssertFalse(url.contains("google/"),
                        "Must NOT use gated Google repo (requires login)")
    }

    func testModelURLPointsToQ4_K_MQuantization() {
        let url = ModelDownloadService.modelURL.absoluteString
        XCTAssertTrue(url.contains("Q4_K_M"),
                       "Must download Q4_K_M quantization for Gemma 4 E2B")
    }

    // MARK: - Cache check

    func testIsModelCachedReturnsFalseWhenNotDownloaded() {
        // This test verifies the cache check logic works when the model
        // has not been downloaded to the test environment.
        // On CI or clean machines, this will always be false.
        // On dev machines with the model cached, this tests the positive path.
        let isCached = ModelDownloadService.isModelCached()
        let fileExists = FileManager.default.fileExists(
            atPath: ModelDownloadService.modelPath().path
        )
        XCTAssertEqual(isCached, fileExists,
                        "isModelCached must reflect actual file existence")
    }

    // MARK: - File name constant

    func testModelFileNameMatchesURL() {
        let urlFileName = ModelDownloadService.modelURL.lastPathComponent
        XCTAssertEqual(ModelDownloadService.modelFileName, urlFileName,
                        "modelFileName constant must match the URL's file name")
    }
}
