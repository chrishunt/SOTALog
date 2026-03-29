import Foundation

enum POTAParkService {
    /// Downloads and parses the POTA all-parks CSV.
    static func fetchAllParks() async throws -> [POTAPark] {
        let url = URL(string: "https://pota.app/all_parks.csv")!
        var request = URLRequest(url: url)
        request.setValue("SOTA Log/1.0", forHTTPHeaderField: "User-Agent")

        let (data, _) = try await URLSession.shared.data(for: request)
        guard let csvString = String(data: data, encoding: .utf8) else {
            throw POTAError.invalidEncoding
        }

        return parseCSV(csvString)
    }

    /// Parses the POTA parks CSV.
    /// Expected header: reference,name,active,entityId,locationDesc,...
    static func parseCSV(_ csv: String) -> [POTAPark] {
        let lines = csv.components(separatedBy: .newlines)
        guard lines.count > 1 else { return [] }

        // Find column indices from header
        let header = parseCSVLine(lines[0])
        guard let refIdx = header.firstIndex(of: "reference"),
              let nameIdx = header.firstIndex(of: "name"),
              let activeIdx = header.firstIndex(of: "active") else {
            return []
        }
        let locDescIdx = header.firstIndex(of: "locationDesc")

        var parks: [POTAPark] = []

        for line in lines.dropFirst() where !line.isEmpty {
            let fields = parseCSVLine(line)
            let maxIdx = max(refIdx, max(nameIdx, activeIdx))
            guard fields.count > maxIdx else { continue }

            let active = fields[activeIdx]
            guard active == "1" else { continue }

            let reference = fields[refIdx]
            let name = fields[nameIdx]
            guard !reference.isEmpty, !name.isEmpty else { continue }

            let locationDesc: String?
            if let idx = locDescIdx, fields.count > idx, !fields[idx].isEmpty {
                locationDesc = fields[idx]
            } else {
                locationDesc = nil
            }

            let park = POTAPark(
                reference: reference,
                name: name,
                referenceNormalized: POTAPark.normalize(reference),
                locationDesc: locationDesc
            )
            parks.append(park)
        }

        return parks
    }

    /// Parses a CSV line handling quoted fields.
    private static func parseCSVLine(_ line: String) -> [String] {
        var fields: [String] = []
        var current = ""
        var inQuotes = false

        for char in line {
            if char == "\"" {
                inQuotes.toggle()
            } else if char == "," && !inQuotes {
                fields.append(current.trimmingCharacters(in: .whitespaces))
                current = ""
            } else {
                current.append(char)
            }
        }
        fields.append(current.trimmingCharacters(in: .whitespaces))

        return fields
    }

    enum POTAError: LocalizedError {
        case invalidEncoding

        var errorDescription: String? {
            switch self {
            case .invalidEncoding: return "Could not decode POTA parks data"
            }
        }
    }
}
