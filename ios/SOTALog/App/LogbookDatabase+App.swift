import Foundation
import SwiftUI
import HamCore

extension LogbookDatabase {
    /// The app's database in Application Support/SOTALog/db.sqlite. Debug
    /// builds rebuild it when a migration changes rather than failing.
    static func shared() throws -> LogbookDatabase {
        let appSupportURL = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directoryURL = appSupportURL.appendingPathComponent("SOTALog", isDirectory: true)
        #if DEBUG
        let eraseOnSchemaChange = true
        #else
        let eraseOnSchemaChange = false
        #endif
        return try LogbookDatabase.onDisk(
            at: directoryURL.appendingPathComponent("db.sqlite"),
            eraseOnSchemaChange: eraseOnSchemaChange)
    }
}

// MARK: - SwiftUI Environment

private struct LogbookDatabaseKey: EnvironmentKey {
    static var defaultValue: LogbookDatabase?
}

extension EnvironmentValues {
    var appDatabase: LogbookDatabase? {
        get { self[LogbookDatabaseKey.self] }
        set { self[LogbookDatabaseKey.self] = newValue }
    }
}
