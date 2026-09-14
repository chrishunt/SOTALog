import Foundation
import GRDB

public struct Log: Codable, Identifiable, Equatable, Hashable {
    public var id: Int64?
    public var createdAt: Date?
    public var date: String
    public var myCallsign: String
    public var myGrid: String?
    public var potaReference: String?
    public var sotaReference: String?
    public var parkName: String?
    public var summitName: String?
    public var notes: String?

    public init(
        id: Int64? = nil,
        createdAt: Date? = nil,
        date: String = "",
        myCallsign: String = "",
        myGrid: String? = nil,
        potaReference: String? = nil,
        sotaReference: String? = nil,
        parkName: String? = nil,
        summitName: String? = nil,
        notes: String? = nil
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
    }

    /// Formats "20240315" as "2024-03-15" for display
    public var formattedDate: String {
        guard date.count == 8 else { return date }
        let y = date.prefix(4)
        let m = date.dropFirst(4).prefix(2)
        let d = date.dropFirst(6).prefix(2)
        return "\(y)-\(m)-\(d)"
    }

    /// Whether this activation is a POTA activation
    public var isPOTA: Bool { potaReference != nil }

    /// Whether this activation is a SOTA activation
    public var isSOTA: Bool { sotaReference != nil }

    /// Display name for the activation reference (shows both for dual activations)
    public var referenceDisplay: String? {
        var parts: [String] = []
        if let ref = potaReference { parts.append(ref) }
        if let ref = sotaReference { parts.append(ref) }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

extension Log: FetchableRecord, MutablePersistableRecord {
    public static var databaseTableName = "log"

    public mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}
