package com.sotalog.android.domain.services

object MaidenheadConverter {

    private const val FIELD_CHARS = "ABCDEFGHIJKLMNOPQR"
    private const val SUB_CHARS = "abcdefghijklmnopqrstuvwx"

    fun gridSquare(latitude: Double, longitude: Double): String {
        val lon = longitude + 180.0
        val lat = latitude + 90.0

        val lonField = (lon / 20.0).toInt()
        val latField = (lat / 10.0).toInt()

        val lonSquare = ((lon - lonField * 20.0) / 2.0).toInt()
        val latSquare = ((lat - latField * 10.0) / 1.0).toInt()

        val lonSub = ((lon - lonField * 20.0 - lonSquare * 2.0) / (2.0 / 24.0)).toInt()
        val latSub = ((lat - latField * 10.0 - latSquare * 1.0) / (1.0 / 24.0)).toInt()

        val c1 = FIELD_CHARS[lonField.coerceAtMost(17)]
        val c2 = FIELD_CHARS[latField.coerceAtMost(17)]
        val c3 = lonSquare.toString()[0]
        val c4 = latSquare.toString()[0]
        val c5 = SUB_CHARS[lonSub.coerceAtMost(23)]
        val c6 = SUB_CHARS[latSub.coerceAtMost(23)]

        return "$c1$c2$c3$c4$c5$c6"
    }

    fun grid4(latitude: Double, longitude: Double): String =
        gridSquare(latitude, longitude).take(4)
}
