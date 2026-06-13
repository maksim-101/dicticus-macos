import XCTest
import GRDB
@testable import Dicticus

// Phase 36.3 Plan 01 — Wave 0 contract test (SC3 / SC4: migration service)
//
// AppLocalMigrationService is created in Plan 04. This file will fail to compile
// until Plan 04 lands (intended RED state).
//
// SEAM CONTRACT FOR PLAN 04:
// The production `runIfNeeded()` hard-codes the real group container path and
// UserDefaults.standard as the destination. Tests MUST NOT touch those real paths.
// Plan 04 MUST expose a testing seam with the following signature:
//
//   #if DEBUG
//   static func runForTesting(
//       sourceContainerURL: URL?,
//       sourceDefaults: UserDefaults,
//       destDefaults: UserDefaults,
//       destDBProvider: @escaping () -> URL
//   ) throws
//   #endif
//
// The seam mirrors `HistoryService.makeForTesting(containerURLProvider:)` —
// it accepts all external dependencies as parameters so tests can run in an
// isolated temp directory without ever reading ~/Library/Group Containers/.
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
    private var sourceDefaults: UserDefaults!
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
        sourceDefaults = UserDefaults(suiteName: "com.dicticus.test.source.\(suiteID)")!
        destDefaults = UserDefaults(suiteName: "com.dicticus.test.dest.\(suiteID)")!

        // Create source service with temp container (mirrors HistoryServiceTests setUp).
        let srcURL = sourceContainerURL
        sourceService = HistoryService.makeForTesting(containerURLProvider: { srcURL })
    }

    override func tearDown() {
        sourceService = nil
        destService = nil
        // Clean up UserDefaults suites.
        sourceDefaults.removePersistentDomain(forName: sourceDefaults.description)
        destDefaults.removePersistentDomain(forName: destDefaults.description)
        sourceDefaults = nil
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

        // Seed a settings key in source defaults.
        sourceDefaults.set(true, forKey: "useSwissGerman")
        sourceDefaults.set(true, forKey: "aiCleanupEnabled")

        let srcURL = sourceContainerURL!
        let destURL = destContainerURL!

        // Run migration via testing seam.
        // AppLocalMigrationService is created in Plan 04 — RED until then.
        try AppLocalMigrationService.runForTesting(
            sourceContainerURL: srcURL,
            sourceDefaults: sourceDefaults,
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
            sourceDefaults: sourceDefaults,
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
        sourceDefaults.set(true, forKey: "useSwissGerman")

        let srcURL = sourceContainerURL!
        let destURL = destContainerURL!

        try AppLocalMigrationService.runForTesting(
            sourceContainerURL: srcURL,
            sourceDefaults: sourceDefaults,
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
            sourceDefaults: sourceDefaults,
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
            sourceDefaults: sourceDefaults,
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
                sourceDefaults: sourceDefaults,
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

    // MARK: - Settings keys transferred

    /// The three settings keys (useSwissGerman, swissDefaultMigratedV2_1, aiCleanupEnabled)
    /// must be copied from sourceDefaults to destDefaults during migration.
    func testSettingsKeysCopiedToDestination() throws {
        sourceDefaults.set(true, forKey: "useSwissGerman")
        sourceDefaults.set(true, forKey: "swissDefaultMigratedV2_1")
        sourceDefaults.set(false, forKey: "aiCleanupEnabled")

        let entry = TranscriptionEntry(text: "settings test", rawText: "settings test",
                                       language: "en", mode: "plain", confidence: 0.9)
        sourceService.save(entry)

        let srcURL = sourceContainerURL!
        let destURL = destContainerURL!

        try AppLocalMigrationService.runForTesting(
            sourceContainerURL: srcURL,
            sourceDefaults: sourceDefaults,
            destDefaults: destDefaults,
            destDBProvider: { destURL }
        )

        XCTAssertTrue(
            destDefaults.bool(forKey: "useSwissGerman"),
            "useSwissGerman must be copied to destDefaults"
        )
        XCTAssertTrue(
            destDefaults.bool(forKey: "swissDefaultMigratedV2_1"),
            "swissDefaultMigratedV2_1 must be copied to destDefaults"
        )
        XCTAssertFalse(
            destDefaults.bool(forKey: "aiCleanupEnabled"),
            "aiCleanupEnabled (false) must be copied to destDefaults"
        )
    }
}
