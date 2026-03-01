import Foundation

enum QRZLogbookService {
    private static let baseURL = "https://logbook.qrz.com/api"

    /// Uploads a single QSO to QRZ logbook.
    static func uploadQSO(apiKey: String, adifRecord: String) async throws -> Int64? {
        var components = URLComponents(string: baseURL)!
        components.queryItems = [
            URLQueryItem(name: "KEY", value: apiKey),
            URLQueryItem(name: "ACTION", value: "INSERT"),
            URLQueryItem(name: "ADIF", value: adifRecord),
        ]

        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        request.setValue("DitLog/1.0", forHTTPHeaderField: "User-Agent")

        let (data, _) = try await URLSession.shared.data(for: request)
        let response = String(data: data, encoding: .utf8) ?? ""

        // Parse response for LOGID
        if response.contains("RESULT=OK") {
            if let logIdStr = extractValue(from: response, key: "LOGID"),
               let logId = Int64(logIdStr) {
                return logId
            }
        }

        if response.contains("RESULT=FAIL") {
            let reason = extractValue(from: response, key: "REASON") ?? "Unknown error"
            throw QRZError.uploadFailed(reason)
        }

        return nil
    }

    /// Downloads QSOs from QRZ logbook using pagination.
    static func downloadQSOs(apiKey: String, afterLogId: Int64 = 0) async throws -> (adif: String, count: Int) {
        var components = URLComponents(string: baseURL)!
        components.queryItems = [
            URLQueryItem(name: "KEY", value: apiKey),
            URLQueryItem(name: "ACTION", value: "FETCH"),
            URLQueryItem(name: "OPTION", value: "MAX:250,AFTERLOGID:\(afterLogId)"),
        ]

        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        request.setValue("DitLog/1.0", forHTTPHeaderField: "User-Agent")

        let (data, _) = try await URLSession.shared.data(for: request)
        let response = String(data: data, encoding: .utf8) ?? ""

        if response.contains("RESULT=FAIL") {
            let reason = extractValue(from: response, key: "REASON") ?? "Unknown error"
            throw QRZError.downloadFailed(reason)
        }

        let adif = extractValue(from: response, key: "ADIF") ?? ""
        let countStr = extractValue(from: response, key: "COUNT") ?? "0"
        let count = Int(countStr) ?? 0

        return (adif, count)
    }

    private static func extractValue(from response: String, key: String) -> String? {
        let pattern = "\(key)="
        guard let range = response.range(of: pattern) else { return nil }
        let rest = response[range.upperBound...]
        if let endRange = rest.range(of: "&") {
            return String(rest[..<endRange.lowerBound])
        }
        return String(rest).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    enum QRZError: LocalizedError {
        case uploadFailed(String)
        case downloadFailed(String)

        var errorDescription: String? {
            switch self {
            case .uploadFailed(let reason): return "QRZ upload failed: \(reason)"
            case .downloadFailed(let reason): return "QRZ download failed: \(reason)"
            }
        }
    }
}
