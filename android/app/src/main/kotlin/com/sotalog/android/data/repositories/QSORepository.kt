package com.sotalog.android.data.repositories

import com.sotalog.android.data.local.database.dao.QSODao
import com.sotalog.android.di.SOTALogDatabase
import com.sotalog.android.domain.models.QSO
import com.sotalog.android.domain.models.ReferenceMetadata
import com.sotalog.android.domain.services.SyncImporter
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.withContext
import java.util.Date
import javax.inject.Inject
import javax.inject.Singleton

data class FullRefreshResult(
    val importedCount: Int,
    val activationsCreated: Int,
    val activationsReused: Int,
)

@Singleton
class QSORepository @Inject constructor(
    private val qsoDao: QSODao,
    private val db: SOTALogDatabase,
) {

    suspend fun fetchAll(): List<QSO> = withContext(Dispatchers.IO) {
        qsoDao.getAll()
    }

    suspend fun fetchAll(logId: Long): List<QSO> = withContext(Dispatchers.IO) {
        qsoDao.getByLogId(logId)
    }

    suspend fun fetchUnsynced(): List<QSO> = withContext(Dispatchers.IO) {
        qsoDao.getUnsynced()
    }

    suspend fun fetchCount(logId: Long): Int = withContext(Dispatchers.IO) {
        qsoDao.getCountByLogId(logId)
    }

    suspend fun fetch(id: Long): QSO? = withContext(Dispatchers.IO) {
        qsoDao.getById(id)
    }

    suspend fun save(qso: QSO): QSO = withContext(Dispatchers.IO) {
        if (qso.id != null && qso.id > 0) {
            qsoDao.update(qso)
            qso
        } else {
            val newId = qsoDao.insert(qso)
            qso.copy(id = newId)
        }
    }

    suspend fun delete(id: Long) = withContext(Dispatchers.IO) {
        qsoDao.deleteById(id)
    }

    suspend fun markSynced(id: Long, qrzLogId: Long) = withContext(Dispatchers.IO) {
        val qso = qsoDao.getById(id) ?: return@withContext
        qsoDao.update(qso.copy(syncedToQRZ = true, qrzLogId = qrzLogId))
    }

    suspend fun isDuplicate(
        callsign: String,
        band: String,
        mode: String,
        logId: Long,
        excludingId: Long?,
    ): Boolean = withContext(Dispatchers.IO) {
        qsoDao.countDuplicates(callsign, band, mode, logId, excludingId) > 0
    }

    suspend fun saveLastSyncedQRZLogId(qrzLogId: Long) = withContext(Dispatchers.IO) {
        db.referenceDao().upsertMetadata(
            ReferenceMetadata(
                key = "lastSyncedQRZLogId",
                lastRefreshed = Date(),
                recordCount = qrzLogId.toInt(),
            )
        )
    }

    suspend fun lastSyncDate(): Date? = withContext(Dispatchers.IO) {
        db.referenceDao().getMetadata("lastSyncedQRZLogId")?.lastRefreshed
    }

    suspend fun loadValidPotaRefs(): Map<String, String> = withContext(Dispatchers.IO) {
        val sqlDb = db.openHelper.readableDatabase
        val cursor = sqlDb.query(
            "SELECT referenceNormalized, reference FROM potaPark WHERE referenceNormalized IS NOT NULL"
        )
        val result = mutableMapOf<String, String>()
        while (cursor.moveToNext()) {
            val normalized = cursor.getString(0)
            val formatted = cursor.getString(1)
            result[normalized] = formatted
        }
        cursor.close()
        result
    }

    suspend fun loadValidSotaCodes(): Map<String, String> = withContext(Dispatchers.IO) {
        val sqlDb = db.openHelper.readableDatabase
        val cursor = sqlDb.query(
            "SELECT codeNormalized, code FROM sotaSummit WHERE codeNormalized IS NOT NULL"
        )
        val result = mutableMapOf<String, String>()
        while (cursor.moveToNext()) {
            val normalized = cursor.getString(0)
            val formatted = cursor.getString(1)
            result[normalized] = formatted
        }
        cursor.close()
        result
    }

    @Suppress("BlockingMethodInNonBlockingContext")
    suspend fun fullRefreshImport(
        groupedQSOs: List<Pair<SyncImporter.ActivationKey, List<SyncImporter.ParsedQSORecord>>>,
        unattachedQSOs: List<SyncImporter.ParsedQSORecord>,
    ): FullRefreshResult = withContext(Dispatchers.IO) {
        var importedCount = 0
        var activationsCreated = 0
        var activationsReused = 0

        db.runInTransaction {
            val sqlDb = db.openHelper.writableDatabase

            // Delete all synced QSOs (they will be re-imported from QRZ)
            sqlDb.execSQL("DELETE FROM qso WHERE syncedToQRZ = 1")

            // Delete logs that now have no QSOs
            sqlDb.execSQL(
                "DELETE FROM log WHERE id NOT IN (SELECT DISTINCT logId FROM qso WHERE logId IS NOT NULL)"
            )

            // Import grouped QSOs into activations
            for ((key, records) in groupedQSOs) {
                // Try to find an existing log matching this activation
                val existingLogCursor = sqlDb.query(
                    """SELECT id FROM log WHERE date = ?
                       AND COALESCE(potaReference, '') = COALESCE(?, '')
                       AND COALESCE(sotaReference, '') = COALESCE(?, '')
                       LIMIT 1""",
                    arrayOf(
                        key.date,
                        key.potaReference ?: "",
                        key.sotaReference ?: "",
                    )
                )

                val logId: Long
                if (existingLogCursor.moveToFirst()) {
                    logId = existingLogCursor.getLong(0)
                    activationsReused++
                } else {
                    // Look up park/summit names
                    val parkName = key.potaReference?.let { ref ->
                        val c = sqlDb.query(
                            "SELECT name FROM potaPark WHERE reference = ?",
                            arrayOf(ref),
                        )
                        val name = if (c.moveToFirst()) c.getString(0) else null
                        c.close()
                        name
                    }
                    val summitName = key.sotaReference?.let { ref ->
                        val c = sqlDb.query(
                            "SELECT name FROM sotaSummit WHERE code = ?",
                            arrayOf(ref),
                        )
                        val name = if (c.moveToFirst()) c.getString(0) else null
                        c.close()
                        name
                    }

                    val contentValues = android.content.ContentValues().apply {
                        put("date", key.date)
                        put("myCallsign", key.stationCallsign)
                        put("myGrid", key.myGrid)
                        put("potaReference", key.potaReference)
                        put("sotaReference", key.sotaReference)
                        put("parkName", parkName)
                        put("summitName", summitName)
                        put("createdAt", Date().time)
                    }
                    logId = sqlDb.insert("log", 0, contentValues)
                    activationsCreated++
                }
                existingLogCursor.close()

                for (record in records) {
                    val qrzLogIdStr = record.rawFields["APP_QRZLOG_LOGID"]
                    val qrzLogId = qrzLogIdStr?.toLongOrNull()

                    // Skip if already exists by qrzLogId
                    if (qrzLogId != null) {
                        val existCursor = sqlDb.query(
                            "SELECT id FROM qso WHERE qrzLogId = ? LIMIT 1",
                            arrayOf(qrzLogId.toString()),
                        )
                        val exists = existCursor.moveToFirst()
                        existCursor.close()
                        if (exists) continue
                    }

                    insertQSOContentValues(sqlDb, record.qso, logId, qrzLogId)
                    importedCount++
                }
            }

            // Import unattached QSOs (no activation reference)
            for (record in unattachedQSOs) {
                val qrzLogIdStr = record.rawFields["APP_QRZLOG_LOGID"]
                val qrzLogId = qrzLogIdStr?.toLongOrNull()

                if (qrzLogId != null) {
                    val existCursor = sqlDb.query(
                        "SELECT id FROM qso WHERE qrzLogId = ? LIMIT 1",
                        arrayOf(qrzLogId.toString()),
                    )
                    val exists = existCursor.moveToFirst()
                    existCursor.close()
                    if (exists) continue
                }

                insertQSOContentValues(sqlDb, record.qso, null, qrzLogId)
                importedCount++
            }
        }

        FullRefreshResult(importedCount, activationsCreated, activationsReused)
    }

    fun observeAll(logId: Long): Flow<List<QSO>> =
        qsoDao.observeByLogId(logId)

    fun observeWorkedKeys(date: String): Flow<Set<String>> =
        qsoDao.observeByDate(date).map { qsos ->
            qsos.map { qso ->
                val ref = qso.potaRef ?: qso.sotaRef ?: ""
                "${qso.date}|${qso.callsign}|$ref|${qso.band}|${qso.mode}"
            }.toSet()
        }

    private fun insertQSOContentValues(
        sqlDb: androidx.sqlite.db.SupportSQLiteDatabase,
        qso: QSO,
        logId: Long?,
        qrzLogId: Long?,
    ) {
        val cv = android.content.ContentValues().apply {
            put("logId", logId)
            put("callsign", qso.callsign)
            put("date", qso.date)
            put("timeOn", qso.timeOn)
            put("frequency", qso.frequency)
            put("band", qso.band)
            put("mode", qso.mode)
            put("rstSent", qso.rstSent)
            put("rstReceived", qso.rstReceived)
            put("name", qso.name)
            put("qth", qso.qth)
            put("grid", qso.grid)
            put("sotaRef", qso.sotaRef)
            put("potaRef", qso.potaRef)
            put("notes", qso.notes)
            put("qrzLogId", qrzLogId)
            put("syncedToQRZ", 1)
        }
        sqlDb.insert("qso", 0, cv)
    }
}
