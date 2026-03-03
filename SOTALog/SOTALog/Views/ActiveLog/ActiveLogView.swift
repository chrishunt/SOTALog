import SwiftUI

struct ActiveLogView: View {
    let database: AppDatabase
    let log: Log

    @Environment(SpotRouter.self) private var spotRouter
    @Environment(SOTACatService.self) private var sotaCatService
    @State private var viewModel: ActiveLogViewModel
    @State private var editingQSO: QSO?

    init(database: AppDatabase, log: Log) {
        self.database = database
        self.log = log
        self._viewModel = State(initialValue: ActiveLogViewModel(database: database, log: log))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            logHeader

            Divider()

            // QSO List
            qsoList
                .safeAreaInset(edge: .bottom) {
                    QSOEntryView(
                        database: database,
                        log: log,
                        editingQSO: $editingQSO,
                        pendingSpot: Binding(
                            get: { spotRouter.pendingSpot },
                            set: { spotRouter.pendingSpot = $0 }
                        ),
                        onSave: { qso in
                            viewModel.qsoSaved()
                        }
                    )
                }
        }
        .background(Color.appBackground)
        .navigationTitle(log.myCallsign)
        .navigationBarTitleDisplayMode(.inline)
        #if os(iOS)
        .toolbar {
            if sotaCatService.isConnected {
                ToolbarItem(placement: .topBarTrailing) {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
            }
        }
        #endif
        #if os(iOS)
        .toolbarBackground(Color.appBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
        #endif
        .task {
            await viewModel.startObserving()
        }
    }

    // MARK: - Header

    private var logHeader: some View {
        ActivationStatusView(
            count: viewModel.qsoCount,
            potaReference: log.potaReference,
            sotaReference: log.sotaReference
        )
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    // MARK: - QSO List

    private var qsoList: some View {
        List {
            if viewModel.qsos.isEmpty {
                Text("Logged contacts appear here")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .padding(.top, 24)
            }

            ForEach(viewModel.qsos) { qso in
                if qso.syncedToQRZ {
                    QSORowView(qso: qso)
                        .listRowBackground(Color.clear)
                } else {
                    Button {
                        editingQSO = qso
                    } label: {
                        QSORowView(qso: qso)
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Color.clear)
                }
            }
            .onDelete { offsets in
                Task {
                    for offset in offsets {
                        let qso = viewModel.qsos[offset]
                        guard !qso.syncedToQRZ, let id = qso.id else { continue }
                        try? await viewModel.deleteQSO(id: id)
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
}
