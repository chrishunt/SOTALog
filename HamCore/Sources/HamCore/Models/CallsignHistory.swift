import Foundation
import GRDB

/// Cached enrichment for a callsign (name/QTH/grid from QRZ and prior contacts).
/// The "times worked" count is NOT stored here — it is derived on demand from the
/// `qso` table (see `QSORepository.countForCallsign`), which is the single source
/// of truth and stays correct across edits, deletes, and imports automatically.
public struct CallsignHistory: Codable, Identifiable, Equatable {
    public var callsign: String
    public var name: String?
    public var qth: String?
    public var grid: String?
    public var lastWorked: Date?

    public var id: String { callsign }

    public init(
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
    public static var databaseTableName = "callsignHistory"
}
