import Foundation
import Observation

@Observable
final class SpotsViewModel {
    enum SourceFilter: String {
        case all, pota, sota
    }

    enum ModeFilter: String {
        case all, cw, ssb
    }

    var spots: [Spot] = []
    var sourceFilter: SourceFilter = .all
    var modeFilter: ModeFilter = .all
    var isLoading = false
    var errorMessage: String?

    private var sotaEpoch: String?
    private var sotaSpots: [Spot] = []
    private var potaSpots: [Spot] = []

    init() {
        if let raw = UserDefaults.standard.string(forKey: "sourceFilter"),
           let saved = SourceFilter(rawValue: raw) {
            sourceFilter = saved
        }
        if let raw = UserDefaults.standard.string(forKey: "modeFilter"),
           let saved = ModeFilter(rawValue: raw) {
            modeFilter = saved
        }
    }

    /// Spots consolidated (one per callsign), grouped by band, sorted by frequency then time.
    var spotsByBand: [(band: String, spots: [Spot])] {
        let consolidated = consolidatedSpots(spots).filter { !$0.isQRT && !$0.isExpired() }

        let sourceFiltered: [Spot]
        switch sourceFilter {
        case .all:  sourceFiltered = consolidated
        case .pota: sourceFiltered = consolidated.filter { $0.potaReference != nil }
        case .sota: sourceFiltered = consolidated.filter { $0.sotaReference != nil }
        }

        let filtered: [Spot]
        switch modeFilter {
        case .all: filtered = sourceFiltered
        case .cw:  filtered = sourceFiltered.filter { $0.mode == "CW" }
        case .ssb: filtered = sourceFiltered.filter { $0.mode == "SSB" }
        }

        // Group by band
        var grouped: [String: [Spot]] = [:]
        for spot in filtered {
            grouped[spot.band, default: []].append(spot)
        }

        // Sort spots within each band by frequency ascending, then newest first
        for (band, bandSpots) in grouped {
            grouped[band] = bandSpots.sorted { a, b in
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
            async let pota = POTASpotService.fetchSpots()
            async let sota = SOTASpotService.fetchSpots()

            let (potaResult, sotaResult) = try await (pota, sota)
            potaSpots = potaResult
            sotaSpots = sotaResult
            sotaEpoch = nil  // Reset epoch so next poll fetches fresh
            spots = potaSpots + sotaSpots
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func startAutoRefresh() async {
        // Initial full fetch of both sources
        await refresh()

        var tickCount = 0

        // Poll every 20 seconds
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(20))
            guard !Task.isCancelled else { break }

            tickCount += 1

            do {
                // Every tick: check SOTA epoch, fetch only if changed
                let epoch = try await SOTASpotService.fetchEpoch()
                if epoch != sotaEpoch {
                    sotaSpots = try await SOTASpotService.fetchSpots()
                    sotaEpoch = epoch
                }

                // Every 3rd tick (~60s): also fetch POTA
                if tickCount % 3 == 0 {
                    potaSpots = try await POTASpotService.fetchSpots()
                }

                spots = potaSpots + sotaSpots
                errorMessage = nil
            } catch {
                errorMessage = error.localizedDescription
            }
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
