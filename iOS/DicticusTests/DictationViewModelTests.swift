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
}
