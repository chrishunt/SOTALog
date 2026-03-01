import Foundation

enum SOTASpotService {
    /// Fetches current SOTA spots (last 60 spots, all modes, then filtered to CW).
    static func fetchSpots() async throws -> [Spot] {
        let url = URL(string: "https://api2.sota.org.uk/api/spots/60/all")!
        var request = URLRequest(url: url)
        request.setValue("SOTALog/1.0", forHTTPHeaderField: "User-Agent")

        let (data, _) = try await URLSession.shared.data(for: request)
        let decoded = try JSONDecoder().decode([SOTASpotDTO].self, from: data)

        return decoded.compactMap { dto -> Spot? in
            guard dto.mode?.uppercased() == "CW" else { return nil }

            let freqMHz: Double
            if let f = Double(dto.frequency ?? "") {
                freqMHz = f > 1000 ? f / 1000.0 : f
            } else {
                return nil
            }

            let sotaRef = dto.associationCode.map { "\($0)/\(dto.summitCode ?? "")" }
                ?? dto.summitCode ?? ""

            return Spot(
                id: "sota-\(dto.id ?? 0)-\(dto.activatorCallsign ?? "")",
                activatorCallsign: dto.activatorCallsign ?? "",
                frequency: freqMHz,
                mode: "CW",
                sotaReference: sotaRef,
                sotaReferenceName: dto.summitDetails,
                spotterCallsign: dto.callsign,
                comments: dto.comments,
                timestamp: dto.parsedTimestamp ?? Date()
            )
        }
    }

    private struct SOTASpotDTO: Decodable {
        let id: Int?
        let activatorCallsign: String?
        let associationCode: String?
        let summitCode: String?
        let summitDetails: String?
        let frequency: String?
        let mode: String?
        let callsign: String?  // spotter
        let comments: String?
        let timeStamp: String?

        var parsedTimestamp: Date? {
            guard let timeStamp = timeStamp else { return nil }
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: timeStamp) { return date }
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: timeStamp) { return date }
            // Fallback for timestamps without timezone designator (assumes UTC)
            let df = DateFormatter()
            df.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
            df.timeZone = TimeZone(identifier: "UTC")
            df.locale = Locale(identifier: "en_US_POSIX")
            return df.date(from: timeStamp)
        }
    }
}
