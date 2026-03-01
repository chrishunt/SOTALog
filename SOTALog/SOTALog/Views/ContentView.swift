import SwiftUI

struct ContentView: View {
    @Environment(\.appDatabase) private var database
    @State private var spotRouter = SpotRouter()
    @State private var spotsViewModel = SpotsViewModel()
    @State private var selectedTab = Tab.logs

    enum Tab {
        case logs, spots, tools
    }

    var body: some View {
        if let db = database {
            TabView(selection: $selectedTab) {
                LogListView(database: db)
                    .tabItem {
                        Label("Logs", systemImage: "list.bullet.rectangle")
                    }
                    .tag(Tab.logs)

                SpotsView(database: db)
                    .tabItem {
                        Label("Spots", systemImage: "antenna.radiowaves.left.and.right")
                    }
                    .tag(Tab.spots)

                QRZSyncView(database: db)
                    .tabItem {
                        Label("Tools", systemImage: "wrench.and.screwdriver")
                    }
                    .tag(Tab.tools)
            }
            .environment(spotRouter)
            .environment(spotsViewModel)
            .task { await spotsViewModel.startAutoRefresh() }
            .onChange(of: spotRouter.pendingSpot) { _, newValue in
                if newValue != nil {
                    selectedTab = .logs
                }
            }
        } else {
            ContentUnavailableView(
                "Database Error",
                systemImage: "exclamationmark.triangle",
                description: Text("Unable to open the database. Try restarting the app.")
            )
        }
    }
}
