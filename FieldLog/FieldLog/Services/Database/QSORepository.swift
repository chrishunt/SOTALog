import Foundation
import GRDB

struct QSORepository {
    let database: AppDatabase

    // MARK: - Fetch

    func fetchAll(forLogId logId: Int64) async throws -> [QSO] {
        try await database.dbWriter.read { db in
            try QSO
                .filter(Column("logId") == logId)
                .order(Column("id").desc)
                .fetchAll(db)
        }
    }

    func fetchUnsynced() async throws -> [QSO] {
        try await database.dbWriter.read { db in
            try QSO
                .filter(Column("syncedToQRZ") == false)
                .order(Column("id").asc)
                .fetchAll(db)
        }
    }

    func fetchCount(forLogId logId: Int64) async throws -> Int {
        try await database.dbWriter.read { db in
            try QSO.filter(Column("logId") == logId).fetchCount(db)
        }
    }

    func fetch(id: Int64) async throws -> QSO? {
        try await database.dbWriter.read { db in
            try QSO.fetchOne(db, id: id)
        }
    }

    /// Check if a QRZ log ID already exists (for deduplication)
    func existsWithQRZLogId(_ qrzLogId: Int64) async throws -> Bool {
        try await database.dbWriter.read { db in
            try QSO.filter(Column("qrzLogId") == qrzLogId).fetchCount(db) > 0
        }
    }

    // MARK: - Save

    @discardableResult
    func save(_ qso: inout QSO) async throws -> QSO {
        qso = try await database.dbWriter.write { [qso] db in
            var mutableQSO = qso
            try mutableQSO.save(db)
            return mutableQSO
        }
        return qso
    }

    func markSynced(id: Int64, qrzLogId: Int64) async throws {
        try await database.dbWriter.write { db in
            try db.execute(
                sql: "UPDATE qso SET syncedToQRZ = 1, qrzLogId = ? WHERE id = ?",
                arguments: [qrzLogId, id]
            )
        }
    }

    // MARK: - Delete

    func delete(id: Int64) async throws {
        _ = try await database.dbWriter.write { db in
            try QSO.deleteOne(db, id: id)
        }
    }

    // MARK: - Observation

    /// Starts observing QSOs for a log, calling the handler on each change.
    func observeAll(forLogId logId: Int64, in writer: any DatabaseWriter, onChange: @escaping ([QSO]) -> Void) -> AnyDatabaseCancellable {
        let observation = ValueObservation.tracking { db in
            try QSO
                .filter(Column("logId") == logId)
                .order(Column("id").desc)
                .fetchAll(db)
        }
        return observation.start(in: writer, onError: { _ in }, onChange: onChange)
    }
}
