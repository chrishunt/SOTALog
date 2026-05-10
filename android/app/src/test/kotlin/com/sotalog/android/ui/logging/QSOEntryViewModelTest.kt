package com.sotalog.android.ui.logging

import androidx.lifecycle.SavedStateHandle
import com.sotalog.android.data.local.database.dao.CallsignHistoryDao
import com.sotalog.android.data.local.database.dao.LogDao
import com.sotalog.android.data.local.database.dao.QSODao
import com.sotalog.android.data.local.database.dao.ReferenceDao
import com.sotalog.android.data.local.preferences.CredentialStore
import com.sotalog.android.data.remote.api.QRZLookupApi
import com.sotalog.android.domain.models.CallsignHistory
import com.sotalog.android.domain.models.Log
import com.sotalog.android.domain.models.QSO
import com.sotalog.android.makeSpot
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.mockk
import io.mockk.slot
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.jupiter.api.AfterEach
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertNotNull
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Nested
import org.junit.jupiter.api.Test

@OptIn(ExperimentalCoroutinesApi::class)
class QSOEntryViewModelTest {

    private val testDispatcher = StandardTestDispatcher()
    private lateinit var logDao: LogDao
    private lateinit var qsoDao: QSODao
    private lateinit var callsignHistoryDao: CallsignHistoryDao
    private lateinit var referenceDao: ReferenceDao
    private lateinit var credentialStore: CredentialStore
    private lateinit var qrzLookupApi: QRZLookupApi

    private val testLog = Log(
        id = 1,
        date = "20240101",
        myCallsign = "W1AW",
        myGrid = "FN31",
        potaReference = "US-4431",
        sotaReference = "W4C/CM-001",
        parkName = "Prescott NF",
        summitName = "Mount Mitchell",
    )

    @BeforeEach
    fun setup() {
        Dispatchers.setMain(testDispatcher)
        logDao = mockk(relaxed = true)
        qsoDao = mockk(relaxed = true)
        callsignHistoryDao = mockk(relaxed = true)
        referenceDao = mockk(relaxed = true)
        credentialStore = mockk(relaxed = true)
        qrzLookupApi = mockk(relaxed = true)

        coEvery { logDao.getById(1) } returns testLog
        coEvery { credentialStore.load(any()) } returns null
        coEvery { callsignHistoryDao.getByCallsign(any()) } returns null
        coEvery { qsoDao.getByLogId(any()) } returns emptyList()
    }

    @AfterEach
    fun tearDown() {
        Dispatchers.resetMain()
    }

    private fun makeVM(): QSOEntryViewModel {
        val savedState = SavedStateHandle(mapOf("logId" to 1L))
        return QSOEntryViewModel(
            savedState, logDao, qsoDao, callsignHistoryDao,
            referenceDao, credentialStore, qrzLookupApi,
        )
    }

    // MARK: - Sensible Defaults

    @Nested
    inner class `Sensible Defaults` {

        @Test
        fun `fresh ViewModel has correct defaults`() = runTest {
            val vm = makeVM()
            advanceUntilIdle()

            assertEquals("599", vm.rstSent.value)
            assertEquals("599", vm.rstReceived.value)
            assertEquals("14.060", vm.frequencyText.value)
            assertEquals("CW", vm.mode.value)
        }
    }

    // MARK: - OmniField Parsing

    @Nested
    inner class `OmniField Parsing` {

        @Test
        fun `parse entry applies RST`() = runTest {
            val vm = makeVM()
            advanceUntilIdle()

            vm.onEntryTextChanged("W1AW 579")
            advanceUntilIdle()

            assertEquals("579", vm.rstSent.value)
        }

        @Test
        fun `parse entry applies frequency`() = runTest {
            val vm = makeVM()
            advanceUntilIdle()

            vm.onEntryTextChanged("W1AW 7.030 ")
            advanceUntilIdle()

            assertEquals("7.030", vm.frequencyText.value)
        }

        @Test
        fun `parse entry applies QTH`() = runTest {
            val vm = makeVM()
            advanceUntilIdle()

            vm.onEntryTextChanged("W1AW NC ")
            advanceUntilIdle()

            assertEquals("NC", vm.qth.value)
        }

        @Test
        fun `parse entry applies POTA ref`() = runTest {
            val vm = makeVM()
            advanceUntilIdle()

            coEvery { referenceDao.searchParksByNormalizedPrefix(any(), any()) } returns emptyList()

            vm.onEntryTextChanged("W1AW US0001 ")
            advanceUntilIdle()

            assertEquals("US0001", vm.potaRefInput.value)
        }

        @Test
        fun `parse entry applies SOTA ref`() = runTest {
            val vm = makeVM()
            advanceUntilIdle()

            coEvery { referenceDao.searchSummitsByNormalizedPrefix(any(), any()) } returns emptyList()

            vm.onEntryTextChanged("W1AW W4CCM001 ")
            advanceUntilIdle()

            assertEquals("W4CCM001", vm.sotaRefInput.value)
        }
    }

    // MARK: - Save Flow

    @Nested
    inner class `Save Flow` {

        @Test
        fun `save creates QSO with CW mode`() = runTest {
            val vm = makeVM()
            advanceUntilIdle()

            coEvery { qsoDao.insert(any()) } returns 1L

            vm.onEntryTextChanged("W1AW")
            advanceUntilIdle()
            vm.saveQSO()
            advanceUntilIdle()

            assertNotNull(vm.lastSavedQSO.value)
            assertEquals("CW", vm.lastSavedQSO.value?.mode)
        }

        @Test
        fun `save creates QSO with FM mode`() = runTest {
            val vm = makeVM()
            advanceUntilIdle()

            coEvery { qsoDao.insert(any()) } returns 1L

            vm.onEntryTextChanged("W1AW")
            advanceUntilIdle()
            vm.onFrequencyChanged("146.520")
            advanceUntilIdle()
            vm.saveQSO()
            advanceUntilIdle()

            assertNotNull(vm.lastSavedQSO.value)
            assertEquals("FM", vm.lastSavedQSO.value?.mode)
            assertEquals("2m", vm.lastSavedQSO.value?.band)
            assertEquals("59", vm.lastSavedQSO.value?.rstSent)
        }

        @Test
        fun `save uppercases callsign`() = runTest {
            val vm = makeVM()
            advanceUntilIdle()

            coEvery { qsoDao.insert(any()) } returns 1L

            vm.onEntryTextChanged("w1aw")
            advanceUntilIdle()
            vm.saveQSO()
            advanceUntilIdle()

            assertEquals("W1AW", vm.lastSavedQSO.value?.callsign)
        }

        @Test
        fun `save derives band from frequency`() = runTest {
            val vm = makeVM()
            advanceUntilIdle()

            coEvery { qsoDao.insert(any()) } returns 1L

            vm.onEntryTextChanged("W1AW")
            vm.onFrequencyChanged("7.030")
            advanceUntilIdle()
            vm.saveQSO()
            advanceUntilIdle()

            assertEquals("40m", vm.lastSavedQSO.value?.band)
        }

        @Test
        fun `save empty callsign is noop`() = runTest {
            val vm = makeVM()
            advanceUntilIdle()

            vm.onEntryTextChanged("")
            vm.saveQSO()
            advanceUntilIdle()

            assertNull(vm.lastSavedQSO.value)
            assertEquals(0, vm.saveCount.value)
        }

        @Test
        fun `save clears fields but preserves frequency`() = runTest {
            val vm = makeVM()
            advanceUntilIdle()

            coEvery { qsoDao.insert(any()) } returns 1L

            vm.onEntryTextChanged("W1AW")
            vm.onFrequencyChanged("7.030")
            vm.onRstSentChanged("579")
            vm.onNameChanged("Hiram")
            vm.onQthChanged("CT")
            advanceUntilIdle()
            vm.saveQSO()
            advanceUntilIdle()

            assertEquals("", vm.entryText.value)
            assertEquals("599", vm.rstSent.value)
            assertEquals("599", vm.rstReceived.value)
            assertEquals("", vm.name.value)
            assertEquals("", vm.qth.value)
            assertEquals("7.030", vm.frequencyText.value) // preserved
        }

        @Test
        fun `save increments save count`() = runTest {
            val vm = makeVM()
            advanceUntilIdle()

            coEvery { qsoDao.insert(any()) } returns 1L

            vm.onEntryTextChanged("W1AW")
            advanceUntilIdle()
            vm.saveQSO()
            advanceUntilIdle()

            assertEquals(1, vm.saveCount.value)
        }

        @Test
        fun `save updates callsign history`() = runTest {
            val vm = makeVM()
            advanceUntilIdle()

            coEvery { qsoDao.insert(any()) } returns 1L
            coEvery { callsignHistoryDao.getByCallsign("K3ABC") } returns null

            vm.onEntryTextChanged("K3ABC")
            vm.onNameChanged("John")
            vm.onQthChanged("PA")
            advanceUntilIdle()
            vm.saveQSO()
            advanceUntilIdle()

            val capturedSlot = slot<CallsignHistory>()
            coVerify { callsignHistoryDao.upsert(capture(capturedSlot)) }
            assertEquals(1, capturedSlot.captured.timesWorked)
            assertEquals("John", capturedSlot.captured.name)
        }
    }

    // MARK: - Editing Flow

    @Nested
    inner class `Editing Flow` {

        @Test
        fun `load for editing populates fields`() = runTest {
            val vm = makeVM()
            advanceUntilIdle()

            val qso = QSO(
                id = 42,
                logId = 1,
                callsign = "W1AW",
                date = "20240101",
                timeOn = "1234",
                frequency = 14.060,
                band = "20m",
                mode = "CW",
                rstSent = "579",
                rstReceived = "559",
                name = "Hiram",
                qth = "CT",
            )

            vm.loadForEditing(qso)
            advanceUntilIdle()

            assertTrue(vm.isEditing)
            assertEquals("W1AW", vm.entryText.value)
            assertEquals("579", vm.rstSent.value)
            assertEquals("559", vm.rstReceived.value)
            assertEquals("14.060", vm.frequencyText.value)
            assertEquals("Hiram", vm.name.value)
            assertEquals("CT", vm.qth.value)
        }

        @Test
        fun `cancel editing clears fields`() = runTest {
            val vm = makeVM()
            advanceUntilIdle()

            val qso = QSO(id = 42, logId = 1, callsign = "W1AW", date = "20240101", timeOn = "1234", band = "20m")
            vm.loadForEditing(qso)
            assertTrue(vm.isEditing)

            vm.cancelEditing()
            assertFalse(vm.isEditing)
            assertEquals("", vm.entryText.value)
        }
    }

    // MARK: - Spot Prefill

    @Nested
    inner class `Spot Prefill` {

        @Test
        fun `prefill from spot sets fields`() = runTest {
            val vm = makeVM()
            advanceUntilIdle()

            coEvery { referenceDao.searchParksByNormalizedPrefix(any(), any()) } returns emptyList()
            coEvery { referenceDao.searchSummitsByNormalizedPrefix(any(), any()) } returns emptyList()

            val spot = makeSpot(
                callsign = "K3ABC",
                frequency = 7.030,
                potaReference = "US-0001",
                sotaReference = "W4C/CM-001",
            )

            vm.prefillFromSpot(spot)
            advanceUntilIdle()

            assertEquals("K3ABC", vm.entryText.value)
            assertEquals("7.030", vm.frequencyText.value)
            assertEquals("US0001", vm.potaRefInput.value)
            assertEquals("W4CCM001", vm.sotaRefInput.value)
        }

        @Test
        fun `prefill clears stale data`() = runTest {
            val vm = makeVM()
            advanceUntilIdle()

            vm.onNameChanged("Old Name")
            vm.onQthChanged("Old QTH")
            vm.onPotaRefChanged("XX9999")
            advanceUntilIdle()

            val spot = makeSpot(callsign = "K3ABC", frequency = 14.060)
            vm.prefillFromSpot(spot)
            advanceUntilIdle()

            assertEquals("", vm.name.value)
            assertEquals("", vm.qth.value)
            assertEquals("", vm.potaRefInput.value)
        }
    }

    // MARK: - parsedCallsign

    @Nested
    inner class `Parsed Callsign` {

        @Test
        fun `extracts first token`() = runTest {
            val vm = makeVM()
            advanceUntilIdle()

            vm.onEntryTextChanged("W1AW 579 14.060")
            advanceUntilIdle()

            assertEquals("W1AW", vm.parsedCallsign)
        }

        @Test
        fun `sanitizes callsign`() = runTest {
            val vm = makeVM()
            advanceUntilIdle()

            vm.onEntryTextChanged("w1aw!!")
            advanceUntilIdle()

            assertEquals("W1AW", vm.parsedCallsign)
        }

        @Test
        fun `empty when no input`() = runTest {
            val vm = makeVM()
            advanceUntilIdle()

            assertEquals("", vm.parsedCallsign)
        }
    }

    // MARK: - Mode Tests

    @Nested
    inner class `Mode` {

        @Test
        fun `default mode is CW`() = runTest {
            val vm = makeVM()
            advanceUntilIdle()

            assertEquals("CW", vm.mode.value)
            assertEquals("599", vm.defaultRST)
        }

        @Test
        fun `toggle mode cycles CW SSB FM`() = runTest {
            val vm = makeVM()
            advanceUntilIdle()

            assertEquals("CW", vm.mode.value)

            vm.toggleMode()
            assertEquals("SSB", vm.mode.value)
            assertEquals("59", vm.rstSent.value)
            assertEquals("59", vm.rstReceived.value)

            vm.toggleMode()
            assertEquals("FM", vm.mode.value)
            assertEquals("59", vm.rstSent.value)
            assertEquals("59", vm.rstReceived.value)

            vm.toggleMode()
            assertEquals("CW", vm.mode.value)
            assertEquals("599", vm.rstSent.value)
            assertEquals("599", vm.rstReceived.value)
        }

        @Test
        fun `mode auto-derives to FM on 2m`() = runTest {
            val vm = makeVM()
            advanceUntilIdle()

            assertEquals("CW", vm.mode.value)

            vm.onFrequencyChanged("146.520")
            assertEquals("FM", vm.mode.value)
            assertEquals("59", vm.rstSent.value)
        }

        @Test
        fun `mode auto-derives from frequency`() = runTest {
            val vm = makeVM()
            advanceUntilIdle()

            assertEquals("CW", vm.mode.value)

            vm.onFrequencyChanged("14.260")
            assertEquals("SSB", vm.mode.value)
            assertEquals("59", vm.rstSent.value)

            vm.onFrequencyChanged("14.060")
            assertEquals("CW", vm.mode.value)
            assertEquals("599", vm.rstSent.value)
        }

        @Test
        fun `manual mode override prevents auto-derivation`() = runTest {
            val vm = makeVM()
            advanceUntilIdle()

            vm.toggleMode() // manual override to SSB
            assertEquals("SSB", vm.mode.value)

            vm.onFrequencyChanged("14.060") // CW sub-band
            assertEquals("SSB", vm.mode.value, "Manual mode override should prevent auto-derivation")
        }

        @Test
        fun `omnifield mode token sets mode`() = runTest {
            val vm = makeVM()
            advanceUntilIdle()

            vm.onEntryTextChanged("W1AW SSB ")
            advanceUntilIdle()

            assertEquals("SSB", vm.mode.value)
            assertEquals("59", vm.rstSent.value)
        }

        @Test
        fun `omnifield RST expanded for CW`() = runTest {
            val vm = makeVM()
            advanceUntilIdle()

            assertEquals("CW", vm.mode.value)
            vm.onEntryTextChanged("W1AW 55")
            advanceUntilIdle()

            assertEquals("559", vm.rstSent.value, "2-digit RST should expand to 3-digit for CW")
        }

        @Test
        fun `omnifield RST not expanded for SSB`() = runTest {
            val vm = makeVM()
            advanceUntilIdle()

            vm.toggleMode() // SSB
            vm.onEntryTextChanged("W1AW 55")
            advanceUntilIdle()

            assertEquals("55", vm.rstSent.value, "2-digit RST should stay 2-digit for SSB")
        }

        @Test
        fun `prefill from spot sets mode`() = runTest {
            val vm = makeVM()
            advanceUntilIdle()

            val spot = makeSpot(callsign = "K3ABC", frequency = 14.260, mode = "SSB")
            vm.prefillFromSpot(spot)
            advanceUntilIdle()

            assertEquals("SSB", vm.mode.value)
            assertEquals("59", vm.rstSent.value)
            assertEquals("59", vm.rstReceived.value)
        }

        @Test
        fun `load for editing sets mode`() = runTest {
            val vm = makeVM()
            advanceUntilIdle()

            val qso = QSO(
                id = 42, logId = 1, callsign = "W1AW", date = "20240101", timeOn = "1234",
                frequency = 14.260, band = "20m", mode = "SSB", rstSent = "59", rstReceived = "59",
            )
            vm.loadForEditing(qso)

            assertEquals("SSB", vm.mode.value)
            assertEquals("59", vm.rstSent.value)
        }

        @Test
        fun `mode persists after save`() = runTest {
            val vm = makeVM()
            advanceUntilIdle()

            coEvery { qsoDao.insert(any()) } returns 1L

            vm.toggleMode() // SSB
            vm.onEntryTextChanged("W1AW")
            vm.onFrequencyChanged("14.260")
            advanceUntilIdle()
            vm.saveQSO()
            advanceUntilIdle()

            assertEquals("SSB", vm.mode.value, "Mode should persist after save")
            assertEquals("59", vm.rstSent.value, "RST should use SSB default after save")
        }
    }

    // MARK: - Empty Callsign Clears All Fields

    @Nested
    inner class `Empty Callsign Clears Fields` {

        @Test
        fun `empty callsign clears all fields`() = runTest {
            val vm = makeVM()
            advanceUntilIdle()

            vm.onEntryTextChanged("W1AW")
            vm.onRstSentChanged("579")
            vm.onRstReceivedChanged("559")
            vm.onNameChanged("Hiram")
            vm.onQthChanged("CT")
            advanceUntilIdle()

            vm.onEntryTextChanged("")
            advanceUntilIdle()

            assertEquals("599", vm.rstSent.value, "RST sent should reset to default")
            assertEquals("599", vm.rstReceived.value, "RST received should reset to default")
            assertEquals("", vm.name.value, "Name should be cleared")
            assertEquals("", vm.qth.value, "QTH should be cleared")
            assertEquals(0, vm.timesWorked.value, "Times worked should reset")
            assertEquals("14.060", vm.frequencyText.value, "Frequency should be preserved")
        }
    }

    // MARK: - Auto-populate Cascade

    @Nested
    inner class `Auto-populate Cascade` {

        @Test
        fun `callsign changed populates from history`() = runTest {
            val vm = makeVM()
            advanceUntilIdle()

            val history = CallsignHistory("W1AW", "Hiram", "CT", null, null, 3)
            coEvery { callsignHistoryDao.getByCallsign("W1AW") } returns history

            vm.onEntryTextChanged("W1AW")
            advanceUntilIdle()

            assertEquals("Hiram", vm.name.value)
            assertEquals("CT", vm.qth.value)
            assertEquals(3, vm.timesWorked.value)
        }

        @Test
        fun `callsign changed falls back to prefix`() = runTest {
            val vm = makeVM()
            advanceUntilIdle()

            vm.onEntryTextChanged("G3ABC")
            advanceUntilIdle()

            assertEquals("GBR", vm.qth.value)
        }

        @Test
        fun `spot lookup populates reference but not frequency`() = runTest {
            val vm = makeVM()
            advanceUntilIdle()

            coEvery { referenceDao.searchParksByNormalizedPrefix(any(), any()) } returns emptyList()

            vm.spotLookup = { call ->
                if (call == "K3ABC") makeSpot(callsign = "K3ABC", frequency = 7.030, potaReference = "US-0001")
                else null
            }

            vm.onEntryTextChanged("K3ABC")
            advanceUntilIdle()

            assertEquals("14.060", vm.frequencyText.value, "Spot lookup should not override frequency")
            assertEquals("US0001", vm.potaRefInput.value)
        }

        @Test
        fun `history does not overwrite existing fields`() = runTest {
            val vm = makeVM()
            advanceUntilIdle()

            val history = CallsignHistory("W1AW", "Hiram", "CT", null, null, 1)
            coEvery { callsignHistoryDao.getByCallsign("W1AW") } returns history

            vm.onNameChanged("Manual Name")
            vm.onEntryTextChanged("W1AW")
            advanceUntilIdle()

            // History is LOW authority — should not overwrite non-empty name
            assertEquals("Manual Name", vm.name.value)
            assertEquals(1, vm.timesWorked.value)
        }

        @Test
        fun `short callsign clears lookup`() = runTest {
            val vm = makeVM()
            advanceUntilIdle()

            val history = CallsignHistory("W1AW", "Hiram", "CT", null, null, 1)
            coEvery { callsignHistoryDao.getByCallsign("W1AW") } returns history

            vm.onEntryTextChanged("W1AW")
            advanceUntilIdle()
            assertEquals("Hiram", vm.name.value)

            // Short callsign — clear lookup fields
            vm.onEntryTextChanged("W1")
            advanceUntilIdle()
            assertEquals("", vm.name.value)
            assertEquals(0, vm.timesWorked.value)
        }
    }

    // MARK: - CW Template Expansion

    @Nested
    inner class `CW Template Expansion` {

        @Test
        fun `expand template with SOTA ref`() = runTest {
            val vm = makeVM()
            advanceUntilIdle()

            val result = vm.expandTemplate("CQ {activity} DE {myCall} K")
            assertEquals("CQ SOTA DE W1AW K", result)
        }

        @Test
        fun `expand template exchange with cut numbers`() = runTest {
            val vm = makeVM()
            advanceUntilIdle()

            vm.onEntryTextChanged("W6SD")
            advanceUntilIdle()
            vm.onRstSentChanged("599")

            val result = vm.expandTemplate("{call} UR {rst} BK")
            assertEquals("W6SD UR 5NN BK", result)
        }

        @Test
        fun `expand template strips SOTA dash`() = runTest {
            val vm = makeVM()
            advanceUntilIdle()

            val result = vm.expandTemplate("{mySOTA}")
            assertEquals("W4C/CM001", result, "Dashes should be stripped from SOTA ref for CW")
        }

        @Test
        fun `expand template empty call`() = runTest {
            val vm = makeVM()
            advanceUntilIdle()

            val result = vm.expandTemplate("{call}?")
            assertEquals("?", result)
        }

        @Test
        fun `expand template collapses spaces`() = runTest {
            val vm = makeVM()
            advanceUntilIdle()

            val result = vm.expandTemplate("{call}  DE  {myCall}")
            assertEquals("DE W1AW", result)
        }

        @Test
        fun `preview template empty call keeps placeholder`() = runTest {
            val vm = makeVM()
            advanceUntilIdle()

            val result = vm.previewExpandTemplate("{call} DE {myCall} K")
            assertEquals("{call} DE W1AW K", result)
        }

        @Test
        fun `preview template filled call substitutes`() = runTest {
            val vm = makeVM()
            advanceUntilIdle()

            vm.onEntryTextChanged("W6SD")
            advanceUntilIdle()

            val result = vm.previewExpandTemplate("{call} DE {myCall} K")
            assertEquals("W6SD DE W1AW K", result)
        }

        @Test
        fun `preview template filled SOTA substitutes`() = runTest {
            val vm = makeVM()
            advanceUntilIdle()

            val result = vm.previewExpandTemplate("{mySOTA}")
            assertEquals("W4C/CM001", result)
        }

        @Test
        fun `preview template activity resolves SOTA`() = runTest {
            val vm = makeVM()
            advanceUntilIdle()

            val result = vm.previewExpandTemplate("CQ {activity} DE {myCall} K")
            assertEquals("CQ SOTA DE W1AW K", result)
        }

        @Test
        fun `expand template RST cut numbers 559`() = runTest {
            val vm = makeVM()
            advanceUntilIdle()

            vm.onEntryTextChanged("W6SD")
            advanceUntilIdle()
            vm.onRstSentChanged("559")

            val result = vm.expandTemplate("{call} UR {rst} BK")
            assertEquals("W6SD UR 55N BK", result)
        }
    }
}
