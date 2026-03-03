import Foundation

/// Maps frequencies (MHz) to amateur radio band names.
enum BandPlan {
    struct BandEntry {
        let name: String
        let lower: Double  // MHz
        let upper: Double  // MHz
    }

    static let bands: [BandEntry] = [
        BandEntry(name: "160m", lower: 1.800, upper: 2.000),
        BandEntry(name: "80m",  lower: 3.500, upper: 4.000),
        BandEntry(name: "60m",  lower: 5.330, upper: 5.410),
        BandEntry(name: "40m",  lower: 7.000, upper: 7.300),
        BandEntry(name: "30m",  lower: 10.100, upper: 10.150),
        BandEntry(name: "20m",  lower: 14.000, upper: 14.350),
        BandEntry(name: "17m",  lower: 18.068, upper: 18.168),
        BandEntry(name: "15m",  lower: 21.000, upper: 21.450),
        BandEntry(name: "12m",  lower: 24.890, upper: 24.990),
        BandEntry(name: "10m",  lower: 28.000, upper: 29.700),
        BandEntry(name: "6m",   lower: 50.000, upper: 54.000),
        BandEntry(name: "2m",   lower: 144.000, upper: 148.000),
    ]

    /// Returns the band name for a given frequency in MHz, or nil if out of range.
    static func band(for frequencyMHz: Double) -> String? {
        bands.first { frequencyMHz >= $0.lower && frequencyMHz <= $0.upper }?.name
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

    /// All band names in order
    static let allBands: [String] = bands.map(\.name)
}
