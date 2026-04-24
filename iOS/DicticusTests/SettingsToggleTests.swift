import XCTest
@testable import Dicticus

/// Wave 0 scaffold — Settings toggle defaults & orthogonality (CLEAN-01, D-08, D-15).
///
/// The two toggles (`aiCleanupEnabled`, `useSwissGerman`) land in Wave 3 Settings UI,
/// but their persistence keys are defined here so Wave 3's view code + tests agree on
/// the key strings. These tests exercise the UserDefaults layer directly.
@MainActor
final class SettingsToggleTests: XCTestCase {

    /// Canonical keys — Wave 3 must use these exact strings in SettingsView/@AppStorage.
    static let aiCleanupKey = "aiCleanupEnabled"
    static let swissGermanKey = "useSwissGerman"
    static let suiteName = "group.com.dicticus"

    private var defaults: UserDefaults!

    override func setUp() async throws {
        try await super.setUp()
        defaults = try XCTUnwrap(UserDefaults(suiteName: Self.suiteName))
        defaults.removeObject(forKey: Self.aiCleanupKey)
        defaults.removeObject(forKey: Self.swissGermanKey)
    }

    override func tearDown() async throws {
        defaults.removeObject(forKey: Self.aiCleanupKey)
        defaults.removeObject(forKey: Self.swissGermanKey)
        try await super.tearDown()
    }

    // MARK: - D-08: aiCleanupEnabled defaults OFF

    func testAiCleanupDefaultOff() {
        let storedObject = defaults.object(forKey: Self.aiCleanupKey)
        XCTAssertNil(storedObject, "aiCleanupEnabled must have no stored value → toggle renders OFF")
        // `bool(forKey:)` returns false for missing keys — matches a @AppStorage default of `false`.
        XCTAssertFalse(defaults.bool(forKey: Self.aiCleanupKey))
    }

    // MARK: - D-15: useSwissGerman defaults OFF

    func testSwissGermanDefaultOff() {
        let storedObject = defaults.object(forKey: Self.swissGermanKey)
        XCTAssertNil(storedObject, "useSwissGerman must have no stored value → toggle renders OFF")
        XCTAssertFalse(defaults.bool(forKey: Self.swissGermanKey))
    }

    // MARK: - Toggles are orthogonal (D-15: independent keys)

    func testTogglesAreOrthogonal() {
        defaults.set(true, forKey: Self.aiCleanupKey)
        XCTAssertTrue(defaults.bool(forKey: Self.aiCleanupKey))
        XCTAssertFalse(defaults.bool(forKey: Self.swissGermanKey),
                       "Setting aiCleanupEnabled must NOT mutate useSwissGerman")

        defaults.removeObject(forKey: Self.aiCleanupKey)
        defaults.set(true, forKey: Self.swissGermanKey)
        XCTAssertTrue(defaults.bool(forKey: Self.swissGermanKey))
        XCTAssertFalse(defaults.bool(forKey: Self.aiCleanupKey),
                       "Setting useSwissGerman must NOT mutate aiCleanupEnabled")
    }

    // MARK: - Both keys can coexist ON

    func testBothTogglesCanBeOnSimultaneously() {
        defaults.set(true, forKey: Self.aiCleanupKey)
        defaults.set(true, forKey: Self.swissGermanKey)
        XCTAssertTrue(defaults.bool(forKey: Self.aiCleanupKey))
        XCTAssertTrue(defaults.bool(forKey: Self.swissGermanKey))
    }
}
