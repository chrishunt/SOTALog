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

    /// Persist sync date after successful sync
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
            guard let row else { return nil }
            return row["lastRefreshed"] as Date?
        }
    }

    /// Check if a callsign+band combination already exists in this log
    func isDuplicate(callsign: String, band: String, logId: Int64, excludingId: Int64?) async throws -> Bool {
        try await database.dbWriter.read { db in
            var sql = "SELECT COUNT(*) FROM qso WHERE callsign = ? AND band = ? AND logId = ?"
            var args: [any DatabaseValueConvertible] = [callsign, band, logId]
            if let excludingId {
                sql += " AND id != ?"
                args.append(excludingId)
            }
            let count = try Int.fetchOne(db, sql: sql, arguments: StatementArguments(args)) ?? 0
            return count > 0
        }
    }

    /// Count all QSOs for a callsign on a given date (any log, including unattached)
    func countForCallsignOnDate(_ callsign: String, date: String) async throws -> Int {
        try await database.dbWriter.read { db in
            try Int.fetchOne(db, sql: """
                SELECT COUNT(*) FROM qso
                WHERE callsign = ? AND date = ?
                """, arguments: [callsign, date]) ?? 0
        }
    }

    // MARK: - Full Refresh Import

    struct FullRefreshResult {
        var importedCount: Int
        var activationsCreated: Int
        var activationsReused: Int
    }

    /// Loads POTA reference validation dictionary: normalizedRef → formattedRef
    func loadValidPotaRefs() async throws -> [String: String] {
        try await database.dbWriter.read { db in
            var dict: [String: String] = [:]
            let rows = try Row.fetchAll(db, sql: "SELECT reference, referenceNormalized FROM potaPark")
            for row in rows {
                if let ref: String = row["reference"],
                   let norm: String = row["referenceNormalized"] {
                    dict[norm] = ref
                }
            }
            return dict
        }
    }

    /// Loads SOTA reference validation dictionary: normalizedCode → formattedCode
    func loadValidSotaCodes() async throws -> [String: String] {
        try await database.dbWriter.read { db in
            var dict: [String: String] = [:]
            let rows = try Row.fetchAll(db, sql: "SELECT code, codeNormalized FROM sotaSummit")
            for row in rows {
                if let code: String = row["code"],
                   let norm: String = row["codeNormalized"] {
                    dict[norm] = code
                }
            }
            return dict
        }
    }

    /// Replaces all synced QSOs with fresh data from QRZ, preserving local unsynced QSOs.
    /// Single atomic transaction: deletes synced QSOs, removes empty logs, creates/reuses
    /// activations, and inserts all imported QSOs.
    func fullRefreshImport(
        groupedQSOs: [(key: SyncImporter.ActivationKey, qsos: [SyncImporter.ParsedQSORecord])],
        unattachedQSOs: [SyncImporter.ParsedQSORecord]
    ) async throws -> FullRefreshResult {
        try await database.dbWriter.write { db in
            // 1. Delete all synced QSOs
            try db.execute(sql: "DELETE FROM qso WHERE syncedToQRZ = 1")

            // 2. Delete logs that have no remaining QSOs
            try db.execute(sql: """
                DELETE FROM log WHERE id NOT IN (
                    SELECT DISTINCT logId FROM qso WHERE logId IS NOT NULL
                )
                """)

            var importedCount = 0
            var activationsCreated = 0
            var activationsReused = 0

            // 3. For each activation group: find or create Log
            for group in groupedQSOs {
                let key = group.key

                // Try to find existing log matching (date, potaReference, sotaReference)
                let existingLog: Log?
                if let potaRef = key.potaReference, let sotaRef = key.sotaReference {
                    existingLog = try Log.filter(
                        Column("date") == key.date &&
                        Column("potaReference") == potaRef &&
                        Column("sotaReference") == sotaRef
                    ).fetchOne(db)
                } else if let potaRef = key.potaReference {
                    existingLog = try Log.filter(
                        Column("date") == key.date &&
                        Column("potaReference") == potaRef &&
                        Column("sotaReference") == nil
                    ).fetchOne(db)
                } else if let sotaRef = key.sotaReference {
                    existingLog = try Log.filter(
                        Column("date") == key.date &&
                        Column("potaReference") == nil &&
                        Column("sotaReference") == sotaRef
                    ).fetchOne(db)
                } else {
                    existingLog = nil
                }

                let logId: Int64
                if let existing = existingLog, let id = existing.id {
                    logId = id
                    activationsReused += 1
                } else {
                    // Look up park/summit names
                    let parkName: String? = key.potaReference.flatMap { ref in
                        try? POTAPark.fetchOne(db, id: ref)?.name
                    }
                    let summitName: String? = key.sotaReference.flatMap { ref in
                        try? SOTASummit.fetchOne(db, id: ref)?.name
                    }

                    // Parse date for createdAt
                    let createdAt = Self.dateFromADIF(key.date) ?? Date()

                    var newLog = Log(
                        createdAt: createdAt,
                        date: key.date,
                        myCallsign: key.stationCallsign,
                        myGrid: key.myGrid,
                        potaReference: key.potaReference,
                        sotaReference: key.sotaReference,
                        parkName: parkName,
                        summitName: summitName
                    )
                    try newLog.insert(db)
                    logId = newLog.id!
                    activationsCreated += 1
                }

                // 4. Insert all QSOs with correct logId
                for record in group.qsos {
                    var qso = record.qso
                    qso.logId = logId
                    qso.syncedToQRZ = true
                    qso.qrzLogId = record.rawFields["APP_QRZLOG_LOGID"].flatMap(Int64.init)
                    try qso.insert(db)
                    importedCount += 1
                }
            }

            // 5. Insert unattached QSOs with logId = nil
            for record in unattachedQSOs {
                var qso = record.qso
                qso.logId = nil
                qso.syncedToQRZ = true
                qso.qrzLogId = record.rawFields["APP_QRZLOG_LOGID"].flatMap(Int64.init)
                try qso.insert(db)
                importedCount += 1
            }

            return FullRefreshResult(
                importedCount: importedCount,
                activationsCreated: activationsCreated,
                activationsReused: activationsReused
            )
        }
    }

    /// Converts ADIF date string "YYYYMMDD" to Date
    private static func dateFromADIF(_ dateStr: String) -> Date? {
        guard dateStr.count == 8 else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.date(from: dateStr)
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

    /// Observes worked composite keys for a given UTC date.
    /// Emits a `Set<String>` of keys in the format "DATE|CALL|REF|BAND".
    func observeWorkedKeys(date: String, in writer: any DatabaseWriter, onChange: @escaping (Set<String>) -> Void) -> AnyDatabaseCancellable {
        let observation = ValueObservation.tracking { db -> Set<String> in
            let rows = try Row.fetchAll(db, sql: """
                SELECT callsign, band, potaRef, sotaRef FROM qso WHERE date = ?
                """, arguments: [date])
            var keys = Set<String>()
            for row in rows {
                guard let callsign: String = row["callsign"],
                      let band: String = row["band"] else { continue }
                if let potaRef: String = row["potaRef"] {
                    keys.insert("\(date)|\(callsign.uppercased())|\(potaRef)|\(band)")
                }
                if let sotaRef: String = row["sotaRef"] {
                    keys.insert("\(date)|\(callsign.uppercased())|\(sotaRef)|\(band)")
                }
            }
            return keys
        }
        return observation.start(
            in: writer,
            onError: { error in AppLog.database.error("Worked keys observation failed: \(error)") },
            onChange: onChange
        )
    }

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
