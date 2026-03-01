import SwiftUI

struct ContentView: View {
    @Environment(\.appDatabase) private var database
    @State private var spotRouter = SpotRouter()
    @State private var spotsViewModel = SpotsViewModel()
    @State private var selectedTab = 0

    var body: some View {
        if let db = database {
            TabView(selection: $selectedTab) {
                LogListView(database: db)
                    .tabItem {
                        Label("Logs", systemImage: "list.bullet.rectangle")
                    }
                    .tag(0)

                SpotsView(database: db)
                    .tabItem {
                        Label("Spots", systemImage: "antenna.radiowaves.left.and.right")
                    }
                    .tag(1)

                QRZSyncView(database: db)
                    .tabItem {
                        Label("Sync", systemImage: "arrow.triangle.2.circlepath")
                    }
                    .tag(2)
            }
            .environment(spotRouter)
            .environment(spotsViewModel)
            .task { await spotsViewModel.startAutoRefresh() }
            .onChange(of: spotRouter.pendingSpot) { _, newValue in
                if newValue != nil {
                    selectedTab = 0
                }
            }
        }
    }
}
