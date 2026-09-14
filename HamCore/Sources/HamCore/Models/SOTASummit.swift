import Foundation
import GRDB

struct SOTASummit: Codable, Identifiable, Equatable {
    var code: String              // e.g. "W4C/CM-001"
    var codeNormalized: String?   // e.g. "W4CCM001"
    var name: String
    var associationCode: String?
    var regionCode: String?
    var altitude: Int?            // Meters
    var points: Int?
    var grid: String?
    var latitude: Double?
    var longitude: Double?
    var validFrom: String?
    var validTo: String?

    var id: String { code }

    /// Display string: "W4C/CM-001 Mount Mitchell"
    var displayName: String {
        "\(code) \(name)"
    }

    /// Creates a normalized code by stripping slashes and dashes
    static func normalize(_ code: String) -> String {
        code.replacingOccurrences(of: "/", with: "")
            .replacingOccurrences(of: "-", with: "")
            .uppercased()
    }
}

extension SOTASummit: FetchableRecord, PersistableRecord {
    static var databaseTableName = "sotaSummit"
}
