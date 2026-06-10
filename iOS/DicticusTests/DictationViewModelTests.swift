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

    // MARK: - Phase 36 Wave 2: cleanup mode toggle gate

    /// D-13 / D-23: mode selection must follow the aiCleanupEnabled toggle and LLM readiness.
    /// Uses DictationViewModel.selectMode() static seam to test without spinning up ASR or LLM.
    func testCleanupModeRespectsAiCleanupToggle() {
        // LLM ready + toggle ON → aiCleanup
        XCTAssertEqual(
            DictationViewModel.selectMode(wantsAiCleanup: true, llmReady: true),
            .aiCleanup,
            "When toggle is ON and LLM is loaded, mode must be .aiCleanup"
        )
        // LLM ready + toggle OFF → plain
        XCTAssertEqual(
            DictationViewModel.selectMode(wantsAiCleanup: false, llmReady: true),
            .plain,
            "When toggle is OFF, mode must be .plain regardless of LLM readiness"
        )
        // LLM NOT ready + toggle ON → plain (graceful degradation D-26)
        XCTAssertEqual(
            DictationViewModel.selectMode(wantsAiCleanup: true, llmReady: false),
            .plain,
            "When LLM is not loaded, mode must fall back to .plain (D-26 graceful degradation)"
        )
        // LLM NOT ready + toggle OFF → plain
        XCTAssertEqual(
            DictationViewModel.selectMode(wantsAiCleanup: false, llmReady: false),
            .plain,
            "When both toggle is OFF and LLM is not loaded, mode must be .plain"
        )
    }
}
