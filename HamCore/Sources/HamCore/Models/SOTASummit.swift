import Foundation
import GRDB

public struct SOTASummit: Codable, Identifiable, Equatable {
    public var code: String              // e.g. "W4C/CM-001"
    public var codeNormalized: String?   // e.g. "W4CCM001"
    public var name: String
    public var associationCode: String?
    public var regionCode: String?
    public var altitude: Int?            // Meters
    public var points: Int?
    public var grid: String?
    public var latitude: Double?
    public var longitude: Double?
    public var validFrom: String?
    public var validTo: String?

    public init(
        code: String,
        codeNormalized: String? = nil,
        name: String,
        associationCode: String? = nil,
        regionCode: String? = nil,
        altitude: Int? = nil,
        points: Int? = nil,
        grid: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        validFrom: String? = nil,
        validTo: String? = nil
    ) {
        self.code = code
        self.codeNormalized = codeNormalized
        self.name = name
        self.associationCode = associationCode
        self.regionCode = regionCode
        self.altitude = altitude
        self.points = points
        self.grid = grid
        self.latitude = latitude
        self.longitude = longitude
        self.validFrom = validFrom
        self.validTo = validTo
    }

    public var id: String { code }

    /// Display string: "W4C/CM-001 Mount Mitchell"
    public var displayName: String {
        "\(code) \(name)"
    }

    /// Creates a normalized code by stripping slashes and dashes
    public static func normalize(_ code: String) -> String {
        code.replacingOccurrences(of: "/", with: "")
            .replacingOccurrences(of: "-", with: "")
            .uppercased()
    }
}

extension SOTASummit: FetchableRecord, PersistableRecord {
    public static var databaseTableName = "sotaSummit"
}
