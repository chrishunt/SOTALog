import Foundation

/// Result from QRZ XML callsign lookup
public struct QRZCallsignResult: Equatable {
    public let callsign: String
    public let firstName: String?
    public let nickname: String?
    public let lastName: String?
    public let city: String?
    public let state: String?
    public let country: String?
    public let grid: String?
    public let county: String?

    public init(
        callsign: String,
        firstName: String? = nil,
        nickname: String? = nil,
        lastName: String? = nil,
        city: String? = nil,
        state: String? = nil,
        country: String? = nil,
        grid: String? = nil,
        county: String? = nil
    ) {
        self.callsign = callsign
        self.firstName = firstName
        self.nickname = nickname
        self.lastName = lastName
        self.city = city
        self.state = state
        self.country = country
        self.grid = grid
        self.county = county
    }

    /// Combined name for display
    public var name: String? {
        if let nickname { return nickname }
        return [firstName, lastName].compactMap { $0 }.joined(separator: " ").nilIfEmpty
    }

    /// QTH for display — state for US, country otherwise
    public var qth: String? {
        state ?? country
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
