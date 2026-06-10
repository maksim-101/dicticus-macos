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

    // MARK: - Phase 36 Wave 3: stop controls + soft cap

    /// Double-session guard: a second startDictation() call while state == .recording
    /// must be a no-op (the existing guard state == .idle gate). This test drives state
    /// directly to .recording (bypassing the full ASR stack) and asserts the guard holds.
    func testDoubleSessionStartIsNoOp() async {
        let vm = DictationViewModel()
        // Force state to .recording to simulate an in-progress session
        vm.state = .recording
        // A second call to startDictation() must not proceed past the guard
        await vm.startDictation()
        // State must remain .recording — the guard returned early
        XCTAssertEqual(vm.state, .recording,
                       "startDictation() while recording must be a no-op (double-session guard)")
    }

    /// Soft-cap auto-finalize (D-03): with a tiny capFinalizeSeconds, the finalize task
    /// must fire and transition the ViewModel out of .recording. Uses injectable interval
    /// and forces state to .recording to bypass the full ASR stack.
    func testSoftCapTimerFiresStopDictation() async {
        let vm = DictationViewModel()
        vm.capFinalizeSeconds = 0.05  // 50ms — tiny interval for test speed
        vm.capWarningSeconds = 0.01   // must be < capFinalizeSeconds

        // Force into recording state (mimics the path after startRecording() succeeds)
        vm.state = .recording
        vm.startCapTimers()

        // Wait just over the finalize interval for the Task to fire
        try? await Task.sleep(for: .seconds(0.3))

        // The finalize task calls stopDictation(); guard state == .recording will pass
        // (state is .recording), then cancelCapTimers(), then set state = .transcribing.
        // stopDictation() will then fail at transcriptionService?.stopRecordingAndTranscribe()
        // (service is nil → returns nil), set endLiveActivity() (no-op), state = .idle.
        XCTAssertNotEqual(vm.state, .recording,
                          "Soft-cap finalize task must transition ViewModel out of .recording")
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
