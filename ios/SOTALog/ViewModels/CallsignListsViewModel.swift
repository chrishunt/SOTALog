import Foundation
import HamCore
import Observation

/// The Sync tab's callsign lists: what is stored, which are downloading, and
/// what went wrong.
@Observable
final class CallsignListsViewModel {
    private let repo: CallsignListRepository
    private let service: CallsignListService

    private(set) var lists: [CallsignList] = []
    private(set) var refreshing: Set<Int64> = []
    private(set) var errors: [Int64: String] = [:]
    /// Why the last reorder was not saved, shown under the lists.
    private(set) var reorderError: String?

    init(database: LogbookDatabase, service: CallsignListService = CallsignListService(client: .sotaLog)) {
        self.repo = CallsignListRepository(database: database)
        self.service = service
    }

    @MainActor
    func load() async {
        lists = (try? await repo.fetchAll()) ?? []
    }

    /// Downloads `list` again. A failure keeps the stored copy and shows its error under the row.
    @MainActor
    func refresh(_ list: CallsignList) async {
        guard let id = list.id, !refreshing.contains(id) else { return }
        refreshing.insert(id)
        errors[id] = nil
        do {
            try await repo.refresh(list, using: service)
        } catch {
            errors[id] = "\(list.name) refresh failed: \(error.localizedDescription)"
        }
        refreshing.remove(id)
        await load()
    }

    /// Moves lists as a drag did, at once on screen, then saves the order,
    /// which is the order of each station's marks and notes. A failed save
    /// puts back the stored order and says why.
    @MainActor
    func move(fromOffsets source: IndexSet, toOffset destination: Int) async {
        lists.move(fromOffsets: source, toOffset: destination)
        reorderError = nil
        do {
            try await repo.reorder(lists.compactMap(\.id))
        } catch {
            reorderError = "The new order wasn't saved: \(error.localizedDescription)"
            await load()
        }
    }

    @MainActor
    func delete(_ list: CallsignList) async {
        try? await repo.delete(list)
        if let id = list.id { errors[id] = nil }
        await load()
    }

    /// What a row says under the list's name, such as "66 calls · ditdit.club · Nov 27".
    static func summary(of list: CallsignList) -> String {
        let calls = callsText(list.callsignCount)
        let host = URL(string: list.link)?.host
        let date = list.lastRefreshed?.shortDateDisplay
        return [calls, host, date].compactMap { $0 }.joined(separator: " · ")
    }

    /// "1 call" or "66 calls".
    static func callsText(_ count: Int) -> String {
        count == 1 ? "1 call" : "\(count.formatted()) calls"
    }
}

/// The sheet that adds a list from a link, or changes a stored list's emoji and name.
@Observable
final class CallsignListEditorViewModel {
    /// The editor shows the first few entries of a downloaded file.
    static let previewCount = 5

    private let repo: CallsignListRepository
    private let service: CallsignListService
    /// The list being changed, or nil when adding one.
    let editing: CallsignList?

    var link = ""
    var name = ""
    var emoji = ""
    private(set) var file: CallsignListFile?
    private(set) var isFetching = false
    private(set) var fetchError: String?
    private(set) var saveError: String?
    private var fetchedLink: String?

    init(database: LogbookDatabase, editing: CallsignList? = nil, service: CallsignListService = CallsignListService(client: .sotaLog)) {
        self.repo = CallsignListRepository(database: database)
        self.service = service
        self.editing = editing
        if let editing {
            link = editing.link
            name = editing.name
            emoji = editing.emoji
        }
    }

    var isAdding: Bool { editing == nil }

    /// Adding needs the file downloaded from the link as it reads now, so a
    /// link changed after its download can't be saved with the old file.
    var canSave: Bool {
        let named = !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let downloaded = file != nil && !isFetching && fetchedLink == trimmedLink
        return named && !emoji.isEmpty && (editing != nil || downloaded)
    }

    /// How many calls the downloaded file holds, counted as a stored list's are.
    var callsText: String? {
        file.map { CallsignListsViewModel.callsText(Set($0.entries.map(\.callsign)).count) }
    }

    /// A preview entry's note with the same emoji and words it will show while
    /// logging, using the emoji and name as they now stand in the sheet.
    func previewLine(for entry: CallsignListFile.Entry) -> String {
        let listName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return CallsignMarks.Note(emoji: emoji, listName: listName, note: entry.note).line
    }

    private var trimmedLink: String { link.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// More characters than this arriving at once is a paste, not typing.
    private static let pasteLength = 10

    /// The link field changed. A download for another link no longer applies,
    /// and a whole link pasted in downloads at once; typing waits for Go.
    @MainActor
    func linkChanged(from oldLink: String) async {
        guard isAdding else { return }
        if trimmedLink != fetchedLink {
            file = nil
            fetchError = nil
        }
        let inserted = trimmedLink.count - oldLink.trimmingCharacters(in: .whitespacesAndNewlines).count
        if inserted >= Self.pasteLength, CallsignListService.downloadURL(for: trimmedLink) != nil {
            await fetch()
        }
    }

    /// Keeps only the last emoji typed, so the field always holds one.
    func emojiChanged(_ newValue: String) {
        let kept = newValue.emojis.last ?? ""
        if kept != emoji { emoji = kept }
        saveError = nil
    }

    /// Downloads the link, unless it is blank or already downloaded, and
    /// starts the name and emoji from what the file suggests. A failed
    /// download can be tried again.
    @MainActor
    func fetch() async {
        let link = trimmedLink
        guard isAdding, !isFetching, link != fetchedLink else { return }
        fetchedLink = link
        file = nil
        fetchError = nil
        saveError = nil
        guard !link.isEmpty else { return }

        isFetching = true
        defer { isFetching = false }
        do {
            let file = try await service.fetch(link: link)
            guard link == trimmedLink else { return }
            self.file = file
            name = CallsignList.suggestedName(link: link, file: file)
            emoji = (try? await repo.suggestedEmoji(for: file)) ?? ""
        } catch {
            fetchedLink = nil
            guard link == trimmedLink, !(error is CancellationError) else { return }
            fetchError = error.localizedDescription
        }
    }

    /// Adds the list or saves the change. Returns false and shows why when it can't.
    @MainActor
    func save() async -> Bool {
        saveError = nil
        do {
            if var list = editing {
                list.name = name
                list.emoji = emoji
                try await repo.updateNameAndEmoji(of: list)
            } else if let file, let fetchedLink {
                try await repo.add(link: fetchedLink, name: name, emoji: emoji, file: file)
            }
            return true
        } catch {
            saveError = error.localizedDescription
            return false
        }
    }
}
