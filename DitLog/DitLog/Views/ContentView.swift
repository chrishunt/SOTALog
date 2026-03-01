import SwiftUI

struct ContentView: View {
    @Environment(\.appDatabase) private var database

    var body: some View {
        if let db = database {
            TabView {
                LogListView(database: db)
                    .tabItem {
                        Label("Logs", systemImage: "list.bullet.rectangle")
                    }

                SpotsView(database: db)
                    .tabItem {
                        Label("Spots", systemImage: "antenna.radiowaves.left.and.right")
                    }

                QRZSyncView(database: db)
                    .tabItem {
                        Label("Sync", systemImage: "arrow.triangle.2.circlepath")
                    }
            }
        }
    }
}
