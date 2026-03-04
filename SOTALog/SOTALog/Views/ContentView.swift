import SwiftUI

struct ContentView: View {
    @Environment(\.appDatabase) private var database
    @State private var spotRouter = SpotRouter()
    @State private var spotsViewModel = SpotsViewModel()
    @State private var sotaCatService = SOTACatService()
    @State private var selectedTab = Tab.activations

    enum Tab {
        case activations, settings
    }

    var body: some View {
        if let db = database {
            TabView(selection: $selectedTab) {
                LogListView(database: db)
                    .tabItem {
                        Label("Activations", systemImage: "mountain.2.fill")
                    }
                    .tag(Tab.activations)

                QRZSyncView(database: db)
                    .tabItem {
                        Label("Settings", systemImage: "gearshape")
                    }
                    .tag(Tab.settings)
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
