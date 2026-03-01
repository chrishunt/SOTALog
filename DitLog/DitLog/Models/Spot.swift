import Foundation

/// Unified spot from POTA or SOTA. In-memory only, not persisted.
struct Spot: Identifiable, Equatable {
    enum Source: String {
        case pota, sota
    }

    let id: String
    let activatorCallsign: String
    let frequency: Double        // MHz
    let mode: String

    // Dual reference fields — a spot can have both POTA and SOTA refs (after consolidation)
    var potaReference: String?
    var potaReferenceName: String?
    var sotaReference: String?
    var sotaReferenceName: String?

    let spotterCallsign: String?
    let comments: String?
    let timestamp: Date

    /// Which sources contributed to this spot
    var sources: Set<Source> {
        var s = Set<Source>()
        if potaReference != nil { s.insert(.pota) }
        if sotaReference != nil { s.insert(.sota) }
        return s
    }

    /// Primary source (backwards compat)
    var source: Source {
        if potaReference != nil { return .pota }
        return .sota
    }

    /// Primary reference (backwards compat)
    var reference: String {
        potaReference ?? sotaReference ?? ""
    }

    /// Primary reference name (backwards compat)
    var referenceName: String? {
        potaReferenceName ?? sotaReferenceName
    }

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

    /// Age of the spot in minutes (minimum 1 — a visible spot is never truly 0m old)
    var ageMinutes: Int {
        max(1, Int(Date().timeIntervalSince(timestamp) / 60))
    }
}
