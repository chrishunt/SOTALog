import SwiftUI
import TipKit

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
        try? Tips.configure([.displayFrequency(.immediate)])
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.appDatabase, database)
        }
    }
}
