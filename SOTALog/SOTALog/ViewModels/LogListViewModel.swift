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
    var allSyncedToQRZ: [Int64: Bool] = [:]

    init(database: AppDatabase) {
        self.database = database
        self.logRepo = LogRepository(database: database)
    }

    func startObserving() async {
        let observation = ValueObservation.tracking { db -> ([Log], [Int64: Int], [Int64: [String]], [Int64: Bool]) in
            let logs = try Log.order(Column("date").desc, Column("createdAt").desc).fetchAll(db)

            // Aggregate counts + QRZ sync status (single query replaces per-log fetchCount)
            var counts: [Int64: Int] = [:]
            var synced: [Int64: Bool] = [:]
            let countRows = try Row.fetchAll(db, sql: """
                SELECT logId, COUNT(*) as total,
                       SUM(CASE WHEN syncedToQRZ THEN 1 ELSE 0 END) as syncedCount
                FROM qso WHERE logId IS NOT NULL GROUP BY logId
                """)
            for row in countRows {
                guard let logId: Int64 = row["logId"] else { continue }
                let total: Int = row["total"] ?? 0
                let syncedCount: Int = row["syncedCount"] ?? 0
                counts[logId] = total
                synced[logId] = total > 0 && syncedCount == total
            }

            // Distinct bands per log (single query replaces per-log SELECT DISTINCT)
            var bands: [Int64: [String]] = [:]
            let bandRows = try Row.fetchAll(db, sql: """
                SELECT DISTINCT logId, band FROM qso WHERE logId IS NOT NULL
                """)
            let bandOrder = BandPlan.allBands
            for row in bandRows {
                guard let logId: Int64 = row["logId"],
                      let band: String = row["band"] else { continue }
                bands[logId, default: []].append(band)
            }
            for (logId, logBands) in bands {
                bands[logId] = logBands.sorted { a, b in
                    (bandOrder.firstIndex(of: a) ?? Int.max) < (bandOrder.firstIndex(of: b) ?? Int.max)
                }
            }

            return (logs, counts, bands, synced)
        }

        cancellable = observation.start(
            in: database.dbWriter,
            onError: { error in AppLog.database.error("Log list observation failed: \(error)") },
            onChange: { [weak self] (logs, counts, bands, synced) in
                self?.logs = logs
                self?.qsoCounts = counts
                self?.bandsByLog = bands
                self?.allSyncedToQRZ = synced
            }
        )
    }

    func deleteLog(id: Int64) async throws {
        try await logRepo.delete(id: id)
    }
}
