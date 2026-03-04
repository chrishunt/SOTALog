import Foundation
import GRDB

struct CWMacro: Codable, Identifiable, Equatable {
    var id: Int64?
    var position: Int
    var label: String
    var template: String

    init(
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

    static let defaults: [CWMacro] = [
        CWMacro(position: 0, label: "CQ", template: "CQ {activity} DE {myCall} K"),
        CWMacro(position: 1, label: "?", template: "{call}?"),
        CWMacro(position: 2, label: "EXCH", template: "{call} UR {rst} {rst} BK"),
        CWMacro(position: 3, label: "TU", template: "BK TU 72 DE {myCall} E E"),
        CWMacro(position: 4, label: "CALL", template: "{myCall}"),
        CWMacro(position: 5, label: "S2S", template: "BK UR {rst} {rst} ON {mySOTA} {mySOTA} TU S2S BK"),
    ]
}

extension CWMacro: FetchableRecord, MutablePersistableRecord {
    static var databaseTableName = "cwMacro"

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}
