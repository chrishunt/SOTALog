import Foundation

enum QRZLogbookService {
    private static let baseURL = URL(string: "https://logbook.qrz.com/api")!

    /// Tests an API key by requesting account status.
    static func testAPIKey(apiKey: String) async throws {
        let params: [(String, String)] = [
            ("KEY", apiKey),
            ("ACTION", "STATUS"),
        ]

        let (data, _) = try await post(params: params)
        let parsed = parseResponse(String(decoding: data, as: UTF8.self))

        if parsed["RESULT"] != "OK" {
            let reason = parsed["REASON"] ?? "Invalid API key"
            throw QRZError.apiKeyFailed(reason)
        }
    }

    /// Uploads a single QSO to QRZ logbook.
    static func uploadQSO(apiKey: String, adifRecord: String) async throws -> Int64? {
        let params: [(String, String)] = [
            ("KEY", apiKey),
            ("ACTION", "INSERT"),
            ("ADIF", adifRecord),
        ]

        let (data, _) = try await post(params: params)
        let parsed = parseResponse(String(decoding: data, as: UTF8.self))

        let resultOk = parsed["RESULT"] == "OK" || parsed["RESULT"] == "REPLACE"
        if !resultOk {
            let reason = parsed["REASON"] ?? "Unknown error"
            throw QRZError.uploadFailed(reason)
        }

        if let logIdStr = parsed["LOGID"], let logId = Int64(logIdStr) {
            return logId
        }

        return nil
    }

    /// Downloads QSOs from QRZ logbook using pagination.
    static func downloadQSOs(apiKey: String, afterLogId: Int64 = 0) async throws -> (adif: String, count: Int) {
        let params: [(String, String)] = [
            ("KEY", apiKey),
            ("ACTION", "FETCH"),
            ("OPTION", "MAX:250,AFTERLOGID:\(afterLogId)"),
        ]

        let (data, _) = try await post(params: params)
        let response = String(decoding: data, as: UTF8.self)

        let parsed = parseResponse(response)

        if parsed["RESULT"] != "OK" {
            let reason = parsed["REASON"] ?? "Unknown error"
            throw QRZError.downloadFailed(reason)
        }

        let rawAdif = parsed["ADIF"] ?? ""
        let adif = rawAdif
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&amp;", with: "&")
        let count = parsed["COUNT"].flatMap(Int.init) ?? 0

        return (adif, count)
    }

    // MARK: - Private

    private static let formSafeCharacters: CharacterSet = {
        var cs = CharacterSet.alphanumerics
        cs.insert(charactersIn: "-._~")
        return cs
    }()

    private static func post(params: [(String, String)]) async throws -> (Data, URLResponse) {
        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("SOTALog/1.0", forHTTPHeaderField: "User-Agent")

        let encoded: [String] = params.map { key, value in
            let escapedKey = key.addingPercentEncoding(withAllowedCharacters: formSafeCharacters) ?? key
            let escapedValue = value.addingPercentEncoding(withAllowedCharacters: formSafeCharacters) ?? value
            return escapedKey + "=" + escapedValue
        }
        request.httpBody = Data(encoded.joined(separator: "&").utf8)

        return try await URLSession.shared.data(for: request)
    }

    /// Parses QRZ's pseudo-form-encoded response.
    /// The ADIF value contains unescaped `&` so standard URL decoding fails.
    /// Strategy: extract short known fields by regex, then treat the remainder as ADIF.
    private static let knownFields = ["RESULT", "REASON", "COUNT", "LOGID", "LOGIDS"]

    static func parseResponse(_ response: String) -> [String: String] {
        var result: [String: String] = [:]
        var remaining = response

        for field in knownFields {
            let pattern = field + "="
            guard let range = remaining.range(of: pattern) else { continue }
            let afterEq = remaining[range.upperBound...]
            let value: String
            if let amp = afterEq.range(of: "&") {
                value = String(afterEq[..<amp.lowerBound])
                // Remove "FIELD=value&" from remaining
                remaining.replaceSubrange(range.lowerBound...amp.lowerBound, with: "")
            } else {
                value = String(afterEq).trimmingCharacters(in: .whitespacesAndNewlines)
                remaining.replaceSubrange(range.lowerBound..., with: "")
            }
            result[field] = value
        }

        // Everything left (after stripping known fields) is the ADIF blob
        let adif = remaining
            .replacingOccurrences(of: "ADIF=", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !adif.isEmpty {
            result["ADIF"] = adif
        }

        return result
    }

    enum QRZError: LocalizedError {
        case apiKeyFailed(String)
        case uploadFailed(String)
        case downloadFailed(String)

        var errorDescription: String? {
            switch self {
            case .apiKeyFailed(let reason): return "QRZ API key failed: \(reason)"
            case .uploadFailed(let reason): return "QRZ upload failed: \(reason)"
            case .downloadFailed(let reason): return "QRZ download failed: \(reason)"
            }
        }
    }
}
