import Foundation
import Observation

@MainActor @Observable
final class NewLogViewModel {
    private static let suggestionLimit = 5
    private let database: AppDatabase
    private let logRepo: LogRepository
    private let refRepo: ReferenceRepository
    private let locationService = LocationService()

    var myCallsign: String = ""
    var myGrid: String = ""
    var potaReference: String = "" {
        didSet { searchParks() }
    }
    var sotaReference: String = "" {
        didSet { searchSummits() }
    }
    var parkName: String?
    var summitName: String?
    var parkSearchResults: [POTAPark] = []
    var summitSearchResults: [SOTASummit] = []
    var hasPOTAData = false
    var hasSOTAData = false

    // Nearby references
    var nearbyParks: [POTAPark] = []
    var nearbySummits: [SOTASummit] = []
    var isPotaFieldFocused = false
    var isSotaFieldFocused = false

    var userLatitude: Double? { locationService.currentLatitude }
    var userLongitude: Double? { locationService.currentLongitude }

    /// Show nearby parks when POTA field is focused and query is short
    var showNearbyParks: Bool {
        isPotaFieldFocused && potaReference.count < 2 && !nearbyParks.isEmpty
    }

    /// Show nearby summits when SOTA field is focused and query is short
    var showNearbySummits: Bool {
        isSotaFieldFocused && sotaReference.count < 2 && !nearbySummits.isEmpty
    }

    private var searchTask: Task<Void, Never>?

    init(database: AppDatabase) {
        self.database = database
        self.logRepo = LogRepository(database: database)
        self.refRepo = ReferenceRepository(database: database)
    }

    func checkReferenceData() async {
        let potaMeta = try? await refRepo.fetchMetadata(key: "potaParks")
        hasPOTAData = (potaMeta?.recordCount ?? 0) > 0
        let sotaMeta = try? await refRepo.fetchMetadata(key: "sotaSummits")
        hasSOTAData = (sotaMeta?.recordCount ?? 0) > 0
    }

    func loadSavedCallsign() {
        if let saved = KeychainService.load(key: .myCallsign) {
            myCallsign = saved
        }
    }

    func requestLocation() {
        locationService.requestPermission()
        locationService.requestLocation()
        if let grid = locationService.currentGrid {
            myGrid = grid
        }
        // Observe for updates
        Task { @MainActor in
            // Wait briefly for location
            try? await Task.sleep(for: .seconds(2))
            if let grid = locationService.currentGrid {
                myGrid = grid
            }
            await loadNearbyReferences()
        }
    }

    func loadNearbyReferences() async {
        guard let lat = locationService.currentLatitude,
              let lon = locationService.currentLongitude else { return }
        nearbyParks = (try? await refRepo.nearbyParks(latitude: lat, longitude: lon, limit: Self.suggestionLimit)) ?? []
        nearbySummits = (try? await refRepo.nearbySummits(latitude: lat, longitude: lon, limit: Self.suggestionLimit)) ?? []
    }

    /// Distance in miles from user to a coordinate, or nil if location unavailable.
    func distanceMiles(to latitude: Double?, longitude: Double?) -> Double? {
        guard let userLat = locationService.currentLatitude,
              let userLon = locationService.currentLongitude,
              let lat = latitude, let lon = longitude else { return nil }
        let km = POTALocationService.approxDistanceKm(lat1: userLat, lon1: userLon, lat2: lat, lon2: lon)
        return POTALocationService.kmToMiles(km)
    }

    func selectPark(_ park: POTAPark) {
        potaReference = park.reference
        parkName = park.name
        parkSearchResults = []
    }

    func selectSummit(_ summit: SOTASummit) {
        sotaReference = summit.code
        summitName = summit.name
        summitSearchResults = []
    }

    func createLog() async throws -> Log {
        let call = myCallsign.sanitizedCallsign

        // Save callsign for next time
        try? KeychainService.save(key: .myCallsign, value: call)

        var log = Log(
            createdAt: Date(),
            date: Date().adifDate,
            myCallsign: call,
            myGrid: myGrid.isEmpty ? nil : myGrid,
            potaReference: potaReference.isEmpty ? nil : potaReference.uppercased(),
            sotaReference: sotaReference.isEmpty ? nil : sotaReference.uppercased(),
            parkName: parkName,
            summitName: summitName
        )

        try await logRepo.save(&log)
        return log
    }

    private func searchParks() {
        searchTask?.cancel()
        let query = potaReference
        guard query.count >= 2 else {
            parkSearchResults = []
            parkName = nil
            return
        }
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            let results = try? await refRepo.searchParks(query: query, limit: Self.suggestionLimit)
            let normalized = POTAPark.normalize(query)
            parkSearchResults = results ?? []
            // Exact match on normalized reference
            if let exact = results?.first(where: { $0.referenceNormalized == normalized }) {
                parkName = exact.name
            }
        }
    }

    private func searchSummits() {
        searchTask?.cancel()
        let query = sotaReference
        guard query.count >= 2 else {
            summitSearchResults = []
            summitName = nil
            return
        }
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            let results = try? await refRepo.searchSummits(query: query, limit: Self.suggestionLimit)
            summitSearchResults = results ?? []
            if let exact = results?.first(where: { $0.code == query.uppercased() }) {
                summitName = exact.name
            }
        }
    }
}
