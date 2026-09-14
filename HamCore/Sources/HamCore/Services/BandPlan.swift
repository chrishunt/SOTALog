import Foundation

/// Maps frequencies (MHz) to amateur radio band names and modes.
enum BandPlan {
    struct BandEntry {
        let name: String
        let lower: Double  // MHz
        let upper: Double  // MHz
        let ssbBoundary: Double?  // MHz — frequency above which SSB begins; nil for CW-only bands
        let fmBoundary: Double?   // MHz — frequency above which FM begins; nil for bands without an FM sub-band
    }

    static let bands: [BandEntry] = [
        BandEntry(name: "160m", lower: 1.800, upper: 2.000,   ssbBoundary: 1.843,   fmBoundary: nil),
        BandEntry(name: "80m",  lower: 3.500, upper: 4.000,   ssbBoundary: 3.600,   fmBoundary: nil),
        BandEntry(name: "60m",  lower: 5.330, upper: 5.410,   ssbBoundary: nil,     fmBoundary: nil),
        BandEntry(name: "40m",  lower: 7.000, upper: 7.300,   ssbBoundary: 7.125,   fmBoundary: nil),
        BandEntry(name: "30m",  lower: 10.100, upper: 10.150, ssbBoundary: nil,     fmBoundary: nil),
        BandEntry(name: "20m",  lower: 14.000, upper: 14.350, ssbBoundary: 14.150,  fmBoundary: nil),
        BandEntry(name: "17m",  lower: 18.068, upper: 18.168, ssbBoundary: 18.110,  fmBoundary: nil),
        BandEntry(name: "15m",  lower: 21.000, upper: 21.450, ssbBoundary: 21.200,  fmBoundary: nil),
        BandEntry(name: "12m",  lower: 24.890, upper: 24.990, ssbBoundary: 24.930,  fmBoundary: nil),
        BandEntry(name: "10m",  lower: 28.000, upper: 29.700, ssbBoundary: 28.300,  fmBoundary: nil),
        BandEntry(name: "6m",   lower: 50.000, upper: 54.000, ssbBoundary: 50.100,  fmBoundary: 51.000),
        BandEntry(name: "2m",   lower: 144.000, upper: 148.000, ssbBoundary: 144.100, fmBoundary: 145.000),
    ]

    /// Returns the band name for a given frequency in MHz, or nil if out of range.
    static func band(for frequencyMHz: Double) -> String? {
        bands.first { frequencyMHz >= $0.lower && frequencyMHz <= $0.upper }?.name
    }

    /// Returns "CW", "SSB", or "FM" based on frequency position within the band, or nil if out of band.
    static func mode(for frequencyMHz: Double) -> String? {
        guard let entry = bands.first(where: { frequencyMHz >= $0.lower && frequencyMHz <= $0.upper }) else {
            return nil
        }
        if let fm = entry.fmBoundary, frequencyMHz >= fm {
            return "FM"
        }
        guard let boundary = entry.ssbBoundary else {
            return "CW"  // CW-only band
        }
        return frequencyMHz >= boundary ? "SSB" : "CW"
    }

    /// Returns the default CW sub-band frequency for a given band name.
    static func defaultCWFrequency(for band: String) -> Double? {
        switch band {
        case "160m": return 1.810
        case "80m":  return 3.530
        case "60m":  return 5.332
        case "40m":  return 7.030
        case "30m":  return 10.110
        case "20m":  return 14.060
        case "17m":  return 18.080
        case "15m":  return 21.060
        case "12m":  return 24.910
        case "10m":  return 28.060
        case "6m":   return 50.060
        case "2m":   return 144.060
        default:     return nil
        }
    }

    /// Returns the default SSB sub-band frequency for a given band name, or nil for CW-only bands.
    static func defaultSSBFrequency(for band: String) -> Double? {
        switch band {
        case "160m": return 1.850
        case "80m":  return 3.860
        case "40m":  return 7.200
        case "20m":  return 14.260
        case "17m":  return 18.130
        case "15m":  return 21.300
        case "12m":  return 24.950
        case "10m":  return 28.400
        case "6m":   return 50.125
        case "2m":   return 144.200
        default:     return nil  // 30m, 60m are CW-only
        }
    }

    /// Returns the default FM sub-band frequency for a given band name, or nil for bands without an FM sub-band.
    static func defaultFMFrequency(for band: String) -> Double? {
        switch band {
        case "6m": return 52.525   // US 6m simplex calling
        case "2m": return 146.520  // US 2m simplex calling
        default:   return nil
        }
    }

    /// All band names in order
    static let allBands: [String] = bands.map(\.name)
}
