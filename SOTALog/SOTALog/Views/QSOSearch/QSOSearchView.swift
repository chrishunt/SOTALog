import SwiftUI

struct QSOSearchView: View {
    let database: AppDatabase
    @State private var viewModel: QSOSearchViewModel

    init(database: AppDatabase) {
        self.database = database
        self._viewModel = State(initialValue: QSOSearchViewModel(database: database))
    }

    var body: some View {
        Group {
            if viewModel.results.isEmpty && !viewModel.searchText.isEmpty {
                ContentUnavailableView.search
            } else if viewModel.results.isEmpty {
                ContentUnavailableView(
                    "No QSOs",
                    systemImage: "radio",
                    description: Text("QSOs will appear here after logging.")
                )
            } else {
                List {
                    if !viewModel.searchText.isEmpty {
                        Section {
                            countSummary
                        }
                    }

                    Section {
                        ForEach(viewModel.results) { result in
                            QSOSearchRowView(result: result)
                        }
                    }
                }
            }
        }
        #if os(iOS)
        .searchable(
            text: $viewModel.searchText,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Search callsigns"
        )
        .textInputAutocapitalization(.characters)
        #else
        .searchable(
            text: $viewModel.searchText,
            prompt: "Search callsigns"
        )
        #endif
        .navigationTitle("Search")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.startObserving()
        }
    }

    @ViewBuilder
    private var countSummary: some View {
        let unique = viewModel.uniqueCallsigns
        if unique.count == 1, let callsign = unique.first {
            HStack(spacing: 4) {
                Text("\(viewModel.resultCount) QSO\(viewModel.resultCount == 1 ? "" : "s") with")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(callsign)
                    .font(.subheadline.monospaced())
                    .foregroundStyle(.secondary)
            }
        } else {
            Text("\(viewModel.resultCount) QSOs")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}
