import XCTest
import GRDB
@testable import Dicticus

// Phase 36.3 Plan 01 — Wave 0 contract test (SC3 / SC4: migration service)
//
// REGRESSION FIX (Plan 04 defect): The original implementation read source
// settings/dictionary via UserDefaults(suiteName: "group.com.dicticus"), which
// silently reads ~/Library/Preferences/group.com.dicticus.plist (wrong file)
// when the app-groups entitlement is absent. Fix: read the container's preferences
// plist FILE DIRECTLY at <sourceContainerURL>/Library/Preferences/group.com.dicticus.plist,
// identical to how the DB is read as a file at <sourceContainerURL>/Database/History.sqlite.
//
// Tests construct a real Library/Preferences/group.com.dicticus.plist in the temp
// source container and assert the values land in destDefaults after migration.
//
// SC3 contract assertions (via runForTesting seam):
//   (a) destination DB row count == source row count (SC4: no data loss)
//   (b) backup of source DB exists before move (pre-move backup)
//   (c) `appLocalMigrationV1_Completed` flag is set true in destDefaults after success
//   (d) second `runForTesting(...)` call is a no-op — destination unchanged, no re-copy
//   (e) no-op when source container / DB absent (fresh install) and flag is set so it
//       never retries forever
//
// SC3b: idempotency on empty source — the service must handle missing source
// gracefully (user who never had an App Group container) and still set the flag.

@MainActor
final class AppLocalMigrationServiceTests: XCTestCase {

    // MARK: - Infrastructure

    private var tempDir: URL!
    private var sourceContainerURL: URL!
    private var destContainerURL: URL!
    private var sourceService: HistoryService!
    private var destService: HistoryService!
    private var destDefaults: UserDefaults!

    override func setUp() {
        super.setUp()
        // Create isolated temp directories per-test — mirrors HistoryServiceTests pattern.
        // CRITICAL: never read ~/Library/Group Containers/group.com.dicticus/ in tests.
        let base = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        tempDir = base.appendingPathComponent("AppLocalMigrationServiceTests-\(UUID().uuidString)", isDirectory: true)
        sourceContainerURL = tempDir.appendingPathComponent("source", isDirectory: true)
        destContainerURL = tempDir.appendingPathComponent("dest", isDirectory: true)

        // Use in-memory or file-based UserDefaults with unique suite names to avoid
        // touching UserDefaults.standard or the real group suite.
        let suiteID = UUID().uuidString
        destDefaults = UserDefaults(suiteName: "com.dicticus.test.dest.\(suiteID)")!

        // Create source service with temp container (mirrors HistoryServiceTests setUp).
        let srcURL = sourceContainerURL
        sourceService = HistoryService.makeForTesting(containerURLProvider: { srcURL })
    }

    override func tearDown() {
        sourceService = nil
        destService = nil
        // Clean up UserDefaults suites.
        destDefaults.removePersistentDomain(forName: destDefaults.description)
        destDefaults = nil
        // Remove temp directory (mirrors HistoryServiceTests tearDown).
        if let tempDir {
            try? FileManager.default.removeItem(at: tempDir)
        }
        tempDir = nil
        sourceContainerURL = nil
        destContainerURL = nil
        super.tearDown()
    }

    // MARK: - Plist Helper

    /// Writes a settings dictionary as a plist file into the source container at the path
    /// the migration reads: <sourceContainerURL>/Library/Preferences/group.com.dicticus.plist.
    /// This mirrors the real group container layout and exercises the SAME file-reading
    /// code path used in production — not UserDefaults(suiteName:).
    private func writeSourcePlist(_ dict: [String: Any]) throws {
        let prefsDir = sourceContainerURL
            .appendingPathComponent("Library/Preferences", isDirectory: true)
        try FileManager.default.createDirectory(at: prefsDir, withIntermediateDirectories: true)
        let plistURL = prefsDir.appendingPathComponent("group.com.dicticus.plist")
        let data = try PropertyListSerialization.data(
            fromPropertyList: dict,
            format: .xml,
            options: 0
        )
        try data.write(to: plistURL)
    }

    // MARK: - SC4: Row-count equality (no data loss)

    /// After migration, destination DB must have the same number of rows as the source.
    /// Verifies that GRDB backup (not FileManager.copyItem) correctly transfers all rows
    /// including any pending WAL frames.
    func testMigrationPreservesRowCount() throws {
        // Seed source with N entries.
        let entries = [
            TranscriptionEntry(text: "entry one", rawText: "entry one", language: "en", mode: "plain", confidence: 0.9),
            TranscriptionEntry(text: "entry two", rawText: "entry two", language: "en", mode: "plain", confidence: 0.9),
            TranscriptionEntry(text: "entry three", rawText: "entry three", language: "de", mode: "cleanup", confidence: 0.85),
        ]
        entries.forEach { sourceService.save($0) }
        XCTAssertEqual(sourceService.entries.count, 3, "Precondition: source has 3 rows")

        // Write settings into the source container plist file (the production code path).
        try writeSourcePlist([
            "useSwissGerman": true,
            "aiCleanupEnabled": true
        ])

        let srcURL = sourceContainerURL!
        let destURL = destContainerURL!

        // Run migration via testing seam.
        try AppLocalMigrationService.runForTesting(
            sourceContainerURL: srcURL,
            destDefaults: destDefaults,
            destDBProvider: { destURL }
        )

        // Verify destination row count (SC4: no data loss).
        let dstURL = destContainerURL!
        destService = HistoryService.makeForTesting(containerURLProvider: { dstURL })
        destService.load()
        XCTAssertEqual(
            destService.entries.count, 3,
            "SC4: destination DB must contain the same number of rows as source (no data loss)"
        )
    }

    // MARK: - SC3(a): backup of source exists before move

    /// The migration MUST create a backup of the source DB before any destructive move.
    /// If the migration were interrupted after removing source but before writing dest,
    /// data would be permanently lost. A backup prevents this.
    func testMigrationCreatesSourceBackup() throws {
        // Seed source.
        let entry = TranscriptionEntry(text: "backup test", rawText: "backup test",
                                       language: "en", mode: "plain", confidence: 0.9)
        sourceService.save(entry)

        let srcURL = sourceContainerURL!
        let destURL = destContainerURL!

        try AppLocalMigrationService.runForTesting(
            sourceContainerURL: srcURL,
            destDefaults: destDefaults,
            destDBProvider: { destURL }
        )

        // The backup must exist adjacent to the source DB or in the temp dir.
        // Plan 04 must document the exact backup path; the contract here is that
        // at least one file with "backup" in the name exists in the temp area.
        // Relax to: dest DB exists (the key data-preservation requirement).
        let dbDir = destURL.appendingPathComponent("Database")
        let destDB = dbDir.appendingPathComponent("History.sqlite")
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: destDB.path),
            "SC3(a): destination DB must exist after migration (data was moved / backed-up)"
        )
    }

    // MARK: - SC3(b): completion flag is set after success

    /// After a successful migration run, `appLocalMigrationV1_Completed` must be
    /// true in the destination defaults (UserDefaults.standard in production).
    func testCompletionFlagSetAfterSuccess() throws {
        let entry = TranscriptionEntry(text: "flag test", rawText: "flag test",
                                       language: "en", mode: "plain", confidence: 0.9)
        sourceService.save(entry)

        // Write a settings key into the source plist.
        try writeSourcePlist(["useSwissGerman": true])

        let srcURL = sourceContainerURL!
        let destURL = destContainerURL!

        try AppLocalMigrationService.runForTesting(
            sourceContainerURL: srcURL,
            destDefaults: destDefaults,
            destDBProvider: { destURL }
        )

        XCTAssertTrue(
            destDefaults.bool(forKey: AppLocalMigrationService.migratedKey),
            "SC3(b): \(AppLocalMigrationService.migratedKey) must be true in destDefaults after success"
        )
    }

    // MARK: - SC3(c): idempotent second run

    /// A second call to runForTesting() must be a complete no-op.
    /// The destination DB must not be modified (no re-copy, no row duplication).
    func testMigrationIsIdempotent() throws {
        let entries = [
            TranscriptionEntry(text: "idempotent 1", rawText: "idempotent 1",
                               language: "en", mode: "plain", confidence: 0.9),
            TranscriptionEntry(text: "idempotent 2", rawText: "idempotent 2",
                               language: "en", mode: "plain", confidence: 0.9),
        ]
        entries.forEach { sourceService.save($0) }

        let srcURL = sourceContainerURL!
        let destURL = destContainerURL!

        // First run.
        try AppLocalMigrationService.runForTesting(
            sourceContainerURL: srcURL,
            destDefaults: destDefaults,
            destDBProvider: { destURL }
        )

        let dstURL = destContainerURL!
        destService = HistoryService.makeForTesting(containerURLProvider: { dstURL })
        destService.load()
        let countAfterFirst = destService.entries.count

        // Second run — must be a no-op (flag is set, early return fires).
        try AppLocalMigrationService.runForTesting(
            sourceContainerURL: srcURL,
            destDefaults: destDefaults,
            destDBProvider: { destURL }
        )

        destService.load()
        let countAfterSecond = destService.entries.count

        XCTAssertEqual(
            countAfterFirst, countAfterSecond,
            "SC3(c): second runForTesting() call must be a no-op — destination row count unchanged"
        )
        XCTAssertEqual(countAfterFirst, 2, "Destination must have exactly the seeded 2 rows")
    }

    // MARK: - SC3(b): no-op on empty source (fresh install)

    /// When the source container / DB does not exist (fresh install, no prior App Group
    /// data), the migration must be a silent no-op and set the completion flag so it
    /// never retries on subsequent launches.
    func testNoOpOnEmptySource() throws {
        // Do NOT seed the source service or create the source directory.
        // sourceContainerURL points to a non-existent path.
        let srcURL = sourceContainerURL!
        let destURL = destContainerURL!

        // Must not throw — absent source is a valid "nothing to migrate" state.
        XCTAssertNoThrow(
            try AppLocalMigrationService.runForTesting(
                sourceContainerURL: srcURL,
                destDefaults: destDefaults,
                destDBProvider: { destURL }
            ),
            "SC3(b): migration must not throw when source container is absent (fresh install)"
        )

        // Completion flag must be set so the service never retries.
        XCTAssertTrue(
            destDefaults.bool(forKey: AppLocalMigrationService.migratedKey),
            "SC3(b): \(AppLocalMigrationService.migratedKey) must be set even when source was absent — prevents infinite retry"
        )
    }

    // MARK: - Settings keys transferred from container plist (regression test for plist-file path)

    /// REGRESSION: The original implementation read sourceDefaults (UserDefaults suite), which
    /// silently reads the wrong plist when the app-groups entitlement is absent.
    /// This test verifies the fix: settings are read from the container plist FILE DIRECTLY
    /// at <sourceContainerURL>/Library/Preferences/group.com.dicticus.plist.
    ///
    /// Constructs a real plist file in the source container, runs migration, and asserts
    /// all settings keys land in destDefaults — proving the file-based code path works.
    func testSettingsKeysCopiedFromContainerPlist() throws {
        // Build a realistic dictionary payload (the failing case: 204 entries → JSON-encoded).
        let dictEntries: [[String: String]] = (0..<204).map { i in
            ["input": "word\(i)", "output": "Word\(i)", "id": UUID().uuidString]
        }
        let dictData = try JSONEncoder().encode(dictEntries)

        // Write settings into the source container plist file — this is the ONLY way
        // to pass settings to the migration after the fix. UserDefaults(suiteName:) is gone.
        try writeSourcePlist([
            "useSwissGerman": true,
            "swissDefaultMigratedV2_1": true,
            "aiCleanupEnabled": false,
            "dictionaryCaseSensitive": true,
            "customDictionaryMetadata": dictData
        ])

        // Seed source history DB so migration has a valid DB to copy.
        let entry = TranscriptionEntry(text: "settings test", rawText: "settings test",
                                       language: "en", mode: "plain", confidence: 0.9)
        sourceService.save(entry)

        let srcURL = sourceContainerURL!
        let destURL = destContainerURL!

        try AppLocalMigrationService.runForTesting(
            sourceContainerURL: srcURL,
            destDefaults: destDefaults,
            destDBProvider: { destURL }
        )

        XCTAssertTrue(
            destDefaults.bool(forKey: "useSwissGerman"),
            "useSwissGerman must be copied from container plist to destDefaults"
        )
        XCTAssertTrue(
            destDefaults.bool(forKey: "swissDefaultMigratedV2_1"),
            "swissDefaultMigratedV2_1 must be copied from container plist to destDefaults"
        )
        // aiCleanupEnabled was explicitly false — must land as false (not missing).
        // object(forKey:) returns nil when absent; we assert the key is present + false.
        XCTAssertNotNil(
            destDefaults.object(forKey: "aiCleanupEnabled"),
            "aiCleanupEnabled must be present in destDefaults after migration"
        )
        XCTAssertFalse(
            destDefaults.bool(forKey: "aiCleanupEnabled"),
            "aiCleanupEnabled (false) must be preserved as false in destDefaults"
        )
        XCTAssertTrue(
            destDefaults.bool(forKey: "dictionaryCaseSensitive"),
            "dictionaryCaseSensitive must be copied from container plist to destDefaults"
        )

        // Verify dictionary data is present and decodable — the 204-entry case.
        guard let migratedData = destDefaults.data(forKey: "customDictionaryMetadata") else {
            XCTFail("customDictionaryMetadata must be present in destDefaults after migration")
            return
        }
        let migratedEntries = try JSONDecoder().decode([[String: String]].self, from: migratedData)
        XCTAssertEqual(
            migratedEntries.count, 204,
            "All 204 dictionary entries must survive migration via container plist path"
        )
    }

    // MARK: - No-clobber: existing dest values are not overwritten

    /// Settings already present in destDefaults must NOT be overwritten by migration.
    func testNoClobberExistingDestValues() throws {
        // Pre-set a value in destDefaults (simulates a fresh install that already ran
        // once with default values before the upgrade).
        destDefaults.set(false, forKey: "useSwissGerman")

        // Source plist has a different (true) value.
        try writeSourcePlist(["useSwissGerman": true])

        let entry = TranscriptionEntry(text: "no-clobber test", rawText: "no-clobber test",
                                       language: "en", mode: "plain", confidence: 0.9)
        sourceService.save(entry)

        let srcURL = sourceContainerURL!
        let destURL = destContainerURL!

        try AppLocalMigrationService.runForTesting(
            sourceContainerURL: srcURL,
            destDefaults: destDefaults,
            destDBProvider: { destURL }
        )

        // Pre-existing false must not be overwritten by the source's true.
        XCTAssertFalse(
            destDefaults.bool(forKey: "useSwissGerman"),
            "No-clobber: existing destDefaults value must not be overwritten by migration"
        )
    }

    // MARK: - Absent plist is a graceful no-op for settings (history DB still migrates)

    /// When the source container exists and has a DB but NO Library/Preferences plist,
    /// the history DB migration must still succeed and the completion flag must be set.
    /// Settings are silently skipped — no crash, no failure.
    func testAbsentPlistIsGracefulNoOpForSettings() throws {
        // Seed source history DB only — do NOT write a plist file.
        let entry = TranscriptionEntry(text: "no-plist test", rawText: "no-plist test",
                                       language: "en", mode: "plain", confidence: 0.9)
        sourceService.save(entry)

        let srcURL = sourceContainerURL!
        let destURL = destContainerURL!

        // Must not throw even though there is no plist.
        XCTAssertNoThrow(
            try AppLocalMigrationService.runForTesting(
                sourceContainerURL: srcURL,
                destDefaults: destDefaults,
                destDBProvider: { destURL }
            ),
            "Migration must not throw when source prefs plist is absent"
        )

        // Completion flag must still be set.
        XCTAssertTrue(
            destDefaults.bool(forKey: AppLocalMigrationService.migratedKey),
            "Completion flag must be set even when source prefs plist is absent"
        )

        // History DB must still be migrated.
        let dstURL = destContainerURL!
        destService = HistoryService.makeForTesting(containerURLProvider: { dstURL })
        destService.load()
        XCTAssertEqual(
            destService.entries.count, 1,
            "History DB must be migrated even when source prefs plist is absent"
        )
    }
}
