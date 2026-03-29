package com.sotalog.android.domain.models

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "sotaSummit")
data class SOTASummit(
    @PrimaryKey
    val code: String,
    val codeNormalized: String? = null,
    val name: String,
    val associationCode: String? = null,
    val regionCode: String? = null,
    val altitude: Int? = null,
    val points: Int? = null,
    val grid: String? = null,
    val latitude: Double? = null,
    val longitude: Double? = null,
    val validFrom: String? = null,
    val validTo: String? = null,
) {
    val displayName: String get() = "$code $name"

    companion object {
        fun normalize(code: String): String =
            code.replace("/", "").replace("-", "").uppercase()
    }
}
