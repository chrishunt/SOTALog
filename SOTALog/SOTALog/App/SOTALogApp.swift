import SwiftUI

@main
struct SOTALogApp: App {
    let database: AppDatabase?

    init() {
        do {
            database = try AppDatabase.shared()
        } catch {
            database = nil
            AppLog.database.error("Database setup failed: \(error.localizedDescription)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.appDatabase, database)
        }
    }
}
