package com.sotalog.android.ui.spots

import com.sotalog.android.data.remote.api.POTASpotApi
import com.sotalog.android.data.remote.api.SOTASpotApi
import com.sotalog.android.makeSpot
import io.mockk.mockk
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.setMain
import kotlinx.serialization.json.Json
import org.junit.jupiter.api.AfterEach
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertNotNull
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Nested
import org.junit.jupiter.api.Test
import java.util.Date

@OptIn(kotlinx.coroutines.ExperimentalCoroutinesApi::class)
class SpotsViewModelTest {

    private val testDispatcher = UnconfinedTestDispatcher()

    @BeforeEach
    fun setup() {
        Dispatchers.setMain(testDispatcher)
    }

    @AfterEach
    fun tearDown() {
        Dispatchers.resetMain()
    }

    private fun makeVM(): SpotsViewModel {
        val potaApi = mockk<POTASpotApi>(relaxed = true)
        val sotaApi = mockk<SOTASpotApi>(relaxed = true)
        val json = Json { ignoreUnknownKeys = true }
        return SpotsViewModel(potaApi, sotaApi, json)
    }

    // MARK: - Consolidation

    @Nested
    inner class Consolidation {

        @Test
        fun `two spots for same callsign keeps newest`() {
            val vm = makeVM()
            val now = Date()

            vm.setSpots(
                listOf(
                    makeSpot(id = "1", callsign = "W1AW", frequency = 14.060, potaReference = "US-0001", timestamp = Date(now.time - 60_000)),
                    makeSpot(id = "2", callsign = "W1AW", frequency = 14.062, potaReference = "US-0002", timestamp = now),
                )
            )

            val all = vm.spotsByBand.value.flatMap { it.spots }
            assertEquals(1, all.size)
            assertEquals("US-0002", all[0].potaReference)
        }

        @Test
        fun `consolidation merges POTA and SOTA`() {
            val vm = makeVM()
            val now = Date()

            vm.setSpots(
                listOf(
                    makeSpot(id = "1", callsign = "W1AW", frequency = 14.060, potaReference = "US-0001", timestamp = now),
                    makeSpot(id = "2", callsign = "W1AW", frequency = 14.060, sotaReference = "W4C/CM-001", timestamp = Date(now.time - 30_000)),
                )
            )

            val all = vm.spotsByBand.value.flatMap { it.spots }
            assertEquals(1, all.size)
            assertNotNull(all[0].potaReference)
            assertNotNull(all[0].sotaReference)
        }

        @Test
        fun `newer reference wins for same type`() {
            val vm = makeVM()
            val now = Date()

            vm.setSpots(
                listOf(
                    makeSpot(id = "1", callsign = "W1AW", frequency = 14.060, potaReference = "US-0002", timestamp = now),
                    makeSpot(id = "2", callsign = "W1AW", frequency = 14.060, potaReference = "US-0001", timestamp = Date(now.time - 60_000)),
                )
            )

            val all = vm.spotsByBand.value.flatMap { it.spots }
            assertEquals(1, all.size)
            assertEquals("US-0002", all[0].potaReference)
        }
    }

    // MARK: - spotsByBand

    @Nested
    inner class SpotsByBand {

        @Test
        fun `groups by band`() {
            val vm = makeVM()
            val now = Date()

            vm.setSpots(
                listOf(
                    makeSpot(id = "1", callsign = "W1AW", frequency = 14.060, potaReference = "US-0001", timestamp = now),
                    makeSpot(id = "2", callsign = "K3ABC", frequency = 7.030, potaReference = "US-0002", timestamp = now),
                )
            )

            assertEquals(2, vm.spotsByBand.value.size)
        }

        @Test
        fun `spots sorted by frequency within band`() {
            val vm = makeVM()
            val now = Date()

            vm.setSpots(
                listOf(
                    makeSpot(id = "1", callsign = "K3ABC", frequency = 14.070, potaReference = "US-0002", timestamp = now),
                    makeSpot(id = "2", callsign = "W1AW", frequency = 14.060, potaReference = "US-0001", timestamp = now),
                )
            )

            val twentyM = vm.spotsByBand.value.first { it.band == "20m" }
            assertEquals(14.060, twentyM.spots[0].frequency)
            assertEquals(14.070, twentyM.spots[1].frequency)
        }

        @Test
        fun `expired spots excluded`() {
            val vm = makeVM()

            vm.setSpots(
                listOf(
                    makeSpot(id = "1", callsign = "W1AW", frequency = 14.060, potaReference = "US-0001", timestamp = Date(Date().time - 11 * 60 * 1000)),
                )
            )

            val all = vm.spotsByBand.value.flatMap { it.spots }
            assertEquals(0, all.size)
        }

        @Test
        fun `QRT spots excluded`() {
            val vm = makeVM()

            vm.setSpots(
                listOf(
                    makeSpot(id = "1", callsign = "W1AW", frequency = 14.060, potaReference = "US-0001", comments = "QRT"),
                )
            )

            val all = vm.spotsByBand.value.flatMap { it.spots }
            assertEquals(0, all.size)
        }

        @Test
        fun `band ordering follows BandPlan`() {
            val vm = makeVM()
            val now = Date()

            vm.setSpots(
                listOf(
                    makeSpot(id = "1", callsign = "K3ABC", frequency = 14.060, potaReference = "US-0001", timestamp = now),
                    makeSpot(id = "2", callsign = "W1AW", frequency = 7.030, potaReference = "US-0002", timestamp = now),
                    makeSpot(id = "3", callsign = "N4XYZ", frequency = 21.060, potaReference = "US-0003", timestamp = now),
                )
            )

            val bandNames = vm.spotsByBand.value.map { it.band }
            assertEquals(listOf("40m", "20m", "15m"), bandNames)
        }
    }

    // MARK: - Source Filtering

    @Nested
    inner class `Source Filtering` {

        @Test
        fun `POTA filter excludes SOTA only`() {
            val vm = makeVM()
            val now = Date()

            vm.setSpots(
                listOf(
                    makeSpot(id = "1", callsign = "W1AW", frequency = 14.060, potaReference = "US-0001", timestamp = now),
                    makeSpot(id = "2", callsign = "K3ABC", frequency = 14.062, sotaReference = "W4C/CM-001", timestamp = now),
                )
            )
            vm.setSourceFilter(SourceFilter.POTA)

            val all = vm.spotsByBand.value.flatMap { it.spots }
            assertEquals(1, all.size)
            assertEquals("W1AW", all[0].activatorCallsign)
        }

        @Test
        fun `SOTA filter excludes POTA only`() {
            val vm = makeVM()
            val now = Date()

            vm.setSpots(
                listOf(
                    makeSpot(id = "1", callsign = "W1AW", frequency = 14.060, potaReference = "US-0001", timestamp = now),
                    makeSpot(id = "2", callsign = "K3ABC", frequency = 14.062, sotaReference = "W4C/CM-001", timestamp = now),
                )
            )
            vm.setSourceFilter(SourceFilter.SOTA)

            val all = vm.spotsByBand.value.flatMap { it.spots }
            assertEquals(1, all.size)
            assertEquals("K3ABC", all[0].activatorCallsign)
        }

        @Test
        fun `ALL filter shows everything`() {
            val vm = makeVM()
            val now = Date()

            vm.setSpots(
                listOf(
                    makeSpot(id = "1", callsign = "W1AW", frequency = 14.060, potaReference = "US-0001", timestamp = now),
                    makeSpot(id = "2", callsign = "K3ABC", frequency = 14.062, sotaReference = "W4C/CM-001", timestamp = now),
                )
            )
            vm.setSourceFilter(SourceFilter.ALL)

            val all = vm.spotsByBand.value.flatMap { it.spots }
            assertEquals(2, all.size)
        }
    }

    // MARK: - Mode Filtering

    @Nested
    inner class `Mode Filtering` {

        @Test
        fun `CW filter excludes SSB`() {
            val vm = makeVM()
            val now = Date()

            vm.setSpots(
                listOf(
                    makeSpot(id = "1", callsign = "W1AW", frequency = 14.060, mode = "CW", potaReference = "US-0001", timestamp = now),
                    makeSpot(id = "2", callsign = "K3ABC", frequency = 14.262, mode = "SSB", potaReference = "US-0002", timestamp = now),
                )
            )
            vm.setModeFilter(ModeFilter.CW)

            val all = vm.spotsByBand.value.flatMap { it.spots }
            assertEquals(1, all.size)
            assertEquals("W1AW", all[0].activatorCallsign)
        }

        @Test
        fun `SSB filter excludes CW`() {
            val vm = makeVM()
            val now = Date()

            vm.setSpots(
                listOf(
                    makeSpot(id = "1", callsign = "W1AW", frequency = 14.060, mode = "CW", potaReference = "US-0001", timestamp = now),
                    makeSpot(id = "2", callsign = "K3ABC", frequency = 14.262, mode = "SSB", potaReference = "US-0002", timestamp = now),
                )
            )
            vm.setModeFilter(ModeFilter.SSB)

            val all = vm.spotsByBand.value.flatMap { it.spots }
            assertEquals(1, all.size)
            assertEquals("K3ABC", all[0].activatorCallsign)
        }

        @Test
        fun `ALL mode filter shows both`() {
            val vm = makeVM()
            val now = Date()

            vm.setSpots(
                listOf(
                    makeSpot(id = "1", callsign = "W1AW", frequency = 14.060, mode = "CW", potaReference = "US-0001", timestamp = now),
                    makeSpot(id = "2", callsign = "K3ABC", frequency = 14.262, mode = "SSB", potaReference = "US-0002", timestamp = now),
                )
            )
            vm.setModeFilter(ModeFilter.ALL)

            val all = vm.spotsByBand.value.flatMap { it.spots }
            assertEquals(2, all.size)
        }

        @Test
        fun `mode and source filters combine`() {
            val vm = makeVM()
            val now = Date()

            vm.setSpots(
                listOf(
                    makeSpot(id = "1", callsign = "W1AW", frequency = 14.060, mode = "CW", potaReference = "US-0001", timestamp = now),
                    makeSpot(id = "2", callsign = "K3ABC", frequency = 14.262, mode = "SSB", potaReference = "US-0002", timestamp = now),
                    makeSpot(id = "3", callsign = "N4XYZ", frequency = 14.060, mode = "CW", sotaReference = "W4C/CM-001", timestamp = now),
                )
            )
            vm.setSourceFilter(SourceFilter.POTA)
            vm.setModeFilter(ModeFilter.CW)

            val all = vm.spotsByBand.value.flatMap { it.spots }
            assertEquals(1, all.size)
            assertEquals("W1AW", all[0].activatorCallsign)
        }
    }

    // MARK: - spotForCallsign

    @Nested
    inner class `Spot For Callsign` {

        @Test
        fun `found`() {
            val vm = makeVM()
            vm.setSpots(
                listOf(
                    makeSpot(callsign = "W1AW", frequency = 14.060, potaReference = "US-0001"),
                )
            )

            val spot = vm.spotForCallsign("W1AW")
            assertNotNull(spot)
            assertEquals("US-0001", spot?.potaReference)
        }

        @Test
        fun `case insensitive`() {
            val vm = makeVM()
            vm.setSpots(
                listOf(
                    makeSpot(callsign = "W1AW", frequency = 14.060, potaReference = "US-0001"),
                )
            )

            val spot = vm.spotForCallsign("w1aw")
            assertNotNull(spot)
        }

        @Test
        fun `excludes expired`() {
            val vm = makeVM()
            vm.setSpots(
                listOf(
                    makeSpot(callsign = "W1AW", frequency = 14.060, potaReference = "US-0001", timestamp = Date(Date().time - 11 * 60 * 1000)),
                )
            )

            val spot = vm.spotForCallsign("W1AW")
            assertNull(spot)
        }

        @Test
        fun `excludes QRT`() {
            val vm = makeVM()
            vm.setSpots(
                listOf(
                    makeSpot(callsign = "W1AW", frequency = 14.060, potaReference = "US-0001", comments = "QRT"),
                )
            )

            val spot = vm.spotForCallsign("W1AW")
            assertNull(spot)
        }

        @Test
        fun `returns null for unknown callsign`() {
            val vm = makeVM()
            vm.setSpots(
                listOf(
                    makeSpot(callsign = "W1AW", frequency = 14.060, potaReference = "US-0001"),
                )
            )

            val spot = vm.spotForCallsign("XX9ZZZ")
            assertNull(spot)
        }
    }
}
