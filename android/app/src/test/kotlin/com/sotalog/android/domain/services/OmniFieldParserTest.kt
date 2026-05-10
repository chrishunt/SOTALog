package com.sotalog.android.domain.services

import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Nested
import org.junit.jupiter.api.Test

class OmniFieldParserTest {

    @Nested
    inner class `Callsign Parsing` {

        @Test
        fun `callsign only`() {
            val result = OmniFieldParser.parse("W1AW")
            assertEquals("W1AW", result.callsign)
            assertNull(result.rstSent)
            assertNull(result.rstReceived)
            assertNull(result.frequency)
            assertNull(result.qth)
            assertNull(result.potaRef)
            assertNull(result.sotaRef)
        }

        @Test
        fun `empty input returns empty callsign`() {
            val result = OmniFieldParser.parse("")
            assertEquals("", result.callsign)
        }
    }

    @Nested
    inner class `RST Parsing` {

        @Test
        fun `two digit RST raw value`() {
            val result = OmniFieldParser.parse("K3ABC 55")
            assertEquals("K3ABC", result.callsign)
            assertEquals("55", result.rstSent)
        }

        @Test
        fun `three digit RST`() {
            val result = OmniFieldParser.parse("K3ABC 579")
            assertEquals("579", result.rstSent)
        }

        @Test
        fun `two RST values gives sent and received`() {
            val result = OmniFieldParser.parse("W1AW 579 339")
            assertEquals("579", result.rstSent)
            assertEquals("339", result.rstReceived)
        }

        @Test
        fun `invalid RST ignored`() {
            // "69" has R=6 which is out of 1-5 range
            val result = OmniFieldParser.parse("W1AW 69")
            assertNull(result.rstSent)
        }
    }

    @Nested
    inner class `Frequency Parsing` {

        @Test
        fun `frequency detection`() {
            val result = OmniFieldParser.parse("W1AW 7.030")
            assertEquals("7.030", result.frequency)
        }

        @Test
        fun `combined RST and frequency`() {
            val result = OmniFieldParser.parse("W1AW 57 14.060")
            assertEquals("57", result.rstSent)
            assertEquals("14.060", result.frequency)
        }
    }

    @Nested
    inner class `Mode Parsing` {

        @Test
        fun `mode token CW`() {
            val result = OmniFieldParser.parse("W1AW CW")
            assertEquals("CW", result.mode)
        }

        @Test
        fun `mode token SSB`() {
            val result = OmniFieldParser.parse("W1AW SSB")
            assertEquals("SSB", result.mode)
        }

        @Test
        fun `mode token case insensitive`() {
            val result = OmniFieldParser.parse("W1AW ssb")
            assertEquals("SSB", result.mode)
        }

        @Test
        fun `mode token consumed in classified tokens`() {
            val result = OmniFieldParser.parse("W1AW SSB")
            assertEquals(2, result.tokens.size)
            assertEquals(TokenKind.MODE, result.tokens[1].kind)
        }

        @Test
        fun `mode token with other tokens`() {
            val result = OmniFieldParser.parse("W1AW SSB 59 14.260")
            assertEquals("SSB", result.mode)
            assertEquals("59", result.rstSent)
            assertEquals("14.260", result.frequency)
        }

        @Test
        fun `mode token FM`() {
            val result = OmniFieldParser.parse("W1AW FM")
            assertEquals("FM", result.mode)
        }

        @Test
        fun `mode token FM case insensitive`() {
            val result = OmniFieldParser.parse("W1AW fm")
            assertEquals("FM", result.mode)
        }

        @Test
        fun `FM mode with frequency and RST`() {
            val result = OmniFieldParser.parse("W1AW 59 146.520 FM")
            assertEquals("FM", result.mode)
            assertEquals("59", result.rstSent)
            assertEquals("146.520", result.frequency)
        }
    }

    @Nested
    inner class `QTH Parsing` {

        @Test
        fun `QTH detection`() {
            val result = OmniFieldParser.parse("W1AW NC")
            assertEquals("NC", result.qth)
        }

        @Test
        fun `Canadian QTH`() {
            val result = OmniFieldParser.parse("VE3ABC ON")
            assertEquals("ON", result.qth)
        }
    }

    @Nested
    inner class `Reference Parsing` {

        @Test
        fun `POTA reference`() {
            val result = OmniFieldParser.parse("W1AW US4431")
            assertEquals("W1AW", result.callsign)
            assertEquals("US4431", result.potaRef)
        }

        @Test
        fun `SOTA reference`() {
            val result = OmniFieldParser.parse("W1AW W4CCM001")
            assertEquals("W1AW", result.callsign)
            assertEquals("W4CCM001", result.sotaRef)
        }
    }

    @Nested
    inner class `Full Exchange` {

        @Test
        fun `full entry with dual RST frequency and QTH`() {
            val result = OmniFieldParser.parse("W1AW 579 559 14.060 CT")
            assertEquals("W1AW", result.callsign)
            assertEquals("579", result.rstSent)
            assertEquals("559", result.rstReceived)
            assertEquals("14.060", result.frequency)
            assertEquals("CT", result.qth)
        }

        @Test
        fun `unrecognized tokens ignored`() {
            val result = OmniFieldParser.parse("W1AW XYZZY")
            assertEquals("W1AW", result.callsign)
            // XYZZY doesn't match any pattern -- silently ignored
        }
    }
}
