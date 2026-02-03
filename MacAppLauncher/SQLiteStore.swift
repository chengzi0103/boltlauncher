import Foundation
import SQLite3

private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

final class SQLiteStore {
    private let db: OpaquePointer?
    private let dateFormatter = ISO8601DateFormatter()

    init() {
        let url = Self.databaseURL()
        let folder = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        var handle: OpaquePointer?
        if sqlite3_open(url.path, &handle) != SQLITE_OK {
            db = nil
            return
        }
        db = handle
        _ = execute(sql: "PRAGMA foreign_keys = ON;")
        _ = execute(sql: """
        CREATE TABLE IF NOT EXISTS apps (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            bundle_id TEXT NOT NULL UNIQUE,
            name TEXT NOT NULL,
            path TEXT NOT NULL,
            key_code INTEGER NOT NULL,
            modifiers INTEGER NOT NULL,
            launch_count INTEGER NOT NULL DEFAULT 0,
            last_launched_at TEXT
        );
        """)
        _ = execute(sql: """
        CREATE TABLE IF NOT EXISTS launch_logs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            app_id INTEGER NOT NULL,
            launched_at TEXT NOT NULL,
            FOREIGN KEY(app_id) REFERENCES apps(id) ON DELETE CASCADE
        );
        """)
    }

    deinit {
        if let db {
            sqlite3_close(db)
        }
    }

    func fetchApps() -> [AppEntry] {
        guard let db else { return [] }
        let sql = """
        SELECT id, bundle_id, name, path, key_code, modifiers, launch_count, last_launched_at
        FROM apps
        ORDER BY name COLLATE NOCASE;
        """
        var statement: OpaquePointer?
        var results: [AppEntry] = []
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK, let statement {
            while sqlite3_step(statement) == SQLITE_ROW {
                let id = Int(sqlite3_column_int(statement, 0))
                let bundleId = stringColumn(statement, index: 1)
                let name = stringColumn(statement, index: 2)
                let path = stringColumn(statement, index: 3)
                let keyCode = Int(sqlite3_column_int(statement, 4))
                let modifiers = Int(sqlite3_column_int(statement, 5))
                let launchCount = Int(sqlite3_column_int(statement, 6))
                let lastLaunchedAt = dateColumn(statement, index: 7)
                results.append(
                    AppEntry(
                        id: id,
                        bundleId: bundleId,
                        name: name,
                        path: path,
                        hotkey: Hotkey(keyCode: keyCode, modifiers: modifiers),
                        launchCount: launchCount,
                        lastLaunchedAt: lastLaunchedAt
                    )
                )
            }
        }
        sqlite3_finalize(statement)
        return results
    }

    func upsertApp(bundleId: String, name: String, path: String) {
        guard let db else { return }
        let sql = """
        INSERT INTO apps (bundle_id, name, path, key_code, modifiers, launch_count)
        VALUES (?, ?, ?, -1, 0, 0)
        ON CONFLICT(bundle_id) DO UPDATE SET name = excluded.name, path = excluded.path;
        """
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK, let statement {
            sqlite3_bind_text(statement, 1, (bundleId as NSString).utf8String, -1, sqliteTransient)
            sqlite3_bind_text(statement, 2, (name as NSString).utf8String, -1, sqliteTransient)
            sqlite3_bind_text(statement, 3, (path as NSString).utf8String, -1, sqliteTransient)
            _ = sqlite3_step(statement)
        }
        sqlite3_finalize(statement)
    }

    func updateHotkey(appId: Int, hotkey: Hotkey) {
        guard let db else { return }
        let sql = "UPDATE apps SET key_code = ?, modifiers = ? WHERE id = ?;"
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK, let statement {
            sqlite3_bind_int(statement, 1, Int32(hotkey.keyCode))
            sqlite3_bind_int(statement, 2, Int32(hotkey.modifiers))
            sqlite3_bind_int(statement, 3, Int32(appId))
            _ = sqlite3_step(statement)
        }
        sqlite3_finalize(statement)
    }

    func removeApp(appId: Int) {
        guard let db else { return }
        let sql = "DELETE FROM apps WHERE id = ?;"
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK, let statement {
            sqlite3_bind_int(statement, 1, Int32(appId))
            _ = sqlite3_step(statement)
        }
        sqlite3_finalize(statement)
    }

    func logLaunch(appId: Int, at date: Date) {
        guard let db else { return }
        let timestamp = dateFormatter.string(from: date)

        let insertSQL = "INSERT INTO launch_logs (app_id, launched_at) VALUES (?, ?);"
        var insertStatement: OpaquePointer?
        if sqlite3_prepare_v2(db, insertSQL, -1, &insertStatement, nil) == SQLITE_OK,
           let insertStatement {
            sqlite3_bind_int(insertStatement, 1, Int32(appId))
            sqlite3_bind_text(insertStatement, 2, (timestamp as NSString).utf8String, -1, sqliteTransient)
            _ = sqlite3_step(insertStatement)
        }
        sqlite3_finalize(insertStatement)

        let updateSQL = "UPDATE apps SET launch_count = launch_count + 1, last_launched_at = ? WHERE id = ?;"
        var updateStatement: OpaquePointer?
        if sqlite3_prepare_v2(db, updateSQL, -1, &updateStatement, nil) == SQLITE_OK,
           let updateStatement {
            sqlite3_bind_text(updateStatement, 1, (timestamp as NSString).utf8String, -1, sqliteTransient)
            sqlite3_bind_int(updateStatement, 2, Int32(appId))
            _ = sqlite3_step(updateStatement)
        }
        sqlite3_finalize(updateStatement)
    }

    private func execute(sql: String) -> Bool {
        guard let db else { return false }
        return sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK
    }

    private func stringColumn(_ statement: OpaquePointer, index: Int32) -> String {
        if let cString = sqlite3_column_text(statement, index) {
            return String(cString: cString)
        }
        return ""
    }

    private func dateColumn(_ statement: OpaquePointer, index: Int32) -> Date? {
        guard let cString = sqlite3_column_text(statement, index) else { return nil }
        let value = String(cString: cString)
        return dateFormatter.date(from: value)
    }

    private static func databaseURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("MacAppLauncher").appendingPathComponent("launcher.sqlite")
    }
}
