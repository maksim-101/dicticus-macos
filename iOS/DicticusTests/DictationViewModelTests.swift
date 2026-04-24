import XCTest
@testable import Dicticus

@MainActor
final class DictationViewModelTests: XCTestCase {
    func testInitialStateIsIdle() {
        let vm = DictationViewModel()
        XCTAssertEqual(vm.state, .idle)
    }

    func testInitialLastResultIsNil() {
        let vm = DictationViewModel()
        XCTAssertNil(vm.lastResult)
    }

    func testInitialErrorIsNil() {
        let vm = DictationViewModel()
        XCTAssertNil(vm.error)
    }

    func testTranscriptionServiceIsNilByDefault() {
        let vm = DictationViewModel()
        XCTAssertNil(vm.transcriptionService)
    }

    func testStartDictationWithNoServiceDoesNotCrash() async {
        let vm = DictationViewModel()
        // transcriptionService is nil — should handle gracefully
        await vm.startDictation()
        // The key test is no crash occurs
    }

    func testStopDictationFromIdleStateIsNoOp() async {
        let vm = DictationViewModel()
        await vm.stopDictation()
        XCTAssertEqual(vm.state, .idle, "stopDictation from idle should remain idle")
        XCTAssertNil(vm.lastResult)
    }

    func testIsShortcutLaunchInitiallyFalse() {
        let vm = DictationViewModel()
        XCTAssertFalse(vm.isShortcutLaunch, "isShortcutLaunch should be false on init")
    }

    func testStopDictationFromIdleDoesNotAffectShortcutFlag() async {
        let vm = DictationViewModel()
        vm.isShortcutLaunch = true  // Simulate shortcut launch
        await vm.stopDictation()
        // stopDictation guards on state == .recording, so it's a no-op from idle
        XCTAssertTrue(vm.isShortcutLaunch, "stopDictation from idle should not reset shortcut flag")
    }

    func testStateEnumEquality() {
        let idle: DictationViewModel.State = .idle
        let recording: DictationViewModel.State = .recording
        let transcribing: DictationViewModel.State = .transcribing
        let preparing: DictationViewModel.State = .preparingLiveActivity
        XCTAssertEqual(idle, .idle)
        XCTAssertEqual(recording, .recording)
        XCTAssertEqual(transcribing, .transcribing)
        XCTAssertEqual(preparing, .preparingLiveActivity)
        XCTAssertNotEqual(idle, recording)
    }

    // MARK: - Phase 19 Wave 5: CleanupService injection seam

    /// The property must exist so DicticusApp can inject the warmed-up
    /// CleanupService when Step 4 completes. Default is nil until injection.
    func testCleanupServiceIsNilByDefault() {
        let vm = DictationViewModel()
        XCTAssertNil(vm.cleanupService,
                     "cleanupService seam must start nil until DicticusApp injects it")
    }

    /// The seam must accept any `CleanupProvider` (including mocks) so tests can
    /// exercise the TextProcessingService routing without spinning up llama.cpp.
    func testCleanupServiceCanBeInjected() {
        final class StubProvider: CleanupProvider {
            var isLoaded: Bool = true
            func cleanup(text: String, language: String, dictionaryContext: [String: String]?) async -> String {
                return text
            }
        }
        let vm = DictationViewModel()
        let stub = StubProvider()
        vm.cleanupService = stub
        XCTAssertNotNil(vm.cleanupService,
                        "cleanupService seam must be writable for DicticusApp injection")
        XCTAssertTrue(vm.cleanupService?.isLoaded == true,
                      "Injected provider must be the same instance")
    }
}
