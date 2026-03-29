import SwiftUI
import GRDB

struct LogListView: View {
    let database: AppDatabase
    @State private var viewModel: LogListViewModel
    @State private var showNewLog = false
    @State private var navigationPath = NavigationPath()
    @State private var pendingNavLog: Log?

    init(database: AppDatabase) {
        self.database = database
        self._viewModel = State(initialValue: LogListViewModel(database: database))
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            Group {
                if viewModel.logs.isEmpty {
                    ContentUnavailableView(
                        "No Activations",
                        systemImage: "radio",
                        description: Text("Tap + to start your first activation.")
                    )
                } else {
                    List {
                        ForEach(viewModel.logs) { log in
                            NavigationLink(value: log) {
                                LogRowView(
                                    log: log,
                                    qsoCount: viewModel.qsoCounts[log.id ?? 0] ?? 0,
                                    bands: viewModel.bandsByLog[log.id ?? 0] ?? [],
                                    allSyncedToQRZ: viewModel.allSyncedToQRZ[log.id ?? 0] ?? false
                                )
                            }
                            .listRowBackground(Color.clear)
                        }
                        .onDelete { offsets in
                            Task {
                                for offset in offsets {
                                    let log = viewModel.logs[offset]
                                    if let id = log.id {
                                        try? await viewModel.deleteLog(id: id)
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(Color.appBackground)
                }
            }
            .navigationTitle("Activations")
            .navigationBarTitleDisplayMode(.large)
            #if os(iOS)
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            #endif
            .navigationDestination(for: Log.self) { log in
                ActiveLogView(database: database, log: log)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showNewLog = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showNewLog, onDismiss: {
                if let log = pendingNavLog {
                    navigationPath.append(log)
                    pendingNavLog = nil
                }
            }) {
                NewLogView(database: database) { newLog in
                    pendingNavLog = newLog
                    showNewLog = false
                }
            }
            .task {
                await viewModel.startObserving()
            }
        }
    }
}
