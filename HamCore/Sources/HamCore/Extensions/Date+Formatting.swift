import Foundation

extension Date {
    /// Formats as "YYYYMMDD" for ADIF
    public var adifDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: self)
    }

    /// Formats as "HHMM" UTC for ADIF
    public var adifTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HHmm"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: self)
    }

    /// Formats as "HH:MMZ" for display
    public var utcTimeDisplay: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: self) + "Z"
    }

    /// Formats as "YYYY-MM-DD" for display
    public var shortDateDisplay: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: self)
    }
}
