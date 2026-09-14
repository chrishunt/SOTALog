import Foundation
import GRDB

public struct POTAPark: Codable, Identifiable, Equatable {
    public var reference: String
    public var name: String
    public var referenceNormalized: String?
    public var latitude: Double?
    public var longitude: Double?
    public var locationDesc: String?

    public init(
        reference: String,
        name: String,
        referenceNormalized: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        locationDesc: String? = nil
    ) {
        self.reference = reference
        self.name = name
        self.referenceNormalized = referenceNormalized
        self.latitude = latitude
        self.longitude = longitude
        self.locationDesc = locationDesc
    }

    public var id: String { reference }

    /// Display string: "US-4431 Prescott NF"
    public var displayName: String {
        "\(reference) \(name)"
    }

    /// Strips dashes and uppercases: "US-4431" → "US4431"
    public static func normalize(_ reference: String) -> String {
        reference.replacingOccurrences(of: "-", with: "").uppercased()
    }
}

extension POTAPark: FetchableRecord, PersistableRecord {
    public static var databaseTableName = "potaPark"
}
