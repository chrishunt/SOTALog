package com.sotalog.android.domain.services

object BandPlan {

    data class BandEntry(
        val name: String,
        val lower: Double,
        val upper: Double,
        val ssbBoundary: Double?,
    )

    val bands: List<BandEntry> = listOf(
        BandEntry(name = "160m", lower = 1.800, upper = 2.000, ssbBoundary = 1.843),
        BandEntry(name = "80m", lower = 3.500, upper = 4.000, ssbBoundary = 3.600),
        BandEntry(name = "60m", lower = 5.330, upper = 5.410, ssbBoundary = null),
        BandEntry(name = "40m", lower = 7.000, upper = 7.300, ssbBoundary = 7.125),
        BandEntry(name = "30m", lower = 10.100, upper = 10.150, ssbBoundary = null),
        BandEntry(name = "20m", lower = 14.000, upper = 14.350, ssbBoundary = 14.150),
        BandEntry(name = "17m", lower = 18.068, upper = 18.168, ssbBoundary = 18.110),
        BandEntry(name = "15m", lower = 21.000, upper = 21.450, ssbBoundary = 21.200),
        BandEntry(name = "12m", lower = 24.890, upper = 24.990, ssbBoundary = 24.930),
        BandEntry(name = "10m", lower = 28.000, upper = 29.700, ssbBoundary = 28.300),
        BandEntry(name = "6m", lower = 50.000, upper = 54.000, ssbBoundary = 50.100),
        BandEntry(name = "2m", lower = 144.000, upper = 148.000, ssbBoundary = 144.100),
    )

    fun band(frequencyMHz: Double): String? =
        bands.firstOrNull { frequencyMHz in it.lower..it.upper }?.name

    fun mode(frequencyMHz: Double): String? {
        val entry = bands.firstOrNull { frequencyMHz in it.lower..it.upper } ?: return null
        val boundary = entry.ssbBoundary ?: return "CW"
        return if (frequencyMHz >= boundary) "SSB" else "CW"
    }

    fun defaultCWFrequency(band: String): Double? = when (band) {
        "160m" -> 1.810
        "80m" -> 3.530
        "60m" -> 5.332
        "40m" -> 7.030
        "30m" -> 10.110
        "20m" -> 14.060
        "17m" -> 18.080
        "15m" -> 21.060
        "12m" -> 24.910
        "10m" -> 28.060
        "6m" -> 50.060
        "2m" -> 144.060
        else -> null
    }

    fun defaultSSBFrequency(band: String): Double? = when (band) {
        "160m" -> 1.850
        "80m" -> 3.860
        "40m" -> 7.200
        "20m" -> 14.260
        "17m" -> 18.130
        "15m" -> 21.300
        "12m" -> 24.950
        "10m" -> 28.400
        "6m" -> 50.125
        "2m" -> 144.200
        else -> null
    }

    val allBands: List<String> = bands.map { it.name }
}
