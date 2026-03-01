import SwiftUI

@main
struct FieldLogApp: App {
    let database: AppDatabase

    init() {
        do {
            database = try AppDatabase.shared()
        } catch {
            fatalError("Database setup failed: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.appDatabase, database)
        }
    }
}
