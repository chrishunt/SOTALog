import XCTest
@testable import SOTALog

// MARK: - Distance Calculation

final class DistanceCalculationTests: XCTestCase {
    func testApproxDistanceKnownPoints() {
        // New York (40.7128, -74.0060) to Philadelphia (39.9526, -75.1652)
        let km = POTALocationService.approxDistanceKm(
            lat1: 40.7128, lon1: -74.0060,
            lat2: 39.9526, lon2: -75.1652
        )
        // Actual distance ~130 km; equirectangular should be within 10%
        XCTAssertGreaterThan(km, 100)
        XCTAssertLessThan(km, 160)
    }

    func testZeroDistance() {
        let km = POTALocationService.approxDistanceKm(
            lat1: 35.0, lon1: -82.0, lat2: 35.0, lon2: -82.0
        )
        XCTAssertEqual(km, 0, accuracy: 0.001)
    }

    func testKmToMiles() {
        let miles = POTALocationService.kmToMiles(100)
        XCTAssertEqual(miles, 62.1371, accuracy: 0.01)
    }
}

// MARK: - Nearest Location Codes

final class NearestLocationCodesTests: XCTestCase {
    func testSortsByDistance() {
        let locations: [POTALocationService.Location] = [
            .init(locationCode: "US-CA", latitude: 37.0, longitude: -120.0, entityId: 291),
            .init(locationCode: "US-NC", latitude: 35.5, longitude: -80.0, entityId: 291),
            .init(locationCode: "US-ME", latitude: 45.0, longitude: -69.0, entityId: 291),
        ]
        // User in North Carolina
        let nearest = POTALocationService.nearestLocationCodes(
            latitude: 35.6, longitude: -82.5, from: locations, limit: 3
        )
        XCTAssertEqual(nearest[0].locationCode, "US-NC")
    }

    func testLimitWorks() {
        let locations: [POTALocationService.Location] = [
            .init(locationCode: "US-CA", latitude: 37.0, longitude: -120.0, entityId: 291),
            .init(locationCode: "US-NC", latitude: 35.5, longitude: -80.0, entityId: 291),
            .init(locationCode: "US-ME", latitude: 45.0, longitude: -69.0, entityId: 291),
        ]
        let nearest = POTALocationService.nearestLocationCodes(
            latitude: 35.6, longitude: -82.5, from: locations, limit: 1
        )
        XCTAssertEqual(nearest.count, 1)
    }

    func testSkipsNilCoordinates() {
        let locations: [POTALocationService.Location] = [
            .init(locationCode: "US-XX", latitude: nil, longitude: nil, entityId: 291),
            .init(locationCode: "US-NC", latitude: 35.5, longitude: -80.0, entityId: 291),
        ]
        let nearest = POTALocationService.nearestLocationCodes(
            latitude: 35.6, longitude: -82.5, from: locations, limit: 10
        )
        XCTAssertEqual(nearest.count, 1)
        XCTAssertEqual(nearest[0].locationCode, "US-NC")
    }
}

// MARK: - Nearby Summits (In-Memory DB)

final class NearbySummitQueryTests: XCTestCase {
    func testNearbySummitsSortedByDistance() async throws {
        let db = try AppDatabase.empty()
        let refRepo = ReferenceRepository(database: db)

        // Insert summits at known coordinates
        let summits = [
            SOTASummit(
                code: "W4C/CM-001", codeNormalized: "W4CCM001", name: "Mount Mitchell",
                latitude: 35.765, longitude: -82.265
            ),
            SOTASummit(
                code: "W4C/CM-002", codeNormalized: "W4CCM002", name: "Clingmans Dome",
                latitude: 35.563, longitude: -83.498
            ),
            SOTASummit(
                code: "W4T/SU-001", codeNormalized: "W4TSU001", name: "Clingmans Dome TN",
                latitude: 35.563, longitude: -83.499
            ),
            // Far away summit — should not appear
            SOTASummit(
                code: "W7A/MR-001", codeNormalized: "W7AMR001", name: "Humphreys Peak",
                latitude: 35.346, longitude: -111.678
            ),
        ]
        try await refRepo.importSummits(summits)

        // Query from near Mount Mitchell
        let nearby = try await refRepo.nearbySummits(latitude: 35.77, longitude: -82.27)

        // Mount Mitchell should be closest
        XCTAssertEqual(nearby.first?.code, "W4C/CM-001")
        // Far away summit excluded by bounding box
        XCTAssertFalse(nearby.contains { $0.code == "W7A/MR-001" })
    }

    func testNearbySummitsEmptyWhenNoneInRange() async throws {
        let db = try AppDatabase.empty()
        let refRepo = ReferenceRepository(database: db)

        let summits = [
            SOTASummit(
                code: "W7A/MR-001", codeNormalized: "W7AMR001", name: "Humphreys Peak",
                latitude: 35.346, longitude: -111.678
            ),
        ]
        try await refRepo.importSummits(summits)

        // Query from east coast — far from Arizona
        let nearby = try await refRepo.nearbySummits(latitude: 35.77, longitude: -82.27)
        XCTAssertTrue(nearby.isEmpty)
    }
}

// MARK: - Nearby Parks (In-Memory DB)

final class NearbyParkQueryTests: XCTestCase {
    func testNearbyParksWithCoordinates() async throws {
        let db = try AppDatabase.empty()
        let refRepo = ReferenceRepository(database: db)

        // Import parks without coordinates
        let parks = [
            POTAPark(reference: "US-0001", name: "Acadia NP", referenceNormalized: "US0001"),
            POTAPark(reference: "US-0002", name: "Pisgah NF", referenceNormalized: "US0002"),
        ]
        try await refRepo.importParks(parks)

        // Enrich with coordinates
        try await refRepo.enrichParksWithCoordinates([
            (reference: "US-0001", latitude: 44.338, longitude: -68.273),
            (reference: "US-0002", latitude: 35.345, longitude: -82.824),
        ])

        // Query from near Pisgah
        let nearby = try await refRepo.nearbyParks(latitude: 35.4, longitude: -82.8)
        XCTAssertEqual(nearby.first?.reference, "US-0002")
        // Acadia is too far (>1 degree away)
        XCTAssertFalse(nearby.contains { $0.reference == "US-0001" })
    }

    func testParksWithoutCoordinatesExcluded() async throws {
        let db = try AppDatabase.empty()
        let refRepo = ReferenceRepository(database: db)

        let parks = [
            POTAPark(reference: "US-0001", name: "Acadia NP", referenceNormalized: "US0001"),
        ]
        try await refRepo.importParks(parks)

        let nearby = try await refRepo.nearbyParks(latitude: 44.338, longitude: -68.273)
        XCTAssertTrue(nearby.isEmpty)
    }
}
