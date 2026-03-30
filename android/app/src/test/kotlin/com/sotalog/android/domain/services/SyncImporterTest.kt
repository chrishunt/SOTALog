package com.sotalog.android.domain.services

import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Nested
import org.junit.jupiter.api.Test

class SyncImporterTest {

    private val validPotaRefs = mapOf(
        "US4431" to "US-4431",
        "US0001" to "US-0001",
        "US0002" to "US-0002",
    )

    private val validSotaCodes = mapOf(
        "W4CCM001" to "W4C/CM-001",
        "GLD001" to "G/LD-001",
    )

    @Nested
    inner class `Single POTA Activation` {

        @Test
        fun `groups QSOs with same POTA ref and date`() {
            val records = listOf(
                mapOf(
                    "CALL" to "K3ABC", "QSO_DATE" to "20240315", "TIME_ON" to "1200",
                    "BAND" to "20m", "MODE" to "CW", "MY_SIG_INFO" to "US-4431",
                    "STATION_CALLSIGN" to "W1AW",
                ),
                mapOf(
                    "CALL" to "N4XYZ", "QSO_DATE" to "20240315", "TIME_ON" to "1205",
                    "BAND" to "20m", "MODE" to "CW", "MY_SIG_INFO" to "US-4431",
                    "STATION_CALLSIGN" to "W1AW",
                ),
            )

            val result = SyncImporter.groupByActivation(records, "W1AW", validPotaRefs, validSotaCodes)

            assertEquals(1, result.activations.size)
            assertEquals(2, result.activations[0].second.size)
            assertEquals("US-4431", result.activations[0].first.potaReference)
            assertNull(result.activations[0].first.sotaReference)
            assertEquals(0, result.unattached.size)
        }
    }

    @Nested
    inner class `SOTA Only Activation` {

        @Test
        fun `groups SOTA-only QSOs`() {
            val records = listOf(
                mapOf(
                    "CALL" to "K3ABC", "QSO_DATE" to "20240315", "TIME_ON" to "1200",
                    "BAND" to "20m", "MODE" to "CW", "MY_SOTA_REF" to "W4C/CM-001",
                    "STATION_CALLSIGN" to "W1AW",
                ),
            )

            val result = SyncImporter.groupByActivation(records, "W1AW", validPotaRefs, validSotaCodes)

            assertEquals(1, result.activations.size)
            assertEquals("W4C/CM-001", result.activations[0].first.sotaReference)
            assertNull(result.activations[0].first.potaReference)
        }
    }

    @Nested
    inner class `Two Activations Same Day` {

        @Test
        fun `different refs on same day create separate activations`() {
            val records = listOf(
                mapOf(
                    "CALL" to "K3ABC", "QSO_DATE" to "20240315", "TIME_ON" to "1200",
                    "BAND" to "20m", "MODE" to "CW", "MY_SIG_INFO" to "US-4431",
                    "STATION_CALLSIGN" to "W1AW",
                ),
                mapOf(
                    "CALL" to "N4XYZ", "QSO_DATE" to "20240315", "TIME_ON" to "1400",
                    "BAND" to "20m", "MODE" to "CW", "MY_SIG_INFO" to "US-0001",
                    "STATION_CALLSIGN" to "W1AW",
                ),
            )

            val result = SyncImporter.groupByActivation(records, "W1AW", validPotaRefs, validSotaCodes)

            assertEquals(2, result.activations.size)
            assertEquals(1, result.activations[0].second.size)
            assertEquals(1, result.activations[1].second.size)
        }
    }

    @Nested
    inner class `Dual Activation` {

        @Test
        fun `POTA and SOTA refs on same QSO`() {
            val records = listOf(
                mapOf(
                    "CALL" to "K3ABC", "QSO_DATE" to "20240315", "TIME_ON" to "1200",
                    "BAND" to "20m", "MODE" to "CW", "MY_SIG_INFO" to "US-4431",
                    "MY_SOTA_REF" to "W4C/CM-001", "STATION_CALLSIGN" to "W1AW",
                ),
            )

            val result = SyncImporter.groupByActivation(records, "W1AW", validPotaRefs, validSotaCodes)

            assertEquals(1, result.activations.size)
            assertEquals("US-4431", result.activations[0].first.potaReference)
            assertEquals("W4C/CM-001", result.activations[0].first.sotaReference)
        }
    }

    @Nested
    inner class `Unattached QSOs` {

        @Test
        fun `no ref QSOs go to unattached`() {
            val records = listOf(
                mapOf(
                    "CALL" to "K3ABC", "QSO_DATE" to "20240315", "TIME_ON" to "1200",
                    "BAND" to "20m", "MODE" to "CW", "STATION_CALLSIGN" to "W1AW",
                ),
            )

            val result = SyncImporter.groupByActivation(records, "W1AW", validPotaRefs, validSotaCodes)

            assertEquals(0, result.activations.size)
            assertEquals(1, result.unattached.size)
        }

        @Test
        fun `mixed refs and no refs`() {
            val records = listOf(
                mapOf(
                    "CALL" to "K3ABC", "QSO_DATE" to "20240315", "TIME_ON" to "1200",
                    "BAND" to "20m", "MODE" to "CW", "MY_SIG_INFO" to "US-4431",
                ),
                mapOf(
                    "CALL" to "N4XYZ", "QSO_DATE" to "20240315", "TIME_ON" to "1205",
                    "BAND" to "20m", "MODE" to "CW",
                ),
            )

            val result = SyncImporter.groupByActivation(records, "W1AW", validPotaRefs, validSotaCodes)

            assertEquals(1, result.activations.size)
            assertEquals(1, result.unattached.size)
        }
    }

    @Nested
    inner class `Fallback Callsign` {

        @Test
        fun `uses fallback callsign when STATION_CALLSIGN missing`() {
            val records = listOf(
                mapOf(
                    "CALL" to "K3ABC", "QSO_DATE" to "20240315", "TIME_ON" to "1200",
                    "BAND" to "20m", "MODE" to "CW", "MY_SIG_INFO" to "US-4431",
                ),
            )

            val result = SyncImporter.groupByActivation(records, "KI5LHR", validPotaRefs, validSotaCodes)

            assertEquals("KI5LHR", result.activations[0].first.stationCallsign)
        }
    }

    @Nested
    inner class `Different Days Same Ref` {

        @Test
        fun `same ref on different days creates separate activations`() {
            val records = listOf(
                mapOf(
                    "CALL" to "K3ABC", "QSO_DATE" to "20240315", "TIME_ON" to "1200",
                    "BAND" to "20m", "MODE" to "CW", "MY_SIG_INFO" to "US-4431",
                ),
                mapOf(
                    "CALL" to "N4XYZ", "QSO_DATE" to "20240316", "TIME_ON" to "1200",
                    "BAND" to "20m", "MODE" to "CW", "MY_SIG_INFO" to "US-4431",
                ),
            )

            val result = SyncImporter.groupByActivation(records, "W1AW", validPotaRefs, validSotaCodes)

            assertEquals(2, result.activations.size)
        }
    }

    @Nested
    inner class `Reference Validation` {

        @Test
        fun `invalid POTA ref treated as unattached`() {
            val records = listOf(
                mapOf(
                    "CALL" to "K3ABC", "QSO_DATE" to "20240315", "TIME_ON" to "1200",
                    "BAND" to "20m", "MODE" to "CW", "MY_SIG_INFO" to "XX-9999",
                ),
            )

            val result = SyncImporter.groupByActivation(records, "W1AW", validPotaRefs, validSotaCodes)

            assertEquals(0, result.activations.size)
            assertEquals(1, result.unattached.size)
        }

        @Test
        fun `invalid SOTA ref treated as unattached`() {
            val records = listOf(
                mapOf(
                    "CALL" to "K3ABC", "QSO_DATE" to "20240315", "TIME_ON" to "1200",
                    "BAND" to "20m", "MODE" to "CW", "MY_SOTA_REF" to "XX/YY-999",
                ),
            )

            val result = SyncImporter.groupByActivation(records, "W1AW", validPotaRefs, validSotaCodes)

            assertEquals(0, result.activations.size)
            assertEquals(1, result.unattached.size)
        }

        @Test
        fun `valid POTA plus invalid SOTA keeps only POTA ref`() {
            val records = listOf(
                mapOf(
                    "CALL" to "K3ABC", "QSO_DATE" to "20240315", "TIME_ON" to "1200",
                    "BAND" to "20m", "MODE" to "CW", "MY_SIG_INFO" to "US-4431",
                    "MY_SOTA_REF" to "XX/YY-999",
                ),
            )

            val result = SyncImporter.groupByActivation(records, "W1AW", validPotaRefs, validSotaCodes)

            assertEquals(1, result.activations.size)
            assertEquals("US-4431", result.activations[0].first.potaReference)
            assertNull(result.activations[0].first.sotaReference)
        }

        @Test
        fun `MY_SIG_INFO without MY_SIG still validated`() {
            val records = listOf(
                mapOf(
                    "CALL" to "K3ABC", "QSO_DATE" to "20240315", "TIME_ON" to "1200",
                    "BAND" to "20m", "MODE" to "CW", "MY_SIG_INFO" to "US-4431",
                ),
            )

            val result = SyncImporter.groupByActivation(records, "W1AW", validPotaRefs, validSotaCodes)

            assertEquals(1, result.activations.size)
            assertEquals("US-4431", result.activations[0].first.potaReference)
        }
    }

    @Nested
    inner class `Normalized Reference Lookup` {

        @Test
        fun `normalized POTA ref lookup`() {
            val records = listOf(
                mapOf(
                    "CALL" to "K3ABC", "QSO_DATE" to "20240315", "TIME_ON" to "1200",
                    "BAND" to "20m", "MODE" to "CW", "MY_SIG_INFO" to "US4431",
                ),
            )

            val result = SyncImporter.groupByActivation(records, "W1AW", validPotaRefs, validSotaCodes)

            assertEquals(1, result.activations.size)
            assertEquals("US-4431", result.activations[0].first.potaReference)
        }

        @Test
        fun `normalized SOTA ref lookup`() {
            val records = listOf(
                mapOf(
                    "CALL" to "K3ABC", "QSO_DATE" to "20240315", "TIME_ON" to "1200",
                    "BAND" to "20m", "MODE" to "CW", "MY_SOTA_REF" to "W4CCM001",
                ),
            )

            val result = SyncImporter.groupByActivation(records, "W1AW", validPotaRefs, validSotaCodes)

            assertEquals(1, result.activations.size)
            assertEquals("W4C/CM-001", result.activations[0].first.sotaReference)
        }
    }
}
