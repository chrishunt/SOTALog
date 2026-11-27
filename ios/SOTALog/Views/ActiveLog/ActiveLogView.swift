import SwiftUI
import HamCore
import TipKit

struct ActiveLogView: View {
    let database: LogbookDatabase
    let log: Log

    @Environment(SpotRouter.self) private var spotRouter
    @Environment(SOTACatService.self) private var sotaCatService
    @Environment(CallsignMarksStore.self) private var marksStore
    @State private var viewModel: ActiveLogViewModel
    @State private var editingQSO: QSO?
    @State private var showSpots = false
    @State private var showSpotMe = false

    init(database: LogbookDatabase, log: Log) {
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
                        },
                        onFrequencyChanged: { freq in
                            viewModel.currentFrequencyMHz = freq
                        },
                        onModeChanged: { mode in
                            viewModel.currentMode = mode
                        }
                    )
                }
        }
        .background(Color.appBackground)
        .navigationTitle(log.myCallsign)
        .navigationBarTitleDisplayMode(.inline)
        #if os(iOS)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showSpots = true
                } label: {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                }
                .popoverTip(SpotsTip())
            }

            if log.isPOTA || log.isSOTA {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSpotMe = true
                    } label: {
                        Image(systemName: "megaphone")
                    }
                }
            }

            if !viewModel.qsos.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(items: viewModel.exportFiles,
                              preview: { SharePreview($0.filename) }) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
        .sheet(isPresented: $showSpots) {
            SpotsSheetView(database: database)
        }
        .sheet(isPresented: $showSpotMe) {
            SpotMeSheetView(
                log: log,
                frequencyMHz: viewModel.currentFrequencyMHz,
                mode: viewModel.currentMode
            )
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
        .task {
            for await status in OmniboxTip().statusUpdates {
                if case .invalidated = status {
                    SpotsTip.omniboxTipClosed = true
                    break
                }
            }
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
                    .foregroundStyle(Color.appTextTertiary)
                    .frame(maxWidth: .infinity)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .padding(.top, 24)
            }

            ForEach(viewModel.qsos) { qso in
                if qso.syncedToQRZ {
                    QSORowView(qso: qso, mark: marksStore.marks.mark(for: qso.callsign))
                        .listRowBackground(Color.clear)
                } else {
                    Button {
                        editingQSO = qso
                    } label: {
                        QSORowView(qso: qso, mark: marksStore.marks.mark(for: qso.callsign))
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(rowBackground(isEditing: qso.id != nil && qso.id == editingQSO?.id))
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

    /// The row being edited sits in one rounded tint, the same as the panel's
    /// Editing strip, so it's clear which contact is changing.
    private func rowBackground(isEditing: Bool) -> some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(isEditing ? Color.appEditingTint : Color.clear)
            .padding(.horizontal, 8)
    }
}
