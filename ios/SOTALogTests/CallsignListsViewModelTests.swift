import XCTest
@testable import SOTALog
import HamCore

@MainActor
final class CallsignListsViewModelTests: XCTestCase {
    private let link = "https://example.com/club.txt"
    private var db: LogbookDatabase!

    override func setUp() async throws {
        db = try LogbookDatabase.empty()
    }

    /// A service that answers every request with `status` and `body`, never touching the network.
    private func service(status: Int = 200, body: String) -> CallsignListService {
        let transport = HTTPTransport { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
            return (Data(body.utf8), response)
        }
        return CallsignListService(client: APIClient(userAgent: "SOTALogTests", transport: transport))
    }

    private let club = "# TITLE: CWO members\nAC4NK 🌊 Banks\nKI7QCF 🐛 Forrest\nK5OHY 🌊 Tim\n"

    // MARK: - Adding

    func testAddingFetchesTheLinkAndSuggestsANameAndEmoji() async throws {
        let editor = CallsignListEditorViewModel(database: db, service: service(body: club))
        XCTAssertFalse(editor.canSave)

        editor.link = " \(link)\n"
        await editor.fetch()

        XCTAssertEqual(editor.file?.entries.count, 3)
        XCTAssertEqual(editor.name, "CWO members")
        XCTAssertEqual(editor.emoji, "🌊")
        XCTAssertTrue(editor.canSave)

        let saved = await editor.save()
        XCTAssertTrue(saved)
        let lists = CallsignListsViewModel(database: db)
        await lists.load()
        XCTAssertEqual(lists.lists.map(\.name), ["CWO members"])
        XCTAssertEqual(lists.lists.first?.link, link)
    }

    func testABadLinkShowsWhyAndCannotBeAdded() async {
        let editor = CallsignListEditorViewModel(database: db, service: service(body: "<!DOCTYPE html><html></html>"))
        editor.link = link
        await editor.fetch()

        XCTAssertNil(editor.file)
        XCTAssertEqual(editor.fetchError, CallsignListError.notPlainText.localizedDescription)
        XCTAssertFalse(editor.canSave)
    }

    func testAnEmojiAnotherListUsesShowsWhyOnSave() async throws {
        try await CallsignListRepository(database: db).add(link: "https://example.com/a", name: "Friends", emoji: "⭐", file: CallsignListFile(parsing: "W6LG"))
        let editor = CallsignListEditorViewModel(database: db, service: service(body: club))
        editor.link = link
        await editor.fetch()
        editor.emojiChanged("⭐")

        let saved = await editor.save()

        XCTAssertFalse(saved)
        XCTAssertEqual(editor.saveError, CallsignListError.emojiInUse(listName: "Friends").localizedDescription)
    }

    func testTheEmojiFieldKeepsOnlyTheLastEmojiTyped() {
        let editor = CallsignListEditorViewModel(database: db)
        editor.emojiChanged("🌊🐛")
        XCTAssertEqual(editor.emoji, "🐛")
        editor.emojiChanged("A")
        XCTAssertEqual(editor.emoji, "")
    }

    // MARK: - Editing

    func testEditingSavesANewNameAndEmoji() async throws {
        let list = try await CallsignListRepository(database: db).add(link: link, name: "CWO", emoji: "🌊", file: CallsignListFile(parsing: club))
        let editor = CallsignListEditorViewModel(database: db, editing: list)
        XCTAssertFalse(editor.isAdding)
        XCTAssertTrue(editor.canSave, "a stored list can be saved without downloading it")

        editor.name = "CW Ops"
        editor.emojiChanged("🐛")
        let saved = await editor.save()

        XCTAssertTrue(saved)
        let stored = try await CallsignListRepository(database: db).fetchAll()
        XCTAssertEqual(stored.map(\.name), ["CW Ops"])
        XCTAssertEqual(stored.map(\.emoji), ["🐛"])
    }

    // MARK: - Refreshing

    func testAFailedRefreshKeepsTheListAndSaysWhy() async throws {
        let list = try await CallsignListRepository(database: db).add(link: link, name: "CWO", emoji: "🌊", file: CallsignListFile(parsing: club))
        let lists = CallsignListsViewModel(database: db, service: service(status: 404, body: ""))
        await lists.load()

        await lists.refresh(list)

        XCTAssertEqual(lists.lists.map(\.callsignCount), [3])
        XCTAssertEqual(lists.errors[list.id!], "CWO refresh failed: \(APIError.httpStatus(404).localizedDescription)")
        XCTAssertTrue(lists.refreshing.isEmpty)
    }

    func testARefreshReplacesTheEntries() async throws {
        let list = try await CallsignListRepository(database: db).add(link: link, name: "CWO", emoji: "🌊", file: CallsignListFile(parsing: club))
        let lists = CallsignListsViewModel(database: db, service: service(body: "W6LG\n"))

        await lists.refresh(list)

        XCTAssertEqual(lists.lists.map(\.callsignCount), [1])
        XCTAssertNil(lists.errors[list.id!])
    }

    func testTheRowSummarySaysHowManyCallsFromWhereAndWhen() {
        let date = Date(timeIntervalSince1970: 1_795_000_000)
        let list = CallsignList(link: "https://ditdit.club/data/members.txt", name: "CWO", emoji: "🌊", callsignCount: 1_066, lastRefreshed: date)
        XCTAssertEqual(CallsignListsViewModel.summary(of: list), "\(1_066.formatted()) calls · ditdit.club · \(date.shortDateDisplay)")

        let one = CallsignList(link: "https://example.com/a", name: "A", emoji: "⭐", callsignCount: 1)
        XCTAssertEqual(CallsignListsViewModel.summary(of: one), "1 call · example.com")
    }
}
