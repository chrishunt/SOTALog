import Foundation
import GRDB

public struct QSO: Codable, Identifiable, Equatable {
    public var id: Int64?
    public var logId: Int64?
    public var callsign: String
    public var date: String          // YYYYMMDD
    public var timeOn: String        // HHMM UTC
    public var frequency: Double?    // MHz
    public var band: String          // e.g. "20m"
    public var mode: String          // Default "CW"
    public var rstSent: String       // Default "599"
    public var rstReceived: String   // Default "599"
    public var name: String?
    public var qth: String?
    public var grid: String?
    public var sotaRef: String?      // Formatted: "W4C/CM-001"
    public var potaRef: String?      // e.g. "US-0001"
    public var notes: String?
    public var qrzLogId: Int64?
    public var syncedToQRZ: Bool

    public init(
        id: Int64? = nil,
        logId: Int64? = nil,
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
    public static var databaseTableName = "qso"

    public mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}
