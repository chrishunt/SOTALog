package com.sotalog.android.domain.models

import com.sotalog.android.domain.services.BandPlan
import java.util.Date

data class Spot(
    val id: String,
    val activatorCallsign: String,
    val frequency: Double,
    val mode: String,
    val potaReference: String? = null,
    val potaReferenceName: String? = null,
    val sotaReference: String? = null,
    val sotaReferenceName: String? = null,
    val spotterCallsign: String? = null,
    val comments: String? = null,
    val timestamp: Date,
) {
    enum class Source(val value: String) {
        POTA("pota"),
        SOTA("sota"),
    }

    val sources: Set<Source>
        get() = buildSet {
            if (potaReference != null) add(Source.POTA)
            if (sotaReference != null) add(Source.SOTA)
        }

    val source: Source
        get() = if (potaReference != null) Source.POTA else Source.SOTA

    val reference: String
        get() = potaReference ?: sotaReference ?: ""

    val referenceName: String?
        get() = potaReferenceName ?: sotaReferenceName

    fun isExpired(afterMinutes: Double = 60.0): Boolean {
        return (Date().time - timestamp.time) > (afterMinutes * 60 * 1000).toLong()
    }

    val isQRT: Boolean
        get() = comments?.uppercase()?.contains("QRT") == true

    val band: String
        get() = BandPlan.band(frequency) ?: "?"

    val ageMinutes: Int
        get() = maxOf(1, ((Date().time - timestamp.time) / 60_000).toInt())
}
