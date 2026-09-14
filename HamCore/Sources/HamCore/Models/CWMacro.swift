import Foundation
import GRDB

public struct CWMacro: Codable, Identifiable, Equatable {
    public var id: Int64?
    public var position: Int
    public var label: String
    public var template: String

    public init(
        id: Int64? = nil,
        position: Int,
        label: String,
        template: String
    ) {
        self.id = id
        self.position = position
        self.label = label
        self.template = template
    }

    public static let defaults: [CWMacro] = [
        CWMacro(position: 0, label: "CQ", template: "CQ {activity} DE {myCall} K"),
        CWMacro(position: 1, label: "?", template: "{call}?"),
        CWMacro(position: 2, label: "EXCH", template: "{call} UR {rst} {rst} BK"),
        CWMacro(position: 3, label: "TU", template: "BK TU 72 DE {myCall} E E"),
        CWMacro(position: 4, label: "CALL", template: "{myCall}"),
        CWMacro(position: 5, label: "S2S", template: "BK {rst} ON {mySOTA} BK"),
    ]
}

extension CWMacro: FetchableRecord, MutablePersistableRecord {
    public static var databaseTableName = "cwMacro"

    public mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}
