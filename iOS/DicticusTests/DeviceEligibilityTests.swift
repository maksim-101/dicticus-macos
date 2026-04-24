import XCTest
@testable import Dicticus

/// Wave 0 scaffold — RAM eligibility gating for AI cleanup (D-03).
///
/// D-03: devices with < 5 GB physical RAM must have the AI cleanup toggle
/// disabled/hidden. Wave 2 adds `IOSModelWarmupService.isAiCleanupSupported`
/// and a `ramThreshold` constant. Until then, this scaffold exercises the raw
/// `ProcessInfo.physicalMemory` read + documents the threshold contract.
@MainActor
final class DeviceEligibilityTests: XCTestCase {

    /// Flip to `true` in Wave 2 when `IOSModelWarmupService.isAiCleanupSupported`
    /// and the shared `ramThreshold` constant land.
    private let isWave2Ready = false

    /// D-03: cutoff is 5 GB. This constant should be mirrored in the Wave 2
    /// implementation (e.g. `IOSModelWarmupService.ramThresholdBytes`).
    static let expectedRamThresholdBytes: UInt64 = 5 * 1024 * 1024 * 1024

    // MARK: - D-03: Threshold constant contract

    func testRamThresholdConstantIsFiveGb() throws {
        try XCTSkipIf(!isWave2Ready,
                      "Pending Wave 2: IOSModelWarmupService.ramThresholdBytes not yet exposed")
        // Wave 2 assertion:
        // XCTAssertEqual(IOSModelWarmupService.ramThresholdBytes,
        //                Self.expectedRamThresholdBytes)
    }

    // MARK: - D-03: Runtime eligibility on current device

    func testIsAiCleanupSupportedOnCurrentDevice() throws {
        let physicalMemory = ProcessInfo.processInfo.physicalMemory
        try XCTSkipIf(physicalMemory < Self.expectedRamThresholdBytes,
                      "Simulator/device has < 5 GB RAM — eligibility test intentionally skipped")
        try XCTSkipIf(!isWave2Ready,
                      "Pending Wave 2: IOSModelWarmupService.isAiCleanupSupported not yet implemented")
        // Wave 2 assertion:
        // XCTAssertTrue(IOSModelWarmupService.isAiCleanupSupported)
    }

    // MARK: - Sanity: ProcessInfo exposes physicalMemory

    func testPhysicalMemoryIsReadable() {
        let mem = ProcessInfo.processInfo.physicalMemory
        XCTAssertGreaterThan(mem, 0, "physicalMemory must be readable for D-03 gating")
    }
}
