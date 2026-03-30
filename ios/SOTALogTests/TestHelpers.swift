import Foundation
@testable import SOTALog

/// Creates a Spot with sensible defaults for testing.
func makeSpot(
    id: String = UUID().uuidString,
    callsign: String = "W1AW",
    frequency: Double = 14.060,
    mode: String = "CW",
    potaReference: String? = nil,
    potaReferenceName: String? = nil,
    sotaReference: String? = nil,
    sotaReferenceName: String? = nil,
    spotterCallsign: String? = nil,
    comments: String? = nil,
    timestamp: Date = Date()
) -> Spot {
    Spot(
        id: id,
        activatorCallsign: callsign,
        frequency: frequency,
        mode: mode,
        potaReference: potaReference,
        potaReferenceName: potaReferenceName,
        sotaReference: sotaReference,
        sotaReferenceName: sotaReferenceName,
        spotterCallsign: spotterCallsign,
        comments: comments,
        timestamp: timestamp
    )
}

/// Creates a deterministic UTC Date from components.
func makeUTCDate(
    year: Int = 2024,
    month: Int = 6,
    day: Int = 15,
    hour: Int = 12,
    minute: Int = 0,
    second: Int = 0
) -> Date {
    var components = DateComponents()
    components.year = year
    components.month = month
    components.day = day
    components.hour = hour
    components.minute = minute
    components.second = second
    components.timeZone = TimeZone(identifier: "UTC")
    return Calendar(identifier: .gregorian).date(from: components)!
}

/// Creates and saves a Log, returning it with its assigned ID.
func makeLogWithId(
    in database: AppDatabase,
    callsign: String = "W1AW",
    potaRef: String? = nil,
    sotaRef: String? = nil
) async throws -> Log {
    let logRepo = LogRepository(database: database)
    var log = Log(
        date: Date().adifDate,
        myCallsign: callsign,
        potaReference: potaRef,
        sotaReference: sotaRef
    )
    try await logRepo.save(&log)
    return log
}
