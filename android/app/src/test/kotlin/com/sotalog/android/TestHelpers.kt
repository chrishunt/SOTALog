package com.sotalog.android

import com.sotalog.android.domain.models.Spot
import java.util.Calendar
import java.util.Date
import java.util.TimeZone
import java.util.UUID

/**
 * Creates a Spot with sensible defaults for testing.
 */
fun makeSpot(
    id: String = UUID.randomUUID().toString(),
    callsign: String = "W1AW",
    frequency: Double = 14.060,
    mode: String = "CW",
    potaReference: String? = null,
    potaReferenceName: String? = null,
    sotaReference: String? = null,
    sotaReferenceName: String? = null,
    spotterCallsign: String? = null,
    comments: String? = null,
    timestamp: Date = Date(),
): Spot = Spot(
    id = id,
    activatorCallsign = callsign,
    frequency = frequency,
    mode = mode,
    potaReference = potaReference,
    potaReferenceName = potaReferenceName,
    sotaReference = sotaReference,
    sotaReferenceName = sotaReferenceName,
    spotterCallsign = spotterCallsign,
    comments = comments,
    timestamp = timestamp,
)

/**
 * Creates a deterministic UTC Date from components.
 */
fun makeUTCDate(
    year: Int = 2024,
    month: Int = 6,
    day: Int = 15,
    hour: Int = 12,
    minute: Int = 0,
    second: Int = 0,
): Date {
    val cal = Calendar.getInstance(TimeZone.getTimeZone("UTC"))
    cal.set(Calendar.YEAR, year)
    cal.set(Calendar.MONTH, month - 1) // Calendar months are 0-based
    cal.set(Calendar.DAY_OF_MONTH, day)
    cal.set(Calendar.HOUR_OF_DAY, hour)
    cal.set(Calendar.MINUTE, minute)
    cal.set(Calendar.SECOND, second)
    cal.set(Calendar.MILLISECOND, 0)
    return cal.time
}
