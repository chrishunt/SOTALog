import Foundation
import SwiftUI
import GRDB

struct AppDatabase {
    let dbWriter: any DatabaseWriter

    init(_ dbWriter: any DatabaseWriter) throws {
        self.dbWriter = dbWriter
        try migrator.migrate(dbWriter)
    }

    private var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()

        #if DEBUG
        migrator.eraseDatabaseOnSchemaChange = true
        #endif

        migrator.registerMigration("v1") { db in
            try db.create(table: "log") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("createdAt", .datetime).defaults(sql: "CURRENT_TIMESTAMP")
                t.column("date", .text).notNull()
                t.column("myCallsign", .text).notNull()
                t.column("myGrid", .text)
                t.column("potaReference", .text)
                t.column("sotaReference", .text)
                t.column("parkName", .text)
                t.column("summitName", .text)
                t.column("notes", .text)
                t.column("isActive", .boolean).notNull().defaults(to: false)
            }

            try db.create(table: "qso") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("logId", .integer).notNull()
                    .references("log", onDelete: .cascade)
                t.column("callsign", .text).notNull()
                t.column("date", .text).notNull()
                t.column("timeOn", .text).notNull()
                t.column("frequency", .double)
                t.column("band", .text).notNull()
                t.column("mode", .text).notNull().defaults(to: "CW")
                t.column("rstSent", .text).notNull().defaults(to: "599")
                t.column("rstReceived", .text).notNull().defaults(to: "599")
                t.column("name", .text)
                t.column("qth", .text)
                t.column("grid", .text)
                t.column("sotaRef", .text)
                t.column("potaRef", .text)
                t.column("notes", .text)
                t.column("qrzLogId", .integer)
                t.column("syncedToQRZ", .boolean).notNull().defaults(to: false)
            }

            try db.create(index: "qso_logId", on: "qso", columns: ["logId"])
            try db.create(index: "qso_callsign", on: "qso", columns: ["callsign"])
            try db.create(index: "qso_syncedToQRZ", on: "qso", columns: ["syncedToQRZ"])

            try db.create(table: "callsignHistory") { t in
                t.primaryKey("callsign", .text)
                t.column("name", .text)
                t.column("qth", .text)
                t.column("grid", .text)
                t.column("lastWorked", .datetime)
                t.column("timesWorked", .integer).notNull().defaults(to: 0)
            }

            try db.create(table: "potaPark") { t in
                t.primaryKey("reference", .text)
                t.column("name", .text).notNull()
                t.column("locationCode", .text).notNull()
                t.column("grid4", .text)
                t.column("grid6", .text)
                t.column("latitude", .double)
                t.column("longitude", .double)
                t.column("active", .boolean)
            }

            try db.create(table: "sotaSummit") { t in
                t.primaryKey("code", .text)
                t.column("codeNormalized", .text)
                t.column("name", .text).notNull()
                t.column("associationCode", .text)
                t.column("regionCode", .text)
                t.column("altitude", .integer)
                t.column("points", .integer)
                t.column("grid", .text)
                t.column("latitude", .double)
                t.column("longitude", .double)
                t.column("validFrom", .text)
                t.column("validTo", .text)
            }

            try db.create(index: "sotaSummit_codeNormalized", on: "sotaSummit", columns: ["codeNormalized"])

            try db.create(table: "referenceMetadata") { t in
                t.primaryKey("key", .text)
                t.column("lastRefreshed", .datetime)
                t.column("recordCount", .integer)
            }
        }

        return migrator
    }

    /// Creates a shared on-disk database
    static func shared() throws -> AppDatabase {
        let fileManager = FileManager.default
        let appSupportURL = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directoryURL = appSupportURL.appendingPathComponent("FieldLog", isDirectory: true)
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let databaseURL = directoryURL.appendingPathComponent("db.sqlite")
        let dbPool = try DatabasePool(path: databaseURL.path)
        return try AppDatabase(dbPool)
    }

    /// Creates an in-memory database for testing
    static func empty() throws -> AppDatabase {
        let dbQueue = try DatabaseQueue(configuration: .init())
        return try AppDatabase(dbQueue)
    }
}

// MARK: - SwiftUI Environment

private struct AppDatabaseKey: EnvironmentKey {
    static var defaultValue: AppDatabase?
}

extension EnvironmentValues {
    var appDatabase: AppDatabase? {
        get { self[AppDatabaseKey.self] }
        set { self[AppDatabaseKey.self] = newValue }
    }
}
