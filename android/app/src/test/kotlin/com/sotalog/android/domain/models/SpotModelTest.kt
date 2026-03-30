package com.sotalog.android.domain.models

import com.sotalog.android.makeSpot
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Nested
import org.junit.jupiter.api.Test
import java.util.Date

class SpotModelTest {

    @Nested
    inner class `Band Derivation` {

        @Test
        fun `band derives from frequency 20m`() {
            val spot = makeSpot(frequency = 14.060)
            assertEquals("20m", spot.band)
        }

        @Test
        fun `band derives from frequency 40m`() {
            val spot = makeSpot(frequency = 7.030)
            assertEquals("40m", spot.band)
        }

        @Test
        fun `band unknown frequency returns question mark`() {
            val spot = makeSpot(frequency = 999.0)
            assertEquals("?", spot.band)
        }
    }

    @Nested
    inner class `Expiration` {

        @Test
        fun `fresh spot not expired`() {
            val spot = makeSpot(timestamp = Date())
            assertFalse(spot.isExpired())
        }

        @Test
        fun `old spot expired`() {
            val spot = makeSpot(timestamp = Date(Date().time - 11 * 60 * 1000))
            assertTrue(spot.isExpired())
        }

        @Test
        fun `isExpired custom threshold`() {
            val spot = makeSpot(timestamp = Date(Date().time - 6 * 60 * 1000))
            assertFalse(spot.isExpired(afterMinutes = 10.0))
            assertTrue(spot.isExpired(afterMinutes = 5.0))
        }
    }

    @Nested
    inner class `QRT Detection` {

        @Test
        fun `isQRT with QRT`() {
            val spot = makeSpot(comments = "QRT")
            assertTrue(spot.isQRT)
        }

        @Test
        fun `isQRT case insensitive`() {
            val spot = makeSpot(comments = "going qrt now")
            assertTrue(spot.isQRT)
        }

        @Test
        fun `isQRT nil comments`() {
            val spot = makeSpot(comments = null)
            assertFalse(spot.isQRT)
        }

        @Test
        fun `isQRT other comments`() {
            val spot = makeSpot(comments = "CQ CQ CQ")
            assertFalse(spot.isQRT)
        }
    }

    @Nested
    inner class `Age Calculation` {

        @Test
        fun `ageMinutes minimum one`() {
            val spot = makeSpot(timestamp = Date())
            assertEquals(1, spot.ageMinutes)
        }

        @Test
        fun `ageMinutes calculation`() {
            val spot = makeSpot(timestamp = Date(Date().time - 5 * 60 * 1000))
            assertEquals(5, spot.ageMinutes)
        }
    }

    @Nested
    inner class `Sources` {

        @Test
        fun `sources POTA only`() {
            val spot = makeSpot(potaReference = "US-0001")
            assertEquals(setOf(Spot.Source.POTA), spot.sources)
        }

        @Test
        fun `sources SOTA only`() {
            val spot = makeSpot(sotaReference = "W4C/CM-001")
            assertEquals(setOf(Spot.Source.SOTA), spot.sources)
        }

        @Test
        fun `sources both`() {
            val spot = makeSpot(potaReference = "US-0001", sotaReference = "W4C/CM-001")
            assertEquals(setOf(Spot.Source.POTA, Spot.Source.SOTA), spot.sources)
        }
    }

    @Nested
    inner class `Source Primary` {

        @Test
        fun `source primary prefers POTA`() {
            val spot = makeSpot(potaReference = "US-0001", sotaReference = "W4C/CM-001")
            assertEquals(Spot.Source.POTA, spot.source)
        }

        @Test
        fun `source falls back to SOTA`() {
            val spot = makeSpot(sotaReference = "W4C/CM-001")
            assertEquals(Spot.Source.SOTA, spot.source)
        }
    }

    @Nested
    inner class `Reference Properties` {

        @Test
        fun `reference prefers POTA`() {
            val spot = makeSpot(potaReference = "US-0001", sotaReference = "W4C/CM-001")
            assertEquals("US-0001", spot.reference)
        }

        @Test
        fun `reference falls back to SOTA`() {
            val spot = makeSpot(sotaReference = "W4C/CM-001")
            assertEquals("W4C/CM-001", spot.reference)
        }

        @Test
        fun `reference empty when none`() {
            val spot = makeSpot()
            assertEquals("", spot.reference)
        }

        @Test
        fun `referenceName prefers POTA`() {
            val spot = makeSpot(
                potaReference = "US-0001", potaReferenceName = "Park A",
                sotaReference = "W4C/CM-001", sotaReferenceName = "Summit B",
            )
            assertEquals("Park A", spot.referenceName)
        }

        @Test
        fun `referenceName falls back to SOTA`() {
            val spot = makeSpot(sotaReference = "W4C/CM-001", sotaReferenceName = "Summit B")
            assertEquals("Summit B", spot.referenceName)
        }

        @Test
        fun `referenceName nil when none`() {
            val spot = makeSpot()
            assertNull(spot.referenceName)
        }
    }
}
