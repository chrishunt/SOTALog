import Foundation
import Observation

@Observable
final class SpotsViewModel {
    enum SourceFilter: String {
        case all, pota, sota
    }

    var spots: [Spot] = []
    var sourceFilter: SourceFilter = .all
    var isLoading = false
    var errorMessage: String?

    /// Spots consolidated (one per callsign), grouped by band, sorted by frequency then time.
    var spotsByBand: [(band: String, spots: [Spot])] {
        let consolidated = consolidatedSpots(spots)

        let filtered: [Spot]
        switch sourceFilter {
        case .all:  filtered = consolidated
        case .pota: filtered = consolidated.filter { $0.potaReference != nil }
        case .sota: filtered = consolidated.filter { $0.sotaReference != nil }
        }

        // Group by band
        var grouped: [String: [Spot]] = [:]
        for spot in filtered {
            grouped[spot.band, default: []].append(spot)
        }

        // Sort spots within each band: non-QRT first, then frequency ascending, then time descending
        for (band, bandSpots) in grouped {
            grouped[band] = bandSpots.sorted { a, b in
                if a.isQRT != b.isQRT { return !a.isQRT }
                if a.frequency != b.frequency { return a.frequency < b.frequency }
                return a.timestamp > b.timestamp
            }
        }

        // Order bands by BandPlan order
        return BandPlan.allBands.compactMap { band in
            guard let bandSpots = grouped[band], !bandSpots.isEmpty else { return nil }
            return (band: band, spots: bandSpots)
        }
    }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }

        do {
            async let potaSpots = POTASpotService.fetchSpots()
            async let sotaSpots = SOTASpotService.fetchSpots()

            let (pota, sota) = try await (potaSpots, sotaSpots)
            spots = pota + sota
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func startAutoRefresh() async {
        await refresh()

        // Auto-refresh every 60 seconds
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(60))
            guard !Task.isCancelled else { break }
            await refresh()
        }
    }

    /// Find a spot for a given callsign (for auto-populating QSO entry)
    func spotForCallsign(_ callsign: String) -> Spot? {
        let consolidated = consolidatedSpots(spots)
        return consolidated.first { $0.activatorCallsign.uppercased() == callsign.uppercased() && !$0.isExpired() && !$0.isQRT }
    }

    /// Consolidates spots: latest per callsign, merging POTA+SOTA references for same callsign.
    private func consolidatedSpots(_ allSpots: [Spot]) -> [Spot] {
        var byCallsign: [String: Spot] = [:]

        // Sort by timestamp descending so first encounter per callsign is the newest
        let sorted = allSpots.sorted { $0.timestamp > $1.timestamp }

        for spot in sorted {
            let key = spot.activatorCallsign.uppercased()

            if var existing = byCallsign[key] {
                // Merge references from this spot into the existing (newer) one
                if existing.potaReference == nil, let ref = spot.potaReference {
                    existing.potaReference = ref
                    existing.potaReferenceName = spot.potaReferenceName
                }
                if existing.sotaReference == nil, let ref = spot.sotaReference {
                    existing.sotaReference = ref
                    existing.sotaReferenceName = spot.sotaReferenceName
                }
                byCallsign[key] = existing
            } else {
                byCallsign[key] = spot
            }
        }

        return Array(byCallsign.values)
    }
}
