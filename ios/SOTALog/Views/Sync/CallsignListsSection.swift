import SwiftUI
import HamCore

/// The Sync tab's callsign lists.
struct CallsignListsSection: View {
    let database: LogbookDatabase
    @State private var viewModel: CallsignListsViewModel
    @State private var editor: Editor?

    private enum Editor: Identifiable {
        case add
        case edit(CallsignList)

        var id: String {
            switch self {
            case .add: return "add"
            case .edit(let list): return "edit-\(list.id ?? 0)"
            }
        }
    }

    init(database: LogbookDatabase) {
        self.database = database
        self._viewModel = State(initialValue: CallsignListsViewModel(database: database))
    }

    var body: some View {
        Section {
            ForEach(viewModel.lists) { list in
                row(list)
            }
            .onDelete { offsets in
                let lists = offsets.map { viewModel.lists[$0] }
                Task { for list in lists { await viewModel.delete(list) } }
            }

            // Modifiers on a Section apply to every row, so the sheet and the
            // first load hang off this one row, which is always there.
            Button {
                editor = .add
            } label: {
                Label("Add List", systemImage: "plus")
            }
            .task { await viewModel.load() }
            .sheet(item: $editor, onDismiss: { Task { await viewModel.load() } }) { editor in
                switch editor {
                case .add:
                    CallsignListEditorView(viewModel: CallsignListEditorViewModel(database: database))
                case .edit(let list):
                    CallsignListEditorView(viewModel: CallsignListEditorViewModel(database: database, editing: list))
                }
            }
        } header: {
            Text("Callsign Lists")
        }
    }

    @ViewBuilder
    private func row(_ list: CallsignList) -> some View {
        HStack(spacing: 12) {
            Button {
                editor = .edit(list)
            } label: {
                HStack(spacing: 12) {
                    Text(list.emoji)
                        .font(.title3)
                        .frame(minWidth: 28)
                    VStack(alignment: .leading) {
                        Text(list.name)
                            .font(.subheadline)
                            .foregroundStyle(Color.appTextPrimary)
                        Text(CallsignListsViewModel.summary(of: list))
                            .font(.appLabel)
                            .foregroundStyle(Color.appTextSecondary)
                    }
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Change the emoji or name")

            if let id = list.id, viewModel.refreshing.contains(id) {
                ProgressView()
            } else {
                Button {
                    Task { await viewModel.refresh(list) }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Refresh \(list.name)")
            }
        }

        if let id = list.id, let error = viewModel.errors[id] {
            Text(error)
                .font(.appLabel)
                .foregroundStyle(Color.appRed)
        }
    }
}

/// Adds a list from a link, or changes a list's emoji and name.
struct CallsignListEditorView: View {
    @State var viewModel: CallsignListEditorViewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var linkFocused: Bool
    @ScaledMetric(relativeTo: .title2) private var emojiSide: CGFloat = 44

    var body: some View {
        NavigationStack {
            Form {
                linkSection

                if viewModel.file != nil || !viewModel.isAdding {
                    shownAsSection
                }

                if let file = viewModel.file {
                    previewSection(file)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.appBackground)
            .navigationTitle(viewModel.isAdding ? "Add List" : "Edit List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(viewModel.isAdding ? "Add" : "Save") {
                        Task {
                            if await viewModel.save() { dismiss() }
                        }
                    }
                    .bold()
                    .disabled(!viewModel.canSave)
                }
            }
            .onChange(of: viewModel.link) { oldLink, _ in
                Task { await viewModel.linkChanged(from: oldLink) }
            }
            .onAppear { linkFocused = viewModel.isAdding }
        }
    }

    private var linkSection: some View {
        Section {
            if viewModel.isAdding {
                TextField("https://", text: $viewModel.link)
                    #if os(iOS)
                    .keyboardType(.URL)
                    #endif
                    .textContentType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($linkFocused)
                    .submitLabel(.go)
                    .onSubmit { Task { await viewModel.fetch() } }
            } else {
                Text(viewModel.link)
                    .foregroundStyle(Color.appTextSecondary)
                    .lineLimit(2)
            }
        } header: {
            Text("Link")
        } footer: {
            if viewModel.isFetching {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.mini)
                    Text("Downloading…")
                }
            } else if let error = viewModel.fetchError {
                Text(error).foregroundStyle(Color.appRed)
            } else if viewModel.isAdding {
                Text("A PoLo callsign notes file. Share links from GitHub Gist, Dropbox, Google Drive and Google Docs work too.")
            }
        }
    }

    private var shownAsSection: some View {
        Section {
            HStack(spacing: 12) {
                #if os(iOS)
                EmojiField(emoji: viewModel.emoji) { viewModel.emojiChanged($0) }
                    .frame(width: emojiSide, height: emojiSide)
                    .background(Color.appTextSecondary.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
                #endif
                TextField("Name", text: $viewModel.name)
                if let callsText = viewModel.callsText {
                    Text(callsText)
                        .font(.appLabel)
                        .foregroundStyle(Color.appTextSecondary)
                }
            }
        } header: {
            Text("Shown As")
        } footer: {
            if let error = viewModel.saveError {
                Text(error).foregroundStyle(Color.appRed)
            }
        }
    }

    private func previewSection(_ file: CallsignListFile) -> some View {
        Section("In This List") {
            ForEach(Array(file.entries.prefix(CallsignListEditorViewModel.previewCount).enumerated()), id: \.offset) { _, entry in
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(entry.callsign)
                        .font(.appCallsignRow)
                        .frame(minWidth: 72, alignment: .leading)
                    Text(CallsignListFile.readable(note: entry.note))
                        .font(.appLabel)
                        .foregroundStyle(Color.appTextSecondary)
                        .lineLimit(1)
                }
            }
            let more = file.entries.count - CallsignListEditorViewModel.previewCount
            if more > 0 {
                Text("\(more.formatted()) more")
                    .font(.appLabel)
                    .foregroundStyle(Color.appTextSecondary)
            }
        }
    }
}
