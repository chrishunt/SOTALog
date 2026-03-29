package com.sotalog.android.domain.services

import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Test

class StringExtensionTest {

    // Mirrors iOS sanitizedOmnifield: uppercase, keep A-Z 0-9 / space . -
    private fun sanitizeOmnifield(input: String): String =
        input.uppercase().filter { it.isLetterOrDigit() || it in listOf('/', ' ', '.', '-') }

    @Test
    fun `uppercases input`() {
        assertEquals("W1AW 579", sanitizeOmnifield("w1aw 579"))
    }

    @Test
    fun `preserves allowed characters`() {
        assertEquals("W1AW/P 14.060 NC-VA", sanitizeOmnifield("W1AW/P 14.060 NC-VA"))
    }

    @Test
    fun `strips special characters`() {
        assertEquals("W1AW 579", sanitizeOmnifield("W1AW!@# 579"))
    }

    @Test
    fun `empty string`() {
        assertEquals("", sanitizeOmnifield(""))
    }
}
