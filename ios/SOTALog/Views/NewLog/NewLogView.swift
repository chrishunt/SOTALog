import SwiftUI

struct NewLogView: View {
    let database: AppDatabase
    let onCreated: (Log) -> Void

    @State private var viewModel: NewLogViewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: Field?

    private enum Field {
        case pota, sota
    }

    init(database: AppDatabase, onCreated: @escaping (Log) -> Void) {
        self.database = database
        self.onCreated = onCreated
        self._viewModel = State(initialValue: NewLogViewModel(database: database))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Station") {
                    TextField("My Callsign", text: $viewModel.myCallsign)
                        .textContentType(.none)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .font(.title2.monospaced())

                    HStack {
                        TextField("Grid Square", text: $viewModel.myGrid)
                            .textContentType(.none)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()

                        Button {
                            viewModel.requestLocation()
                        } label: {
                            Image(systemName: "location")
                        }
                    }
                }

                Section("POTA") {
                    if viewModel.hasPOTAData {
                        TextField("Park Reference (e.g. US-4431)", text: $viewModel.potaReference)
                            .textContentType(.none)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .focused($focusedField, equals: .pota)

                        if viewModel.showNearbyParks {
                            ForEach(viewModel.nearbyParks) { park in
                                Button {
                                    viewModel.selectPark(park)
                                    focusedField = nil
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "location")
                                            .foregroundStyle(Color.appGreen)
                                        VStack(alignment: .leading) {
                                            Text(park.reference)
                                                .font(.appCallsign)
                                                .foregroundStyle(Color.appTextPrimary)
                                            Text(park.name)
                                                .font(.appLabel)
                                                .foregroundStyle(Color.appTextSecondary)
                                        }
                                        Spacer()
                                        if let miles = viewModel.distanceMiles(to: park.latitude, longitude: park.longitude) {
                                            Text(String(format: "%.0f mi", miles))
                                                .font(.appDistanceLabel)
                                                .foregroundStyle(Color.appTextSecondary)
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        } else if !viewModel.parkSearchResults.isEmpty {
                            ForEach(viewModel.parkSearchResults) { park in
                                Button {
                                    viewModel.selectPark(park)
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "tree")
                                            .foregroundStyle(Color.appGreen)
                                        VStack(alignment: .leading) {
                                            Text(park.reference)
                                                .font(.appCallsign)
                                                .foregroundStyle(Color.appTextPrimary)
                                            Text(park.name)
                                                .font(.appLabel)
                                                .foregroundStyle(Color.appTextSecondary)
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        if let name = viewModel.parkName {
                            Text(name)
                                .foregroundStyle(Color.appTextSecondary)
                        }
                    } else {
                        ReferenceDownloadRow.potaParks(
                            database: database,
                            userLatitude: viewModel.userLatitude,
                            userLongitude: viewModel.userLongitude
                        ) {
                            viewModel.hasPOTAData = true
                        }
                    }
                }

                Section("SOTA") {
                    if viewModel.hasSOTAData {
                        TextField("Summit Reference (e.g. W4C/CM-001)", text: $viewModel.sotaReference)
                            .textContentType(.none)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .focused($focusedField, equals: .sota)

                        if viewModel.showNearbySummits {
                            ForEach(viewModel.nearbySummits) { summit in
                                Button {
                                    viewModel.selectSummit(summit)
                                    focusedField = nil
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "location")
                                            .foregroundStyle(Color.appBlue)
                                        VStack(alignment: .leading) {
                                            Text(summit.code)
                                                .font(.appCallsign)
                                                .foregroundStyle(Color.appTextPrimary)
                                            Text("\(summit.name) (\(summit.points ?? 0)pt)")
                                                .font(.appLabel)
                                                .foregroundStyle(Color.appTextSecondary)
                                        }
                                        Spacer()
                                        if let miles = viewModel.distanceMiles(to: summit.latitude, longitude: summit.longitude) {
                                            Text(String(format: "%.0f mi", miles))
                                                .font(.appDistanceLabel)
                                                .foregroundStyle(Color.appTextSecondary)
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        } else if !viewModel.summitSearchResults.isEmpty {
                            ForEach(viewModel.summitSearchResults) { summit in
                                Button {
                                    viewModel.selectSummit(summit)
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "mountain.2")
                                            .foregroundStyle(Color.appBlue)
                                        VStack(alignment: .leading) {
                                            Text(summit.code)
                                                .font(.appCallsign)
                                                .foregroundStyle(Color.appTextPrimary)
                                            Text("\(summit.name) (\(summit.points ?? 0)pt)")
                                                .font(.appLabel)
                                                .foregroundStyle(Color.appTextSecondary)
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        if let name = viewModel.summitName {
                            Text(name)
                                .foregroundStyle(Color.appTextSecondary)
                        }
                    } else {
                        ReferenceDownloadRow.sotaSummits(database: database) {
                            viewModel.hasSOTAData = true
                        }
                    }
                }
            }
            .task {
                await viewModel.checkReferenceData()
                await viewModel.loadNearbyReferences()
            }
            .onChange(of: focusedField) { _, newValue in
                viewModel.isPotaFieldFocused = newValue == .pota
                viewModel.isSotaFieldFocused = newValue == .sota
            }
            .navigationTitle("New Activation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Start") {
                        Task {
                            if let log = try? await viewModel.createLog() {
                                onCreated(log)
                            }
                        }
                    }
                    .disabled(!viewModel.canCreate)
                    .bold()
                }
            }
            .onAppear {
                viewModel.loadSavedCallsign()
            }
        }
    }
}
