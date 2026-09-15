import Foundation
import HamCore

extension CWMacro {
    /// The six message keys a new install starts with. HamCore stores macros
    /// but leaves their content to the app; these are seeded on first use and
    /// restored by "Restore Defaults".
    static let defaults: [CWMacro] = [
        CWMacro(position: 0, label: "CQ", template: "CQ {activity} DE {myCall} K"),
        CWMacro(position: 1, label: "?", template: "{call}?"),
        CWMacro(position: 2, label: "EXCH", template: "{call} UR {rst} {rst} BK"),
        CWMacro(position: 3, label: "TU", template: "BK TU 72 DE {myCall} E E"),
        CWMacro(position: 4, label: "CALL", template: "{myCall}"),
        CWMacro(position: 5, label: "S2S", template: "BK {rst} ON {mySOTA} BK"),
    ]
}
