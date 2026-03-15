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
    var currentFrequencyMHz: String = "14.060"
    var currentMode: String = "CW"

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

    // MARK: - Export

    var exportFiles: [ADIFFile] {
        var files: [ADIFFile] = []
        if log.isPOTA {
            files.append(ADIFFile(
                filename: ADIFFormatter.activationFilename(log: log, program: .pota),
                content: ADIFFormatter.encodeFile(qsos: qsos, log: log, program: .pota)
            ))
        }
        if log.isSOTA {
            files.append(ADIFFile(
                filename: ADIFFormatter.activationFilename(log: log, program: .sota),
                content: ADIFFormatter.encodeFile(qsos: qsos, log: log, program: .sota)
            ))
        } else if qsos.contains(where: { $0.sotaRef != nil }) {
            files.append(ADIFFile(
                filename: ADIFFormatter.activationFilename(log: log, program: .sota),
                content: ADIFFormatter.encodeFile(qsos: qsos, log: log, program: .sota)
            ))
        }
        files.append(ADIFFile(
            filename: ADIFFormatter.activationFilename(log: log, program: nil),
            content: ADIFFormatter.encodeFile(qsos: qsos, log: log)
        ))
        return files
    }
}
