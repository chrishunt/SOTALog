import Foundation

extension String {
    /// Sanitizes input to valid callsign characters (A-Z, 0-9, /)
    var sanitizedCallsign: String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "/"))
        return uppercased().unicodeScalars.filter { allowed.contains($0) }.map { String($0) }.joined()
    }

    /// Sanitizes input to alphanumeric only (for SOTA code entry without slashes/dashes)
    var sanitizedAlphanumeric: String {
        uppercased().unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }.map { String($0) }.joined()
    }
}
