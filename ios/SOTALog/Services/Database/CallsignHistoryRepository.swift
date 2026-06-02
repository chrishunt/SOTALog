import Foundation
import GRDB

/// Stores cached enrichment (name/QTH/grid/lastWorked) per callsign. The worked
/// count is derived from the `qso` table on demand and is intentionally not kept
/// here — see `QSORepository.countForCallsign`.
struct CallsignHistoryRepository {
    let database: AppDatabase

    /// Fetches the history for a callsign
    func fetch(callsign: String) async throws -> CallsignHistory? {
        try await database.dbWriter.read { db in
            try CallsignHistory.fetchOne(db, id: callsign.uppercased())
        }
    }

    /// Records that a QSO was just logged: refreshes lastWorked and fills in
    /// name/qth/grid if provided. Call this when creating a new QSO.
    func recordQSO(callsign: String, name: String?, qth: String?, grid: String?) async throws {
        try await database.dbWriter.write { db in
            let key = callsign.uppercased()
            if var existing = try CallsignHistory.fetchOne(db, id: key) {
                existing.lastWorked = Date()
                if let name = name, !name.isEmpty { existing.name = name }
                if let qth = qth, !qth.isEmpty { existing.qth = qth }
                if let grid = grid, !grid.isEmpty { existing.grid = grid }
                try existing.update(db)
            } else {
                let history = CallsignHistory(
                    callsign: key,
                    name: name,
                    qth: qth,
                    grid: grid,
                    lastWorked: Date()
                )
                try history.insert(db)
            }
        }
    }

    /// Updates enrichment with data from a QRZ lookup or an edit, without touching
    /// lastWorked (no new contact was made).
    func updateFromLookup(callsign: String, name: String?, qth: String?, grid: String?) async throws {
        try await database.dbWriter.write { db in
            let key = callsign.uppercased()
            if var existing = try CallsignHistory.fetchOne(db, id: key) {
                if let name = name, !name.isEmpty { existing.name = name }
                if let qth = qth, !qth.isEmpty { existing.qth = qth }
                if let grid = grid, !grid.isEmpty { existing.grid = grid }
                try existing.update(db)
            } else {
                let history = CallsignHistory(
                    callsign: key,
                    name: name,
                    qth: qth,
                    grid: grid
                )
                try history.insert(db)
            }
        }
    }
}
