import Foundation

/// Result from QRZ XML callsign lookup
struct QRZCallsignResult: Equatable {
    let callsign: String
    let firstName: String?
    let nickname: String?
    let lastName: String?
    let city: String?
    let state: String?
    let country: String?
    let grid: String?
    let county: String?

    /// Combined name for display
    var name: String? {
        if let nickname { return nickname }
        return [firstName, lastName].compactMap { $0 }.joined(separator: " ").nilIfEmpty
    }

    /// QTH for display — state for US, country otherwise
    var qth: String? {
        state ?? country
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
