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

    /// Common DX prefixes → ISO 3166-1 alpha-3 country codes
    private static let dxPrefixes: [String: String] = [
        "G": "GBR", "M": "GBR",
        "F": "FRA",
        "DL": "DEU", "DA": "DEU", "DB": "DEU", "DC": "DEU",
        "DD": "DEU", "DF": "DEU", "DG": "DEU", "DH": "DEU",
        "DJ": "DEU", "DK": "DEU", "DM": "DEU",
        "I": "ITA",
        "EA": "ESP",
        "JA": "JPN", "JH": "JPN", "JR": "JPN", "JE": "JPN",
        "JF": "JPN", "JG": "JPN", "JI": "JPN", "JJ": "JPN",
        "JK": "JPN", "JL": "JPN", "JM": "JPN", "JN": "JPN",
        "JO": "JPN", "JP": "JPN", "JQ": "JPN", "JS": "JPN",
        "VK": "AUS",
        "ZL": "NZL",
        "ZS": "ZAF",
        "LU": "ARG",
        "PY": "BRA",
        "UA": "RUS", "RA": "RUS",
        "OH": "FIN",
        "SM": "SWE", "SA": "SWE",
        "LA": "NOR",
        "OZ": "DNK",
        "PA": "NLD", "PH": "NLD", "PE": "NLD",
        "ON": "BEL",
        "HB": "CHE",
        "OE": "AUT",
        "SP": "POL", "SQ": "POL",
        "OK": "CZE",
        "HA": "HUN",
        "YO": "ROU",
        "LZ": "BGR",
        "SV": "GRC",
        "CT": "PRT",
    ]

    /// Maps full country names (from QRZ) to ISO 3166-1 alpha-3 codes
    private static let countryToISO: [String: String] = [
        "England": "GBR",
        "Wales": "GBR",
        "Scotland": "GBR",
        "Northern Ireland": "GBR",
        "United Kingdom": "GBR",
        "France": "FRA",
        "Germany": "DEU",
        "Fed. Rep. of Germany": "DEU",
        "Italy": "ITA",
        "Spain": "ESP",
        "Japan": "JPN",
        "Australia": "AUS",
        "New Zealand": "NZL",
        "South Africa": "ZAF",
        "Argentina": "ARG",
        "Brazil": "BRA",
        "Russia": "RUS",
        "Russian Federation": "RUS",
        "Finland": "FIN",
        "Sweden": "SWE",
        "Norway": "NOR",
        "Denmark": "DNK",
        "Netherlands": "NLD",
        "Belgium": "BEL",
        "Switzerland": "CHE",
        "Austria": "AUT",
        "Poland": "POL",
        "Czech Republic": "CZE",
        "Hungary": "HUN",
        "Romania": "ROU",
        "Bulgaria": "BGR",
        "Greece": "GRC",
        "Portugal": "PRT",
    ]

    // MARK: - Public API

    /// Abbreviates a full country name to its ISO 3166-1 alpha-3 code.
    /// e.g. "Japan" → "JPN", "Germany" → "DEU"
    /// Returns the original string if no mapping is found.
    static func abbreviate(_ country: String) -> String {
        countryToISO[country] ?? country
    }

    /// Resolves a callsign to a likely QTH string.
    /// Returns state abbreviation for US, province for Canada, ISO alpha-3 for DX.
    static func resolve(_ callsign: String) -> String? {
        let call = callsign.uppercased()
        guard call.count >= 2 else { return nil }

        // Handle US callsigns: K, W, N, AA-AL prefixes
        // Only return QTH when the call area maps to a single state
        if isUSCallsign(call) {
            if let digit = extractUSDigit(call),
               let states = usCallAreas[digit],
               !states.contains("/") {
                return states
            }
            return nil
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
