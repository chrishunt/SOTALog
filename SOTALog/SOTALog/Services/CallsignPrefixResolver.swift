import Foundation

/// Resolves callsign prefixes to US states, Canadian provinces, and DX countries.
enum CallsignPrefixResolver {

    // MARK: - US Call Areas (digit-based)

    /// US call area digit → likely states
    private static let usCallAreas: [Character: String] = [
        "1": "CT/MA/ME/NH/RI/VT",
        "2": "NJ/NY",
        "3": "DE/MD/PA",
        "4": "AL/FL/GA/KY/NC/SC/TN/VA",
        "5": "AR/LA/MS/NM/OK/TX",
        "6": "CA",
        "7": "AZ/ID/MT/NV/OR/UT/WA/WY",
        "8": "MI/OH/WV",
        "9": "IL/IN/WI",
        "0": "CO/IA/KS/MN/MO/NE/ND/SD",
    ]

    /// Canadian prefix → province
    private static let canadianPrefixes: [String: String] = [
        "VE1": "NS", "VA1": "NS",
        "VE2": "QC", "VA2": "QC",
        "VE3": "ON", "VA3": "ON",
        "VE4": "MB",
        "VE5": "SK",
        "VE6": "AB", "VA6": "AB",
        "VE7": "BC", "VA7": "BC",
        "VE8": "NT",
        "VE9": "NB",
        "VY1": "YT",
        "VY2": "PE",
        "VO1": "NL",
        "VO2": "NL",
        "VY0": "NU",
    ]

    /// Common DX prefixes → country/entity
    private static let dxPrefixes: [String: String] = [
        "G": "England", "M": "England",
        "F": "France",
        "DL": "Germany", "DA": "Germany", "DB": "Germany", "DC": "Germany",
        "DD": "Germany", "DF": "Germany", "DG": "Germany", "DH": "Germany",
        "DJ": "Germany", "DK": "Germany", "DM": "Germany",
        "I": "Italy",
        "EA": "Spain",
        "JA": "Japan", "JH": "Japan", "JR": "Japan", "JE": "Japan",
        "JF": "Japan", "JG": "Japan", "JI": "Japan", "JJ": "Japan",
        "JK": "Japan", "JL": "Japan", "JM": "Japan", "JN": "Japan",
        "JO": "Japan", "JP": "Japan", "JQ": "Japan", "JS": "Japan",
        "VK": "Australia",
        "ZL": "New Zealand",
        "ZS": "South Africa",
        "LU": "Argentina",
        "PY": "Brazil",
        "UA": "Russia", "RA": "Russia",
        "OH": "Finland",
        "SM": "Sweden", "SA": "Sweden",
        "LA": "Norway",
        "OZ": "Denmark",
        "PA": "Netherlands", "PH": "Netherlands", "PE": "Netherlands",
        "ON": "Belgium",
        "HB": "Switzerland",
        "OE": "Austria",
        "SP": "Poland", "SQ": "Poland",
        "OK": "Czech Republic",
        "HA": "Hungary",
        "YO": "Romania",
        "LZ": "Bulgaria",
        "SV": "Greece",
        "CT": "Portugal",
    ]

    // MARK: - Public API

    /// Resolves a callsign to a likely QTH string.
    /// Returns state abbreviation for US, province for Canada, country for DX.
    static func resolve(_ callsign: String) -> String? {
        let call = callsign.uppercased()
        guard call.count >= 2 else { return nil }

        // Handle US callsigns: K, W, N, AA-AL prefixes
        if isUSCallsign(call) {
            if let digit = extractUSDigit(call) {
                return usCallAreas[digit]
            }
        }

        // Handle Canadian callsigns
        if call.hasPrefix("VE") || call.hasPrefix("VA") || call.hasPrefix("VY") || call.hasPrefix("VO") {
            let prefix = String(call.prefix(3))
            return canadianPrefixes[prefix]
        }

        // Try DX prefixes (longest match first)
        for length in stride(from: min(3, call.count), through: 1, by: -1) {
            let prefix = String(call.prefix(length))
            if let country = dxPrefixes[prefix] {
                return country
            }
        }

        return nil
    }

    // MARK: - Private helpers

    private static func isUSCallsign(_ call: String) -> Bool {
        let first = call.first!
        if first == "K" || first == "W" || first == "N" { return true }
        if call.count >= 2 && first == "A" {
            let second = call[call.index(after: call.startIndex)]
            return second >= "A" && second <= "L"
        }
        return false
    }

    private static func extractUSDigit(_ call: String) -> Character? {
        // US callsigns have the digit after the prefix letters
        for char in call {
            if char.isNumber {
                return char
            }
        }
        return nil
    }
}
