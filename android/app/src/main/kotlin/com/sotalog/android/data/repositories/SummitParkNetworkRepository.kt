package com.sotalog.android.data.repositories

import com.sotalog.android.domain.models.POTAPark
import com.sotalog.android.domain.models.SOTASummit
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.OkHttpClient
import okhttp3.Request
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class SummitParkNetworkRepository @Inject constructor(
    private val client: OkHttpClient,
) {

    companion object {
        private const val SOTA_SUMMITS_URL = "https://www.sotadata.org.uk/summitslist.csv"
        private const val POTA_PARKS_URL = "https://pota.app/all_parks.csv"
        private const val USER_AGENT = "SOTA Log/1.0"
    }

    suspend fun fetchSOTASummits(): List<SOTASummit> = withContext(Dispatchers.IO) {
        val request = Request.Builder()
            .url(SOTA_SUMMITS_URL)
            .header("User-Agent", USER_AGENT)
            .get()
            .build()

        val response = client.newCall(request).execute()
        val body = response.body?.string() ?: return@withContext emptyList()

        val lines = body.lines()
        if (lines.size < 2) return@withContext emptyList()

        // Skip header row
        lines.drop(1).mapNotNull { line ->
            parseSOTASummitLine(line)
        }
    }

    suspend fun fetchPOTAParks(): List<POTAPark> = withContext(Dispatchers.IO) {
        val request = Request.Builder()
            .url(POTA_PARKS_URL)
            .header("User-Agent", USER_AGENT)
            .get()
            .build()

        val response = client.newCall(request).execute()
        val body = response.body?.string() ?: return@withContext emptyList()

        val lines = body.lines()
        if (lines.size < 2) return@withContext emptyList()

        // Parse header to find column indices
        val header = parseCSVLine(lines[0])
        val refIdx = header.indexOf("reference")
        val nameIdx = header.indexOf("name")
        val activeIdx = header.indexOf("active")
        val locationIdx = header.indexOf("locationDesc")

        if (refIdx == -1 || nameIdx == -1) return@withContext emptyList()

        lines.drop(1).mapNotNull { line ->
            if (line.isBlank()) return@mapNotNull null
            val fields = parseCSVLine(line)
            if (fields.size <= maxOf(refIdx, nameIdx)) return@mapNotNull null

            // Filter active parks only
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

    private fun parseSOTASummitLine(line: String): SOTASummit? {
        if (line.isBlank()) return null
        val fields = parseCSVLine(line)
        if (fields.size < 14) return null

        val code = fields[0]
        val name = fields[3]
        val altitude = fields[4].toIntOrNull()
        val longitude = fields[8].toDoubleOrNull()
        val latitude = fields[9].toDoubleOrNull()
        val points = fields[10].toIntOrNull()
        val validFrom = fields[12].takeIf { it.isNotEmpty() }
        val validTo = fields[13].takeIf { it.isNotEmpty() }

        // Split code for association and region: "W7W/KG-001" -> association="W7W", region="KG"
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

        return SOTASummit(
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

    /**
     * Parses a CSV line respecting quoted fields.
     * Handles commas inside double quotes and escaped double quotes ("").
     */
    private fun parseCSVLine(line: String): List<String> {
        val fields = mutableListOf<String>()
        val current = StringBuilder()
        var inQuotes = false
        var i = 0

        while (i < line.length) {
            val c = line[i]
            when {
                c == '"' && !inQuotes -> {
                    inQuotes = true
                }
                c == '"' && inQuotes -> {
                    // Check for escaped quote ""
                    if (i + 1 < line.length && line[i + 1] == '"') {
                        current.append('"')
                        i++ // skip next quote
                    } else {
                        inQuotes = false
                    }
                }
                c == ',' && !inQuotes -> {
                    fields.add(current.toString())
                    current.clear()
                }
                else -> {
                    current.append(c)
                }
            }
            i++
        }
        fields.add(current.toString())
        return fields
    }
}
