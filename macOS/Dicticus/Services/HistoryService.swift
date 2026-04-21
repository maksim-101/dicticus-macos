import Foundation
import GRDB
import os.log

/// Metadata for a transcription history entry.
struct TranscriptionEntry: Identifiable, Codable, FetchableRecord, PersistableRecord {
    var id: Int64? // SQLite RowID
    var uuid: UUID
    var text: String
    var rawText: String
    var language: String
    var mode: String
    var createdAt: Date
    var confidence: Double

    /// Database column names.
    enum Columns: String, ColumnExpression {
        case id, uuid, text, rawText, language, mode, createdAt, confidence
    }

    /// GRDB requirement: Define the table name.
    /// nonisolated(unsafe) is needed for Swift 6 global shared state.
    nonisolated(unsafe) static var databaseTableName = "transcriptionEntry"

    /// Initialize a new entry from a transcription result.
    init(
        id: Int64? = nil,
        uuid: UUID = UUID(),
        text: String,
        rawText: String,
        language: String,
        mode: String,
        createdAt: Date = Date(),
        confidence: Double
    ) {
        self.id = id
        self.uuid = uuid
        self.text = text
        self.rawText = rawText
        self.language = language
        self.mode = mode
        self.createdAt = createdAt
        self.confidence = confidence
    }
}

/// Manages the transcription history database using GRDB and SQLite FTS5.
@MainActor
class HistoryService: ObservableObject {

    static let shared = HistoryService()
    
    private let dbQueue: DatabaseQueue
    private static let log = Logger(subsystem: "com.dicticus", category: "history")

    @Published private(set) var entries: [TranscriptionEntry] = []

    private init() {
        do {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let dbFolder = appSupport.appendingPathComponent("Dicticus", isDirectory: true)
            try FileManager.default.createDirectory(at: dbFolder, withIntermediateDirectories: true)
            
            let dbURL = dbFolder.appendingPathComponent("History.sqlite")
            self.dbQueue = try DatabaseQueue(path: dbURL.path)
            
            try migrate()
            load()
        } catch {
            Self.log.error("Failed to initialize database: \(error.localizedDescription)")
            fatalError("Failed to initialize History database")
        }
    }

    private func migrate() throws {
        var migrator = DatabaseMigrator()
        
        // Wipe old schema if it exists to fix the UUID/Integer ID conflict
        migrator.registerMigration("v2-setup") { db in
            try db.drop(table: "transcriptionEntry")
            try db.drop(table: "transcription_search")
            
            try db.create(table: "transcriptionEntry") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("uuid", .text).notNull().unique()
                t.column("text", .text).notNull()
                t.column("rawText", .text).notNull()
                t.column("language", .text).notNull()
                t.column("mode", .text).notNull()
                t.column("createdAt", .datetime).notNull().indexed()
                t.column("confidence", .double).notNull()
            }
            
            try db.execute(sql: """
                CREATE VIRTUAL TABLE transcription_search USING fts5(
                    text,
                    rawText,
                    content='transcriptionEntry',
                    content_rowid='id'
                )
                """)
                
            try db.execute(sql: """
                CREATE TRIGGER transcription_search_insert AFTER INSERT ON transcriptionEntry BEGIN
                    INSERT INTO transcription_search(rowid, text, rawText) VALUES (new.id, new.text, new.rawText);
                END;
                CREATE TRIGGER transcription_search_delete AFTER DELETE ON transcriptionEntry BEGIN
                    INSERT INTO transcription_search(transcription_search, rowid, text, rawText) VALUES('delete', old.id, old.text, old.rawText);
                END;
                CREATE TRIGGER transcription_search_update AFTER UPDATE ON transcriptionEntry BEGIN
                    INSERT INTO transcription_search(transcription_search, rowid, text, rawText) VALUES('delete', old.id, old.text, old.rawText);
                    INSERT INTO transcription_search(rowid, text, rawText) VALUES (new.id, new.text, new.rawText);
                END;
                """)
        }
        
        try migrator.migrate(dbQueue)
    }

    func load(query: String? = nil) {
        do {
            try dbQueue.read { db in
                if let query = query, !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    let sql = "SELECT * FROM transcriptionEntry WHERE id IN (SELECT rowid FROM transcription_search WHERE transcription_search MATCH ?) ORDER BY createdAt DESC"
                    self.entries = try TranscriptionEntry.fetchAll(db, sql: sql, arguments: [query])
                } else {
                    self.entries = try TranscriptionEntry.order(TranscriptionEntry.Columns.createdAt.desc).fetchAll(db)
                }
            }
        } catch {
            Self.log.error("Failed to load history: \(error.localizedDescription)")
        }
    }

    func save(_ entry: TranscriptionEntry) {
        do {
            let entryToSave = entry
            try dbQueue.write { db in
                try entryToSave.insert(db)
            }
            Self.log.info("Saved transcription to history: \(entry.text.prefix(20))...")
            load()
        } catch {
            Self.log.error("Failed to save entry: \(error.localizedDescription)")
        }
    }

    func delete(id: Int64) {
        do {
            _ = try dbQueue.write { db in
                try TranscriptionEntry.filter(key: id).deleteAll(db)
            }
            load()
        } catch {
            Self.log.error("Failed to delete entry: \(error.localizedDescription)")
        }
    }

    func clearAll() {
        do {
            _ = try dbQueue.write { db in
                try TranscriptionEntry.deleteAll(db)
            }
            load()
        } catch {
            Self.log.error("Failed to clear history: \(error.localizedDescription)")
        }
    }
}
