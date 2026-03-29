package com.sotalog.android.data.repositories

import com.sotalog.android.data.local.database.dao.CallsignHistoryDao
import com.sotalog.android.data.local.database.dao.LogDao
import com.sotalog.android.data.local.database.dao.QSODao
import com.sotalog.android.data.local.database.dao.ReferenceDao
import com.sotalog.android.di.SOTALogDatabase
import com.sotalog.android.domain.models.CallsignHistory
import com.sotalog.android.domain.models.Log
import com.sotalog.android.domain.models.POTAPark
import com.sotalog.android.domain.models.QSO
import com.sotalog.android.domain.models.ReferenceMetadata
import com.sotalog.android.domain.models.SOTASummit
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.mockk
import io.mockk.slot
import kotlinx.coroutines.test.runTest
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertNotNull
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Nested
import org.junit.jupiter.api.Test
import java.util.Date

// MARK: - ReferenceRepository — Parks

class ReferenceRepositoryParkTest {

    @Test
    fun `import and search parks by normalized prefix`() = runTest {
        val dao = mockk<ReferenceDao>()
        val repo = ReferenceRepository(dao)

        val park = POTAPark(reference = "US-4431", name = "Prescott NF", referenceNormalized = "US4431")

        coEvery { dao.insertParks(any()) } returns Unit
        coEvery { dao.searchParksByNormalizedPrefix("US4431", 20) } returns listOf(park)

        repo.importParks(listOf(park))
        val results = repo.searchParks(query = "US-4431")
        assertEquals(1, results.size)
        assertEquals("Prescott NF", results[0].name)
    }

    @Test
    fun `search parks falls back to name search`() = runTest {
        val dao = mockk<ReferenceDao>()
        val repo = ReferenceRepository(dao)

        val park = POTAPark(reference = "US-0001", name = "Acadia NP", referenceNormalized = "US0001")

        coEvery { dao.searchParksByNormalizedPrefix(any(), any()) } returns emptyList()
        coEvery { dao.searchParksByName("Acadia", 20) } returns listOf(park)

        val results = repo.searchParks(query = "Acadia")
        assertEquals(1, results.size)
    }

    @Test
    fun `fetch park by normalized`() = runTest {
        val dao = mockk<ReferenceDao>()
        val repo = ReferenceRepository(dao)

        val park = POTAPark(reference = "US-4431", name = "Prescott NF", referenceNormalized = "US4431")
        coEvery { dao.searchParksByNormalizedPrefix("US4431", 1) } returns listOf(park)

        val found = repo.fetchParkByNormalized("US4431")
        assertNotNull(found)
        assertEquals("Prescott NF", found?.name)
    }

    @Test
    fun `fetch park by normalized not found`() = runTest {
        val dao = mockk<ReferenceDao>()
        val repo = ReferenceRepository(dao)

        coEvery { dao.searchParksByNormalizedPrefix("XX9999", 1) } returns emptyList()

        val found = repo.fetchParkByNormalized("XX9999")
        assertNull(found)
    }

    @Test
    fun `park count and delete all`() = runTest {
        val dao = mockk<ReferenceDao>()
        val repo = ReferenceRepository(dao)

        coEvery { dao.getParkCount() } returnsMany listOf(2, 0)
        coEvery { dao.deleteAllParks() } returns Unit

        assertEquals(2, repo.parkCount())
        repo.deleteAllParks()
        assertEquals(0, repo.parkCount())
    }
}

// MARK: - ReferenceRepository — Summits

class ReferenceRepositorySummitTest {

    @Test
    fun `import and search summits`() = runTest {
        val dao = mockk<ReferenceDao>()
        val repo = ReferenceRepository(dao)

        val summit = SOTASummit(code = "W4C/CM-001", codeNormalized = "W4CCM001", name = "Mount Mitchell")
        coEvery { dao.insertSummits(any()) } returns Unit
        coEvery { dao.searchSummitsByNormalizedPrefix("W4CCM001", 20) } returns listOf(summit)

        repo.importSummits(listOf(summit))
        val results = repo.searchSummits(query = "W4C/CM-001")
        assertEquals(1, results.size)
        assertEquals("Mount Mitchell", results[0].name)
    }

    @Test
    fun `fetch summit by normalized`() = runTest {
        val dao = mockk<ReferenceDao>()
        val repo = ReferenceRepository(dao)

        val summit = SOTASummit(code = "W4C/CM-001", codeNormalized = "W4CCM001", name = "Mount Mitchell")
        coEvery { dao.searchSummitsByNormalizedPrefix("W4CCM001", 1) } returns listOf(summit)

        val found = repo.fetchSummitByNormalized("W4CCM001")
        assertNotNull(found)
        assertEquals("W4C/CM-001", found?.code)
    }

    @Test
    fun `fetch summit by normalized not found`() = runTest {
        val dao = mockk<ReferenceDao>()
        val repo = ReferenceRepository(dao)

        coEvery { dao.searchSummitsByNormalizedPrefix("XX000", 1) } returns emptyList()

        val found = repo.fetchSummitByNormalized("XX000")
        assertNull(found)
    }

    @Test
    fun `summit count and delete all`() = runTest {
        val dao = mockk<ReferenceDao>()
        val repo = ReferenceRepository(dao)

        coEvery { dao.getSummitCount() } returnsMany listOf(2, 0)
        coEvery { dao.deleteAllSummits() } returns Unit

        assertEquals(2, repo.summitCount())
        repo.deleteAllSummits()
        assertEquals(0, repo.summitCount())
    }
}

// MARK: - ReferenceRepository — Metadata

class ReferenceRepositoryMetadataTest {

    @Test
    fun `metadata round trip`() = runTest {
        val dao = mockk<ReferenceDao>()
        val repo = ReferenceRepository(dao)

        val now = Date()
        val metadata = ReferenceMetadata(key = "potaParks", lastRefreshed = now, recordCount = 42)

        coEvery { dao.upsertMetadata(any()) } returns Unit
        coEvery { dao.getMetadata("potaParks") } returns metadata

        repo.saveMetadata(metadata)
        val fetched = repo.fetchMetadata("potaParks")
        assertNotNull(fetched)
        assertEquals(42, fetched?.recordCount)
    }
}

// MARK: - LogRepository

class LogRepositoryTest {

    @Test
    fun `delete log removes unsynced QSOs preserves synced`() = runTest {
        val logDao = mockk<LogDao>()
        val qsoDao = mockk<QSODao>()
        val repo = LogRepository(logDao, qsoDao)

        val log = Log(id = 1, date = "20240101", myCallsign = "W1AW")
        val unsynced = QSO(id = 10, logId = 1, callsign = "K3ABC", date = "20240101", timeOn = "1200", band = "20m", syncedToQRZ = false)
        val synced = QSO(id = 11, logId = 1, callsign = "N4XYZ", date = "20240101", timeOn = "1201", band = "20m", syncedToQRZ = true)

        coEvery { logDao.getById(1) } returns log
        coEvery { qsoDao.getByLogId(1) } returns listOf(unsynced, synced)
        coEvery { qsoDao.delete(any()) } returns Unit
        coEvery { logDao.delete(any()) } returns Unit

        repo.delete(1)

        // Only unsynced QSO should be deleted
        coVerify(exactly = 1) { qsoDao.delete(match { it.id == 10L }) }
        // Synced QSO should NOT be deleted via qsoDao.delete
        coVerify(exactly = 0) { qsoDao.delete(match { it.id == 11L }) }
        // Log itself should be deleted
        coVerify(exactly = 1) { logDao.delete(log) }
    }

    @Test
    fun `save inserts new log`() = runTest {
        val logDao = mockk<LogDao>()
        val qsoDao = mockk<QSODao>()
        val repo = LogRepository(logDao, qsoDao)

        val log = Log(date = "20240101", myCallsign = "W1AW")
        coEvery { logDao.insert(any()) } returns 42L

        val saved = repo.save(log)
        assertEquals(42L, saved.id)
    }

    @Test
    fun `save updates existing log`() = runTest {
        val logDao = mockk<LogDao>()
        val qsoDao = mockk<QSODao>()
        val repo = LogRepository(logDao, qsoDao)

        val log = Log(id = 1, date = "20240101", myCallsign = "W1AW")
        coEvery { logDao.update(any()) } returns Unit

        val saved = repo.save(log)
        assertEquals(1L, saved.id)
        coVerify { logDao.update(log) }
    }
}

// MARK: - QSORepository

class QSORepositoryTest {

    @Nested
    inner class `Basic Operations` {

        @Test
        fun `fetch unsynced returns only unsynced QSOs`() = runTest {
            val qsoDao = mockk<QSODao>()
            val db = mockk<SOTALogDatabase>()
            val repo = QSORepository(qsoDao, db)

            val unsyncedQSO = QSO(id = 1, logId = 1, callsign = "K3ABC", date = "20240101", timeOn = "1200", band = "20m", syncedToQRZ = false)
            coEvery { qsoDao.getUnsynced() } returns listOf(unsyncedQSO)

            val unsynced = repo.fetchUnsynced()
            assertEquals(1, unsynced.size)
            assertEquals("K3ABC", unsynced[0].callsign)
        }

        @Test
        fun `mark synced updates QSO`() = runTest {
            val qsoDao = mockk<QSODao>()
            val db = mockk<SOTALogDatabase>()
            val repo = QSORepository(qsoDao, db)

            val qso = QSO(id = 1, logId = 1, callsign = "K3ABC", date = "20240101", timeOn = "1200", band = "20m")
            coEvery { qsoDao.getById(1) } returns qso
            coEvery { qsoDao.update(any()) } returns Unit

            repo.markSynced(1, 12345)

            val capturedSlot = slot<QSO>()
            coVerify { qsoDao.update(capture(capturedSlot)) }
            assertEquals(true, capturedSlot.captured.syncedToQRZ)
            assertEquals(12345L, capturedSlot.captured.qrzLogId)
        }

        @Test
        fun `delete QSO by id`() = runTest {
            val qsoDao = mockk<QSODao>()
            val db = mockk<SOTALogDatabase>()
            val repo = QSORepository(qsoDao, db)

            coEvery { qsoDao.deleteById(1) } returns Unit

            repo.delete(1)
            coVerify { qsoDao.deleteById(1) }
        }

        @Test
        fun `fetch by id`() = runTest {
            val qsoDao = mockk<QSODao>()
            val db = mockk<SOTALogDatabase>()
            val repo = QSORepository(qsoDao, db)

            val qso = QSO(id = 1, logId = 1, callsign = "K3ABC", date = "20240101", timeOn = "1200", band = "20m")
            coEvery { qsoDao.getById(1) } returns qso

            val fetched = repo.fetch(1)
            assertNotNull(fetched)
            assertEquals("K3ABC", fetched?.callsign)
        }

        @Test
        fun `save inserts new QSO`() = runTest {
            val qsoDao = mockk<QSODao>()
            val db = mockk<SOTALogDatabase>()
            val repo = QSORepository(qsoDao, db)

            val qso = QSO(logId = 1, callsign = "K3ABC", date = "20240101", timeOn = "1200", band = "20m")
            coEvery { qsoDao.insert(any()) } returns 42L

            val saved = repo.save(qso)
            assertEquals(42L, saved.id)
        }

        @Test
        fun `save updates existing QSO`() = runTest {
            val qsoDao = mockk<QSODao>()
            val db = mockk<SOTALogDatabase>()
            val repo = QSORepository(qsoDao, db)

            val qso = QSO(id = 1, logId = 1, callsign = "K3ABC", date = "20240101", timeOn = "1200", band = "20m")
            coEvery { qsoDao.update(any()) } returns Unit

            val saved = repo.save(qso)
            assertEquals(1L, saved.id)
            coVerify { qsoDao.update(qso) }
        }
    }

    @Nested
    inner class `Last Sync Date` {

        @Test
        fun `returns null when no sync has occurred`() = runTest {
            val qsoDao = mockk<QSODao>()
            val db = mockk<SOTALogDatabase>()
            val referenceDao = mockk<ReferenceDao>()
            val repo = QSORepository(qsoDao, db)

            coEvery { db.referenceDao() } returns referenceDao
            coEvery { referenceDao.getMetadata("lastSyncedQRZLogId") } returns null

            val date = repo.lastSyncDate()
            assertNull(date)
        }

        @Test
        fun `returns date when sync has occurred`() = runTest {
            val qsoDao = mockk<QSODao>()
            val db = mockk<SOTALogDatabase>()
            val referenceDao = mockk<ReferenceDao>()
            val repo = QSORepository(qsoDao, db)

            val now = Date()
            coEvery { db.referenceDao() } returns referenceDao
            coEvery { referenceDao.getMetadata("lastSyncedQRZLogId") } returns
                ReferenceMetadata("lastSyncedQRZLogId", now, 0)

            val date = repo.lastSyncDate()
            assertNotNull(date)
        }
    }
}

// MARK: - CallsignHistoryRepository

class CallsignHistoryRepositoryTest {

    @Test
    fun `update from lookup creates new entry`() = runTest {
        val dao = mockk<CallsignHistoryDao>()
        val db = mockk<SOTALogDatabase>()
        val repo = CallsignHistoryRepository(dao, db)

        coEvery { dao.getByCallsign("W1AW") } returns null
        coEvery { dao.upsert(any()) } returns Unit

        repo.updateFromLookup(callsign = "W1AW", name = "Hiram", qth = "CT", grid = null)

        val capturedSlot = slot<CallsignHistory>()
        coVerify { dao.upsert(capture(capturedSlot)) }
        assertEquals(0, capturedSlot.captured.timesWorked)
        assertEquals("Hiram", capturedSlot.captured.name)
    }

    @Test
    fun `update from lookup does not increment existing`() = runTest {
        val dao = mockk<CallsignHistoryDao>()
        val db = mockk<SOTALogDatabase>()
        val repo = CallsignHistoryRepository(dao, db)

        val existing = CallsignHistory("W1AW", "Hiram", "CT", null, Date(), 1)
        coEvery { dao.getByCallsign("W1AW") } returns existing
        coEvery { dao.upsert(any()) } returns Unit

        repo.updateFromLookup(callsign = "W1AW", name = "Hiram P Maxim", qth = "CT", grid = "FN31")

        val capturedSlot = slot<CallsignHistory>()
        coVerify { dao.upsert(capture(capturedSlot)) }
        assertEquals(1, capturedSlot.captured.timesWorked) // not incremented
        assertEquals("Hiram P Maxim", capturedSlot.captured.name)
        assertEquals("FN31", capturedSlot.captured.grid)
    }

    @Test
    fun `record QSO does not overwrite with nil`() = runTest {
        val dao = mockk<CallsignHistoryDao>()
        val db = mockk<SOTALogDatabase>()
        val repo = CallsignHistoryRepository(dao, db)

        val existing = CallsignHistory("W1AW", "Hiram", "CT", "FN31", Date(), 1)
        coEvery { dao.getByCallsign("W1AW") } returns existing
        coEvery { dao.upsert(any()) } returns Unit

        repo.recordQSO(callsign = "W1AW", name = null, qth = null, grid = null)

        val capturedSlot = slot<CallsignHistory>()
        coVerify { dao.upsert(capture(capturedSlot)) }
        assertEquals("Hiram", capturedSlot.captured.name)
        assertEquals("CT", capturedSlot.captured.qth)
        assertEquals("FN31", capturedSlot.captured.grid)
    }

    @Test
    fun `update from lookup does not overwrite with nil`() = runTest {
        val dao = mockk<CallsignHistoryDao>()
        val db = mockk<SOTALogDatabase>()
        val repo = CallsignHistoryRepository(dao, db)

        val existing = CallsignHistory("W1AW", "Hiram", "CT", null, Date(), 1)
        coEvery { dao.getByCallsign("W1AW") } returns existing
        coEvery { dao.upsert(any()) } returns Unit

        repo.updateFromLookup(callsign = "W1AW", name = null, qth = null, grid = null)

        val capturedSlot = slot<CallsignHistory>()
        coVerify { dao.upsert(capture(capturedSlot)) }
        assertEquals("Hiram", capturedSlot.captured.name)
        assertEquals("CT", capturedSlot.captured.qth)
    }
}
