import Foundation
import GRDB

/// Cached enrichment for a callsign (name/QTH/grid from QRZ and prior contacts).
/// The "times worked" count is NOT stored here — it is derived on demand from the
/// `qso` table (see `QSORepository.countForCallsign`), which is the single source
/// of truth and stays correct across edits, deletes, and imports automatically.
struct CallsignHistory: Codable, Identifiable, Equatable {
    var callsign: String
    var name: String?
    var qth: String?
    var grid: String?
    var lastWorked: Date?

    var id: String { callsign }

    init(
        callsign: String,
        name: String? = nil,
        qth: String? = nil,
        grid: String? = nil,
        lastWorked: Date? = nil
    ) {
        self.callsign = callsign
        self.name = name
        self.qth = qth
        self.grid = grid
        self.lastWorked = lastWorked
    }
}

extension CallsignHistory: FetchableRecord, PersistableRecord {
    static var databaseTableName = "callsignHistory"
}
