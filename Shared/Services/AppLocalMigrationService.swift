import Foundation
import GRDB
import os.log

#if os(macOS)
/// One-time migration moving history DB + dictionary + settings
/// from the App Group container to per-app storage.
/// Idempotency contract: gated by `appLocalMigrationV1_Completed` flag in
/// UserDefaults.standard. After first run, subsequent calls are no-ops.
/// Called from macOS/Dicticus/DicticusApp.swift BEFORE SwissDefaultMigration
/// and before any service initialization.
public enum AppLocalMigrationService {
    static let migratedKey = "appLocalMigrationV1_Completed"
    private static let log = Logger(subsystem: "com.dicticus", category: "AppLocalMigration")

    // MARK: - Production Entry Point

    public static func runIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: migratedKey) else { return }

        // Resolve the group container source. The binary ships WITHOUT the entitlement,
        // but users who previously had it retain TCC consent, making the path accessible.
        // Both methods are tried; if both fail, the migration is a graceful no-op.
        let sourceContainer: URL? = {
            if let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.dicticus"),
               FileManager.default.fileExists(atPath: url.path) {
                return url
            }
            // Fallback: direct raw path (works when TCC consent exists but API returns nil)
            let rawPath = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Group Containers/group.com.dicticus")
            if FileManager.default.fileExists(atPath: rawPath.path) {
                return rawPath
            }
            return nil
        }()

        let destContainer: URL = {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let bundleID = Bundle.main.bundleIdentifier ?? "com.dicticus.app"
            return appSupport.appendingPathComponent(bundleID, isDirectory: true)
        }()

        do {
            try migrate(
                sourceContainerURL: sourceContainer,
                sourceDefaults: sourceContainer != nil ? UserDefaults(suiteName: "group.com.dicticus") ?? .standard : .standard,
                destDefaults: .standard,
                destDBProvider: { destContainer }
            )
        } catch {
            // Migration failure is non-fatal. Log and set the flag so we never retry
            // forever — the app continues with whatever app-local store exists.
            log.error("[AppLocalMigration] FAILED — \(error.localizedDescription). App will use existing app-local store.")
            UserDefaults.standard.set(true, forKey: migratedKey)
        }
    }

    // MARK: - Core Migration Logic

    /// Shared implementation used by both `runIfNeeded()` (production) and
    /// `runForTesting(...)` (test seam). All external dependencies are injected.
    private static func migrate(
        sourceContainerURL: URL?,
        sourceDefaults: UserDefaults,
        destDefaults: UserDefaults,
        destDBProvider: () -> URL
    ) throws {
        // Idempotency gate — reads destDefaults (UserDefaults.standard in production).
        guard !destDefaults.bool(forKey: migratedKey) else { return }

        let destContainerURL = destDBProvider()
        let destDBDir = destContainerURL.appendingPathComponent("Database", isDirectory: true)
        let destDBURL = destDBDir.appendingPathComponent("History.sqlite")

        // Validate source DB presence.
        guard let srcContainer = sourceContainerURL else {
            // Fresh install — no group container exists. Set flag and return.
            log.info("[AppLocalMigration] Source container absent — fresh install or TCC expired. Marking complete.")
            destDefaults.set(true, forKey: migratedKey)
            return
        }

        let srcDBDir = srcContainer.appendingPathComponent("Database", isDirectory: true)
        let srcDBURL = srcDBDir.appendingPathComponent("History.sqlite")

        guard FileManager.default.fileExists(atPath: srcDBURL.path) else {
            // Source container exists but no DB in it — treat as fresh install.
            log.info("[AppLocalMigration] Source DB absent — marking complete without migration.")
            destDefaults.set(true, forKey: migratedKey)
            return
        }

        // STEP 1: Create backup of source DB files before any writes.
        let ts = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let backupDir = destContainerURL
            .appendingPathComponent("Backups", isDirectory: true)
            .appendingPathComponent("pre-migration-\(ts)", isDirectory: true)
        try FileManager.default.createDirectory(at: backupDir, withIntermediateDirectories: true)

        // Copy source DB sidecar files to backup (raw copy is safe for backup purposes only).
        let sidecarSuffixes = ["", "-wal", "-shm"]
        for suffix in sidecarSuffixes {
            let srcFile = srcDBDir.appendingPathComponent("History.sqlite\(suffix)")
            if FileManager.default.fileExists(atPath: srcFile.path) {
                let backupFile = backupDir.appendingPathComponent("History.sqlite\(suffix)")
                try FileManager.default.copyItem(at: srcFile, to: backupFile)
            }
        }
        log.info("[AppLocalMigration] Backup created at \(backupDir.path)")

        // STEP 2: Migrate history DB via GRDB online backup API (WAL-safe).
        try FileManager.default.createDirectory(at: destDBDir, withIntermediateDirectories: true)
        let sourceCount: Int = try {
            let sourcePool = try DatabasePool(path: srcDBURL.path)
            let destQueue = try DatabaseQueue(path: destDBURL.path)
            try sourcePool.backup(to: destQueue)
            return try sourcePool.read { db in
                try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM transcriptionEntry") ?? 0
            }
        }()

        // STEP 3: Verify destination DB is readable and row count matches.
        let destCount: Int = try {
            let destPool = try DatabasePool(path: destDBURL.path)
            return try destPool.read { db in
                try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM transcriptionEntry") ?? 0
            }
        }()

        guard destCount == sourceCount else {
            throw MigrationError.rowCountMismatch(source: sourceCount, dest: destCount)
        }

        // STEP 4: Migrate dictionary and settings keys (do not clobber existing dest values).
        let settingsKeys = ["customDictionaryMetadata", "dictionaryCaseSensitive",
                            "useSwissGerman", "swissDefaultMigratedV2_1", "aiCleanupEnabled"]
        for key in settingsKeys {
            if destDefaults.object(forKey: key) == nil,
               let value = sourceDefaults.object(forKey: key) {
                destDefaults.set(value, forKey: key)
            }
        }

        // STEP 5: Verify dictionary is decodable if present.
        if let dictData = destDefaults.data(forKey: "customDictionaryMetadata") {
            let decoder = JSONDecoder()
            // Attempt decode as array of basic dictionaries — if it throws, log but continue.
            if (try? decoder.decode([[String: String]].self, from: dictData)) == nil &&
               (try? decoder.decode([String: String].self, from: dictData)) == nil {
                log.warning("[AppLocalMigration] Dictionary data present but not decodable as expected type — migration continues.")
            }
        }

        // Determine dictionary entry count for logging.
        let dictEntryCount: Int
        if let dictData = destDefaults.data(forKey: "customDictionaryMetadata"),
           let arr = try? JSONDecoder().decode([[String: String]].self, from: dictData) {
            dictEntryCount = arr.count
        } else {
            dictEntryCount = 0
        }

        // STEP 6: Write completion flag LAST — only after all assets verified.
        destDefaults.set(true, forKey: migratedKey)
        log.info("[AppLocalMigration] COMPLETE — migrated \(destCount) history entries, \(dictEntryCount) dictionary entries")
    }

    // MARK: - Errors

    private enum MigrationError: Error {
        case rowCountMismatch(source: Int, dest: Int)
    }

    // MARK: - Test Seam

    #if DEBUG
    /// Runs the migration with fully injected source and destination dependencies.
    /// Tests use this to avoid ever touching the real group container or
    /// UserDefaults.standard.
    ///
    /// - Parameter sourceContainerURL: Root of the source container directory.
    ///   The DB is expected at `<sourceContainerURL>/Database/History.sqlite`.
    ///   Pass nil or a non-existent URL to simulate a fresh install.
    /// - Parameter sourceDefaults: UserDefaults suite for source settings keys.
    /// - Parameter destDefaults: UserDefaults suite for destination (receives the
    ///   migration-complete flag and migrated settings).
    /// - Parameter destDBProvider: Closure returning the root of the destination
    ///   container. The DB will be written to `<result>/Database/History.sqlite`.
    public static func runForTesting(
        sourceContainerURL: URL?,
        sourceDefaults: UserDefaults,
        destDefaults: UserDefaults,
        destDBProvider: @escaping () -> URL
    ) throws {
        try migrate(
            sourceContainerURL: sourceContainerURL,
            sourceDefaults: sourceDefaults,
            destDefaults: destDefaults,
            destDBProvider: destDBProvider
        )
    }
    #endif
}
#endif
