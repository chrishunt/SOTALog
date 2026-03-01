import SwiftUI
import GRDB

struct LogListView: View {
    let database: AppDatabase
    @Environment(SpotRouter.self) private var spotRouter
    @State private var viewModel: LogListViewModel
    @State private var showNewLog = false
    @State private var navigationPath = NavigationPath()

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
                                LogRowView(log: log, qsoCount: viewModel.qsoCounts[log.id ?? 0] ?? 0)
                            }
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
                }
            }
            .navigationTitle("SOTA Log")
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
            .sheet(isPresented: $showNewLog) {
                NewLogView(database: database) { newLog in
                    showNewLog = false
                }
            }
            .task {
                await viewModel.startObserving()
            }
            .onChange(of: spotRouter.pendingSpot) { _, newValue in
                guard newValue != nil, navigationPath.isEmpty, let firstLog = viewModel.logs.first else { return }
                navigationPath.append(firstLog)
            }
        }
    }
}
