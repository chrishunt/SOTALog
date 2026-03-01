import SwiftUI

struct SpotsView: View {
    let database: AppDatabase
    @Environment(SpotRouter.self) private var spotRouter
    @Environment(SpotsViewModel.self) private var viewModel

    var body: some View {
        @Bindable var viewModel = viewModel
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.spots.isEmpty {
                    ProgressView("Loading spots...")
                } else if viewModel.spots.isEmpty {
                    ContentUnavailableView(
                        "No Spots",
                        systemImage: "antenna.radiowaves.left.and.right",
                        description: Text("Pull to refresh or wait for CW activators.")
                    )
                } else {
                    List {
                        ForEach(viewModel.spotsByBand, id: \.band) { section in
                            Section {
                                ForEach(section.spots) { spot in
                                    Button {
                                        spotRouter.pendingSpot = spot
                                    } label: {
                                        SpotRowView(spot: spot)
                                            .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                }
                            } header: {
                                HStack {
                                    Text(section.band)
                                        .font(.title3.monospacedDigit().bold())
                                        .foregroundStyle(.primary)
                                    Text("\(section.spots.count)")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.top, 8)
                                .textCase(nil)
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
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
        }
    }
}
