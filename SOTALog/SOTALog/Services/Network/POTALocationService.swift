import Foundation

enum POTALocationService {
    /// A POTA location (state/province/territory) with center coordinates.
    struct Location: Decodable {
        let locationCode: String
        let latitude: Double?
        let longitude: Double?
        let entityId: Int?

        enum CodingKeys: String, CodingKey {
            case locationCode = "locationDesc"
            case latitude
            case longitude
            case entityId
        }
    }

    /// A park with coordinates from the per-location API.
    struct ParkCoordinate: Decodable {
        let reference: String
        let latitude: Double?
        let longitude: Double?
    }

    /// Fetches all POTA locations (states/provinces/territories).
    static func fetchLocations() async throws -> [Location] {
        let url = URL(string: "https://api.pota.app/locations")!
        var request = URLRequest(url: url)
        request.setValue("SOTA Log/1.0", forHTTPHeaderField: "User-Agent")
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode([Location].self, from: data)
    }

    /// Fetches parks with coordinates for a specific location code.
    static func fetchParksInLocation(_ code: String) async throws -> [ParkCoordinate] {
        let encoded = code.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? code
        let url = URL(string: "https://api.pota.app/location/parks/\(encoded)")!
        var request = URLRequest(url: url)
        request.setValue("SOTA Log/1.0", forHTTPHeaderField: "User-Agent")
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode([ParkCoordinate].self, from: data)
    }

    /// Finds the nearest location codes to the user's position.
    /// Returns up to `limit` locations sorted by distance.
    static func nearestLocationCodes(
        latitude: Double,
        longitude: Double,
        from locations: [Location],
        limit: Int = 10
    ) -> [Location] {
        locations
            .compactMap { loc -> (Location, Double)? in
                guard let lat = loc.latitude, let lon = loc.longitude else { return nil }
                let dist = approxDistanceKm(lat1: latitude, lon1: longitude, lat2: lat, lon2: lon)
                return (loc, dist)
            }
            .sorted { $0.1 < $1.1 }
            .prefix(limit)
            .map(\.0)
    }

    /// Equirectangular approximation of distance in km.
    /// Good enough for sorting; avoids trig-heavy haversine.
    static func approxDistanceKm(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        let dLat = (lat2 - lat1) * 111.32
        let dLon = (lon2 - lon1) * 111.32 * cos(lat1 * .pi / 180)
        return (dLat * dLat + dLon * dLon).squareRoot()
    }

    /// Converts km to miles.
    static func kmToMiles(_ km: Double) -> Double {
        km * 0.621371
    }

    /// Enriches POTA parks with coordinates by fetching per-location data.
    /// - Parameters:
    ///   - refRepo: Repository for database operations
    ///   - userLatitude: User's current latitude (nil = use default country)
    ///   - userLongitude: User's current longitude (nil = use default country)
    ///   - onProgress: Progress callback for UI updates
    static func enrichParks(
        refRepo: ReferenceRepository,
        userLatitude: Double?,
        userLongitude: Double?,
        onProgress: @escaping (String) -> Void
    ) async throws {
        onProgress("Fetching park locations...")

        let allLocations = try await fetchLocations()

        // Find the nearest location to determine the user's country (entityId)
        let targetEntityId: Int
        if let lat = userLatitude, let lon = userLongitude {
            let nearest = nearestLocationCodes(latitude: lat, longitude: lon, from: allLocations, limit: 1)
            targetEntityId = nearest.first?.entityId ?? 291 // Default to US
        } else {
            targetEntityId = 291 // US
        }

        // Filter to all locations in the same country
        let countryLocations = allLocations.filter { $0.entityId == targetEntityId }
        let total = countryLocations.count
        onProgress("Fetching coordinates for \(total) regions...")

        // Fetch parks for each location with concurrency limit
        var allParkCoords: [ParkCoordinate] = []
        var completed = 0

        try await withThrowingTaskGroup(of: [ParkCoordinate].self) { group in
            var pending = countryLocations.makeIterator()
            let maxConcurrent = 5

            // Seed initial tasks
            for _ in 0..<maxConcurrent {
                guard let loc = pending.next() else { break }
                group.addTask {
                    try await fetchParksInLocation(loc.locationCode)
                }
            }

            for try await parks in group {
                allParkCoords.append(contentsOf: parks)
                completed += 1
                onProgress("Fetching coordinates (\(completed)/\(total))...")

                // Launch next task
                if let loc = pending.next() {
                    group.addTask {
                        try await fetchParksInLocation(loc.locationCode)
                    }
                }
            }
        }

        // Batch-update the database
        let validCoords = allParkCoords.filter { $0.latitude != nil && $0.longitude != nil }
        onProgress("Updating \(validCoords.count) park coordinates...")
        try await refRepo.enrichParksWithCoordinates(validCoords.map {
            (reference: $0.reference, latitude: $0.latitude!, longitude: $0.longitude!)
        })
    }
}
