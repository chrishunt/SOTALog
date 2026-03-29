package com.sotalog.android.domain.models

import androidx.room.Entity
import androidx.room.PrimaryKey
import java.util.Date

@Entity(tableName = "callsignHistory")
data class CallsignHistory(
    @PrimaryKey
    val callsign: String,
    val name: String? = null,
    val qth: String? = null,
    val grid: String? = null,
    val lastWorked: Date? = null,
    val timesWorked: Int = 0,
)
