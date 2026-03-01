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
