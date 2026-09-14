import Foundation
import SwiftUI
import HamCore

extension AppDatabase {
    /// The app's database in Application Support/SOTALog/db.sqlite.
    static func shared() throws -> AppDatabase {
        let appSupportURL = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directoryURL = appSupportURL.appendingPathComponent("SOTALog", isDirectory: true)
        return try AppDatabase.onDisk(at: directoryURL.appendingPathComponent("db.sqlite"))
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
