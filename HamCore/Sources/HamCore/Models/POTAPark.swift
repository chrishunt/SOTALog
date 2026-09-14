import Foundation
import GRDB

struct POTAPark: Codable, Identifiable, Equatable {
    var reference: String
    var name: String
    var referenceNormalized: String?
    var latitude: Double?
    var longitude: Double?
    var locationDesc: String?

    var id: String { reference }

    /// Display string: "US-4431 Prescott NF"
    var displayName: String {
        "\(reference) \(name)"
    }

    /// Strips dashes and uppercases: "US-4431" → "US4431"
    static func normalize(_ reference: String) -> String {
        reference.replacingOccurrences(of: "-", with: "").uppercased()
    }
}

extension POTAPark: FetchableRecord, PersistableRecord {
    static var databaseTableName = "potaPark"
}
