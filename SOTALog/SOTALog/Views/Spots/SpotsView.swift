import SwiftUI
import GRDB

struct SpotsView: View {
    let database: AppDatabase
    @Environment(SpotRouter.self) private var spotRouter
    @Environment(SpotsViewModel.self) private var viewModel
    @State private var workedKeys: Set<String> = []
    @State private var workedCancellable: AnyDatabaseCancellable?

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
                                        SpotRowView(spot: spot, isWorked: isWorked(spot))
                                            .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    .listRowBackground(Color.clear)
                                }
                            } header: {
                                HStack {
                                    Text(section.band.uppercased())
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
                    .scrollContentBackground(.hidden)
                    .background(Color.appBackground)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            #if os(iOS)
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            #endif
            .toolbar {
                ToolbarItem(placement: .principal) {
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
                let today = todayUTCDate()
                let repo = QSORepository(database: database)
                workedCancellable = repo.observeWorkedKeys(date: today, in: database.dbWriter) { keys in
                    workedKeys = keys
                }
            }
        }
    }

    private func isWorked(_ spot: Spot) -> Bool {
        let spotDate = spotUTCDate(spot.timestamp)
        let callsign = spot.activatorCallsign.uppercased()
        let band = spot.band

        if let potaRef = spot.potaReference {
            if workedKeys.contains("\(spotDate)|\(callsign)|\(potaRef)|\(band)") {
                return true
            }
        }
        if let sotaRef = spot.sotaReference {
            if workedKeys.contains("\(spotDate)|\(callsign)|\(sotaRef)|\(band)") {
                return true
            }
        }
        return false
    }

    private func todayUTCDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: Date())
    }

    private func spotUTCDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: date)
    }
}
