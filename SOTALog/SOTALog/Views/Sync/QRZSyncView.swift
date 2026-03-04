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
                                .font(.appLabel)
                                .foregroundStyle(Color.appTextSecondary)
                        }
                    }
                }

                HStack {
                    Image(systemName: viewModel.hasAPIKey ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(viewModel.hasAPIKey ? Color.appGreen : .secondary)
                    Text(viewModel.hasAPIKey ? "QRZ logbook sync enabled" : "QRZ logbook sync not set up")
                    Spacer()
                    if viewModel.hasAPIKey {
                        Button("Change") { showLogin = true }
                            .font(.appLabel)
                    }
                }

                HStack {
                    Image(systemName: viewModel.hasCredentials ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(viewModel.hasCredentials ? Color.appGreen : .secondary)
                    Text(viewModel.hasCredentials ? "Callsign lookup enabled" : "Callsign lookup not set up")
                    Spacer()
                    if viewModel.hasCredentials {
                        Button("Change") { showLogin = true }
                            .font(.appLabel)
                    }
                }
            }

            if viewModel.hasAPIKey {
                // Sync
                Section("Sync") {
                    syncStatusRow

                    if viewModel.unsyncedCount > 0 {
                        Button {
                            Task { await viewModel.uploadAll() }
                        } label: {
                            Label("Upload \(viewModel.unsyncedCount) QSOs", systemImage: "arrow.up.circle")
                        }
                        .disabled(viewModel.isBusy)
                    }

                    Button {
                        Task { await viewModel.refreshFromQRZ() }
                    } label: {
                        Label("Re-download all from QRZ", systemImage: "arrow.triangle.2.circlepath")
                    }
                    .disabled(viewModel.isBusy)

                    if let date = viewModel.lastSyncDate {
                        Text("Last synced: \(date.formatted(date: .abbreviated, time: .shortened))")
                            .font(.appLabel)
                            .foregroundStyle(Color.appTextSecondary)
                    }
                }
            }

            // ADIF Export
            Section("Export") {
                ShareLink(
                    item: viewModel.adifExport,
                    preview: SharePreview(viewModel.adifExport.filename)
                ) {
                    Label("Export all as ADIF", systemImage: "square.and.arrow.up")
                }
            }

            // Reference Databases
            Section("Reference Databases") {
                ReferenceManagerView(database: database)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.appBackground)
        .navigationTitle("Sync")
        .navigationBarTitleDisplayMode(.large)
        #if os(iOS)
        .toolbarBackground(Color.appBackground, for: .navigationBar)
        #endif
        }
        .sheet(isPresented: $showLogin) {
            QRZLoginView(viewModel: viewModel)
        }
        .task {
            await viewModel.loadState()
        }
    }

    // MARK: - Status Row

    @ViewBuilder
    private var syncStatusRow: some View {
        switch viewModel.syncStatus {
        case .synced, .idle:
            if viewModel.unsyncedCount == 0 {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.appGreen)
                    Text("All QSOs uploaded")
                        .foregroundStyle(Color.appGreen)
                }
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundStyle(Color.appOrange)
                    Text("\(viewModel.unsyncedCount) QSOs not uploaded")
                        .foregroundStyle(Color.appOrange)
                }
            }

        case .uploading(let done, let total):
            HStack(spacing: 8) {
                ProgressView()
                Text("Uploading \(done)/\(total)...")
            }

        case .preparingReferences:
            HStack(spacing: 8) {
                ProgressView()
                Text("Fetching reference data...")
            }

        case .downloading(let count):
            HStack(spacing: 8) {
                ProgressView()
                Text("Downloading... \(count) QSOs")
            }

        case .importing:
            HStack(spacing: 8) {
                ProgressView()
                Text("Importing...")
            }

        case .error(let message):
            Text(message)
                .foregroundStyle(Color.appRed)
        }
    }
}
