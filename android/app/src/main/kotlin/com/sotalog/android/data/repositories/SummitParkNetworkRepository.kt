package com.sotalog.android.data.repositories

import com.sotalog.android.data.remote.api.POTALocationApi
import com.sotalog.android.domain.models.POTAPark
import com.sotalog.android.domain.models.SOTASummit
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.sync.Semaphore
import kotlinx.coroutines.sync.withPermit
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.doubleOrNull
import kotlinx.serialization.json.intOrNull
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import okhttp3.OkHttpClient
import okhttp3.Request
import javax.inject.Inject
import javax.inject.Singleton
import kotlin.math.cos
import kotlin.math.sqrt

data class ParkCoordinate(
    val reference: String,
    val latitude: Double?,
    val longitude: Double?,
)

data class POTALocation(
    val locationCode: String,
    val latitude: Double?,
    val longitude: Double?,
    val entityId: Int?,
)

@Singleton
class SummitParkNetworkRepository @Inject constructor(
    private val client: OkHttpClient,
    private val potaLocationApi: POTALocationApi,
    private val json: Json,
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

    // MARK: - POTA Park Coordinate Enrichment

    suspend fun fetchLocations(): List<POTALocation> = withContext(Dispatchers.IO) {
        try {
            val body = potaLocationApi.getLocations()
            val array = json.parseToJsonElement(body).jsonArray
            array.mapNotNull { element ->
                val obj = element.jsonObject
                val code = obj["locationDesc"]?.jsonPrimitive?.contentOrNull ?: return@mapNotNull null
                POTALocation(
                    locationCode = code,
                    latitude = obj["latitude"]?.jsonPrimitive?.doubleOrNull,
                    longitude = obj["longitude"]?.jsonPrimitive?.doubleOrNull,
                    entityId = obj["entityId"]?.jsonPrimitive?.intOrNull,
                )
            }
        } catch (_: Exception) {
            emptyList()
        }
    }

    suspend fun fetchParksInLocation(locationCode: String): List<ParkCoordinate> =
        withContext(Dispatchers.IO) {
            try {
                val body = potaLocationApi.getParksByLocation(locationCode)
                val array = json.parseToJsonElement(body).jsonArray
                array.mapNotNull { element ->
                    val obj = element.jsonObject
                    val ref = obj["reference"]?.jsonPrimitive?.contentOrNull ?: return@mapNotNull null
                    ParkCoordinate(
                        reference = ref,
                        latitude = obj["latitude"]?.jsonPrimitive?.doubleOrNull,
                        longitude = obj["longitude"]?.jsonPrimitive?.doubleOrNull,
                    )
                }
            } catch (_: Exception) {
                emptyList()
            }
        }

    fun nearestLocationCodes(
        latitude: Double,
        longitude: Double,
        locations: List<POTALocation>,
        limit: Int = 10,
    ): List<POTALocation> {
        val cosLat = cos(Math.toRadians(latitude))
        return locations
            .filter { it.latitude != null && it.longitude != null }
            .sortedBy { loc ->
                val dLat = loc.latitude!! - latitude
                val dLon = (loc.longitude!! - longitude) * cosLat
                sqrt(dLat * dLat + dLon * dLon)
            }
            .take(limit)
    }

    suspend fun enrichParks(
        refRepo: ReferenceRepository,
        userLatitude: Double?,
        userLongitude: Double?,
    ) = withContext(Dispatchers.IO) {
        val allLocations = fetchLocations()
        if (allLocations.isEmpty()) return@withContext

        // Find user's country (entityId) from nearest location
        val targetEntityId = if (userLatitude != null && userLongitude != null) {
            val nearest = nearestLocationCodes(userLatitude, userLongitude, allLocations, 1)
            nearest.firstOrNull()?.entityId ?: 291
        } else {
            291 // Default to US
        }

        // Filter to all locations in the same country
        val countryLocations = allLocations.filter { it.entityId == targetEntityId }

        // Fetch parks for each location with concurrency limit
        val semaphore = Semaphore(5)
        val allParkCoords = coroutineScope {
            countryLocations.map { loc ->
                async {
                    semaphore.withPermit {
                        fetchParksInLocation(loc.locationCode)
                    }
                }
            }.awaitAll().flatten()
        }

        // Batch-update the database
        val validCoords = allParkCoords
            .filter { it.latitude != null && it.longitude != null }
            .map { Triple(it.reference, it.latitude!!, it.longitude!!) }

        refRepo.enrichParksWithCoordinates(validCoords)
    }
}
