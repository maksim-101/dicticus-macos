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
}
