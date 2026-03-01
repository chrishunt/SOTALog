import Foundation
import GRDB
import Observation

@Observable
final class LogListViewModel {
    private let database: AppDatabase
    private let logRepo: LogRepository
    private let qsoRepo: QSORepository
    private var cancellable: AnyDatabaseCancellable?

    var logs: [Log] = []
    var qsoCounts: [Int64: Int] = [:]

    init(database: AppDatabase) {
        self.database = database
        self.logRepo = LogRepository(database: database)
        self.qsoRepo = QSORepository(database: database)
    }

    func startObserving() async {
        cancellable = logRepo.observeAll(in: database.dbWriter) { [weak self] logs in
            guard let self else { return }
            self.logs = logs
            Task { [weak self] in
                guard let self else { return }
                var counts: [Int64: Int] = [:]
                for log in logs {
                    if let id = log.id {
                        counts[id] = try? await self.qsoRepo.fetchCount(forLogId: id)
                    }
                }
                let finalCounts = counts
                await MainActor.run { [weak self] in
                    self?.qsoCounts = finalCounts
                }
            }
        }
    }

    func deleteLog(id: Int64) async throws {
        try await logRepo.delete(id: id)
    }
}
