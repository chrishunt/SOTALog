import SwiftUI

struct NewLogView: View {
    let database: AppDatabase
    let onCreated: (Log) -> Void

    @State private var viewModel: NewLogViewModel
    @Environment(\.dismiss) private var dismiss

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
                    TextField("Park Reference (e.g. US-4431)", text: $viewModel.potaReference)
                        .textContentType(.none)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()

                    if !viewModel.parkSearchResults.isEmpty {
                        ForEach(viewModel.parkSearchResults) { park in
                            Button {
                                viewModel.selectPark(park)
                            } label: {
                                VStack(alignment: .leading) {
                                    Text(park.reference)
                                        .font(.headline.monospaced())
                                    Text(park.name)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }

                    if let name = viewModel.parkName {
                        Text(name)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("SOTA") {
                    TextField("Summit Reference (e.g. W4C/CM-001)", text: $viewModel.sotaReference)
                        .textContentType(.none)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()

                    if !viewModel.summitSearchResults.isEmpty {
                        ForEach(viewModel.summitSearchResults) { summit in
                            Button {
                                viewModel.selectSummit(summit)
                            } label: {
                                VStack(alignment: .leading) {
                                    Text(summit.code)
                                        .font(.headline.monospaced())
                                    Text("\(summit.name) (\(summit.points ?? 0)pt)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }

                    if let name = viewModel.summitName {
                        Text(name)
                            .foregroundStyle(.secondary)
                    }
                }
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
                    .disabled(viewModel.myCallsign.isEmpty)
                    .bold()
                }
            }
            .onAppear {
                viewModel.loadSavedCallsign()
            }
        }
    }
}
