import Foundation

/// Unified spot from POTA or SOTA. In-memory only, not persisted.
struct Spot: Identifiable, Equatable {
    enum Source: String {
        case pota, sota
    }

    let id: String
    let source: Source
    let activatorCallsign: String
    let frequency: Double        // MHz
    let mode: String
    let reference: String        // Park or summit reference
    let referenceName: String?
    let spotterCallsign: String?
    let comments: String?
    let timestamp: Date

    /// Whether this spot is older than the expiry threshold
    func isExpired(after minutes: Double = 10) -> Bool {
        Date().timeIntervalSince(timestamp) > minutes * 60
    }

    /// Whether comments contain "QRT"
    var isQRT: Bool {
        guard let comments = comments else { return false }
        return comments.uppercased().contains("QRT")
    }

    /// The band derived from frequency
    var band: String {
        BandPlan.band(for: frequency) ?? "?"
    }

    /// Age of the spot in minutes
    var ageMinutes: Int {
        Int(Date().timeIntervalSince(timestamp) / 60)
    }
}
