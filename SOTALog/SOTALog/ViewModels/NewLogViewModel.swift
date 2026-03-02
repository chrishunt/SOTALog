import Foundation
import Observation

@Observable
final class NewLogViewModel {
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

    private var searchTask: Task<Void, Never>?

    init(database: AppDatabase) {
        self.database = database
        self.logRepo = LogRepository(database: database)
        self.refRepo = ReferenceRepository(database: database)
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
        }
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
            let results = try? await refRepo.searchParks(query: query, limit: 5)
            let normalized = POTAPark.normalize(query)
            await MainActor.run {
                parkSearchResults = results ?? []
                // Exact match on normalized reference
                if let exact = results?.first(where: { $0.referenceNormalized == normalized }) {
                    parkName = exact.name
                }
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
            let results = try? await refRepo.searchSummits(query: query, limit: 5)
            await MainActor.run {
                summitSearchResults = results ?? []
                if let exact = results?.first(where: { $0.code == query.uppercased() }) {
                    summitName = exact.name
                }
            }
        }
    }
}
