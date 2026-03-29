package com.sotalog.android.domain.services

import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Nested
import org.junit.jupiter.api.Test

class CallsignPrefixResolverTest {

    @Nested
    inner class `US Callsigns` {

        @Test
        fun `single state area returns state`() {
            assertEquals("CA", CallsignPrefixResolver.resolve("K6ABC"))
        }

        @Test
        fun `multi state area returns null`() {
            assertNull(CallsignPrefixResolver.resolve("W1AW"))   // district 1 = CT/MA/ME/...
            assertNull(CallsignPrefixResolver.resolve("N4XYZ"))  // district 4 = AL/FL/GA/...
            assertNull(CallsignPrefixResolver.resolve("AA1BB"))  // district 1
        }
    }

    @Nested
    inner class `Canadian Callsigns` {

        @Test
        fun `VE and VA prefixes resolve to provinces`() {
            assertEquals("ON", CallsignPrefixResolver.resolve("VE3ABC"))
            assertEquals("BC", CallsignPrefixResolver.resolve("VA7XYZ"))
            assertEquals("NS", CallsignPrefixResolver.resolve("VE1QQ"))
        }
    }

    @Nested
    inner class `DX Callsigns` {

        @Test
        fun `known DX prefixes resolve to ISO codes`() {
            assertEquals("GBR", CallsignPrefixResolver.resolve("G3ABC"))
            assertEquals("DEU", CallsignPrefixResolver.resolve("DL1XYZ"))
            assertEquals("JPN", CallsignPrefixResolver.resolve("JA1ABC"))
            assertEquals("AUS", CallsignPrefixResolver.resolve("VK2ABC"))
        }
    }

    @Nested
    inner class `Short Callsigns` {

        @Test
        fun `single char returns null`() {
            assertNull(CallsignPrefixResolver.resolve("A"))
        }

        @Test
        fun `empty string returns null`() {
            assertNull(CallsignPrefixResolver.resolve(""))
        }
    }

    @Nested
    inner class `Abbreviation` {

        @Test
        fun `abbreviate known countries`() {
            assertEquals("JPN", CallsignPrefixResolver.abbreviate("Japan"))
            assertEquals("DEU", CallsignPrefixResolver.abbreviate("Germany"))
            assertEquals("GBR", CallsignPrefixResolver.abbreviate("England"))
            assertEquals("AUS", CallsignPrefixResolver.abbreviate("Australia"))
        }

        @Test
        fun `abbreviate unknown country returns passthrough`() {
            assertEquals("Narnia", CallsignPrefixResolver.abbreviate("Narnia"))
        }
    }
}
