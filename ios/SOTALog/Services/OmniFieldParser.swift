import Foundation

struct ParsedEntry {
    enum TokenKind {
        case callsign, rst, frequency, mode, qth, gridSquare, potaRef, sotaRef, time, unrecognized
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
    var gridSquare: String?
    var potaRef: String?
    var sotaRef: String?
    var timeOn: String?
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
            } else if let time = parseTimeToken(token) {
                result.timeOn = time
                result.tokens.append(.init(text: token, kind: .time))
            } else if isQTH(token) {
                result.qth = token.uppercased()
                result.tokens.append(.init(text: token, kind: .qth))
            } else if let grid = parseGridSquare(token) {
                result.gridSquare = grid
                result.tokens.append(.init(text: token, kind: .gridSquare))
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

    /// Matches "CW", "SSB", or "FM" (case-insensitive)
    private static func isModeToken(_ token: String) -> Bool {
        let upper = token.uppercased()
        return upper == "CW" || upper == "SSB" || upper == "FM"
    }

    /// Matches a decimal number (frequency in MHz)
    private static func isFrequency(_ token: String) -> Bool {
        token.contains(".") && Double(token) != nil
    }

    /// UTC time token: HHMM digits with a trailing Z, e.g. "1432Z" or "932Z".
    /// The Z suffix disambiguates from RST. Returns "HHMM" or nil.
    private static func parseTimeToken(_ token: String) -> String? {
        guard token.count >= 4, token.count <= 5,
              token.last == "Z" || token.last == "z" else { return nil }
        return parseTime(String(token.dropLast()))
    }

    /// Validates bare HHMM digits (3-4 chars, HH < 24, MM < 60).
    /// Returns the zero-padded "HHMM" or nil.
    static func parseTime(_ raw: String) -> String? {
        guard raw.count >= 3, raw.count <= 4,
              raw.allSatisfy(\.isNumber) else { return nil }
        let padded = String(repeating: "0", count: 4 - raw.count) + raw
        guard let hh = Int(padded.prefix(2)), hh < 24,
              let mm = Int(padded.suffix(2)), mm < 60 else { return nil }
        return padded
    }

    /// Matches US state, DC, territory, or Canadian province/territory abbreviation
    private static func isQTH(_ token: String) -> Bool {
        qthCodes.contains(token.uppercased())
    }

    /// Maidenhead grid: 4, 6, or 8 chars with strict alternation.
    /// Pair 1 (field): A-R letters. Pair 2 (square): digits. Pair 3 (subsquare): a-x letters. Pair 4: digits.
    /// Returns canonical mixed-case form (field upper, subsquare lower) or nil.
    static func parseGridSquare(_ token: String) -> String? {
        guard token.count == 4 || token.count == 6 || token.count == 8 else { return nil }
        let upper = Array(token.uppercased())
        let lower = Array(token.lowercased())

        guard ("A"..."R").contains(upper[0]), ("A"..."R").contains(upper[1]),
              upper[2].isNumber, upper[3].isNumber else { return nil }

        var canon = "\(upper[0])\(upper[1])\(upper[2])\(upper[3])"

        if upper.count >= 6 {
            guard ("a"..."x").contains(lower[4]), ("a"..."x").contains(lower[5]) else { return nil }
            canon += "\(lower[4])\(lower[5])"
        }

        if upper.count == 8 {
            guard upper[6].isNumber, upper[7].isNumber else { return nil }
            canon += "\(upper[6])\(upper[7])"
        }

        return canon
    }

    /// POTA candidate: starts with letter(s) followed by digits, e.g. US1234, K4567, VE0001.
    /// Separators are ignored, so the standard "US-1234" form is accepted too.
    private static func isPOTACandidate(_ token: String) -> Bool {
        let upper = POTAPark.normalize(token)
        guard upper.count >= 3 else { return false }
        let letters = upper.prefix(while: \.isLetter)
        let digits = upper.dropFirst(letters.count)
        return !letters.isEmpty && !digits.isEmpty && digits.allSatisfy(\.isNumber)
    }

    /// SOTA candidate: letter(s) + digit(s) + letter(s) + digit(s), e.g. W4CCM001.
    /// Separators are ignored, so the standard "W4C/CM-001" form is accepted too.
    private static func isSOTACandidate(_ token: String) -> Bool {
        let upper = SOTASummit.normalize(token)
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
