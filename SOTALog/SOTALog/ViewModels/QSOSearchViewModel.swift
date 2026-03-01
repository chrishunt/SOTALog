import Foundation
import GRDB
import Observation

@Observable
final class QSOSearchViewModel {
    private let database: AppDatabase
    private var cancellable: AnyDatabaseCancellable?

    var results: [QSOSearchResult] = []
    var searchText: String = "" {
        didSet { updateObservation() }
    }

    init(database: AppDatabase) {
        self.database = database
    }

    func startObserving() {
        updateObservation()
    }

    private func updateObservation() {
        cancellable?.cancel()

        let query = searchText.trimmingCharacters(in: .whitespaces).uppercased()

        let observation = ValueObservation.tracking { db -> [QSOSearchResult] in
            let sql: String
            var arguments: StatementArguments

            if query.isEmpty {
                sql = """
                    SELECT q.id, q.callsign, q.date, q.timeOn, q.band, q.frequency,
                           l.potaReference AS logPotaReference, l.sotaReference AS logSotaReference
                    FROM qso q
                    LEFT JOIN log l ON l.id = q.logId
                    ORDER BY q.date DESC, q.timeOn DESC
                    LIMIT 200
                    """
                arguments = []
            } else {
                sql = """
                    SELECT q.id, q.callsign, q.date, q.timeOn, q.band, q.frequency,
                           l.potaReference AS logPotaReference, l.sotaReference AS logSotaReference
                    FROM qso q
                    LEFT JOIN log l ON l.id = q.logId
                    WHERE q.callsign LIKE ? || '%'
                    ORDER BY q.date DESC, q.timeOn DESC
                    """
                arguments = [query]
            }

            return try QSOSearchResult.fetchAll(db, sql: sql, arguments: arguments)
        }

        cancellable = observation.start(
            in: database.dbWriter,
            onError: { error in AppLog.database.error("QSO search observation failed: \(error)") },
            onChange: { [weak self] results in
                self?.results = results
            }
        )
    }

    var resultCount: Int { results.count }

    var uniqueCallsigns: Set<String> {
        Set(results.map(\.callsign))
    }
}

struct QSOSearchResult: Identifiable, Equatable, FetchableRecord, Codable {
    var id: Int64
    var callsign: String
    var date: String
    var timeOn: String
    var band: String
    var frequency: Double?
    var logPotaReference: String?
    var logSotaReference: String?

    var formattedDate: String {
        guard date.count == 8 else { return date }
        let y = date.prefix(4)
        let m = date.dropFirst(4).prefix(2)
        let d = date.dropFirst(6).prefix(2)
        return "\(y)-\(m)-\(d)"
    }
}
