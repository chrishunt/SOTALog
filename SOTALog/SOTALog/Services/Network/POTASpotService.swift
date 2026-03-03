import Foundation

enum POTASpotService {
    /// Fetches current POTA activator spots.
    static func fetchSpots() async throws -> [Spot] {
        let url = URL(string: "https://api.pota.app/spot/activator")!
        var request = URLRequest(url: url)
        request.setValue("SOTA Log/1.0", forHTTPHeaderField: "User-Agent")

        let (data, _) = try await URLSession.shared.data(for: request)
        let decoded = try JSONDecoder().decode([POTASpotDTO].self, from: data)

        return decoded.compactMap { dto -> Spot? in
            let upperMode = dto.mode?.uppercased()
            guard upperMode == "CW" || upperMode == "SSB" else { return nil }
            guard let freq = Double(dto.frequency ?? "") else { return nil }

            let freqMHz = freq > 1000 ? freq / 1000.0 : freq
            let mode = upperMode ?? "CW"

            return Spot(
                id: "pota-\(dto.spotId ?? 0)-\(dto.activator ?? "")",
                activatorCallsign: dto.activator ?? "",
                frequency: freqMHz,
                mode: mode,
                potaReference: dto.reference,
                potaReferenceName: dto.name,
                spotterCallsign: dto.spotter,
                comments: dto.comments,
                timestamp: dto.parsedTimestamp ?? Date()
            )
        }
    }

    private struct POTASpotDTO: Decodable {
        let spotId: Int?
        let activator: String?
        let frequency: String?
        let mode: String?
        let reference: String?
        let name: String?
        let spotter: String?
        let comments: String?
        let spotTime: String?

        var parsedTimestamp: Date? {
            guard let spotTime = spotTime else { return nil }
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: spotTime) { return date }
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: spotTime) { return date }
            // Fallback for timestamps without timezone designator (assumes UTC)
            let df = DateFormatter()
            df.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
            df.timeZone = TimeZone(identifier: "UTC")
            df.locale = Locale(identifier: "en_US_POSIX")
            return df.date(from: spotTime)
        }
    }
}
