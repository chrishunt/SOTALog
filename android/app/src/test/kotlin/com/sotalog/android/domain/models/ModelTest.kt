package com.sotalog.android.domain.models

import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Nested
import org.junit.jupiter.api.Test

class ModelTest {

    @Nested
    inner class `Log Computed Properties` {

        @Test
        fun `isPOTA returns true when potaReference set`() {
            val log = Log(myCallsign = "W1AW", potaReference = "US-4431")
            assertTrue(log.isPOTA)
            assertFalse(log.isSOTA)
        }

        @Test
        fun `isSOTA returns true when sotaReference set`() {
            val log = Log(myCallsign = "W1AW", sotaReference = "W4C/CM-001")
            assertFalse(log.isPOTA)
            assertTrue(log.isSOTA)
        }

        @Test
        fun `both POTA and SOTA`() {
            val log = Log(myCallsign = "W1AW", potaReference = "US-4431", sotaReference = "W4C/CM-001")
            assertTrue(log.isPOTA)
            assertTrue(log.isSOTA)
        }

        @Test
        fun `referenceDisplay POTA only`() {
            val log = Log(myCallsign = "W1AW", potaReference = "US-4431")
            assertEquals("US-4431", log.referenceDisplay)
        }

        @Test
        fun `referenceDisplay SOTA only`() {
            val log = Log(myCallsign = "W1AW", sotaReference = "W4C/CM-001")
            assertEquals("W4C/CM-001", log.referenceDisplay)
        }

        @Test
        fun `referenceDisplay both`() {
            val log = Log(myCallsign = "W1AW", potaReference = "US-4431", sotaReference = "W4C/CM-001")
            assertEquals("US-4431 \u00B7 W4C/CM-001", log.referenceDisplay)
        }

        @Test
        fun `referenceDisplay neither`() {
            val log = Log(myCallsign = "W1AW")
            assertNull(log.referenceDisplay)
        }

        @Test
        fun `formattedDate standard 8 digit date`() {
            val log = Log(date = "20240315", myCallsign = "W1AW")
            assertEquals("2024-03-15", log.formattedDate)
        }

        @Test
        fun `formattedDate short string returns as-is`() {
            val log = Log(date = "202", myCallsign = "W1AW")
            assertEquals("202", log.formattedDate)
        }

        @Test
        fun `formattedDate empty returns empty`() {
            val log = Log(date = "", myCallsign = "W1AW")
            assertEquals("", log.formattedDate)
        }
    }

    @Nested
    inner class `POTAPark Normalization` {

        @Test
        fun `normalize strips dash and uppercases`() {
            assertEquals("US4431", POTAPark.normalize("US-4431"))
        }

        @Test
        fun `normalize lowercase`() {
            assertEquals("US4431", POTAPark.normalize("us-4431"))
        }

        @Test
        fun `normalize already normalized`() {
            assertEquals("US4431", POTAPark.normalize("US4431"))
        }

        @Test
        fun `displayName`() {
            val park = POTAPark(reference = "US-4431", name = "Prescott NF")
            assertEquals("US-4431 Prescott NF", park.displayName)
        }
    }

    @Nested
    inner class `SOTASummit Normalization` {

        @Test
        fun `normalize strips slash and dash and uppercases`() {
            assertEquals("W4CCM001", SOTASummit.normalize("W4C/CM-001"))
        }

        @Test
        fun `normalize lowercase`() {
            assertEquals("W4CCM001", SOTASummit.normalize("w4c/cm-001"))
        }

        @Test
        fun `normalize already normalized`() {
            assertEquals("W4CCM001", SOTASummit.normalize("W4CCM001"))
        }

        @Test
        fun `displayName`() {
            val summit = SOTASummit(code = "W4C/CM-001", name = "Mount Mitchell")
            assertEquals("W4C/CM-001 Mount Mitchell", summit.displayName)
        }
    }

    @Nested
    inner class `QRZCallsignResult` {

        @Test
        fun `name with both first and last`() {
            val result = QRZCallsignResult(callsign = "W1AW", firstName = "Hiram", lastName = "Maxim")
            assertEquals("Hiram Maxim", result.name)
        }

        @Test
        fun `name first only`() {
            val result = QRZCallsignResult(callsign = "W1AW", firstName = "Hiram")
            assertEquals("Hiram", result.name)
        }

        @Test
        fun `name last only`() {
            val result = QRZCallsignResult(callsign = "W1AW", lastName = "Maxim")
            assertEquals("Maxim", result.name)
        }

        @Test
        fun `name both nil returns null`() {
            val result = QRZCallsignResult(callsign = "W1AW")
            assertNull(result.name)
        }

        @Test
        fun `nickname overrides first and last`() {
            val result = QRZCallsignResult(callsign = "W1AW", firstName = "Hiram", nickname = "Hi", lastName = "Maxim")
            assertEquals("Hi", result.name)
        }

        @Test
        fun `qth prefers state`() {
            val result = QRZCallsignResult(callsign = "W1AW", state = "CT", country = "United States")
            assertEquals("CT", result.qth)
        }

        @Test
        fun `qth falls back to country`() {
            val result = QRZCallsignResult(callsign = "G3ABC", country = "England")
            assertEquals("England", result.qth)
        }

        @Test
        fun `qth both nil returns null`() {
            val result = QRZCallsignResult(callsign = "W1AW")
            assertNull(result.qth)
        }
    }
}
