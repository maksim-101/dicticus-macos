import XCTest

// Tests for SystemSettingsURL URL constants
// Verifies each URL contains the correct Privacy anchor and uses the expected scheme
final class SystemSettingsURLTests: XCTestCase {

    func testMicrophoneURLScheme() {
        let url = SystemSettingsURL.microphone
        XCTAssertEqual(url.scheme, "x-apple.systempreferences")
    }

    func testMicrophoneURLContainsPrivacyAnchor() {
        let urlString = SystemSettingsURL.microphone.absoluteString
        XCTAssertTrue(urlString.contains("Privacy_Microphone"),
                      "Microphone URL must contain Privacy_Microphone anchor, got: \(urlString)")
    }

    func testAccessibilityURLScheme() {
        let url = SystemSettingsURL.accessibility
        XCTAssertEqual(url.scheme, "x-apple.systempreferences")
    }

    func testAccessibilityURLContainsPrivacyAnchor() {
        let urlString = SystemSettingsURL.accessibility.absoluteString
        XCTAssertTrue(urlString.contains("Privacy_Accessibility"),
                      "Accessibility URL must contain Privacy_Accessibility anchor, got: \(urlString)")
    }

    func testInputMonitoringURLScheme() {
        let url = SystemSettingsURL.inputMonitoring
        XCTAssertEqual(url.scheme, "x-apple.systempreferences")
    }

    func testInputMonitoringURLContainsPrivacyAnchor() {
        let urlString = SystemSettingsURL.inputMonitoring.absoluteString
        XCTAssertTrue(urlString.contains("Privacy_ListenEvent"),
                      "Input Monitoring URL must contain Privacy_ListenEvent anchor, got: \(urlString)")
    }

    func testAllURLsAreDistinct() {
        let mic = SystemSettingsURL.microphone.absoluteString
        let acc = SystemSettingsURL.accessibility.absoluteString
        let inp = SystemSettingsURL.inputMonitoring.absoluteString
        XCTAssertNotEqual(mic, acc)
        XCTAssertNotEqual(mic, inp)
        XCTAssertNotEqual(acc, inp)
    }
}
