import Foundation

/// Converts latitude/longitude to Maidenhead grid square locator.
enum MaidenheadConverter {
    /// Converts lat/lon to a 6-character Maidenhead grid square.
    /// - Parameters:
    ///   - latitude: Latitude in decimal degrees (-90 to 90)
    ///   - longitude: Longitude in decimal degrees (-180 to 180)
    /// - Returns: 6-character grid square (e.g. "FM19la")
    static func gridSquare(latitude: Double, longitude: Double) -> String {
        let lon = longitude + 180.0
        let lat = latitude + 90.0

        // Field (18 zones, A-R)
        let lonField = Int(lon / 20.0)
        let latField = Int(lat / 10.0)

        // Square (10 zones, 0-9)
        let lonSquare = Int((lon - Double(lonField) * 20.0) / 2.0)
        let latSquare = Int((lat - Double(latField) * 10.0) / 1.0)

        // Subsquare (24 zones, a-x)
        let lonSub = Int((lon - Double(lonField) * 20.0 - Double(lonSquare) * 2.0) / (2.0 / 24.0))
        let latSub = Int((lat - Double(latField) * 10.0 - Double(latSquare) * 1.0) / (1.0 / 24.0))

        let fieldChars = "ABCDEFGHIJKLMNOPQR"
        let subChars = "abcdefghijklmnopqrstuvwx"

        let c1 = fieldChars[fieldChars.index(fieldChars.startIndex, offsetBy: min(lonField, 17))]
        let c2 = fieldChars[fieldChars.index(fieldChars.startIndex, offsetBy: min(latField, 17))]
        let c3 = Character("\(lonSquare)")
        let c4 = Character("\(latSquare)")
        let c5 = subChars[subChars.index(subChars.startIndex, offsetBy: min(lonSub, 23))]
        let c6 = subChars[subChars.index(subChars.startIndex, offsetBy: min(latSub, 23))]

        return String([c1, c2, c3, c4, c5, c6])
    }

    /// Returns just the 4-character grid square (field + square).
    static func grid4(latitude: Double, longitude: Double) -> String {
        String(gridSquare(latitude: latitude, longitude: longitude).prefix(4))
    }
}
