package com.sotalog.android.data.local.database.dao

import androidx.room.Dao
import androidx.room.Delete
import androidx.room.Insert
import androidx.room.Query
import androidx.room.Update
import com.sotalog.android.domain.models.Log
import kotlinx.coroutines.flow.Flow

@Dao
interface LogDao {

    @Query("SELECT * FROM log ORDER BY createdAt DESC")
    fun observeAll(): Flow<List<Log>>

    @Query("SELECT * FROM log ORDER BY createdAt DESC")
    suspend fun getAll(): List<Log>

    @Query("SELECT * FROM log WHERE id = :id")
    suspend fun getById(id: Long): Log?

    @Query("SELECT * FROM log WHERE id = :id")
    fun observeById(id: Long): Flow<Log?>

    @Insert
    suspend fun insert(log: Log): Long

    @Update
    suspend fun update(log: Log)

    @Delete
    suspend fun delete(log: Log)
}
