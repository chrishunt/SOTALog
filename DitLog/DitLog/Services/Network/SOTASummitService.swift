import Foundation

enum SOTASummitService {
    /// Downloads and parses the SOTA summits CSV.
    static func fetchSummits() async throws -> [SOTASummit] {
        let url = URL(string: "https://www.sotadata.org.uk/summitslist.csv")!
        var request = URLRequest(url: url)
        request.setValue("DitLog/1.0", forHTTPHeaderField: "User-Agent")

        let (data, _) = try await URLSession.shared.data(for: request)
        guard let csvString = String(data: data, encoding: .utf8) else {
            throw SOTAError.invalidEncoding
        }

        return parseCSV(csvString)
    }

    /// Parses the SOTA summits CSV format.
    /// Expected columns: SummitCode,AssociationName,RegionName,SummitName,AltM,AltFt,GridRef1,GridRef2,Longitude,Latitude,Points,BonusPoints,ValidFrom,ValidTo,ActivationCount,ActivationDate,ActivationCall
    static func parseCSV(_ csv: String) -> [SOTASummit] {
        let lines = csv.components(separatedBy: .newlines)
        guard lines.count > 1 else { return [] }

        var summits: [SOTASummit] = []

        for line in lines.dropFirst() where !line.isEmpty {
            let fields = parseCSVLine(line)
            guard fields.count >= 14 else { continue }

            let code = fields[0]
            let name = fields[3]
            guard !code.isEmpty, !name.isEmpty else { continue }

            // Split code to get association and region
            let codeParts = code.split(separator: "/", maxSplits: 1)
            let associationCode = codeParts.count > 0 ? String(codeParts[0]) : nil
            let regionPart = codeParts.count > 1 ? String(codeParts[1]) : nil
            let regionCode = regionPart?.split(separator: "-").first.map(String.init)

            let summit = SOTASummit(
                code: code,
                codeNormalized: SOTASummit.normalize(code),
                name: name,
                associationCode: associationCode,
                regionCode: regionCode,
                altitude: Int(fields[4]),
                points: Int(fields[10]),
                grid: nil,
                latitude: Double(fields[9]),
                longitude: Double(fields[8]),
                validFrom: fields[12].isEmpty ? nil : fields[12],
                validTo: fields[13].isEmpty ? nil : fields[13]
            )
            summits.append(summit)
        }

        return summits
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

    enum SOTAError: LocalizedError {
        case invalidEncoding

        var errorDescription: String? {
            switch self {
            case .invalidEncoding: return "Could not decode SOTA summits data"
            }
        }
    }
}
