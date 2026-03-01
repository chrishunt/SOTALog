import SwiftUI

struct ActiveLogView: View {
    let database: AppDatabase
    let log: Log

    @Environment(SpotRouter.self) private var spotRouter
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

            // QSO Entry Form
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

            Divider()

            // QSO List
            qsoList
        }
        .navigationTitle(log.myCallsign)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.startObserving()
        }
    }

    // MARK: - Header

    private var logHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(log.myCallsign)
                    .font(.headline.monospaced())

                if let ref = log.referenceDisplay {
                    Text(ref)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if log.isPOTA || log.isSOTA {
                if log.isPOTA {
                    ThresholdBadge(count: viewModel.qsoCount, threshold: 10, label: "POTA")
                }
                if log.isSOTA {
                    ThresholdBadge(count: viewModel.qsoCount, threshold: 4, label: "SOTA")
                }
            } else {
                Text("\(viewModel.qsoCount) QSOs")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    // MARK: - QSO List

    private var qsoList: some View {
        List {
            ForEach(viewModel.qsos) { qso in
                Button {
                    editingQSO = qso
                } label: {
                    QSORowView(qso: qso)
                }
                .buttonStyle(.plain)
            }
            .onDelete { offsets in
                Task {
                    for offset in offsets {
                        let qso = viewModel.qsos[offset]
                        if let id = qso.id {
                            try? await viewModel.deleteQSO(id: id)
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
    }
}
