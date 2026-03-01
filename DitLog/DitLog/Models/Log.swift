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

    /// Display name for the activation reference (shows both for dual activations)
    var referenceDisplay: String? {
        var parts: [String] = []
        if let ref = potaReference { parts.append(ref) }
        if let ref = sotaReference { parts.append(ref) }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

extension Log: FetchableRecord, MutablePersistableRecord {
    static var databaseTableName = "log"

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}
