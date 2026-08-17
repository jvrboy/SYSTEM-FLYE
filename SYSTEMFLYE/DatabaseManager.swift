import Foundation
import SQLite3
import Combine

enum DatabaseError: LocalizedError {
    case connectionFailed
    case migrationFailed(Error)
    case queryFailed(Error)
    case recordNotFound
    case constraintViolation

    var errorDescription: String? {
        switch self {
        case .connectionFailed: return "Database connection failed."
        case .migrationFailed(let error): return "Migration error: \\(error.localizedDescription)"
        case .queryFailed(let error): return "Query error: \\(error.localizedDescription)"
        case .recordNotFound: return "Record not found."
        case .constraintViolation: return "Constraint violation."
        }
    }
}

@MainActor
final class DatabaseManager: ObservableObject {
    static let shared = DatabaseManager()
    @Published private(set) var isReady = false
    @Published private(set) var recordCounts: [String: Int] = [:]

    private var db: OpaquePointer?
    private let databaseName = "systemflye.db"
    private let schemaVersion = 3
    private let queue = DispatchQueue(label: "database.queue", qos: .utility, attributes: .concurrent)

    private init() {}

    func open() throws {
        guard db == nil else { return }
        let paths = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let folder = paths[0].appendingPathComponent("SYSTEMFLYE", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let dbPath = folder.appendingPathComponent(databaseName).path
        if sqlite3_open(dbPath, &db) != SQLITE_OK { throw DatabaseError.connectionFailed }
        try migrate()
        isReady = true
    }

    func close() {
        if let db = db { sqlite3_close(db); self.db = nil }
    }

    func execute(_ sql: String, parameters: [String: Any] = [:]) throws -> Int64 {
        guard let db = db else { throw DatabaseError.connectionFailed }
        var stmt: OpaquePointer?
        defer { if let stmt = stmt { sqlite3_finalize(stmt) } }
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { throw DatabaseError.queryFailed(NSError(domain: "sqlite", code: 1)) }
        for (key, value) in parameters {
            let index = sqlite3_bind_parameter_index(stmt, ":\\\(key)")
            if index == 0 { continue }
            switch value {
            case let v as Int: sqlite3_bind_int64(stmt, index, Int64(v))
            case let v as Int64: sqlite3_bind_int64(stmt, index, v)
            case let v as Double: sqlite3_bind_double(stmt, index, v)
            case let v as String: sqlite3_bind_text(stmt, index, v, -1, nil)
            case let v as Data: sqlite3_bind_blob(stmt, index, (v as NSData).bytes, Int32(v.count), nil)
            case let v as Bool: sqlite3_bind_int(stmt, index, v ? 1 : 0)
            case nil: sqlite3_bind_null(stmt, index)
            default: break
            }
        }
        guard sqlite3_step(stmt) == SQLITE_DONE else { throw DatabaseError.queryFailed(NSError(domain: "sqlite", code: 2)) }
        return sqlite3_changes(db)
    }

    func query<T: Decodable>(_ sql: String, parameters: [String: Any] = [:], rowMapper: @escaping (SQLiteRow) throws -> T) throws -> [T] {
        guard let db = db else { throw DatabaseError.connectionFailed }
        var stmt: OpaquePointer?
        defer { if let stmt = stmt { sqlite3_finalize(stmt) } }
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { throw DatabaseError.queryFailed(NSError(domain: "sqlite", code: 3)) }
        for (key, value) in parameters {
            let index = sqlite3_bind_parameter_index(stmt, ":\\\(key)")
            if index == 0 { continue }
            switch value {
            case let v as Int: sqlite3_bind_int64(stmt, index, Int64(v))
            case let v as Int64: sqlite3_bind_int64(stmt, index, v)
            case let v as Double: sqlite3_bind_double(stmt, index, v)
            case let v as String: sqlite3_bind_text(stmt, index, v, -1, nil)
            case let v as Data: sqlite3_bind_blob(stmt, index, (v as NSData).bytes, Int32(v.count), nil)
            case let v as Bool: sqlite3_bind_int(stmt, index, v ? 1 : 0)
            case nil: sqlite3_bind_null(stmt, index)
            default: break
            }
        }
        var results: [T] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let row = SQLiteRow(stmt: stmt!)
            results.append(try rowMapper(row))
        }
        return results
    }

    func transaction(_ block: () throws -> Void) throws {
        try execute("BEGIN TRANSACTION")
        do {
            try block()
            try execute("COMMIT")
        } catch {
            try execute("ROLLBACK")
            throw error
        }
    }

    private func migrate() throws {
        let currentVersion = try? execute("PRAGMA user_version").description
        let existingVersion = Int(currentVersion ?? "0") ?? 0
        if existingVersion < schemaVersion {
            try execute("CREATE TABLE IF NOT EXISTS migrations (version INTEGER PRIMARY KEY, applied_at TEXT)")
            for version in (existingVersion + 1)...schemaVersion {
                try applyMigration(version: version)
                try execute("INSERT OR REPLACE INTO migrations (version, applied_at) VALUES (:\\(version), '\\(ISO8601DateFormatter().string(from: Date()))')")
            }
            try execute("PRAGMA user_version = \\(schemaVersion)")
        }
    }

    private func applyMigration(version: Int) throws {
        switch version {
        case 1:
            try execute("""
                CREATE TABLE IF NOT EXISTS settings (
                    key TEXT PRIMARY KEY,
                    value TEXT NOT NULL,
                    updated_at TEXT NOT NULL
                );
                CREATE TABLE IF NOT EXISTS price_history (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    pair TEXT NOT NULL,
                    timestamp REAL NOT NULL,
                    open REAL NOT NULL,
                    high REAL NOT NULL,
                    low REAL NOT NULL,
                    close REAL NOT NULL,
                    volume INTEGER NOT NULL
                );
                CREATE INDEX idx_price_pair_time ON price_history(pair, timestamp);
            """)
        case 2:
            try execute("""
                CREATE TABLE IF NOT EXISTS trade_journal (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    pair TEXT NOT NULL,
                    direction TEXT NOT NULL,
                    entry REAL NOT NULL,
                    exit REAL,
                    quantity REAL NOT NULL,
                    pnl REAL,
                    notes TEXT,
                    opened_at TEXT NOT NULL,
                    closed_at TEXT
                );
                CREATE TABLE IF NOT EXISTS signals (
                    id TEXT PRIMARY KEY,
                    pair TEXT NOT NULL,
                    type TEXT NOT NULL,
                    confidence REAL NOT NULL,
                    data TEXT NOT NULL,
                    created_at TEXT NOT NULL
                );
            """)
        case 3:
            try execute("""
                CREATE TABLE IF NOT EXISTS model_checkpoints (
                    id TEXT PRIMARY KEY,
                    model_name TEXT NOT NULL,
                    epoch INTEGER NOT NULL,
                    weights BLOB NOT NULL,
                    metadata TEXT,
                    created_at TEXT NOT NULL
                );
                CREATE TABLE IF NOT EXISTS audio_projects (
                    id TEXT PRIMARY KEY,
                    name TEXT NOT NULL,
                    project_data TEXT NOT NULL,
                    updated_at TEXT NOT NULL
                );
            """)
        default: break
        }
    }
}

struct SQLiteRow {
    let stmt: OpaquePointer

    func string(at index: Int32) -> String? {
        guard let text = sqlite3_column_text(stmt, index) else { return nil }
        return String(cString: text)
    }

    func int(at index: Int32) -> Int64? {
        guard sqlite3_column_type(stmt, index) != SQLITE_NULL else { return nil }
        return sqlite3_column_int64(stmt, index)
    }

    func double(at index: Int32) -> Double? {
        guard sqlite3_column_type(stmt, index) != SQLITE_NULL else { return nil }
        return sqlite3_column_double(stmt, index)
    }

    func data(at index: Int32) -> Data? {
        guard let bytes = sqlite3_column_blob(stmt, index) else { return nil }
        let count = sqlite3_column_bytes(stmt, index)
        return Data(bytes: bytes, count: Int(count))
    }

    func bool(at index: Int32) -> Bool? {
        guard let value = int(at: index) else { return nil }
        return value != 0
    }
}
