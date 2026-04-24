import XCTest
@testable import Dicticus

@MainActor
final class IOSModelWarmupServiceTests: XCTestCase {
    func testInitialState() {
        let service = IOSModelWarmupService()
        XCTAssertFalse(service.isWarming)
        XCTAssertFalse(service.isReady)
        XCTAssertNil(service.error)
    }
    func testAsrManagerIsNilBeforeWarmup() {
        let service = IOSModelWarmupService()
        XCTAssertNil(service.asrManagerInstance)
    }
    func testVadManagerIsNilBeforeWarmup() {
        let service = IOSModelWarmupService()
        XCTAssertNil(service.vadManagerInstance)
    }
    func testCancelWarmupResetsState() {
        let service = IOSModelWarmupService()
        service.cancelWarmup()
        XCTAssertFalse(service.isWarming)
    }

    // MARK: - Wave 3 (Plan 19-04) — Task 1: LlmStatus type surface

    func testLlmStatusIsIdleOnInit() {
        let service = IOSModelWarmupService()
        XCTAssertEqual(service.llmStatus, .idle)
    }

    func testIsLlmReadyIsFalseOnInit() {
        let service = IOSModelWarmupService()
        XCTAssertFalse(service.isLlmReady)
    }

    func testCleanupServiceInstanceIsNilOnInit() {
        let service = IOSModelWarmupService()
        XCTAssertNil(service.cleanupServiceInstance)
    }

    func testLlmStatusIdleLabel() {
        XCTAssertEqual(IOSModelWarmupService.LlmStatus.idle.label, "Waiting")
    }

    func testLlmStatusReadyLabel() {
        XCTAssertEqual(IOSModelWarmupService.LlmStatus.ready.label, "Ready")
    }

    func testLlmStatusFailedLabelCarriesReason() {
        XCTAssertEqual(
            IOSModelWarmupService.LlmStatus.failed("AI cleanup unavailable").label,
            "AI cleanup unavailable"
        )
    }

    func testLlmStatusIsActiveOnlyWhileLoading() {
        XCTAssertFalse(IOSModelWarmupService.LlmStatus.idle.isActive)
        XCTAssertTrue(IOSModelWarmupService.LlmStatus.loading.isActive)
        XCTAssertFalse(IOSModelWarmupService.LlmStatus.ready.isActive)
        XCTAssertFalse(IOSModelWarmupService.LlmStatus.failed("x").isActive)
    }
}
