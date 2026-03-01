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

    var filteredSpots: [Spot] {
        let filtered: [Spot]
        switch sourceFilter {
        case .all:  filtered = spots
        case .pota: filtered = spots.filter { $0.source == .pota }
        case .sota: filtered = spots.filter { $0.source == .sota }
        }

        // Sort: non-QRT first, then by timestamp descending
        return filtered.sorted { a, b in
            if a.isQRT != b.isQRT { return !a.isQRT }
            return a.timestamp > b.timestamp
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
        spots.first { $0.activatorCallsign.uppercased() == callsign.uppercased() && !$0.isExpired() && !$0.isQRT }
    }
}
