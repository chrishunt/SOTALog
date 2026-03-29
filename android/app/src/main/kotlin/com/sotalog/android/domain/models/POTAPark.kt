package com.sotalog.android.domain.models

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "potaPark")
data class POTAPark(
    @PrimaryKey
    val reference: String,
    val name: String,
    val referenceNormalized: String? = null,
    val latitude: Double? = null,
    val longitude: Double? = null,
    val locationDesc: String? = null,
) {
    val displayName: String get() = "$reference $name"

    companion object {
        fun normalize(reference: String): String =
            reference.replace("-", "").uppercase()
    }
}
