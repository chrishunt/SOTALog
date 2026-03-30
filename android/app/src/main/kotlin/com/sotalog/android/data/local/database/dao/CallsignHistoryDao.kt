package com.sotalog.android.data.local.database.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import com.sotalog.android.domain.models.CallsignHistory

@Dao
interface CallsignHistoryDao {

    @Query("SELECT * FROM callsignHistory WHERE callsign = :callsign")
    suspend fun getByCallsign(callsign: String): CallsignHistory?

    @Query("SELECT * FROM callsignHistory ORDER BY lastWorked DESC LIMIT :limit")
    suspend fun getRecent(limit: Int = 50): List<CallsignHistory>

    @Query("SELECT * FROM callsignHistory WHERE callsign LIKE :prefix || '%' ORDER BY timesWorked DESC LIMIT :limit")
    suspend fun searchByPrefix(prefix: String, limit: Int = 20): List<CallsignHistory>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsert(history: CallsignHistory)
}
