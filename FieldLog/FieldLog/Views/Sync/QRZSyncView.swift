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
                    if viewModel.hasAPIKey {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("API Key configured")
                            Spacer()
                            Button("Change") { showLogin = true }
                        }
                    } else {
                        Button {
                            showLogin = true
                        } label: {
                            Label("Set QRZ API Key", systemImage: "key")
                        }
                    }

                    if viewModel.hasCredentials {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("XML lookup credentials set")
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
                        preview: SharePreview("FieldLog ADIF Export", image: Image(systemName: "doc.text"))
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
