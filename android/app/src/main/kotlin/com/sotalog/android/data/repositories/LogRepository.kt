package com.sotalog.android.data.repositories

import com.sotalog.android.data.local.database.dao.LogDao
import com.sotalog.android.data.local.database.dao.QSODao
import com.sotalog.android.domain.models.Log
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.withContext
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class LogRepository @Inject constructor(
    private val logDao: LogDao,
    private val qsoDao: QSODao,
) {

    suspend fun fetchAll(): List<Log> = withContext(Dispatchers.IO) {
        logDao.getAll()
    }

    suspend fun fetch(id: Long): Log? = withContext(Dispatchers.IO) {
        logDao.getById(id)
    }

    suspend fun save(log: Log): Log = withContext(Dispatchers.IO) {
        if (log.id != null && log.id > 0) {
            logDao.update(log)
            log
        } else {
            val newId = logDao.insert(log)
            log.copy(id = newId)
        }
    }

    suspend fun delete(id: Long) = withContext(Dispatchers.IO) {
        val log = logDao.getById(id) ?: return@withContext
        // Delete unsynced QSOs for this log
        val qsos = qsoDao.getByLogId(id)
        for (qso in qsos) {
            if (!qso.syncedToQRZ) {
                qsoDao.delete(qso)
            }
        }
        logDao.delete(log)
    }

    fun observeAll(): Flow<List<Log>> = logDao.observeAll()
}
