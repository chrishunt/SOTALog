package com.sotalog.android.domain.models

import androidx.room.Entity
import androidx.room.PrimaryKey
import java.util.Date

/**
 * Cached enrichment for a callsign (name/QTH/grid from QRZ and prior contacts).
 * The "times worked" count is NOT stored here — it is derived on demand from the
 * `qso` table (see [com.sotalog.android.data.local.database.dao.QSODao.countByCallsign]),
 * which is the single source of truth and stays correct across edits, deletes, and
 * imports automatically.
 */
@Entity(tableName = "callsignHistory")
data class CallsignHistory(
    @PrimaryKey
    val callsign: String,
    val name: String? = null,
    val qth: String? = null,
    val grid: String? = null,
    val lastWorked: Date? = null,
)
