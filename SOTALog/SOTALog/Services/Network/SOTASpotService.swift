import Foundation

enum SOTASpotService {
    private static let baseURL = "https://api-db2.sota.org.uk"

    /// Fetches the current SOTA spots epoch. Returns a UUID string that changes when spots are updated.
    static func fetchEpoch() async throws -> String {
        let url = URL(string: "\(baseURL)/api/spots/epoch")!
        var request = URLRequest(url: url)
        request.setValue("SOTA Log/1.0", forHTTPHeaderField: "User-Agent")

        let (data, _) = try await URLSession.shared.data(for: request)
        // Epoch endpoint returns a plain UUID string (possibly quoted)
        let raw = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines.union(.init(charactersIn: "\""))) ?? ""
        return raw
    }

    /// Fetches current SOTA CW and SSB spots (last 1 hour, all bands).
    static func fetchSpots() async throws -> [Spot] {
        let url = URL(string: "\(baseURL)/api/spots/-1/all/cw,ssb")!
        var request = URLRequest(url: url)
        request.setValue("SOTA Log/1.0", forHTTPHeaderField: "User-Agent")

        let (data, _) = try await URLSession.shared.data(for: request)
        let decoded = try JSONDecoder().decode([SOTASpotDTO].self, from: data)

        return decoded.compactMap { dto -> Spot? in
            guard let freqMHz = dto.frequency, freqMHz > 0 else { return nil }

            // Prepend "QRT" to comments if the spot type is QRT, so existing isQRT logic works
            let comments: String?
            if dto.type?.uppercased() == "QRT" {
                let existing = dto.comments ?? ""
                comments = existing.uppercased().contains("QRT") ? existing : "QRT \(existing)".trimmingCharacters(in: .whitespaces)
            } else {
                comments = dto.comments
            }

            let mode = dto.mode?.uppercased() ?? BandPlan.mode(for: freqMHz) ?? "CW"

            return Spot(
                id: "sota-\(dto.id ?? 0)-\(dto.activatorCallsign ?? "")",
                activatorCallsign: dto.activatorCallsign ?? "",
                frequency: freqMHz,
                mode: mode,
                sotaReference: dto.summitCode ?? "",
                sotaReferenceName: dto.summitName,
                spotterCallsign: dto.callsign,
                comments: comments,
                timestamp: dto.parsedTimestamp ?? Date()
            )
        }
    }

    private struct SOTASpotDTO: Decodable {
        let id: Int?
        let activatorCallsign: String?
        let summitCode: String?
        let summitName: String?
        let frequency: Double?
        let mode: String?
        let callsign: String?  // spotter
        let comments: String?
        let timeStamp: String?
        let type: String?

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
