package com.sotalog.android.domain.models

import androidx.room.ColumnInfo
import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "qso")
data class QSO(
    @PrimaryKey(autoGenerate = true)
    val id: Long? = null,
    val logId: Long? = null,
    val callsign: String = "",
    val date: String = "",
    val timeOn: String = "",
    val frequency: Double? = null,
    val band: String = "20m",
    val mode: String = "CW",
    val rstSent: String = "599",
    val rstReceived: String = "599",
    val name: String? = null,
    val qth: String? = null,
    val grid: String? = null,
    val sotaRef: String? = null,
    val potaRef: String? = null,
    val notes: String? = null,
    val qrzLogId: Long? = null,
    @ColumnInfo(name = "syncedToQRZ")
    val syncedToQRZ: Boolean = false,
)
