package com.sotalog.android.data.local.database.dao

import androidx.room.Dao
import androidx.room.Delete
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.Update
import com.sotalog.android.domain.models.QSO
import kotlinx.coroutines.flow.Flow

@Dao
interface QSODao {

    @Query("SELECT * FROM qso ORDER BY id DESC")
    suspend fun getAll(): List<QSO>

    @Query("SELECT * FROM qso WHERE logId = :logId ORDER BY date DESC, timeOn DESC")
    fun observeByLogId(logId: Long): Flow<List<QSO>>

    @Query("SELECT * FROM qso WHERE logId = :logId ORDER BY date DESC, timeOn DESC")
    suspend fun getByLogId(logId: Long): List<QSO>

    @Query("SELECT * FROM qso WHERE id = :id")
    suspend fun getById(id: Long): QSO?

    @Query("SELECT * FROM qso WHERE syncedToQRZ = 0")
    suspend fun getUnsynced(): List<QSO>

    @Query("SELECT * FROM qso WHERE syncedToQRZ = 0 AND logId = :logId")
    suspend fun getUnsyncedByLogId(logId: Long): List<QSO>

    @Query("SELECT * FROM qso WHERE qrzLogId = :qrzLogId LIMIT 1")
    suspend fun getByQrzLogId(qrzLogId: Long): QSO?

    @Query("SELECT COUNT(*) FROM qso WHERE logId = :logId")
    suspend fun getCountByLogId(logId: Long): Int

    @Query("SELECT COUNT(*) FROM qso WHERE logId = :logId")
    fun observeCountByLogId(logId: Long): Flow<Int>

    @Insert(onConflict = OnConflictStrategy.ABORT)
    suspend fun insert(qso: QSO): Long

    @Update
    suspend fun update(qso: QSO)

    @Delete
    suspend fun delete(qso: QSO)

    @Query("DELETE FROM qso WHERE id = :id")
    suspend fun deleteById(id: Long)

    @Query("DELETE FROM qso WHERE logId = :logId")
    suspend fun deleteByLogId(logId: Long)

    @Query(
        """SELECT COUNT(*) FROM qso
           WHERE callsign = :callsign AND band = :band AND mode = :mode
           AND logId = :logId AND (:excludingId IS NULL OR id != :excludingId)"""
    )
    suspend fun countDuplicates(
        callsign: String,
        band: String,
        mode: String,
        logId: Long,
        excludingId: Long?,
    ): Int

    @Query("SELECT * FROM qso WHERE date = :date")
    fun observeByDate(date: String): Flow<List<QSO>>
}
