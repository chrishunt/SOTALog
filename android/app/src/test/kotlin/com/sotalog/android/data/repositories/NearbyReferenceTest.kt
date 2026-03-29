package com.sotalog.android.data.repositories

import com.sotalog.android.data.local.database.dao.ReferenceDao
import com.sotalog.android.domain.models.POTAPark
import com.sotalog.android.domain.models.SOTASummit
import io.mockk.coEvery
import io.mockk.mockk
import kotlinx.coroutines.test.runTest
import org.junit.jupiter.api.Assertions.*
import org.junit.jupiter.api.Nested
import org.junit.jupiter.api.Test
import kotlin.math.cos
import kotlin.math.sqrt

class NearbyReferenceTest {

    // -- Helpers --

    private fun approxDistanceKm(lat1: Double, lon1: Double, lat2: Double, lon2: Double): Double {
        val dLat = lat2 - lat1
        val dLon = (lon2 - lon1) * cos(Math.toRadians(lat1))
        return 111.32 * sqrt(dLat * dLat + dLon * dLon)
    }

    private fun kmToMiles(km: Double): Double = km * 0.621371

    // -- Distance Calculation --

    @Nested
    inner class `Distance Calculation` {

        @Test
        fun `approx distance for known points`() {
            // New York (40.7128, -74.0060) to Philadelphia (39.9526, -75.1652)
            val km = approxDistanceKm(40.7128, -74.0060, 39.9526, -75.1652)
            // Actual distance ~130 km; equirectangular should be within 10%
            assertTrue(km > 100, "Expected >100 km, got $km")
            assertTrue(km < 160, "Expected <160 km, got $km")
        }

        @Test
        fun `zero distance for same point`() {
            val km = approxDistanceKm(35.0, -82.0, 35.0, -82.0)
            assertEquals(0.0, km, 0.001)
        }

        @Test
        fun `km to miles conversion`() {
            val miles = kmToMiles(100.0)
            assertEquals(62.1371, miles, 0.01)
        }
    }

    // -- Nearby Summits --

    @Nested
    inner class `Nearby Summits` {

        @Test
        fun `nearby summits sorted by distance`() = runTest {
            val dao = mockk<ReferenceDao>()
            val repo = ReferenceRepository(dao)

            val summits = listOf(
                SOTASummit(
                    code = "W4C/CM-001", codeNormalized = "W4CCM001", name = "Mount Mitchell",
                    latitude = 35.765, longitude = -82.265,
                ),
                SOTASummit(
                    code = "W4C/CM-002", codeNormalized = "W4CCM002", name = "Clingmans Dome",
                    latitude = 35.563, longitude = -83.498,
                ),
                SOTASummit(
                    code = "W4T/SU-001", codeNormalized = "W4TSU001", name = "Clingmans Dome TN",
                    latitude = 35.563, longitude = -83.499,
                ),
            )

            // Mock DAO to return all summits as if they are within the bounding box
            coEvery {
                dao.getSummitsInBounds(any(), any(), any(), any())
            } returns summits

            // Query from near Mount Mitchell
            val nearby = repo.nearbySummits(latitude = 35.77, longitude = -82.27)

            // Mount Mitchell should be closest
            assertEquals("W4C/CM-001", nearby.first().code)
            // All three should be present
            assertEquals(3, nearby.size)
        }

        @Test
        fun `empty when none in range`() = runTest {
            val dao = mockk<ReferenceDao>()
            val repo = ReferenceRepository(dao)

            // DAO returns empty list (no summits in bounding box)
            coEvery {
                dao.getSummitsInBounds(any(), any(), any(), any())
            } returns emptyList()

            val nearby = repo.nearbySummits(latitude = 35.77, longitude = -82.27)
            assertTrue(nearby.isEmpty())
        }

        @Test
        fun `respects limit parameter`() = runTest {
            val dao = mockk<ReferenceDao>()
            val repo = ReferenceRepository(dao)

            val summits = listOf(
                SOTASummit(
                    code = "W4C/CM-001", codeNormalized = "W4CCM001", name = "Summit A",
                    latitude = 35.765, longitude = -82.265,
                ),
                SOTASummit(
                    code = "W4C/CM-002", codeNormalized = "W4CCM002", name = "Summit B",
                    latitude = 35.760, longitude = -82.270,
                ),
                SOTASummit(
                    code = "W4C/CM-003", codeNormalized = "W4CCM003", name = "Summit C",
                    latitude = 35.755, longitude = -82.275,
                ),
            )

            coEvery {
                dao.getSummitsInBounds(any(), any(), any(), any())
            } returns summits

            val nearby = repo.nearbySummits(latitude = 35.77, longitude = -82.27, limit = 1)
            assertEquals(1, nearby.size)
        }
    }

    // -- Nearby Parks --

    @Nested
    inner class `Nearby Parks` {

        @Test
        fun `nearby parks sorted by distance`() = runTest {
            val dao = mockk<ReferenceDao>()
            val repo = ReferenceRepository(dao)

            val parks = listOf(
                POTAPark(
                    reference = "US-0002", name = "Pisgah NF",
                    referenceNormalized = "US0002",
                    latitude = 35.345, longitude = -82.824,
                ),
                POTAPark(
                    reference = "US-0003", name = "Nantahala NF",
                    referenceNormalized = "US0003",
                    latitude = 35.200, longitude = -83.500,
                ),
            )

            coEvery {
                dao.getParksInBounds(any(), any(), any(), any())
            } returns parks

            // Query from near Pisgah
            val nearby = repo.nearbyParks(latitude = 35.4, longitude = -82.8)

            assertEquals("US-0002", nearby.first().reference)
            assertEquals(2, nearby.size)
        }

        @Test
        fun `parks without coordinates excluded`() = runTest {
            val dao = mockk<ReferenceDao>()
            val repo = ReferenceRepository(dao)

            val parks = listOf(
                POTAPark(
                    reference = "US-0001", name = "Acadia NP",
                    referenceNormalized = "US0001",
                    latitude = null, longitude = null,
                ),
                POTAPark(
                    reference = "US-0002", name = "Pisgah NF",
                    referenceNormalized = "US0002",
                    latitude = 35.345, longitude = -82.824,
                ),
            )

            coEvery {
                dao.getParksInBounds(any(), any(), any(), any())
            } returns parks

            val nearby = repo.nearbyParks(latitude = 35.4, longitude = -82.8)

            // Only park with coordinates should appear
            assertEquals(1, nearby.size)
            assertEquals("US-0002", nearby.first().reference)
        }

        @Test
        fun `empty when no parks have coordinates`() = runTest {
            val dao = mockk<ReferenceDao>()
            val repo = ReferenceRepository(dao)

            val parks = listOf(
                POTAPark(
                    reference = "US-0001", name = "Acadia NP",
                    referenceNormalized = "US0001",
                    latitude = null, longitude = null,
                ),
            )

            coEvery {
                dao.getParksInBounds(any(), any(), any(), any())
            } returns parks

            val nearby = repo.nearbyParks(latitude = 44.338, longitude = -68.273)
            assertTrue(nearby.isEmpty())
        }
    }
}
