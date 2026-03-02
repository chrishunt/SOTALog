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

    init(database: AppDatabase) {
        self.database = database
        self.logRepo = LogRepository(database: database)
    }

    func startObserving() async {
        let observation = ValueObservation.tracking { db -> ([Log], [Int64: Int]) in
            let logs = try Log.order(Column("date").desc).fetchAll(db)
            var counts: [Int64: Int] = [:]
            for log in logs {
                if let id = log.id {
                    counts[id] = try QSO.filter(Column("logId") == id).fetchCount(db)
                }
            }
            return (logs, counts)
        }

        cancellable = observation.start(
            in: database.dbWriter,
            onError: { error in AppLog.database.error("Log list observation failed: \(error)") },
            onChange: { [weak self] (logs, counts) in
                self?.logs = logs
                self?.qsoCounts = counts
            }
        )
    }

    func deleteLog(id: Int64) async throws {
        try await logRepo.delete(id: id)
    }
}
