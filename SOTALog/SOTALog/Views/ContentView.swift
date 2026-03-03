import SwiftUI

struct ContentView: View {
    @Environment(\.appDatabase) private var database
    @State private var spotRouter = SpotRouter()
    @State private var spotsViewModel = SpotsViewModel()
    @State private var sotaCatService = SOTACatService()
    @State private var selectedTab = Tab.activations

    enum Tab {
        case activations, spots, tools
    }

    var body: some View {
        if let db = database {
            TabView(selection: $selectedTab) {
                LogListView(database: db)
                    .tabItem {
                        Label("Activations", systemImage: "list.bullet.rectangle")
                    }
                    .tag(Tab.activations)

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
            #if os(iOS)
            .toolbarBackground(Color.appBackground, for: .tabBar)
            #endif
            .environment(spotRouter)
            .environment(spotsViewModel)
            .environment(sotaCatService)
            .task { await spotsViewModel.startAutoRefresh() }
            .task { sotaCatService.startMonitoring() }
            .onChange(of: spotRouter.pendingSpot) { _, newValue in
                if let spot = newValue, sotaCatService.isConnected {
                    sotaCatService.tune(frequencyMHz: spot.frequency, mode: spot.mode)
                }
                if newValue != nil {
                    selectedTab = .activations
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
