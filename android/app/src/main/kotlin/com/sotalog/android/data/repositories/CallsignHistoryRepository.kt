package com.sotalog.android.data.repositories

import com.sotalog.android.data.local.database.dao.CallsignHistoryDao
import com.sotalog.android.domain.models.CallsignHistory
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.util.Date
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class CallsignHistoryRepository @Inject constructor(
    private val callsignHistoryDao: CallsignHistoryDao,
) {

    suspend fun fetch(callsign: String): CallsignHistory? = withContext(Dispatchers.IO) {
        callsignHistoryDao.getByCallsign(callsign.uppercase())
    }

    /**
     * Records that a QSO was just logged: refreshes lastWorked and fills in
     * name/qth/grid if provided. Call this when creating a new QSO.
     */
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
                )
            )
        }
    }

    /**
     * Updates enrichment from a QRZ lookup or an edit, without touching lastWorked
     * (no new contact was made).
     */
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
                )
            )
        }
    }
}
