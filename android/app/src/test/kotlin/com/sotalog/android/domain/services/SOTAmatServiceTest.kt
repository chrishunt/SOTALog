package com.sotalog.android.domain.services

import com.sotalog.android.domain.models.Log
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Nested
import org.junit.jupiter.api.Test

class SOTAmatServiceTest {

    @Nested
    inner class `SOTA Only` {

        @Test
        fun `SOTA spot message format`() {
            val log = Log(myCallsign = "AB1CD", sotaReference = "W4C/CM-001")
            val result = SOTAmatService.spotMessage(log, frequencyMHz = "14.062", mode = "CW", comment = null)
            assertEquals("SotaPostSpot AB1CD W4C/CM-001 14.062 CW", result)
        }

        @Test
        fun `SOTA spot with comment`() {
            val log = Log(myCallsign = "AB1CD", sotaReference = "W4C/CM-001")
            val result = SOTAmatService.spotMessage(log, frequencyMHz = "14.062", mode = "CW", comment = "Running 5W")
            assertEquals("SotaPostSpot AB1CD W4C/CM-001 14.062 CW 'Running 5W", result)
        }
    }

    @Nested
    inner class `POTA Only` {

        @Test
        fun `POTA spot message format`() {
            val log = Log(myCallsign = "AB1CD", potaReference = "US-4431")
            val result = SOTAmatService.spotMessage(log, frequencyMHz = "14.062", mode = "CW", comment = null)
            assertEquals("PotaPostSpot AB1CD US-4431 14.062 CW", result)
        }

        @Test
        fun `POTA spot with comment`() {
            val log = Log(myCallsign = "AB1CD", potaReference = "US-4431")
            val result = SOTAmatService.spotMessage(log, frequencyMHz = "7.030", mode = "CW", comment = "On the trail")
            assertEquals("PotaPostSpot AB1CD US-4431 7.030 CW 'On the trail", result)
        }
    }

    @Nested
    inner class `Dual Activation` {

        @Test
        fun `dual activation spot`() {
            val log = Log(myCallsign = "AB1CD", potaReference = "US-4431", sotaReference = "W4C/CM-001")
            val result = SOTAmatService.spotMessage(log, frequencyMHz = "14.062", mode = "CW", comment = null)
            assertEquals(
                "SotaPostSpot AB1CD W4C/CM-001 14.062 CW; PotaPostSpot AB1CD US-4431 14.062 CW",
                result,
            )
        }

        @Test
        fun `dual activation with comment`() {
            val log = Log(myCallsign = "AB1CD", potaReference = "US-4431", sotaReference = "W4C/CM-001")
            val result = SOTAmatService.spotMessage(log, frequencyMHz = "14.062", mode = "CW", comment = "Running 5W")
            assertEquals(
                "SotaPostSpot AB1CD W4C/CM-001 14.062 CW 'Running 5W; PotaPostSpot AB1CD US-4431 14.062 CW 'Running 5W",
                result,
            )
        }
    }

    @Nested
    inner class `No Reference` {

        @Test
        fun `nil when no references`() {
            val log = Log(myCallsign = "AB1CD")
            val result = SOTAmatService.spotMessage(log, frequencyMHz = "14.062", mode = "CW", comment = null)
            assertNull(result)
        }
    }

    @Nested
    inner class `Comment Sanitization` {

        @Test
        fun `sanitizes reserved chars from comment`() {
            val log = Log(myCallsign = "AB1CD", sotaReference = "W4C/CM-001")
            val result = SOTAmatService.spotMessage(log, frequencyMHz = "14.062", mode = "CW", comment = "it's a nice; day, here")
            assertEquals("SotaPostSpot AB1CD W4C/CM-001 14.062 CW 'its a nice day here", result)
        }

        @Test
        fun `sanitizes smart quotes from comment`() {
            val log = Log(myCallsign = "AB1CD", sotaReference = "W4C/CM-001")
            val result = SOTAmatService.spotMessage(
                log, frequencyMHz = "14.062", mode = "CW",
                comment = "it\u2019s a \u201Cnice\u201D day",
            )
            assertEquals("SotaPostSpot AB1CD W4C/CM-001 14.062 CW 'its a nice day", result)
        }

        @Test
        fun `empty comment after sanitization`() {
            val log = Log(myCallsign = "AB1CD", sotaReference = "W4C/CM-001")
            val result = SOTAmatService.spotMessage(log, frequencyMHz = "14.062", mode = "CW", comment = ";;,'")
            assertEquals("SotaPostSpot AB1CD W4C/CM-001 14.062 CW", result)
        }

        @Test
        fun `whitespace only comment`() {
            val log = Log(myCallsign = "AB1CD", sotaReference = "W4C/CM-001")
            val result = SOTAmatService.spotMessage(log, frequencyMHz = "14.062", mode = "CW", comment = "   ")
            assertEquals("SotaPostSpot AB1CD W4C/CM-001 14.062 CW", result)
        }
    }

    @Nested
    inner class `QRT Inference` {

        @Test
        fun `QRT inference SOTA`() {
            val log = Log(myCallsign = "AB1CD", sotaReference = "W4C/CM-001")
            val result = SOTAmatService.spotMessage(log, frequencyMHz = "14.062", mode = "CW", comment = "QRT thanks for the contacts")
            assertEquals(
                "SotaPostSpot AB1CD W4C/CM-001 14.062 QRT 'QRT thanks for the contacts",
                result,
            )
        }

        @Test
        fun `QRT inference POTA`() {
            val log = Log(myCallsign = "AB1CD", potaReference = "US-4431")
            val result = SOTAmatService.spotMessage(log, frequencyMHz = "14.062", mode = "CW", comment = "QRT thanks for the contacts")
            assertEquals(
                "PotaPostSpot AB1CD US-4431 14.062 CW 'QRT thanks for the contacts",
                result,
            )
        }

        @Test
        fun `QRT inference case insensitive`() {
            val log = Log(myCallsign = "AB1CD", sotaReference = "W4C/CM-001")
            val result = SOTAmatService.spotMessage(log, frequencyMHz = "14.062", mode = "SSB", comment = "going qrt now")
            assertEquals(
                "SotaPostSpot AB1CD W4C/CM-001 14.062 QRT 'going qrt now",
                result,
            )
        }

        @Test
        fun `QRT dual activation`() {
            val log = Log(myCallsign = "AB1CD", potaReference = "US-4431", sotaReference = "W4C/CM-001")
            val result = SOTAmatService.spotMessage(log, frequencyMHz = "14.062", mode = "CW", comment = "QRT thanks")
            assertEquals(
                "SotaPostSpot AB1CD W4C/CM-001 14.062 QRT 'QRT thanks; PotaPostSpot AB1CD US-4431 14.062 CW 'QRT thanks",
                result,
            )
        }
    }

    @Nested
    inner class `SSB Mode` {

        @Test
        fun `SSB mode spot`() {
            val log = Log(myCallsign = "AB1CD", sotaReference = "W4C/CM-001")
            val result = SOTAmatService.spotMessage(log, frequencyMHz = "14.285", mode = "SSB", comment = null)
            assertEquals("SotaPostSpot AB1CD W4C/CM-001 14.285 SSB", result)
        }
    }
}
