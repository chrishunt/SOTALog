import Foundation
import GRDB

struct QSO: Codable, Identifiable, Equatable {
    var id: Int64?
    var logId: Int64
    var callsign: String
    var date: String          // YYYYMMDD
    var timeOn: String        // HHMM UTC
    var frequency: Double?    // MHz
    var band: String          // e.g. "20m"
    var mode: String          // Default "CW"
    var rstSent: String       // Default "599"
    var rstReceived: String   // Default "599"
    var name: String?
    var qth: String?
    var grid: String?
    var sotaRef: String?      // Formatted: "W4C/CM-001"
    var potaRef: String?      // e.g. "US-0001"
    var notes: String?
    var qrzLogId: Int64?
    var syncedToQRZ: Bool

    init(
        id: Int64? = nil,
        logId: Int64,
        callsign: String = "",
        date: String = "",
        timeOn: String = "",
        frequency: Double? = nil,
        band: String = "20m",
        mode: String = "CW",
        rstSent: String = "599",
        rstReceived: String = "599",
        name: String? = nil,
        qth: String? = nil,
        grid: String? = nil,
        sotaRef: String? = nil,
        potaRef: String? = nil,
        notes: String? = nil,
        qrzLogId: Int64? = nil,
        syncedToQRZ: Bool = false
    ) {
        self.id = id
        self.logId = logId
        self.callsign = callsign
        self.date = date
        self.timeOn = timeOn
        self.frequency = frequency
        self.band = band
        self.mode = mode
        self.rstSent = rstSent
        self.rstReceived = rstReceived
        self.name = name
        self.qth = qth
        self.grid = grid
        self.sotaRef = sotaRef
        self.potaRef = potaRef
        self.notes = notes
        self.qrzLogId = qrzLogId
        self.syncedToQRZ = syncedToQRZ
    }
}

extension QSO: FetchableRecord, MutablePersistableRecord {
    static var databaseTableName = "qso"

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}
