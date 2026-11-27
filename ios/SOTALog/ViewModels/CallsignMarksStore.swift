import Foundation
import GRDB
import HamCore
import Observation

/// The callsign list marks every screen reads, kept current as lists are
/// added, refreshed, changed or removed.
@Observable
final class CallsignMarksStore {
    private(set) var marks: CallsignMarks = .none
    private var cancellable: AnyDatabaseCancellable?

    /// HamCore delivers observation changes on the main actor, so this runs there.
    @MainActor
    func start(database: LogbookDatabase) {
        guard cancellable == nil else { return }
        cancellable = CallsignListRepository(database: database).observeMarks(in: database.dbWriter) { [weak self] marks in
            MainActor.assumeIsolated { self?.marks = marks }
        }
    }
}

extension CallsignMarks.Note {
    /// The note as one line of text, such as "🌊 Ryan Banks".
    var line: String {
        [emoji, text].filter { !$0.isEmpty }.joined(separator: " ")
    }
}
