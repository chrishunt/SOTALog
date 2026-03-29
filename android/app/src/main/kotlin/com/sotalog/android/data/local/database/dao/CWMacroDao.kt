package com.sotalog.android.data.local.database.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.Query
import androidx.room.Update
import com.sotalog.android.domain.models.CWMacro
import kotlinx.coroutines.flow.Flow

@Dao
interface CWMacroDao {

    @Query("SELECT * FROM cwMacro ORDER BY position ASC")
    fun observeAll(): Flow<List<CWMacro>>

    @Query("SELECT * FROM cwMacro ORDER BY position ASC")
    suspend fun getAll(): List<CWMacro>

    @Insert
    suspend fun insertAll(macros: List<CWMacro>)

    @Update
    suspend fun update(macro: CWMacro)

    @Query("DELETE FROM cwMacro")
    suspend fun deleteAll()
}
