import SwiftUI

struct QSOSearchView: View {
    let database: AppDatabase
    @State private var viewModel: QSOSearchViewModel
    @FocusState private var isSearchFocused: Bool

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
        .safeAreaInset(edge: .top) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search callsigns", text: $viewModel.searchText)
                    #if os(iOS)
                    .textInputAutocapitalization(.characters)
                    #endif
                    .focused($isSearchFocused)
                if !viewModel.searchText.isEmpty {
                    Button {
                        viewModel.searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(10)
            #if os(iOS)
            .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 10))
            #else
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
            #endif
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .navigationTitle("Search")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.startObserving()
            isSearchFocused = true
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
