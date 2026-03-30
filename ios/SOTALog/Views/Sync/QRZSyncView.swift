import SwiftUI

struct QRZSyncView: View {
    let database: AppDatabase
    @State private var viewModel: QRZSyncViewModel
    @State private var showLogbookSignIn = false
    @State private var showCallsignSignIn = false
    @State private var showLogbookSignOut = false
    @State private var showCallsignSignOut = false

    init(database: AppDatabase) {
        self.database = database
        self._viewModel = State(initialValue: QRZSyncViewModel(database: database))
    }

    var body: some View {
        NavigationStack {
        List {
            // Logbook Sync
            Section {
                if viewModel.hasAPIKey {
                    syncStatusRow

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

                    Button("Sign Out", role: .destructive) {
                        showLogbookSignOut = true
                    }
                } else {
                    Button {
                        showLogbookSignIn = true
                    } label: {
                        Label("Sign In to QRZ", systemImage: "person.badge.key")
                            .font(.body.bold())
                    }
                }
            } header: {
                Text("Logbook Sync")
            } footer: {
                if !viewModel.hasAPIKey {
                    Text("Upload and download QSOs with QRZ.com")
                }
            }

            // Callsign Lookup
            Section {
                if viewModel.hasCredentials {
                    if let callsign = viewModel.username {
                        Text("Signed in as ")
                         + Text(callsign.uppercased())
                            .font(.body.monospaced())
                    }

                    Button("Sign Out", role: .destructive) {
                        showCallsignSignOut = true
                    }
                } else {
                    Button {
                        showCallsignSignIn = true
                    } label: {
                        Label("Sign In to QRZ", systemImage: "person.badge.key")
                            .font(.body.bold())
                    }
                }
            } header: {
                Text("Callsign Lookup")
            } footer: {
                if !viewModel.hasCredentials {
                    Text("Look up name and location for callsigns.")
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
        .sheet(isPresented: $showLogbookSignIn) {
            LogbookSyncSignInView(viewModel: viewModel)
        }
        .sheet(isPresented: $showCallsignSignIn) {
            CallsignLookupSignInView(viewModel: viewModel)
        }
        .alert("Sign Out of Logbook Sync?", isPresented: $showLogbookSignOut) {
            Button("Sign Out", role: .destructive) { viewModel.clearAPIKey() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Your QSOs are not affected.")
        }
        .alert("Sign Out of Callsign Lookup?", isPresented: $showCallsignSignOut) {
            Button("Sign Out", role: .destructive) { viewModel.clearXMLCredentials() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Callsign lookups will stop working.")
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
                Button {
                    Task { await viewModel.uploadAll() }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.up.circle.fill")
                            .foregroundStyle(Color.appOrange)
                        Text("Upload \(viewModel.unsyncedCount) QSOs")
                            .foregroundStyle(Color.appOrange)
                    }
                }
                .disabled(viewModel.isBusy)
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
