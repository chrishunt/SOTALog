import Foundation
import GRDB
import Observation

@Observable
final class LogListViewModel {
    private let database: AppDatabase
    private let logRepo: LogRepository
    private var cancellable: AnyDatabaseCancellable?

    var logs: [Log] = []
    var qsoCounts: [Int64: Int] = [:]
    var bandsByLog: [Int64: [String]] = [:]

    init(database: AppDatabase) {
        self.database = database
        self.logRepo = LogRepository(database: database)
    }

    func startObserving() async {
        let observation = ValueObservation.tracking { db -> ([Log], [Int64: Int], [Int64: [String]]) in
            let logs = try Log.order(Column("date").desc, Column("createdAt").desc).fetchAll(db)
            var counts: [Int64: Int] = [:]
            var bands: [Int64: [String]] = [:]
            for log in logs {
                if let id = log.id {
                    counts[id] = try QSO.filter(Column("logId") == id).fetchCount(db)

                    let rows = try Row.fetchAll(db, sql: """
                        SELECT DISTINCT band FROM qso WHERE logId = ?
                        """, arguments: [id])
                    let logBands = rows.compactMap { $0["band"] as String? }
                    let bandOrder = BandPlan.allBands
                    bands[id] = logBands.sorted { a, b in
                        (bandOrder.firstIndex(of: a) ?? Int.max) < (bandOrder.firstIndex(of: b) ?? Int.max)
                    }
                }
            }
            return (logs, counts, bands)
        }

        cancellable = observation.start(
            in: database.dbWriter,
            onError: { error in AppLog.database.error("Log list observation failed: \(error)") },
            onChange: { [weak self] (logs, counts, bands) in
                self?.logs = logs
                self?.qsoCounts = counts
                self?.bandsByLog = bands
            }
        )
    }

    func deleteLog(id: Int64) async throws {
        try await logRepo.delete(id: id)
    }
}
