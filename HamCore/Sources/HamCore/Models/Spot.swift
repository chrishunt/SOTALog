import Foundation

/// Unified spot from POTA or SOTA. In-memory only, not persisted.
public struct Spot: Identifiable, Equatable {
    public enum Source: String {
        case pota, sota
    }

    public let id: String
    public let activatorCallsign: String
    public let frequency: Double        // MHz
    public let mode: String

    // Dual reference fields — a spot can have both POTA and SOTA refs (after consolidation)
    public var potaReference: String?
    public var potaReferenceName: String?
    public var sotaReference: String?
    public var sotaReferenceName: String?

    public let spotterCallsign: String?
    public let comments: String?
    public let timestamp: Date

    public init(
        id: String,
        activatorCallsign: String,
        frequency: Double,
        mode: String,
        potaReference: String? = nil,
        potaReferenceName: String? = nil,
        sotaReference: String? = nil,
        sotaReferenceName: String? = nil,
        spotterCallsign: String? = nil,
        comments: String? = nil,
        timestamp: Date
    ) {
        self.id = id
        self.activatorCallsign = activatorCallsign
        self.frequency = frequency
        self.mode = mode
        self.potaReference = potaReference
        self.potaReferenceName = potaReferenceName
        self.sotaReference = sotaReference
        self.sotaReferenceName = sotaReferenceName
        self.spotterCallsign = spotterCallsign
        self.comments = comments
        self.timestamp = timestamp
    }

    /// Which sources contributed to this spot
    public var sources: Set<Source> {
        var s = Set<Source>()
        if potaReference != nil { s.insert(.pota) }
        if sotaReference != nil { s.insert(.sota) }
        return s
    }

    /// Primary source (backwards compat)
    public var source: Source {
        if potaReference != nil { return .pota }
        return .sota
    }

    /// Primary reference (backwards compat)
    public var reference: String {
        potaReference ?? sotaReference ?? ""
    }

    /// Primary reference name (backwards compat)
    public var referenceName: String? {
        potaReferenceName ?? sotaReferenceName
    }

    /// Whether this spot is older than the expiry threshold
    public func isExpired(after minutes: Double = 60) -> Bool {
        Date().timeIntervalSince(timestamp) > minutes * 60
    }

    /// Whether comments contain "QRT"
    public var isQRT: Bool {
        guard let comments = comments else { return false }
        return comments.uppercased().contains("QRT")
    }

    /// The band derived from frequency
    public var band: String {
        BandPlan.band(for: frequency) ?? "?"
    }

    /// Age of the spot in minutes (minimum 1 — a visible spot is never truly 0m old)
    public var ageMinutes: Int {
        max(1, Int(Date().timeIntervalSince(timestamp) / 60))
    }
}
