package com.sotalog.android.data.repositories

import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Nested
import org.junit.jupiter.api.Test

class SOTACatRepositoryTest {

    // These mirror the inline conversion used in SOTACatRepository
    private fun hzToMHz(hz: Long): Double = hz.toDouble() / 1_000_000.0
    private fun mhzToHz(mhz: Double): Long = (mhz * 1_000_000).toLong()

    @Nested
    inner class `Frequency Conversion` {

        @Test
        fun `hzToMHz converts Hz to MHz`() {
            assertEquals(14.060, hzToMHz(14_060_000))
        }

        @Test
        fun `mhzToHz converts MHz to Hz`() {
            assertEquals(14_060_000L, mhzToHz(14.060))
        }

        @Test
        fun `hzToMHz formats to 3 decimal places`() {
            val mhz = hzToMHz(7_030_000)
            assertEquals("7.030", "%.3f".format(mhz))
        }

        @Test
        fun `zero frequency converts correctly`() {
            assertEquals(0.0, hzToMHz(0))
            assertEquals(0L, mhzToHz(0.0))
        }

        @Test
        fun `round-trip conversion preserves value`() {
            val originalMHz = 14.060
            val hz = mhzToHz(originalMHz)
            val backToMHz = hzToMHz(hz)
            assertEquals(originalMHz, backToMHz)
        }
    }
}
