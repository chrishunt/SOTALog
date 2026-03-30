package com.sotalog.android.data.repositories

import com.sotalog.android.data.local.database.dao.CallsignHistoryDao
import com.sotalog.android.di.SOTALogDatabase
import com.sotalog.android.domain.models.CallsignHistory
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.util.Date
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class CallsignHistoryRepository @Inject constructor(
    private val callsignHistoryDao: CallsignHistoryDao,
    private val db: SOTALogDatabase,
) {

    suspend fun fetch(callsign: String): CallsignHistory? = withContext(Dispatchers.IO) {
        callsignHistoryDao.getByCallsign(callsign.uppercase())
    }

    suspend fun recordQSO(
        callsign: String,
        name: String?,
        qth: String?,
        grid: String?,
    ) = withContext(Dispatchers.IO) {
        val upper = callsign.uppercase()
        val existing = callsignHistoryDao.getByCallsign(upper)
        if (existing != null) {
            callsignHistoryDao.upsert(
                existing.copy(
                    timesWorked = existing.timesWorked + 1,
                    lastWorked = Date(),
                    name = name?.takeIf { it.isNotEmpty() } ?: existing.name,
                    qth = qth?.takeIf { it.isNotEmpty() } ?: existing.qth,
                    grid = grid?.takeIf { it.isNotEmpty() } ?: existing.grid,
                )
            )
        } else {
            callsignHistoryDao.upsert(
                CallsignHistory(
                    callsign = upper,
                    name = name,
                    qth = qth,
                    grid = grid,
                    lastWorked = Date(),
                    timesWorked = 1,
                )
            )
        }
    }

    suspend fun rebuildFromQSOTable() = withContext(Dispatchers.IO) {
        val sqlDb = db.openHelper.readableDatabase
        sqlDb.query(
            """
            SELECT callsign,
                   COUNT(*) as cnt,
                   MAX(date || timeOn) as lastWorked,
                   COALESCE(MAX(name), '') as name,
                   COALESCE(MAX(qth), '') as qth,
                   COALESCE(MAX(grid), '') as grid
            FROM qso
            GROUP BY callsign
            """.trimIndent()
        ).use { cursor ->
            while (cursor.moveToNext()) {
                val cs = cursor.getString(0)
                val count = cursor.getInt(1)
                val nameVal = cursor.getString(3).takeIf { it.isNotEmpty() }
                val qthVal = cursor.getString(4).takeIf { it.isNotEmpty() }
                val gridVal = cursor.getString(5).takeIf { it.isNotEmpty() }

                val existing = callsignHistoryDao.getByCallsign(cs)
                callsignHistoryDao.upsert(
                    CallsignHistory(
                        callsign = cs,
                        name = nameVal ?: existing?.name,
                        qth = qthVal ?: existing?.qth,
                        grid = gridVal ?: existing?.grid,
                        lastWorked = existing?.lastWorked ?: Date(),
                        timesWorked = count,
                    )
                )
            }
        }
    }

    suspend fun updateFromLookup(
        callsign: String,
        name: String?,
        qth: String?,
        grid: String?,
    ) = withContext(Dispatchers.IO) {
        val upper = callsign.uppercase()
        val existing = callsignHistoryDao.getByCallsign(upper)
        if (existing != null) {
            callsignHistoryDao.upsert(
                existing.copy(
                    name = name?.takeIf { it.isNotEmpty() } ?: existing.name,
                    qth = qth?.takeIf { it.isNotEmpty() } ?: existing.qth,
                    grid = grid?.takeIf { it.isNotEmpty() } ?: existing.grid,
                )
            )
        } else {
            callsignHistoryDao.upsert(
                CallsignHistory(
                    callsign = upper,
                    name = name,
                    qth = qth,
                    grid = grid,
                    lastWorked = null,
                    timesWorked = 0,
                )
            )
        }
    }
}
