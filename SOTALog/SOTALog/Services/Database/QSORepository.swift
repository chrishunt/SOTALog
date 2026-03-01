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

    /// Fetch a QSO by its QRZ log ID (exact match for merge)
    func fetchByQRZLogId(_ qrzLogId: Int64) async throws -> QSO? {
        try await database.dbWriter.read { db in
            try QSO.filter(Column("qrzLogId") == qrzLogId).fetchOne(db)
        }
    }

    /// Find a semantic match: same callsign + band + date, timeOn within ±5 minutes
    func findSemanticMatch(callsign: String, band: String, date: String, timeOn: String) async throws -> QSO? {
        guard timeOn.count >= 4,
              let hh = Int(timeOn.prefix(2)),
              let mm = Int(timeOn.dropFirst(2).prefix(2)) else { return nil }

        let totalMinutes = hh * 60 + mm
        let lo = max(totalMinutes - 5, 0)
        let hi = min(totalMinutes + 5, 24 * 60 - 1)

        let loStr = String(format: "%02d%02d", lo / 60, lo % 60)
        let hiStr = String(format: "%02d%02d", hi / 60, hi % 60)

        return try await database.dbWriter.read { db in
            try QSO.fetchOne(db, sql: """
                SELECT * FROM qso
                WHERE callsign = ? AND band = ? AND date = ?
                  AND timeOn BETWEEN ? AND ?
                LIMIT 1
                """, arguments: [callsign, band, date, loStr, hiStr])
        }
    }

    /// Read sync cursor (last QRZ log ID we've seen)
    func lastSyncedQRZLogId() async throws -> Int64 {
        try await database.dbWriter.read { db in
            let row = try Row.fetchOne(db, sql: """
                SELECT recordCount FROM referenceMetadata WHERE key = 'qrzSync'
                """)
            return row?["recordCount"] as? Int64 ?? 0
        }
    }

    /// Persist sync cursor after successful download
    func saveLastSyncedQRZLogId(_ qrzLogId: Int64) async throws {
        try await database.dbWriter.write { db in
            try db.execute(sql: """
                INSERT INTO referenceMetadata (key, lastRefreshed, recordCount)
                VALUES ('qrzSync', ?, ?)
                ON CONFLICT(key) DO UPDATE SET lastRefreshed = excluded.lastRefreshed, recordCount = excluded.recordCount
                """, arguments: [Date(), qrzLogId])
        }
    }

    /// Read last sync date
    func lastSyncDate() async throws -> Date? {
        try await database.dbWriter.read { db in
            let row = try Row.fetchOne(db, sql: """
                SELECT lastRefreshed FROM referenceMetadata WHERE key = 'qrzSync'
                """)
            return row?["lastRefreshed"] as? Date
        }
    }

    /// Delete all unattached QSOs (logId IS NULL)
    func deleteAllUnattached() async throws {
        try await database.dbWriter.write { db in
            try db.execute(sql: "DELETE FROM qso WHERE logId IS NULL")
        }
    }

    /// Clear all sync state: set qrzLogId=NULL and syncedToQRZ=false on all QSOs
    func clearAllSyncState() async throws {
        try await database.dbWriter.write { db in
            try db.execute(sql: "UPDATE qso SET qrzLogId = NULL, syncedToQRZ = 0")
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
        return observation.start(
            in: writer,
            onError: { error in AppLog.database.error("QSO observation failed: \(error)") },
            onChange: onChange
        )
    }
}
