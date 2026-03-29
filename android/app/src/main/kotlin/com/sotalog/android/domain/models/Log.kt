package com.sotalog.android.domain.models

import androidx.room.Entity
import androidx.room.PrimaryKey
import java.util.Date

@Entity(tableName = "log")
data class Log(
    @PrimaryKey(autoGenerate = true)
    val id: Long? = null,
    val createdAt: Date? = null,
    val date: String = "",
    val myCallsign: String = "",
    val myGrid: String? = null,
    val potaReference: String? = null,
    val sotaReference: String? = null,
    val parkName: String? = null,
    val summitName: String? = null,
    val notes: String? = null,
) {
    val formattedDate: String
        get() {
            if (date.length != 8) return date
            val y = date.substring(0, 4)
            val m = date.substring(4, 6)
            val d = date.substring(6, 8)
            return "$y-$m-$d"
        }

    val isPOTA: Boolean get() = potaReference != null

    val isSOTA: Boolean get() = sotaReference != null

    val referenceDisplay: String?
        get() {
            val parts = buildList {
                potaReference?.let { add(it) }
                sotaReference?.let { add(it) }
            }
            return parts.ifEmpty { null }?.joinToString(" \u00B7 ")
        }
}
