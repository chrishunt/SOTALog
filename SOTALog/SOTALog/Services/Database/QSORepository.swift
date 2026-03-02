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
            guard let row else { return nil }
            return row["lastRefreshed"] as Date?
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

    // MARK: - Batch Import

    struct ImportResult {
        var newCount = 0
        var updatedCount = 0
        var maxLogId: Int64 = 0
    }

    /// Imports an entire page of ADIF records in one write transaction.
    /// Uses 3-tier merge: exact match by qrzLogId → semantic match → insert.
    /// Per-record qrzLogId (APP_QRZLOG_LOGID) is optional — records without it
    /// skip tier 1 and go straight to semantic match or insert.
    func importPage(_ records: [[String: String]]) async throws -> ImportResult {
        try await database.dbWriter.write { db in
            var result = ImportResult()

            for fields in records {
                let qrzLogId = fields["APP_QRZLOG_LOGID"].flatMap(Int64.init)
                if let qrzLogId { result.maxLogId = max(result.maxLogId, qrzLogId) }

                guard var incoming = ADIFFormatter.qsoFromFields(fields) else { continue }
                incoming.syncedToQRZ = true
                incoming.qrzLogId = qrzLogId

                // Tier 1: Exact match by qrzLogId (only if record has one)
                if let qrzLogId,
                   var existing = try QSO.filter(Column("qrzLogId") == qrzLogId).fetchOne(db) {
                    let changed = syncFieldsChanged(existing: existing, incoming: incoming)
                    existing.callsign = incoming.callsign
                    existing.date = incoming.date
                    existing.timeOn = incoming.timeOn
                    existing.frequency = incoming.frequency
                    existing.band = incoming.band
                    existing.mode = incoming.mode
                    existing.rstSent = incoming.rstSent
                    existing.rstReceived = incoming.rstReceived
                    existing.name = incoming.name
                    existing.qth = incoming.qth
                    existing.grid = incoming.grid
                    existing.sotaRef = incoming.sotaRef
                    existing.potaRef = incoming.potaRef
                    existing.notes = incoming.notes
                    existing.syncedToQRZ = true
                    try existing.save(db)
                    if changed { result.updatedCount += 1 }
                    continue
                }

                // Tier 2: Semantic match (callsign + band + date + timeOn ±5 min)
                if var matched = try findSemanticMatchSync(
                    db: db,
                    callsign: incoming.callsign,
                    band: incoming.band,
                    date: incoming.date,
                    timeOn: incoming.timeOn
                ) {
                    let changed = mergedFieldsChanged(matched: matched, incoming: incoming)
                    matched.qrzLogId = qrzLogId ?? matched.qrzLogId
                    matched.frequency = incoming.frequency ?? matched.frequency
                    matched.name = incoming.name ?? matched.name
                    matched.qth = incoming.qth ?? matched.qth
                    matched.grid = incoming.grid ?? matched.grid
                    matched.sotaRef = incoming.sotaRef ?? matched.sotaRef
                    matched.potaRef = incoming.potaRef ?? matched.potaRef
                    matched.notes = incoming.notes ?? matched.notes
                    matched.syncedToQRZ = true
                    try matched.save(db)
                    if changed { result.updatedCount += 1 }
                    continue
                }

                // Tier 3: No match — insert unattached
                try incoming.save(db)
                result.newCount += 1
            }

            return result
        }
    }

    /// Returns true if any sync-relevant fields differ between existing and incoming QSOs.
    private func syncFieldsChanged(existing: QSO, incoming: QSO) -> Bool {
        existing.callsign != incoming.callsign ||
        existing.date != incoming.date ||
        existing.timeOn != incoming.timeOn ||
        existing.frequency != incoming.frequency ||
        existing.band != incoming.band ||
        existing.mode != incoming.mode ||
        existing.rstSent != incoming.rstSent ||
        existing.rstReceived != incoming.rstReceived ||
        existing.name != incoming.name ||
        existing.qth != incoming.qth ||
        existing.grid != incoming.grid ||
        existing.sotaRef != incoming.sotaRef ||
        existing.potaRef != incoming.potaRef ||
        existing.notes != incoming.notes
    }

    /// Returns true if any of the incoming non-nil fields differ from the matched record.
    private func mergedFieldsChanged(matched: QSO, incoming: QSO) -> Bool {
        if let v = incoming.qrzLogId, v != matched.qrzLogId { return true }
        if !matched.syncedToQRZ && incoming.syncedToQRZ { return true }
        if let v = incoming.frequency, v != matched.frequency { return true }
        if let v = incoming.name, v != matched.name { return true }
        if let v = incoming.qth, v != matched.qth { return true }
        if let v = incoming.grid, v != matched.grid { return true }
        if let v = incoming.sotaRef, v != matched.sotaRef { return true }
        if let v = incoming.potaRef, v != matched.potaRef { return true }
        if let v = incoming.notes, v != matched.notes { return true }
        return false
    }

    /// Synchronous semantic match for use inside a GRDB transaction.
    private func findSemanticMatchSync(db: Database, callsign: String, band: String, date: String, timeOn: String) throws -> QSO? {
        guard timeOn.count >= 4,
              let hh = Int(timeOn.prefix(2)),
              let mm = Int(timeOn.dropFirst(2).prefix(2)) else { return nil }

        let totalMinutes = hh * 60 + mm
        let lo = max(totalMinutes - 5, 0)
        let hi = min(totalMinutes + 5, 24 * 60 - 1)

        let loStr = String(format: "%02d%02d", lo / 60, lo % 60)
        let hiStr = String(format: "%02d%02d", hi / 60, hi % 60)

        return try QSO.fetchOne(db, sql: """
            SELECT * FROM qso
            WHERE callsign = ? AND band = ? AND date = ?
              AND timeOn BETWEEN ? AND ?
            LIMIT 1
            """, arguments: [callsign, band, date, loStr, hiStr])
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
