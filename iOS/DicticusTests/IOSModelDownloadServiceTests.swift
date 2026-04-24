import XCTest
@testable import Dicticus

/// Wave 0 scaffold — IOSModelDownloadService tests (D-10, Q6).
///
/// **TDD RED state.** Wave 2 adds `iOS/Dicticus/Services/IOSModelDownloadService.swift`
/// with these required test seams:
///
/// - `init(sessionConfiguration: URLSessionConfiguration)` — lets tests inject
///   a `URLSessionConfiguration` whose `protocolClasses = [MockURLProtocol.self]`.
/// - `static var modelURL: URL`
/// - `static var modelFileName: String` (`"gemma-4-E2B-it-Q4_K_M.gguf"`)
/// - `static func modelPath() -> URL`
/// - `static func isModelCached() -> Bool`
/// - `@Published var state: DownloadState` (`.idle / .downloading / .paused / .completed / .failed`)
/// - `@Published var progress: Double` (0.0 … 1.0)
/// - `func start()`, `func pause()`, `func resume()`
/// - `func startAndWaitForCompletion() async` and `func waitForCompletion() async`
///   — test-helper methods that await the final state (Wave 2 may implement as
///   async wrappers around Combine sinks or AsyncSequence).
///
/// Once Wave 2 lands, flip `isWave2Ready` to `true` and fill in the TODO bodies
/// below. `MockURLProtocol` (shipped in this plan) drives all chunked-progress,
/// Range-header resume, and failure-injection scenarios.
@MainActor
final class IOSModelDownloadServiceTests: XCTestCase {

    /// Flip to `true` in Wave 2 once IOSModelDownloadService exists.
    private let isWave2Ready = false

    override func setUp() async throws {
        try await super.setUp()
        MockURLProtocol.reset()
    }

    override func tearDown() async throws {
        MockURLProtocol.reset()
        try await super.tearDown()
    }

    // MARK: - D-10: Progress callbacks over ≥3 chunks

    func testProgressCallbacks() async throws {
        try XCTSkipIf(!isWave2Ready,
                      "Pending Wave 2: IOSModelDownloadService not yet implemented")
        // Wave 2 implementation:
        // let cfg = URLSessionConfiguration.ephemeral
        // cfg.protocolClasses = [MockURLProtocol.self]
        // MockURLProtocol.responseData[IOSModelDownloadService.modelURL.absoluteString] =
        //     Data(repeating: 0xAB, count: 8 * 1024)
        // MockURLProtocol.chunkCount = 4
        // let service = IOSModelDownloadService(sessionConfiguration: cfg)
        //
        // var progressSamples: [Double] = []
        // let cancel = service.$progress.sink { progressSamples.append($0) }
        // defer { cancel.cancel() }
        //
        // await service.startAndWaitForCompletion()
        //
        // XCTAssertGreaterThanOrEqual(progressSamples.count, 3)
        // XCTAssertEqual(progressSamples.last ?? 0, 1.0, accuracy: 0.01)
    }

    // MARK: - D-10: Pause / resume with Range header

    func testPauseResume() async throws {
        try XCTSkipIf(!isWave2Ready,
                      "Pending Wave 2: IOSModelDownloadService not yet implemented")
        // Wave 2 implementation:
        // MockURLProtocol.chunkDelay = 0.2
        // let service = makeService()  // helper below
        // service.start()
        // try await Task.sleep(nanoseconds: 300_000_000)
        // service.pause()
        // // XCTAssertEqual(service.state, .paused)
        // let midProgress = service.progress
        // XCTAssertGreaterThan(midProgress, 0.0)
        // XCTAssertLessThan(midProgress, 1.0)
        //
        // service.resume()
        // await service.waitForCompletion()
        // // XCTAssertEqual(service.state, .completed)
    }

    // MARK: - Q6: Backup exclusion

    func testBackupExclusion() async throws {
        try XCTSkipIf(!isWave2Ready,
                      "Pending Wave 2: IOSModelDownloadService not yet implemented")
        // Wave 2 implementation:
        // await makeService().startAndWaitForCompletion()
        // let url = IOSModelDownloadService.modelPath()
        // let values = try url.resourceValues(forKeys: [.isExcludedFromBackupKey])
        // XCTAssertTrue(values.isExcludedFromBackup ?? false,
        //               "Q6: downloaded GGUF must be marked isExcludedFromBackup")
    }

    // MARK: - Sanity: MockURLProtocol Range header handling

    func testMockURLProtocolHonorsRangeHeader() throws {
        let expectation = expectation(description: "range response")
        let totalBytes = 1024
        let url = URL(string: "https://example.test/mock.bin")!
        MockURLProtocol.responseData[url.absoluteString] = Data(repeating: 0x42, count: totalBytes)
        MockURLProtocol.chunkDelay = 0  // fast

        let cfg = URLSessionConfiguration.ephemeral
        cfg.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: cfg)

        var req = URLRequest(url: url)
        req.setValue("bytes=512-", forHTTPHeaderField: "Range")
        var capturedStatus: Int = 0
        var capturedLength: Int = 0
        session.dataTask(with: req) { data, response, _ in
            if let http = response as? HTTPURLResponse {
                capturedStatus = http.statusCode
            }
            capturedLength = data?.count ?? 0
            expectation.fulfill()
        }.resume()

        wait(for: [expectation], timeout: 5)
        XCTAssertEqual(capturedStatus, 206, "Range request must produce 206 Partial Content")
        XCTAssertEqual(capturedLength, totalBytes - 512,
                       "Range response body must start at offset 512")
    }
}
