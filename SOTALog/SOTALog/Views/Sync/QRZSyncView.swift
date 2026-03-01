import SwiftUI

struct QRZSyncView: View {
    let database: AppDatabase
    @State private var viewModel: QRZSyncViewModel
    @State private var showLogin = false

    init(database: AppDatabase) {
        self.database = database
        self._viewModel = State(initialValue: QRZSyncViewModel(database: database))
    }

    var body: some View {
        NavigationStack {
            List {
                // QRZ Account
                Section("QRZ Account") {
                    if !viewModel.hasAPIKey || !viewModel.hasCredentials {
                        Button {
                            showLogin = true
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Label("Set Up QRZ Account", systemImage: "person.badge.key")
                                    .font(.body.bold())
                                Text("API key syncs your logbook. Username & password enable callsign lookups.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    HStack {
                        Image(systemName: viewModel.hasAPIKey ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(viewModel.hasAPIKey ? .green : .secondary)
                        Text(viewModel.hasAPIKey ? "API key configured" : "API key not set")
                        Spacer()
                        if viewModel.hasAPIKey {
                            Button("Change") { showLogin = true }
                                .font(.caption)
                        }
                    }

                    HStack {
                        Image(systemName: viewModel.hasCredentials ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(viewModel.hasCredentials ? .green : .secondary)
                        Text(viewModel.hasCredentials ? "Callsign lookup configured" : "Callsign lookup not set up")
                        Spacer()
                        if viewModel.hasCredentials {
                            Button("Change") { showLogin = true }
                                .font(.caption)
                        }
                    }
                }

                // Upload
                Section("Upload to QRZ") {
                    HStack {
                        Text("Unsynced QSOs")
                        Spacer()
                        Text("\(viewModel.unsyncedCount)")
                            .foregroundStyle(.secondary)
                    }

                    if viewModel.unsyncedCount > 0 {
                        Button {
                            Task { await viewModel.uploadAll() }
                        } label: {
                            if viewModel.isUploading {
                                HStack {
                                    ProgressView()
                                    Text("Uploading \(viewModel.uploadProgress)/\(viewModel.unsyncedCount)...")
                                }
                            } else {
                                Label("Upload \(viewModel.unsyncedCount) QSOs", systemImage: "arrow.up.circle")
                            }
                        }
                        .disabled(viewModel.isUploading || !viewModel.hasAPIKey)
                    }
                }

                // Download
                Section("Download from QRZ") {
                    Button {
                        Task { await viewModel.downloadNew() }
                    } label: {
                        if viewModel.isDownloading {
                            HStack {
                                ProgressView()
                                Text("Downloading...")
                            }
                        } else {
                            Label("Check for new QSOs", systemImage: "arrow.down.circle")
                        }
                    }
                    .disabled(viewModel.isDownloading || !viewModel.hasAPIKey)

                    if let count = viewModel.downloadedCount {
                        Text("Found \(count) new QSOs")
                            .foregroundStyle(.secondary)
                    }
                }

                // ADIF Export
                Section("Export") {
                    ShareLink(
                        item: viewModel.exportADIF(),
                        preview: SharePreview("SOTA Log ADIF Export", image: Image(systemName: "doc.text"))
                    ) {
                        Label("Export All as ADIF", systemImage: "square.and.arrow.up")
                    }
                }

                // Reference Databases
                Section("Reference Databases") {
                    ReferenceManagerView(database: database)
                }

                // Status
                if let error = viewModel.errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                    }
                }

                if let success = viewModel.successMessage {
                    Section {
                        Text(success)
                            .foregroundStyle(.green)
                    }
                }
            }
            .navigationTitle("Sync")
            .sheet(isPresented: $showLogin) {
                QRZLoginView(viewModel: viewModel)
            }
            .task {
                await viewModel.loadState()
            }
        }
    }
}
