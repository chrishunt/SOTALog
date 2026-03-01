import Foundation
import GRDB

struct POTAPark: Codable, Identifiable, Equatable {
    var reference: String
    var name: String
    var locationCode: String
    var grid4: String?
    var grid6: String?
    var latitude: Double?
    var longitude: Double?
    var active: Bool?

    var id: String { reference }

    /// Display string: "US-4431 Prescott NF"
    var displayName: String {
        "\(reference) \(name)"
    }
}

extension POTAPark: FetchableRecord, PersistableRecord {
    static var databaseTableName = "potaPark"
}
