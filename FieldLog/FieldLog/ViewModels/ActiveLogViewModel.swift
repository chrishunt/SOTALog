import Foundation
import GRDB
import Observation

@Observable
final class ActiveLogViewModel {
    private let database: AppDatabase
    private let qsoRepo: QSORepository
    private var cancellable: AnyDatabaseCancellable?
    let log: Log

    var qsos: [QSO] = []
    var qsoCount: Int = 0

    init(database: AppDatabase, log: Log) {
        self.database = database
        self.log = log
        self.qsoRepo = QSORepository(database: database)
    }

    func startObserving() async {
        guard let logId = log.id else { return }

        cancellable = qsoRepo.observeAll(forLogId: logId, in: database.dbWriter) { [weak self] qsos in
            self?.qsos = qsos
            self?.qsoCount = qsos.count
        }
    }

    func qsoSaved() {
        // Count will update via observation
    }

    func deleteQSO(id: Int64) async throws {
        try await qsoRepo.delete(id: id)
    }
}
