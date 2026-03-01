import Foundation

enum POTAParkService {
    /// Fetches all POTA location codes.
    static func fetchLocations() async throws -> [POTALocation] {
        let url = URL(string: "https://api.pota.app/programs/locations/")!
        var request = URLRequest(url: url)
        request.setValue("FieldLog/1.0", forHTTPHeaderField: "User-Agent")

        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode([POTALocation].self, from: data)
    }

    /// Fetches parks for a single location code (e.g. "US-NC").
    static func fetchParks(locationCode: String) async throws -> [POTAPark] {
        let url = URL(string: "https://api.pota.app/location/parks/\(locationCode)")!
        var request = URLRequest(url: url)
        request.setValue("FieldLog/1.0", forHTTPHeaderField: "User-Agent")

        let (data, _) = try await URLSession.shared.data(for: request)
        let dtos = try JSONDecoder().decode([POTAParkDTO].self, from: data)

        return dtos.map { dto in
            POTAPark(
                reference: dto.reference,
                name: dto.name,
                locationCode: locationCode,
                grid4: dto.grid4,
                grid6: dto.grid6,
                latitude: dto.latitude,
                longitude: dto.longitude,
                active: dto.active == 1
            )
        }
    }

    struct POTALocation: Decodable, Identifiable {
        let programId: Int?
        let entityId: Int?
        let locationCode: String
        let locationName: String?
        let parks: Int?

        var id: String { locationCode }

        enum CodingKeys: String, CodingKey {
            case programId, entityId
            case locationCode = "locationCode"
            case locationName = "locationName"
            case parks
        }
    }

    private struct POTAParkDTO: Decodable {
        let reference: String
        let name: String
        let grid4: String?
        let grid6: String?
        let latitude: Double?
        let longitude: Double?
        let active: Int?
    }
}
