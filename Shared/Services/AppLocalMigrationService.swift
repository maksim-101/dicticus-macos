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
///
/// NOTE: Full implementation is in Plan 04. This stub exposes the type and
/// required seam so AppLocalMigrationServiceTests.swift compiles (RED state).
public enum AppLocalMigrationService {
    static let migratedKey = "appLocalMigrationV1_Completed"
    private static let log = Logger(subsystem: "com.dicticus", category: "AppLocalMigration")

    public static func runIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: migratedKey) else { return }
        // Full migration body implemented in Plan 04.
        UserDefaults.standard.set(true, forKey: migratedKey)
    }

    #if DEBUG
    /// Test seam. Plan 04 provides the full implementation.
    public static func runForTesting(
        sourceContainerURL: URL?,
        sourceDefaults: UserDefaults,
        destDefaults: UserDefaults,
        destDBProvider: @escaping () -> URL
    ) throws {
        // Stub: no-op until Plan 04.
        // Set the flag so idempotency tests pass the guard check.
        destDefaults.set(true, forKey: migratedKey)
    }
    #endif
}
#endif
