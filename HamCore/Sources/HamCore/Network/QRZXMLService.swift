import Foundation

enum QRZXMLService {
    private static let baseURL = "https://xmldata.qrz.com/xml/current/"

    /// Authenticates with QRZ XML API and returns a session key.
    static func login(username: String, password: String) async throws -> String {
        var components = URLComponents(string: baseURL)!
        components.queryItems = [
            URLQueryItem(name: "username", value: username),
            URLQueryItem(name: "password", value: password),
        ]

        var request = URLRequest(url: components.url!)
        request.setValue("SOTA Log/1.0", forHTTPHeaderField: "User-Agent")

        let (data, _) = try await URLSession.shared.data(for: request)
        let xml = String(data: data, encoding: .utf8) ?? ""

        guard let key = extractXMLValue(from: xml, tag: "Key") else {
            let error = extractXMLValue(from: xml, tag: "Error") ?? "Login failed"
            throw QRZXMLError.loginFailed(error)
        }

        return key
    }

    /// Looks up a callsign using the QRZ XML API.
    static func lookup(callsign: String, sessionKey: String) async throws -> QRZCallsignResult {
        var components = URLComponents(string: baseURL)!
        components.queryItems = [
            URLQueryItem(name: "s", value: sessionKey),
            URLQueryItem(name: "callsign", value: callsign),
        ]

        var request = URLRequest(url: components.url!)
        request.setValue("SOTA Log/1.0", forHTTPHeaderField: "User-Agent")

        let (data, _) = try await URLSession.shared.data(for: request)
        let xml = String(data: data, encoding: .utf8) ?? ""

        // Check for session expiry
        if let error = extractXMLValue(from: xml, tag: "Error") {
            if error.contains("Session") || error.contains("Invalid session") {
                throw QRZXMLError.sessionExpired
            }
            throw QRZXMLError.lookupFailed(error)
        }

        return QRZCallsignResult(
            callsign: extractXMLValue(from: xml, tag: "call") ?? callsign,
            firstName: extractXMLValue(from: xml, tag: "fname"),
            nickname: extractXMLValue(from: xml, tag: "nickname"),
            lastName: extractXMLValue(from: xml, tag: "name"),
            city: extractXMLValue(from: xml, tag: "addr2"),
            state: extractXMLValue(from: xml, tag: "state"),
            country: extractXMLValue(from: xml, tag: "country"),
            grid: extractXMLValue(from: xml, tag: "grid"),
            county: extractXMLValue(from: xml, tag: "county")
        )
    }

    /// Simple XML tag value extractor (no need for full XML parser for this API).
    private static func extractXMLValue(from xml: String, tag: String) -> String? {
        let openTag = "<\(tag)>"
        let closeTag = "</\(tag)>"
        guard let openRange = xml.range(of: openTag),
              let closeRange = xml.range(of: closeTag, range: openRange.upperBound..<xml.endIndex) else {
            return nil
        }
        let value = String(xml[openRange.upperBound..<closeRange.lowerBound])
        return value.isEmpty ? nil : value
    }

    enum QRZXMLError: LocalizedError {
        case loginFailed(String)
        case sessionExpired
        case lookupFailed(String)

        var errorDescription: String? {
            switch self {
            case .loginFailed(let reason): return "QRZ login failed: \(reason)"
            case .sessionExpired: return "QRZ session expired, please re-authenticate"
            case .lookupFailed(let reason): return "QRZ lookup failed: \(reason)"
            }
        }
    }
}
