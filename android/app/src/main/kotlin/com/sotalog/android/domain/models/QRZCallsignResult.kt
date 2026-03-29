package com.sotalog.android.domain.models

data class QRZCallsignResult(
    val callsign: String,
    val firstName: String? = null,
    val nickname: String? = null,
    val lastName: String? = null,
    val city: String? = null,
    val state: String? = null,
    val country: String? = null,
    val grid: String? = null,
    val county: String? = null,
) {
    val name: String?
        get() {
            if (nickname != null) return nickname
            val full = listOfNotNull(firstName, lastName).joinToString(" ")
            return full.ifEmpty { null }
        }

    val qth: String?
        get() = state ?: country
}
