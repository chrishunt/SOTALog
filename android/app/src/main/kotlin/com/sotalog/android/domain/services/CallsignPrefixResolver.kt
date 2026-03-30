package com.sotalog.android.domain.services

object CallsignPrefixResolver {

    // US call area digit -> states
    private val usCallAreas: Map<Char, String> = mapOf(
        '1' to "CT/MA/ME/NH/RI/VT",
        '2' to "NJ/NY",
        '3' to "DE/MD/PA",
        '4' to "AL/FL/GA/KY/NC/SC/TN/VA",
        '5' to "AR/LA/MS/NM/OK/TX",
        '6' to "CA",
        '7' to "AZ/ID/MT/NV/OR/UT/WA/WY",
        '8' to "MI/OH/WV",
        '9' to "IL/IN/WI",
        '0' to "CO/IA/KS/MN/MO/NE/ND/SD",
    )

    // Canadian prefix -> province
    private val canadianPrefixes: Map<String, String> = mapOf(
        "VE1" to "NS", "VA1" to "NS",
        "VE2" to "QC", "VA2" to "QC",
        "VE3" to "ON", "VA3" to "ON",
        "VE4" to "MB",
        "VE5" to "SK",
        "VE6" to "AB", "VA6" to "AB",
        "VE7" to "BC", "VA7" to "BC",
        "VE8" to "NT",
        "VE9" to "NB",
        "VY1" to "YT",
        "VY2" to "PE",
        "VO1" to "NL",
        "VO2" to "NL",
        "VY0" to "NU",
    )

    // DX prefixes -> ISO 3166-1 alpha-3 codes
    private val dxPrefixes: Map<String, String> = mapOf(
        "G" to "GBR", "M" to "GBR",
        "F" to "FRA",
        "DL" to "DEU", "DA" to "DEU", "DB" to "DEU", "DC" to "DEU",
        "DD" to "DEU", "DF" to "DEU", "DG" to "DEU", "DH" to "DEU",
        "DJ" to "DEU", "DK" to "DEU", "DM" to "DEU",
        "I" to "ITA",
        "EA" to "ESP",
        "JA" to "JPN", "JH" to "JPN", "JR" to "JPN", "JE" to "JPN",
        "JF" to "JPN", "JG" to "JPN", "JI" to "JPN", "JJ" to "JPN",
        "JK" to "JPN", "JL" to "JPN", "JM" to "JPN", "JN" to "JPN",
        "JO" to "JPN", "JP" to "JPN", "JQ" to "JPN", "JS" to "JPN",
        "VK" to "AUS",
        "ZL" to "NZL",
        "ZS" to "ZAF",
        "LU" to "ARG",
        "PY" to "BRA",
        "UA" to "RUS", "RA" to "RUS",
        "OH" to "FIN",
        "SM" to "SWE", "SA" to "SWE",
        "LA" to "NOR",
        "OZ" to "DNK",
        "PA" to "NLD", "PH" to "NLD", "PE" to "NLD",
        "ON" to "BEL",
        "HB" to "CHE",
        "OE" to "AUT",
        "SP" to "POL", "SQ" to "POL",
        "OK" to "CZE",
        "HA" to "HUN",
        "YO" to "ROU",
        "LZ" to "BGR",
        "SV" to "GRC",
        "CT" to "PRT",
    )

    // Country name -> ISO 3166-1 alpha-3 code
    private val countryToISO: Map<String, String> = mapOf(
        "England" to "GBR",
        "Wales" to "GBR",
        "Scotland" to "GBR",
        "Northern Ireland" to "GBR",
        "United Kingdom" to "GBR",
        "France" to "FRA",
        "Germany" to "DEU",
        "Fed. Rep. of Germany" to "DEU",
        "Italy" to "ITA",
        "Spain" to "ESP",
        "Japan" to "JPN",
        "Australia" to "AUS",
        "New Zealand" to "NZL",
        "South Africa" to "ZAF",
        "Argentina" to "ARG",
        "Brazil" to "BRA",
        "Russia" to "RUS",
        "Russian Federation" to "RUS",
        "Finland" to "FIN",
        "Sweden" to "SWE",
        "Norway" to "NOR",
        "Denmark" to "DNK",
        "Netherlands" to "NLD",
        "Belgium" to "BEL",
        "Switzerland" to "CHE",
        "Austria" to "AUT",
        "Poland" to "POL",
        "Czech Republic" to "CZE",
        "Hungary" to "HUN",
        "Romania" to "ROU",
        "Bulgaria" to "BGR",
        "Greece" to "GRC",
        "Portugal" to "PRT",
        "Colombia" to "COL",
        "Venezuela" to "VEN",
        "Ecuador" to "ECU",
        "Peru" to "PER",
        "Bolivia" to "BOL",
        "Chile" to "CHL",
        "Uruguay" to "URY",
        "Paraguay" to "PRY",
        "Trinidad and Tobago" to "TTO",
        "Mexico" to "MEX",
        "Costa Rica" to "CRI",
        "Panama" to "PAN",
        "Honduras" to "HND",
        "Guatemala" to "GTM",
        "El Salvador" to "SLV",
        "Nicaragua" to "NIC",
        "Belize" to "BLZ",
        "Jamaica" to "JAM",
        "Cuba" to "CUB",
        "Dominican Republic" to "DOM",
        "Haiti" to "HTI",
        "Guyana" to "GUY",
        "Suriname" to "SUR",
        "India" to "IND",
        "Malaysia" to "MYS",
        "Singapore" to "SGP",
        "Thailand" to "THA",
        "Vietnam" to "VNM",
        "Laos" to "LAO",
        "Cambodia" to "KHM",
        "Myanmar" to "MMR",
        "Philippines" to "PHL",
        "Indonesia" to "IDN",
        "Taiwan" to "TWN",
        "China" to "CHN",
        "South Korea" to "KOR",
        "Mongolia" to "MNG",
        "Hong Kong" to "HKG",
        "Macao" to "MAC",
        "Samoa" to "WSM",
        "Tonga" to "TON",
        "Fiji" to "FJI",
        "Kiribati" to "KIR",
        "Palau" to "PLW",
        "Marshall Islands" to "MHL",
        "Namibia" to "NAM",
        "Botswana" to "BWA",
        "Lesotho" to "LSO",
        "Mozambique" to "MOZ",
        "Zimbabwe" to "ZWE",
        "Zambia" to "ZMB",
        "Malawi" to "MWI",
        "Tanzania" to "TZA",
        "Kenya" to "KEN",
        "Uganda" to "UGA",
        "Burundi" to "BDI",
        "Rwanda" to "RWA",
        "Ethiopia" to "ETH",
        "Sudan" to "SDN",
        "Egypt" to "EGY",
        "Libya" to "LBY",
        "Algeria" to "DZA",
        "Morocco" to "MAR",
        "Tunisia" to "TUN",
        "Mauritania" to "MRT",
        "Senegal" to "SEN",
        "Ivory Coast" to "CIV",
        "Liberia" to "LBR",
        "Ghana" to "GHA",
        "Nigeria" to "NGA",
        "Cameroon" to "CMR",
        "Gabon" to "GAB",
        "Republic of the Congo" to "COG",
        "Democratic Republic of the Congo" to "COD",
        "Angola" to "AGO",
        "Chad" to "TCD",
        "Madagascar" to "MDG",
        "Israel" to "ISR",
        "Lebanon" to "LBN",
        "Syria" to "SYR",
        "Saudi Arabia" to "SAU",
        "Qatar" to "QAT",
        "United Arab Emirates" to "ARE",
        "Oman" to "OMN",
        "Kuwait" to "KWT",
        "Ukraine" to "UKR",
        "Belarus" to "BLR",
        "Estonia" to "EST",
        "Latvia" to "LVA",
        "Lithuania" to "LTU",
        "Kyrgyzstan" to "KGZ",
        "Uzbekistan" to "UZB",
        "Tajikistan" to "TJK",
        "Turkmenistan" to "TKM",
        "Kazakhstan" to "KAZ",
        "Serbia" to "SRB",
        "Croatia" to "HRV",
        "Slovenia" to "SVN",
        "North Macedonia" to "MKD",
        "Albania" to "ALB",
        "Bosnia and Herzegovina" to "BIH",
        "Montenegro" to "MNE",
        "Kosovo" to "XKX",
        "Moldova" to "MDA",
    )

    /**
     * Abbreviates a full country name to its ISO 3166-1 alpha-3 code.
     * Returns the original string if no mapping is found.
     */
    fun abbreviate(country: String): String =
        countryToISO[country] ?: country

    /**
     * Resolves a callsign to a likely QTH string.
     * Returns state abbreviation for US (single-state areas only),
     * province for Canada, ISO alpha-3 for DX.
     */
    fun resolve(callsign: String): String? {
        val call = callsign.uppercase()
        if (call.length < 2) return null

        // US callsigns: K, W, N, AA-AL prefixes
        if (isUSCallsign(call)) {
            val digit = extractUSDigit(call) ?: return null
            val states = usCallAreas[digit] ?: return null
            return if ('/' !in states) states else null
        }

        // Canadian callsigns
        if (call.startsWith("VE") || call.startsWith("VA") ||
            call.startsWith("VY") || call.startsWith("VO")
        ) {
            val prefix = call.take(3)
            return canadianPrefixes[prefix]
        }

        // DX prefixes (longest match first)
        for (length in minOf(3, call.length) downTo 1) {
            val prefix = call.take(length)
            dxPrefixes[prefix]?.let { return it }
        }

        return null
    }

    private fun isUSCallsign(call: String): Boolean {
        val first = call[0]
        if (first == 'K' || first == 'W' || first == 'N') return true
        if (call.length >= 2 && first == 'A') {
            val second = call[1]
            return second in 'A'..'L'
        }
        return false
    }

    private fun extractUSDigit(call: String): Char? =
        call.firstOrNull { it.isDigit() }
}
