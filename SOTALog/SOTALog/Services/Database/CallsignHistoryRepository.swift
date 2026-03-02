import Foundation
import GRDB

struct CallsignHistoryRepository {
    let database: AppDatabase

    /// Fetches the history for a callsign
    func fetch(callsign: String) async throws -> CallsignHistory? {
        try await database.dbWriter.read { db in
            try CallsignHistory.fetchOne(db, id: callsign.uppercased())
        }
    }

    /// Updates history when a QSO is saved.
    /// Increments timesWorked, updates lastWorked, and fills in name/qth/grid if provided.
    func recordQSO(callsign: String, name: String?, qth: String?, grid: String?) async throws {
        try await database.dbWriter.write { db in
            let key = callsign.uppercased()
            if var existing = try CallsignHistory.fetchOne(db, id: key) {
                existing.timesWorked += 1
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
                    lastWorked: Date(),
                    timesWorked: 1
                )
                try history.insert(db)
            }
        }
    }

    /// Rebuilds callsignHistory from the QSO table, setting timesWorked to the true count.
    /// Preserves richer name/qth/grid from prior QRZ XML lookups via COALESCE.
    func rebuildFromQSOTable() async throws {
        try await database.dbWriter.write { db in
            try db.execute(sql: """
                INSERT INTO callsignHistory (callsign, timesWorked, name, qth, grid)
                SELECT UPPER(callsign), COUNT(*), MAX(name), MAX(qth), MAX(grid)
                FROM qso GROUP BY UPPER(callsign)
                ON CONFLICT(callsign) DO UPDATE SET
                    timesWorked = excluded.timesWorked,
                    name = COALESCE(callsignHistory.name, excluded.name),
                    qth = COALESCE(callsignHistory.qth, excluded.qth),
                    grid = COALESCE(callsignHistory.grid, excluded.grid)
                """)
        }
    }

    /// Updates history with data from QRZ lookup (without incrementing count)
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
                    grid: grid,
                    timesWorked: 0
                )
                try history.insert(db)
            }
        }
    }
}
