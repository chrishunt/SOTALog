import SwiftUI

struct SpotsView: View {
    let database: AppDatabase
    @State private var viewModel: SpotsViewModel

    init(database: AppDatabase) {
        self.database = database
        self._viewModel = State(initialValue: SpotsViewModel())
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.spots.isEmpty {
                    ProgressView("Loading spots...")
                } else if viewModel.spots.isEmpty {
                    ContentUnavailableView(
                        "No CW Spots",
                        systemImage: "antenna.radiowaves.left.and.right",
                        description: Text("Pull to refresh or wait for CW activators.")
                    )
                } else {
                    List {
                        ForEach(viewModel.spotsByBand, id: \.band) { section in
                            Section(section.band) {
                                ForEach(section.spots) { spot in
                                    SpotRowView(spot: spot)
                                        .listRowBackground(spotBackground(spot))
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("CW Spots")
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Picker("Source", selection: $viewModel.sourceFilter) {
                        Text("All").tag(SpotsViewModel.SourceFilter.all)
                        Text("POTA").tag(SpotsViewModel.SourceFilter.pota)
                        Text("SOTA").tag(SpotsViewModel.SourceFilter.sota)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 180)
                }
            }
            .refreshable {
                await viewModel.refresh()
            }
            .task {
                await viewModel.startAutoRefresh()
            }
        }
    }

    private func spotBackground(_ spot: Spot) -> Color {
        if spot.isQRT { return Color.red.opacity(0.05) }
        if spot.isExpired() { return Color.gray.opacity(0.1) }
        return .clear
    }
}
