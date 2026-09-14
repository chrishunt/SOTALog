import Foundation
import GRDB

public struct ReferenceMetadata: Codable, Identifiable, Equatable {
    public var id: String { key }
    public var key: String
    public var lastRefreshed: Date?
    public var recordCount: Int?

    public init(key: String, lastRefreshed: Date? = nil, recordCount: Int? = nil) {
        self.key = key
        self.lastRefreshed = lastRefreshed
        self.recordCount = recordCount
    }
}

extension ReferenceMetadata: FetchableRecord, PersistableRecord {
    public static var databaseTableName = "referenceMetadata"
}
