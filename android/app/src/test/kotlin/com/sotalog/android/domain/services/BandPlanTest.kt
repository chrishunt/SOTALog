package com.sotalog.android.domain.services

import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertNotNull
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Nested
import org.junit.jupiter.api.Test

class BandPlanTest {

    @Nested
    inner class `Band Lookup` {

        @Test
        fun `band lookup returns correct band for known frequencies`() {
            assertEquals("20m", BandPlan.band(14.060))
            assertEquals("40m", BandPlan.band(7.030))
            assertEquals("80m", BandPlan.band(3.530))
            assertEquals("15m", BandPlan.band(21.060))
            assertEquals("10m", BandPlan.band(28.060))
            assertEquals("30m", BandPlan.band(10.110))
            assertEquals("160m", BandPlan.band(1.810))
            assertEquals("6m", BandPlan.band(50.060))
            assertEquals("17m", BandPlan.band(18.080))
            assertEquals("12m", BandPlan.band(24.910))
            assertEquals("2m", BandPlan.band(144.060))
        }

        @Test
        fun `out of band frequencies return null`() {
            assertNull(BandPlan.band(0.5))
            assertNull(BandPlan.band(100.0))
            assertNull(BandPlan.band(5.0))
        }

        @Test
        fun `default CW frequencies are within band`() {
            for (bandName in BandPlan.allBands) {
                val freq = BandPlan.defaultCWFrequency(bandName)
                assertNotNull(freq, "Missing default CW freq for $bandName")
                assertEquals(bandName, BandPlan.band(freq!!))
            }
        }
    }

    @Nested
    inner class `Mode Derivation` {

        @Test
        fun `CW sub-band returns CW`() {
            assertEquals("CW", BandPlan.mode(14.060))
            assertEquals("CW", BandPlan.mode(7.030))
            assertEquals("CW", BandPlan.mode(3.530))
            assertEquals("CW", BandPlan.mode(21.060))
        }

        @Test
        fun `SSB sub-band returns SSB`() {
            assertEquals("SSB", BandPlan.mode(14.260))
            assertEquals("SSB", BandPlan.mode(7.200))
            assertEquals("SSB", BandPlan.mode(3.860))
            assertEquals("SSB", BandPlan.mode(21.300))
        }

        @Test
        fun `mode at SSB boundary returns SSB`() {
            assertEquals("SSB", BandPlan.mode(14.150))
        }

        @Test
        fun `mode just below SSB boundary returns CW`() {
            assertEquals("CW", BandPlan.mode(14.149))
        }

        @Test
        fun `CW-only bands return CW`() {
            assertEquals("CW", BandPlan.mode(10.110)) // 30m
            assertEquals("CW", BandPlan.mode(5.332))  // 60m
        }

        @Test
        fun `out of band frequencies return null`() {
            assertNull(BandPlan.mode(0.5))
            assertNull(BandPlan.mode(100.0))
        }
    }

    @Nested
    inner class `Default SSB Frequencies` {

        @Test
        fun `SSB-capable bands have defaults`() {
            assertNotNull(BandPlan.defaultSSBFrequency("20m"))
            assertNotNull(BandPlan.defaultSSBFrequency("40m"))
        }

        @Test
        fun `CW-only bands return null`() {
            assertNull(BandPlan.defaultSSBFrequency("30m"))
            assertNull(BandPlan.defaultSSBFrequency("60m"))
        }

        @Test
        fun `default SSB frequencies are within band and return SSB mode`() {
            for (bandName in BandPlan.allBands) {
                val freq = BandPlan.defaultSSBFrequency(bandName)
                if (freq != null) {
                    assertEquals(bandName, BandPlan.band(freq))
                    assertEquals("SSB", BandPlan.mode(freq))
                }
            }
        }
    }
}
