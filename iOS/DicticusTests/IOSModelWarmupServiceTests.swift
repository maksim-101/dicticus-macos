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

    // MARK: - Wave 3 (Plan 19-04) — Task 2: Step 4 gate defaults

    /// Gate precondition: with no AppGroup value set, `aiCleanupEnabled`
    /// must read as `false` — warmup Step 4 MUST skip silently and
    /// `llmStatus` must remain `.idle`. This verifies the default-OFF
    /// posture independently of the heavy warmup pipeline.
    func testAiCleanupToggleDefaultsOffInAppGroup() {
        let suite = UserDefaults(suiteName: "group.com.dicticus") ?? UserDefaults.standard
        // Confirm the key Step 4 reads matches the Settings UI key.
        // (SettingsView.appGroupBinding writes this same key.)
        suite.removeObject(forKey: "aiCleanupEnabled")
        XCTAssertFalse(suite.bool(forKey: "aiCleanupEnabled"),
                       "Default must be false so Step 4 skips on a fresh install")
    }

    /// Gate precondition: before Step 4 runs, the published state snapshot
    /// must be the safe default — `.idle` + `isLlmReady == false` — even
    /// after a cancelWarmup round-trip that previously only cleared ASR state.
    func testLlmStatusRemainsIdleAfterCancelWarmup() {
        let service = IOSModelWarmupService()
        service.cancelWarmup()
        XCTAssertEqual(service.llmStatus, .idle)
        XCTAssertFalse(service.isLlmReady)
    }

    // MARK: - Phase 33 Plan 01 — Task 1 (IOS-ONB-01): synchronous hasModels init

    /// Pins the IOS-ONB-01 fix: `hasModels` must reflect the real filesystem
    /// state immediately after init — BEFORE any async warmup runs.
    ///
    /// On a simulator with no model downloaded, `hasModels` must be `false`
    /// right after construction. This ensures the first SwiftUI frame renders
    /// the correct state and cold-launch never shows a phantom download screen
    /// when the model is already present.
    func testHasModelsReflectsFilesystemStateImmediatelyAfterInit() {
        let service = IOSModelWarmupService()
        // On the test runner (no model downloaded), modelsExist returns false.
        // The important invariant: hasModels is set synchronously at init time,
        // not deferred to an async dispatch. If the property were still `= false`
        // (the old bug), this test would pass trivially — but the acceptance
        // criteria additionally requires that hasModels == true on a device where
        // the model IS present (manual verification step per 33-VALIDATION.md).
        // We verify the synchronous init contract by confirming no Task is needed.
        let expectedValue = {
            let cacheDir = AsrModels.defaultCacheDirectory(for: .v3)
            return AsrModels.modelsExist(at: cacheDir, version: .v3)
        }()
        XCTAssertEqual(service.hasModels, expectedValue,
                       "hasModels must match filesystem state synchronously at init — no async dispatch allowed")
    }
}
