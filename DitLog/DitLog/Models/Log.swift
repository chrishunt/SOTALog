import Foundation
import GRDB

struct Log: Codable, Identifiable, Equatable, Hashable {
    var id: Int64?
    var createdAt: Date?
    var date: String
    var myCallsign: String
    var myGrid: String?
    var potaReference: String?
    var sotaReference: String?
    var parkName: String?
    var summitName: String?
    var notes: String?
    var isActive: Bool

    init(
        id: Int64? = nil,
        createdAt: Date? = nil,
        date: String = "",
        myCallsign: String = "",
        myGrid: String? = nil,
        potaReference: String? = nil,
        sotaReference: String? = nil,
        parkName: String? = nil,
        summitName: String? = nil,
        notes: String? = nil,
        isActive: Bool = false
    ) {
        self.id = id
        self.createdAt = createdAt
        self.date = date
        self.myCallsign = myCallsign
        self.myGrid = myGrid
        self.potaReference = potaReference
        self.sotaReference = sotaReference
        self.parkName = parkName
        self.summitName = summitName
        self.notes = notes
        self.isActive = isActive
    }

    /// Whether this activation is a POTA activation
    var isPOTA: Bool { potaReference != nil }

    /// Whether this activation is a SOTA activation
    var isSOTA: Bool { sotaReference != nil }

    /// Display name for the activation reference
    var referenceDisplay: String? {
        if let ref = potaReference {
            return parkName.map { "\(ref) \($0)" } ?? ref
        }
        if let ref = sotaReference {
            return summitName.map { "\(ref) \($0)" } ?? ref
        }
        return nil
    }

    /// The activation threshold for this log type
    var activationThreshold: Int {
        if isSOTA { return 4 }
        if isPOTA { return 10 }
        return 0
    }

    /// Label for the threshold display
    var thresholdLabel: String {
        if isSOTA { return "SOTA" }
        if isPOTA { return "POTA" }
        return ""
    }
}

extension Log: FetchableRecord, MutablePersistableRecord {
    static var databaseTableName = "log"

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}
