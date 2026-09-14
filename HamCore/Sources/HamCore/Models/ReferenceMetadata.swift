import Foundation
import GRDB

struct ReferenceMetadata: Codable, Identifiable, Equatable {
    var id: String { key }
    var key: String
    var lastRefreshed: Date?
    var recordCount: Int?
}

extension ReferenceMetadata: FetchableRecord, PersistableRecord {
    static var databaseTableName = "referenceMetadata"
}
