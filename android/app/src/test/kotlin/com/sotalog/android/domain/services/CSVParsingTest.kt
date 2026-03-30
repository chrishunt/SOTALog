package com.sotalog.android.domain.services

import com.sotalog.android.domain.models.POTAPark
import com.sotalog.android.domain.models.SOTASummit
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Nested
import org.junit.jupiter.api.Test

/**
 * Tests for CSV parsing logic ported from iOS POTAParkCSVTests and SOTASummitCSVTests.
 *
 * The Android implementation embeds CSV parsing in SummitParkNetworkRepository.
 * These tests exercise the same parsing logic via standalone helper functions
 * to validate correctness independent of network I/O.
 */
class CSVParsingTest {

    // -- CSV parsing helpers (mirrors SummitParkNetworkRepository private methods) --

    private fun parseCSVLine(line: String): List<String> {
        val fields = mutableListOf<String>()
        val current = StringBuilder()
        var inQuotes = false
        var i = 0

        while (i < line.length) {
            val c = line[i]
            when {
                c == '"' && !inQuotes -> inQuotes = true
                c == '"' && inQuotes -> {
                    if (i + 1 < line.length && line[i + 1] == '"') {
                        current.append('"')
                        i++
                    } else {
                        inQuotes = false
                    }
                }
                c == ',' && !inQuotes -> {
                    fields.add(current.toString())
                    current.clear()
                }
                else -> current.append(c)
            }
            i++
        }
        fields.add(current.toString())
        return fields
    }

    private fun parsePOTAParksCSV(csv: String): List<POTAPark> {
        val lines = csv.lines()
        if (lines.isEmpty()) return emptyList()

        val header = parseCSVLine(lines[0])
        val refIdx = header.indexOf("reference")
        val nameIdx = header.indexOf("name")
        val activeIdx = header.indexOf("active")
        val locationIdx = header.indexOf("locationDesc")

        if (refIdx == -1 || nameIdx == -1) return emptyList()

        return lines.drop(1).mapNotNull { line ->
            if (line.isBlank()) return@mapNotNull null
            val fields = parseCSVLine(line)
            if (fields.size <= maxOf(refIdx, nameIdx)) return@mapNotNull null

            if (activeIdx >= 0 && activeIdx < fields.size && fields[activeIdx] != "1") {
                return@mapNotNull null
            }

            val reference = fields[refIdx]
            val name = fields[nameIdx]
            val locationDesc = if (locationIdx >= 0 && locationIdx < fields.size) {
                fields[locationIdx]
            } else null

            POTAPark(
                reference = reference,
                name = name,
                referenceNormalized = POTAPark.normalize(reference),
                locationDesc = locationDesc,
            )
        }
    }

    private fun parseSOTASummitsCSV(csv: String): List<SOTASummit> {
        val lines = csv.lines()
        if (lines.size < 2) return emptyList()

        return lines.drop(1).mapNotNull { line ->
            if (line.isBlank()) return@mapNotNull null
            val fields = parseCSVLine(line)
            if (fields.size < 14) return@mapNotNull null

            val code = fields[0]
            val name = fields[3]
            val altitude = fields[4].toIntOrNull()
            val longitude = fields[8].toDoubleOrNull()
            val latitude = fields[9].toDoubleOrNull()
            val points = fields[10].toIntOrNull()
            val validFrom = fields[12].takeIf { it.isNotEmpty() }
            val validTo = fields[13].takeIf { it.isNotEmpty() }

            val slashIndex = code.indexOf('/')
            val associationCode: String?
            val regionCode: String?
            if (slashIndex >= 0) {
                associationCode = code.substring(0, slashIndex)
                val remainder = code.substring(slashIndex + 1)
                val dashIndex = remainder.indexOf('-')
                regionCode = if (dashIndex >= 0) remainder.substring(0, dashIndex) else remainder
            } else {
                associationCode = null
                regionCode = null
            }

            SOTASummit(
                code = code,
                codeNormalized = SOTASummit.normalize(code),
                name = name,
                associationCode = associationCode,
                regionCode = regionCode,
                altitude = altitude,
                points = points,
                latitude = latitude,
                longitude = longitude,
                validFrom = validFrom,
                validTo = validTo,
            )
        }
    }

    @Nested
    inner class `POTA Park CSV Parsing` {

        @Test
        fun `basic CSV`() {
            val csv = """
                reference,name,active,entityId,locationDesc
                US-0001,Acadia NP,1,291,Maine
                US-0002,Yellowstone NP,1,291,Wyoming
            """.trimIndent()
            val parks = parsePOTAParksCSV(csv)
            assertEquals(2, parks.size)
            assertEquals("US-0001", parks[0].reference)
            assertEquals("Acadia NP", parks[0].name)
            assertEquals("US0001", parks[0].referenceNormalized)
            assertEquals("Maine", parks[0].locationDesc)
            assertEquals("Wyoming", parks[1].locationDesc)
        }

        @Test
        fun `locationDesc missing column`() {
            val csv = """
                reference,name,active,entityId
                US-0001,Acadia NP,1,291
            """.trimIndent()
            val parks = parsePOTAParksCSV(csv)
            assertEquals(1, parks.size)
            assertNull(parks[0].locationDesc)
        }

        @Test
        fun `inactive parks filtered`() {
            val csv = """
                reference,name,active,entityId
                US-0001,Acadia NP,1,291
                US-9999,Closed Park,0,291
            """.trimIndent()
            val parks = parsePOTAParksCSV(csv)
            assertEquals(1, parks.size)
            assertEquals("US-0001", parks[0].reference)
        }

        @Test
        fun `quoted fields with commas`() {
            val csv = """
                reference,name,active,entityId
                US-0001,"Acadia NP, Maine",1,291
            """.trimIndent()
            val parks = parsePOTAParksCSV(csv)
            assertEquals(1, parks.size)
            assertEquals("Acadia NP, Maine", parks[0].name)
        }

        @Test
        fun `empty CSV`() {
            val parks = parsePOTAParksCSV("")
            assertEquals(0, parks.size)
        }

        @Test
        fun `header only`() {
            val csv = "reference,name,active,entityId"
            val parks = parsePOTAParksCSV(csv)
            assertEquals(0, parks.size)
        }

        @Test
        fun `wrong headers`() {
            val csv = """
                foo,bar,baz
                US-0001,Acadia NP,1
            """.trimIndent()
            val parks = parsePOTAParksCSV(csv)
            assertEquals(0, parks.size)
        }
    }

    @Nested
    inner class `SOTA Summit CSV Parsing` {

        @Test
        fun `basic CSV`() {
            val csv = """
                SummitCode,AssociationName,RegionName,SummitName,AltM,AltFt,GridRef1,GridRef2,Longitude,Latitude,Points,BonusPoints,ValidFrom,ValidTo,ActivationCount,ActivationDate,ActivationCall
                W4C/CM-001,Western Carolinas,Clingmans,Mount Mitchell,2037,6684,,,-82.265,35.765,10,0,01/04/2013,31/12/2099,100,01/01/2024,W1AW
            """.trimIndent()
            val summits = parseSOTASummitsCSV(csv)
            assertEquals(1, summits.size)
            assertEquals("W4C/CM-001", summits[0].code)
            assertEquals("W4CCM001", summits[0].codeNormalized)
            assertEquals("Mount Mitchell", summits[0].name)
            assertEquals("W4C", summits[0].associationCode)
            assertEquals("CM", summits[0].regionCode)
            assertEquals(2037, summits[0].altitude)
            assertEquals(10, summits[0].points)
            assertEquals(35.765, summits[0].latitude)
            assertEquals(-82.265, summits[0].longitude)
        }

        @Test
        fun `code splitting`() {
            val csv = """
                SummitCode,AssociationName,RegionName,SummitName,AltM,AltFt,GridRef1,GridRef2,Longitude,Latitude,Points,BonusPoints,ValidFrom,ValidTo
                G/LD-001,Lake District,LD,Helvellyn,950,3117,,,-3.0,54.5,8,0,01/03/2004,
            """.trimIndent()
            val summits = parseSOTASummitsCSV(csv)
            assertEquals(1, summits.size)
            assertEquals("G", summits[0].associationCode)
            assertEquals("LD", summits[0].regionCode)
        }

        @Test
        fun `empty CSV`() {
            val summits = parseSOTASummitsCSV("")
            assertEquals(0, summits.size)
        }

        @Test
        fun `too few fields`() {
            val csv = """
                SummitCode,Name
                W4C/CM-001,Mount Mitchell
            """.trimIndent()
            val summits = parseSOTASummitsCSV(csv)
            assertEquals(0, summits.size)
        }

        @Test
        fun `quoted fields`() {
            val csv = """
                SummitCode,AssociationName,RegionName,SummitName,AltM,AltFt,GridRef1,GridRef2,Longitude,Latitude,Points,BonusPoints,ValidFrom,ValidTo
                W4C/CM-001,Western Carolinas,CM,"Mount Mitchell, NC",2037,6684,,,-82.265,35.765,10,0,01/04/2013,31/12/2099
            """.trimIndent()
            val summits = parseSOTASummitsCSV(csv)
            assertEquals(1, summits.size)
            assertEquals("Mount Mitchell, NC", summits[0].name)
        }

        @Test
        fun `validity dates`() {
            val csv = """
                SummitCode,AssociationName,RegionName,SummitName,AltM,AltFt,GridRef1,GridRef2,Longitude,Latitude,Points,BonusPoints,ValidFrom,ValidTo
                W4C/CM-001,WC,CM,Mount Mitchell,2037,6684,,,-82.265,35.765,10,0,01/04/2013,31/12/2099
            """.trimIndent()
            val summits = parseSOTASummitsCSV(csv)
            assertEquals("01/04/2013", summits[0].validFrom)
            assertEquals("31/12/2099", summits[0].validTo)
        }
    }
}
