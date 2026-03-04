import SwiftUI
import GRDB

struct SpotsSheetView: View {
    let database: AppDatabase
    @Environment(\.dismiss) private var dismiss
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
                        description: Text("Pull to refresh or wait for activators.")
                    )
                } else {
                    List {
                        ForEach(viewModel.spotsByBand, id: \.band) { section in
                            Section {
                                ForEach(section.spots) { spot in
                                    Button {
                                        spotRouter.pendingSpot = spot
                                        dismiss()
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
                                        .font(.appSectionHeader)
                                        .foregroundStyle(Color.appTextPrimary)
                                    Text("\(section.spots.count)")
                                        .font(.subheadline)
                                        .foregroundStyle(Color.appTextSecondary)
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
            .safeAreaInset(edge: .top) {
                HStack(spacing: 8) {
                    Picker("Source", selection: $viewModel.sourceFilter) {
                        Text("All").tag(SpotsViewModel.SourceFilter.all)
                        Text("POTA").tag(SpotsViewModel.SourceFilter.pota)
                        Text("SOTA").tag(SpotsViewModel.SourceFilter.sota)
                    }
                    .pickerStyle(.segmented)

                    Picker("Mode", selection: $viewModel.modeFilter) {
                        Text("All").tag(SpotsViewModel.ModeFilter.all)
                        Text("CW").tag(SpotsViewModel.ModeFilter.cw)
                        Text("SSB").tag(SpotsViewModel.ModeFilter.ssb)
                    }
                    .pickerStyle(.segmented)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color.appBackground)
            }
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
                #endif
            }
            .refreshable {
                await viewModel.refresh()
            }
            .onChange(of: viewModel.sourceFilter) { _, newValue in
                UserDefaults.standard.set(newValue.rawValue, forKey: "sourceFilter")
            }
            .onChange(of: viewModel.modeFilter) { _, newValue in
                UserDefaults.standard.set(newValue.rawValue, forKey: "modeFilter")
            }
            .task {
                let today = todayUTCDate()
                let repo = QSORepository(database: database)
                workedCancellable = repo.observeWorkedKeys(date: today, in: database.dbWriter) { keys in
                    workedKeys = keys
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationContentInteraction(.scrolls)
    }

    private func isWorked(_ spot: Spot) -> Bool {
        let spotDate = spotUTCDate(spot.timestamp)
        let callsign = spot.activatorCallsign.uppercased()
        let band = spot.band
        let mode = spot.mode

        if let potaRef = spot.potaReference {
            if workedKeys.contains("\(spotDate)|\(callsign)|\(potaRef)|\(band)|\(mode)") {
                return true
            }
        }
        if let sotaRef = spot.sotaReference {
            if workedKeys.contains("\(spotDate)|\(callsign)|\(sotaRef)|\(band)|\(mode)") {
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
