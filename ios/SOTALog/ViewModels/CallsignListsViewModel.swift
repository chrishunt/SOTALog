import Foundation
import HamCore
import Observation

/// The Sync tab's callsign lists: what is stored, which are downloading, and
/// what went wrong. Lists download only when the operator adds or refreshes one.
@Observable
final class CallsignListsViewModel {
    private let repo: CallsignListRepository
    private let service: CallsignListService

    private(set) var lists: [CallsignList] = []
    private(set) var refreshing: Set<Int64> = []
    private(set) var errors: [Int64: String] = [:]

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

    @MainActor
    func delete(_ list: CallsignList) async {
        try? await repo.delete(list)
        if let id = list.id { errors[id] = nil }
        await load()
    }

    /// What a row says under the list's name, such as "66 calls · ditdit.club · Nov 27".
    static func summary(of list: CallsignList) -> String {
        let calls = list.callsignCount == 1 ? "1 call" : "\(list.callsignCount.formatted()) calls"
        let host = URL(string: list.link)?.host
        let date = list.lastRefreshed?.shortDateDisplay
        return [calls, host, date].compactMap { $0 }.joined(separator: " · ")
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

    var canSave: Bool {
        let named = !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return named && emoji.emojis.count == 1 && (editing != nil || (file != nil && !isFetching))
    }

    /// Keeps only the last emoji typed, so the field always holds one.
    func emojiChanged(_ newValue: String) {
        let kept = newValue.emojis.last ?? ""
        if kept != emoji { emoji = kept }
        saveError = nil
    }

    /// Downloads the link, unless it is blank or already downloaded, and
    /// starts the name and emoji from what the file suggests.
    @MainActor
    func fetch() async {
        let link = link.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isAdding, link != fetchedLink else { return }
        fetchedLink = link
        file = nil
        fetchError = nil
        saveError = nil
        guard !link.isEmpty else { return }

        isFetching = true
        defer { isFetching = false }
        do {
            let file = try await service.fetch(link: link)
            guard link == self.link.trimmingCharacters(in: .whitespacesAndNewlines) else { return }
            self.file = file
            name = CallsignList.suggestedName(link: link, file: file)
            emoji = (try? await repo.suggestedEmoji(for: file)) ?? "⭐"
        } catch {
            guard link == self.link.trimmingCharacters(in: .whitespacesAndNewlines) else { return }
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
            } else if let file {
                try await repo.add(link: link, name: name, emoji: emoji, file: file)
            }
            return true
        } catch {
            saveError = error.localizedDescription
            return false
        }
    }
}
