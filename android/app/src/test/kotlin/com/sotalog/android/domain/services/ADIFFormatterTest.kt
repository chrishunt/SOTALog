package com.sotalog.android.domain.services

import com.sotalog.android.domain.models.Log
import com.sotalog.android.domain.models.QSO
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertNotNull
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Nested
import org.junit.jupiter.api.Test

class ADIFFormatterTest {

    @Nested
    inner class `Field Encoding` {

        @Test
        fun `encodeField produces correct name-length format`() {
            val field = ADIFFormatter.encodeField("CALL", "W1AW")
            assertEquals("<CALL:4>W1AW", field)
        }
    }

    @Nested
    inner class `QSO Encoding` {

        @Test
        fun `encode QSO with all fields`() {
            val qso = QSO(
                logId = 1,
                callsign = "W1AW",
                date = "20240101",
                timeOn = "1234",
                frequency = 14.060,
                band = "20m",
                mode = "CW",
                rstSent = "599",
                rstReceived = "579",
            )
            val adif = ADIFFormatter.encode(qso)
            assertTrue(adif.contains("<CALL:4>W1AW"))
            assertTrue(adif.contains("<QSO_DATE:8>20240101"))
            assertTrue(adif.contains("<TIME_ON:4>1234"))
            assertTrue(adif.contains("<BAND:3>20m"))
            assertTrue(adif.contains("<MODE:2>CW"))
            assertTrue(adif.contains("<RST_SENT:3>599"))
            assertTrue(adif.contains("<RST_RCVD:3>579"))
            assertTrue(adif.contains("<FREQ:7>14.0600"))
            assertTrue(adif.contains("<EOR>"))
        }

        @Test
        fun `encode POTA fields`() {
            val qso = QSO(logId = 1, callsign = "W1AW", date = "20240101", timeOn = "1234", band = "20m", potaRef = "US-0001")
            val log = Log(myCallsign = "K3ABC", potaReference = "US-4431", parkName = "Prescott NF")
            val adif = ADIFFormatter.encode(qso, log)
            assertTrue(adif.contains("<MY_SIG:4>POTA"))
            assertTrue(adif.contains("<MY_SIG_INFO:7>US-4431"))
            assertTrue(adif.contains("<SIG:4>POTA"))
            assertTrue(adif.contains("<SIG_INFO:7>US-0001"))
        }
    }

    @Nested
    inner class `Decoding` {

        @Test
        fun `decode ADIF records`() {
            val adif = """
                Test header
                <ADIF_VER:5>3.1.4<EOH>
                <CALL:4>W1AW<QSO_DATE:8>20240101<TIME_ON:4>1234<BAND:3>20m<MODE:2>CW<RST_SENT:3>599<RST_RCVD:3>579<EOR>
                <CALL:5>K3ABC<QSO_DATE:8>20240102<TIME_ON:4>0000<BAND:3>40m<MODE:2>CW<EOR>
            """.trimIndent()
            val records = ADIFFormatter.decode(adif)
            assertEquals(2, records.size)
            assertEquals("W1AW", records[0]["CALL"])
            assertEquals("20m", records[0]["BAND"])
            assertEquals("K3ABC", records[1]["CALL"])
            assertEquals("40m", records[1]["BAND"])
        }

        @Test
        fun `decode uppercases field names`() {
            val adif = "<call:4>W1AW<qso_date:8>20240101<time_on:4>1200<band:3>20m<app_qrzlog_logid:3>100<EOR>"
            val records = ADIFFormatter.decode(adif)
            assertEquals("W1AW", records[0]["CALL"])
            assertEquals("100", records[0]["APP_QRZLOG_LOGID"])
        }

        @Test
        fun `decode preserves APP_QRZLOG_LOGID`() {
            val adif = "<CALL:4>W1AW<QSO_DATE:8>20240101<TIME_ON:4>1200<BAND:3>20m<APP_QRZLOG_LOGID:6>123456<EOR>"
            val records = ADIFFormatter.decode(adif)
            assertEquals(1, records.size)
            assertEquals("123456", records[0]["APP_QRZLOG_LOGID"])
        }
    }

    @Nested
    inner class `QSO From Fields` {

        @Test
        fun `fields to QSO`() {
            val fields = mapOf(
                "CALL" to "W1AW",
                "QSO_DATE" to "20240101",
                "TIME_ON" to "1234",
                "BAND" to "20m",
                "MODE" to "CW",
                "RST_SENT" to "599",
                "RST_RCVD" to "579",
                "FREQ" to "14.060",
                "NAME" to "Hiram",
                "QTH" to "CT",
            )
            val qso = ADIFFormatter.qsoFromFields(fields, logId = 1)
            assertNotNull(qso)
            assertEquals("W1AW", qso?.callsign)
            assertEquals(14.060, qso?.frequency)
            assertEquals("Hiram", qso?.name)
            assertEquals("CT", qso?.qth)
        }
    }

    @Nested
    inner class `File Generation` {

        @Test
        fun `encodeFile with log context`() {
            val qso = QSO(logId = 1, callsign = "W1AW", date = "20240101", timeOn = "1234", band = "20m")
            val log = Log(myCallsign = "K3ABC", myGrid = "FN20", potaReference = "US-4431", parkName = "Prescott NF")
            val adif = ADIFFormatter.encodeFile(sections = listOf(log to listOf(qso)))
            assertTrue(adif.contains("<STATION_CALLSIGN:5>K3ABC"))
            assertTrue(adif.contains("<MY_SIG:4>POTA"))
            assertTrue(adif.contains("<MY_SIG_INFO:7>US-4431"))
            assertTrue(adif.contains("<MY_GRIDSQUARE:4>FN20"))
        }

        @Test
        fun `encodeFile multiple log sections`() {
            val qso1 = QSO(logId = 1, callsign = "W1AW", date = "20240101", timeOn = "1234", band = "20m")
            val log1 = Log(myCallsign = "K3ABC", potaReference = "US-4431", parkName = "Prescott NF")

            val qso2 = QSO(logId = 2, callsign = "VE3XYZ", date = "20240102", timeOn = "0800", band = "40m")
            val log2 = Log(myCallsign = "K3ABC", sotaReference = "W4C/CM-001", summitName = "Mt Mitchell")

            val adif = ADIFFormatter.encodeFile(sections = listOf(log1 to listOf(qso1), log2 to listOf(qso2)))

            // Only one header
            val eohCount = adif.split("<EOH>").size - 1
            assertEquals(1, eohCount)

            // First QSO gets POTA fields
            assertTrue(adif.contains("<MY_SIG:4>POTA"))
            assertTrue(adif.contains("<MY_SIG_INFO:7>US-4431"))

            // Second QSO gets SOTA field
            assertTrue(adif.contains("<MY_SOTA_REF:10>W4C/CM-001"))

            // Both QSOs present
            assertTrue(adif.contains("<CALL:4>W1AW"))
            assertTrue(adif.contains("<CALL:6>VE3XYZ"))
        }

        @Test
        fun `encodeFile without log context omits log fields`() {
            val qso = QSO(logId = 1, callsign = "W1AW", date = "20240101", timeOn = "1234", band = "20m")
            val adif = ADIFFormatter.encodeFile(qsos = listOf(qso))
            assertFalse(adif.contains("STATION_CALLSIGN"))
            assertFalse(adif.contains("MY_SIG"))
            assertFalse(adif.contains("MY_GRIDSQUARE"))
            assertFalse(adif.contains("MY_SOTA_REF"))
        }
    }

    @Nested
    inner class `Round Trip` {

        @Test
        fun `encode then decode preserves fields`() {
            val qso = QSO(
                logId = 1,
                callsign = "VE3ABC",
                date = "20240315",
                timeOn = "1422",
                frequency = 7.030,
                band = "40m",
                mode = "CW",
                rstSent = "599",
                rstReceived = "559",
                name = "John",
                qth = "ON",
            )
            val encoded = ADIFFormatter.encode(qso)
            val decoded = ADIFFormatter.decode(encoded)
            assertEquals(1, decoded.size)
            assertEquals("VE3ABC", decoded[0]["CALL"])
            assertEquals("John", decoded[0]["NAME"])
        }
    }

    @Nested
    inner class `Program Filtering` {

        private val dualLog = Log(
            myCallsign = "W1AW",
            myGrid = "FN31",
            potaReference = "US-4431",
            sotaReference = "W4C/CM-001",
            parkName = "Prescott NF",
            summitName = "Mt Mitchell",
        )

        private fun makeDualQSO(): QSO = QSO(
            logId = 1,
            callsign = "K3ABC",
            date = "20240315",
            timeOn = "1200",
            band = "20m",
            mode = "CW",
            rstSent = "599",
            rstReceived = "579",
            sotaRef = "W4C/CM-002",
            potaRef = "US-0001",
        )

        @Test
        fun `POTA export strips SOTA fields`() {
            val adif = ADIFFormatter.encode(makeDualQSO(), dualLog, ADIFFormatter.Program.POTA)
            assertFalse(adif.contains("MY_SOTA_REF"))
            assertFalse(adif.contains("SOTA_REF"))
            assertTrue(adif.contains("MY_SIG"))
            assertTrue(adif.contains("MY_SIG_INFO"))
        }

        @Test
        fun `SOTA export strips POTA fields`() {
            val adif = ADIFFormatter.encode(makeDualQSO(), dualLog, ADIFFormatter.Program.SOTA)
            assertFalse(adif.contains("MY_SIG"))
            assertFalse(adif.contains("MY_SIG_INFO"))
            assertFalse(adif.contains("<SIG:"))
            assertFalse(adif.contains("SIG_INFO"))
            assertTrue(adif.contains("MY_SOTA_REF"))
            assertTrue(adif.contains("SOTA_REF"))
        }

        @Test
        fun `unfiltered includes all fields`() {
            val adif = ADIFFormatter.encode(makeDualQSO(), dualLog, program = null)
            assertTrue(adif.contains("MY_SIG"))
            assertTrue(adif.contains("MY_SIG_INFO"))
            assertTrue(adif.contains("MY_SOTA_REF"))
            assertTrue(adif.contains("SOTA_REF"))
            assertTrue(adif.contains("SIG_INFO"))
        }

        @Test
        fun `P2P preserved in POTA export`() {
            val qso = QSO(logId = 1, callsign = "K3ABC", date = "20240315", timeOn = "1200", band = "20m", potaRef = "US-0001")
            val log = Log(myCallsign = "W1AW", potaReference = "US-4431", parkName = "Prescott NF")
            val adif = ADIFFormatter.encode(qso, log, ADIFFormatter.Program.POTA)
            assertTrue(adif.contains("<SIG:4>POTA"))
            assertTrue(adif.contains("<SIG_INFO:7>US-0001"))
        }

        @Test
        fun `S2S preserved in SOTA export`() {
            val qso = QSO(logId = 1, callsign = "K3ABC", date = "20240315", timeOn = "1200", band = "20m", sotaRef = "W4C/CM-002")
            val log = Log(myCallsign = "W1AW", sotaReference = "W4C/CM-001", summitName = "Mt Mitchell")
            val adif = ADIFFormatter.encode(qso, log, ADIFFormatter.Program.SOTA)
            assertTrue(adif.contains("<SOTA_REF:10>W4C/CM-002"))
            assertTrue(adif.contains("<MY_SOTA_REF:10>W4C/CM-001"))
        }

        @Test
        fun `cross program refs excluded`() {
            // SOTA ref in POTA export -> no SOTA_REF
            val qsoWithSOTA = QSO(logId = 1, callsign = "K3ABC", date = "20240315", timeOn = "1200", band = "20m", sotaRef = "W4C/CM-002")
            val potaLog = Log(myCallsign = "W1AW", potaReference = "US-4431", parkName = "Prescott NF")
            val potaADIF = ADIFFormatter.encode(qsoWithSOTA, potaLog, ADIFFormatter.Program.POTA)
            assertFalse(potaADIF.contains("SOTA_REF"))

            // POTA ref in SOTA export -> no SIG/SIG_INFO
            val qsoWithPOTA = QSO(logId = 1, callsign = "K3ABC", date = "20240315", timeOn = "1200", band = "20m", potaRef = "US-0001")
            val sotaLog = Log(myCallsign = "W1AW", sotaReference = "W4C/CM-001", summitName = "Mt Mitchell")
            val sotaADIF = ADIFFormatter.encode(qsoWithPOTA, sotaLog, ADIFFormatter.Program.SOTA)
            assertFalse(sotaADIF.contains("<SIG:"))
            assertFalse(sotaADIF.contains("SIG_INFO"))
        }
    }

    @Nested
    inner class `Filenames` {

        @Test
        fun `exportAll filename format`() {
            val name = ADIFFormatter.exportAllFilename()
            assertTrue(name.startsWith("SOTALog_"))
            assertTrue(name.endsWith("Z.adi"))
            assertEquals(26, name.length)
        }

        @Test
        fun `POTA activation filename`() {
            val potaLog = Log(date = "20240315", myCallsign = "W1AW", potaReference = "US-4431", parkName = "Prescott NF")
            assertEquals(
                "W1AW@US-4431_20240315.adi",
                ADIFFormatter.activationFilename(potaLog, ADIFFormatter.Program.POTA),
            )
        }

        @Test
        fun `SOTA activation filename`() {
            val sotaLog = Log(date = "20240315", myCallsign = "W1AW", sotaReference = "W4C/CM-001", summitName = "Mt Mitchell")
            assertEquals(
                "W1AW@W4C-CM-001_20240315.adi",
                ADIFFormatter.activationFilename(sotaLog, ADIFFormatter.Program.SOTA),
            )
        }

        @Test
        fun `chaser filename without SOTA ref`() {
            val chaserLog = Log(date = "20240315", myCallsign = "W1AW")
            assertEquals(
                "W1AW_SOTA_20240315.adi",
                ADIFFormatter.activationFilename(chaserLog, ADIFFormatter.Program.SOTA),
            )
        }

        @Test
        fun `complete filename without program`() {
            val potaLog = Log(date = "20240315", myCallsign = "W1AW", potaReference = "US-4431", parkName = "Prescott NF")
            assertEquals(
                "W1AW_20240315.adi",
                ADIFFormatter.activationFilename(potaLog, program = null),
            )
        }
    }
}
