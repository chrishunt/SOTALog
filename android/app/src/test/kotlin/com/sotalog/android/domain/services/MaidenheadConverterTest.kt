package com.sotalog.android.domain.services

import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Nested
import org.junit.jupiter.api.Test

class MaidenheadConverterTest {

    @Nested
    inner class `Known Locations` {

        @Test
        fun `Washington DC area`() {
            val dc = MaidenheadConverter.gridSquare(latitude = 38.9072, longitude = -77.0369)
            assertTrue(dc.startsWith("FM18"), "DC grid should start with FM18, got $dc")
        }

        @Test
        fun `New York City`() {
            val nyc = MaidenheadConverter.gridSquare(latitude = 40.7128, longitude = -74.0060)
            assertTrue(nyc.startsWith("FN20"), "NYC grid should start with FN20, got $nyc")
        }

        @Test
        fun `London`() {
            val london = MaidenheadConverter.gridSquare(latitude = 51.5074, longitude = -0.1278)
            assertTrue(london.startsWith("IO91"), "London grid should start with IO91, got $london")
        }
    }

    @Nested
    inner class `Grid Length` {

        @Test
        fun `grid4 returns 4 characters`() {
            val grid = MaidenheadConverter.grid4(latitude = 35.0, longitude = -80.0)
            assertEquals(4, grid.length)
        }

        @Test
        fun `gridSquare returns 6 characters`() {
            val grid = MaidenheadConverter.gridSquare(latitude = 35.0, longitude = -80.0)
            assertEquals(6, grid.length)
        }
    }
}
