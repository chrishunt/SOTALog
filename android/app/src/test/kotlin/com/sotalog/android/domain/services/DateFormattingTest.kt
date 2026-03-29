package com.sotalog.android.domain.services

import com.sotalog.android.makeUTCDate
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Nested
import org.junit.jupiter.api.Test
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone

class DateFormattingTest {

    // These mirror the private formatting methods in QSOEntryViewModel
    private fun formatADIFDate(date: Date): String {
        val fmt = SimpleDateFormat("yyyyMMdd", Locale.US)
        fmt.timeZone = TimeZone.getTimeZone("UTC")
        return fmt.format(date)
    }

    private fun formatADIFTime(date: Date): String {
        val fmt = SimpleDateFormat("HHmm", Locale.US)
        fmt.timeZone = TimeZone.getTimeZone("UTC")
        return fmt.format(date)
    }

    @Nested
    inner class `ADIF Date Formatting` {

        @Test
        fun `formats date as yyyyMMdd`() {
            val date = makeUTCDate(year = 2024, month = 6, day = 15)
            assertEquals("20240615", formatADIFDate(date))
        }
    }

    @Nested
    inner class `ADIF Time Formatting` {

        @Test
        fun `formats time as HHmm`() {
            val date = makeUTCDate(hour = 14, minute = 30)
            assertEquals("1430", formatADIFTime(date))
        }

        @Test
        fun `midnight formats as 0000`() {
            val date = makeUTCDate(hour = 0, minute = 0)
            assertEquals("0000", formatADIFTime(date))
        }

        @Test
        fun `end of day formats as 2359`() {
            val date = makeUTCDate(hour = 23, minute = 59)
            assertEquals("2359", formatADIFTime(date))
        }
    }
}
