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

        @Test
        fun `2m FM sub-band returns FM`() {
            assertEquals("FM", BandPlan.mode(146.520))
            assertEquals("FM", BandPlan.mode(145.000)) // at boundary
            assertEquals("FM", BandPlan.mode(147.000))
        }

        @Test
        fun `2m between SSB and FM boundaries returns SSB`() {
            assertEquals("SSB", BandPlan.mode(144.999))
            assertEquals("SSB", BandPlan.mode(144.200))
        }

        @Test
        fun `2m below SSB boundary returns CW`() {
            assertEquals("CW", BandPlan.mode(144.060))
        }

        @Test
        fun `6m FM sub-band returns FM`() {
            assertEquals("FM", BandPlan.mode(52.525))
            assertEquals("FM", BandPlan.mode(51.000)) // at boundary
        }

        @Test
        fun `6m between SSB and FM boundaries returns SSB`() {
            assertEquals("SSB", BandPlan.mode(50.999))
            assertEquals("SSB", BandPlan.mode(50.500))
        }

        @Test
        fun `HF bands have no FM derivation`() {
            assertEquals("SSB", BandPlan.mode(14.260))
            assertEquals("SSB", BandPlan.mode(28.400))
            assertEquals("SSB", BandPlan.mode(29.600)) // 10m FM happens here, but operator must toggle
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

    @Nested
    inner class `Default FM Frequencies` {

        @Test
        fun `FM-capable bands have defaults`() {
            assertEquals(146.520, BandPlan.defaultFMFrequency("2m"))
            assertEquals(52.525, BandPlan.defaultFMFrequency("6m"))
        }

        @Test
        fun `HF bands return null`() {
            assertNull(BandPlan.defaultFMFrequency("20m"))
            assertNull(BandPlan.defaultFMFrequency("40m"))
            assertNull(BandPlan.defaultFMFrequency("10m"))
        }

        @Test
        fun `default FM frequencies are within band and return FM mode`() {
            for (bandName in BandPlan.allBands) {
                val freq = BandPlan.defaultFMFrequency(bandName)
                if (freq != null) {
                    assertEquals(bandName, BandPlan.band(freq))
                    assertEquals("FM", BandPlan.mode(freq))
                }
            }
        }
    }
}
