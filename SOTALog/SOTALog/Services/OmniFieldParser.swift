import Foundation

struct ParsedEntry {
    enum TokenKind {
        case callsign, rst, frequency, mode, qth, potaRef, sotaRef, unrecognized
    }

    struct ClassifiedToken {
        let text: String
        let kind: TokenKind
    }

    var callsign: String = ""
    var rstSent: String?
    var rstReceived: String?
    var frequency: String?
    var mode: String?
    var qth: String?
    var potaRef: String?
    var sotaRef: String?
    var tokens: [ClassifiedToken] = []
}

enum OmniFieldParser {

    static func parse(_ input: String) -> ParsedEntry {
        let tokens = input.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        guard let first = tokens.first else { return ParsedEntry() }

        var result = ParsedEntry(callsign: first)
        result.tokens.append(.init(text: first, kind: .callsign))
        var rstCount = 0

        for token in tokens.dropFirst() {
            if isModeToken(token) {
                result.mode = token.uppercased()
                result.tokens.append(.init(text: token, kind: .mode))
            } else if let rst = parseRST(token) {
                if rstCount == 0 {
                    result.rstSent = rst
                } else if rstCount == 1 {
                    result.rstReceived = rst
                }
                rstCount += 1
                result.tokens.append(.init(text: token, kind: .rst))
            } else if isFrequency(token) {
                result.frequency = token
                result.tokens.append(.init(text: token, kind: .frequency))
            } else if isQTH(token) {
                result.qth = token.uppercased()
                result.tokens.append(.init(text: token, kind: .qth))
            } else if isPOTACandidate(token) {
                result.potaRef = token.uppercased()
                result.tokens.append(.init(text: token, kind: .potaRef))
            } else if isSOTACandidate(token) {
                result.sotaRef = token.uppercased()
                result.tokens.append(.init(text: token, kind: .sotaRef))
            } else {
                result.tokens.append(.init(text: token, kind: .unrecognized))
            }
        }

        return result
    }

    // MARK: - Token Classifiers

    /// Matches 2-3 digit RST: [1-5][1-9][1-9]?
    /// Returns the raw value as-is. The view model handles tone expansion based on mode.
    private static func parseRST(_ token: String) -> String? {
        guard token.count >= 2, token.count <= 3,
              token.allSatisfy(\.isNumber) else { return nil }

        let digits = Array(token)
        guard let r = digits[0].wholeNumberValue, (1...5).contains(r),
              let s = digits[1].wholeNumberValue, (1...9).contains(s) else { return nil }

        if digits.count == 3 {
            guard let t = digits[2].wholeNumberValue, (1...9).contains(t) else { return nil }
        }
        return token
    }

    /// Matches "CW" or "SSB" (case-insensitive)
    private static func isModeToken(_ token: String) -> Bool {
        let upper = token.uppercased()
        return upper == "CW" || upper == "SSB"
    }

    /// Matches a decimal number (frequency in MHz)
    private static func isFrequency(_ token: String) -> Bool {
        token.contains(".") && Double(token) != nil
    }

    /// Matches US state, DC, territory, or Canadian province/territory abbreviation
    private static func isQTH(_ token: String) -> Bool {
        qthCodes.contains(token.uppercased())
    }

    /// POTA candidate: starts with letter(s) followed by digits, e.g. US1234, K4567, VE0001
    private static func isPOTACandidate(_ token: String) -> Bool {
        let upper = token.uppercased()
        guard upper.count >= 3 else { return false }
        let letters = upper.prefix(while: \.isLetter)
        let digits = upper.dropFirst(letters.count)
        return !letters.isEmpty && !digits.isEmpty && digits.allSatisfy(\.isNumber)
    }

    /// SOTA candidate: letter(s) + digit(s) + letter(s) + digit(s), e.g. W4CCM001
    private static func isSOTACandidate(_ token: String) -> Bool {
        let upper = token.uppercased()
        guard upper.count >= 4 else { return false }
        // Pattern: letters, digits, letters, digits
        var i = upper.startIndex
        // Association prefix: one or more letters
        guard i < upper.endIndex, upper[i].isLetter else { return false }
        while i < upper.endIndex, upper[i].isLetter { i = upper.index(after: i) }
        // Region digit(s)
        guard i < upper.endIndex, upper[i].isNumber else { return false }
        while i < upper.endIndex, upper[i].isNumber { i = upper.index(after: i) }
        // Summit code: one or more letters
        guard i < upper.endIndex, upper[i].isLetter else { return false }
        while i < upper.endIndex, upper[i].isLetter { i = upper.index(after: i) }
        // Summit number: one or more digits
        guard i < upper.endIndex, upper[i].isNumber else { return false }
        while i < upper.endIndex, upper[i].isNumber { i = upper.index(after: i) }
        return i == upper.endIndex
    }

    // MARK: - QTH Codes

    private static let qthCodes: Set<String> = {
        // US states
        let states: Set<String> = [
            "AL", "AK", "AZ", "AR", "CA", "CO", "CT", "DE", "FL", "GA",
            "HI", "ID", "IL", "IN", "IA", "KS", "KY", "LA", "ME", "MD",
            "MA", "MI", "MN", "MS", "MO", "MT", "NE", "NV", "NH", "NJ",
            "NM", "NY", "NC", "ND", "OH", "OK", "OR", "PA", "RI", "SC",
            "SD", "TN", "TX", "UT", "VT", "VA", "WA", "WV", "WI", "WY",
        ]
        // DC + territories
        let territories: Set<String> = ["DC", "PR", "VI", "GU", "AS", "MP"]
        // Canadian provinces/territories
        let canada: Set<String> = [
            "AB", "BC", "MB", "NB", "NL", "NS", "NT", "NU", "ON", "PE", "QC", "SK", "YT",
        ]
        return states.union(territories).union(canada)
    }()
}
