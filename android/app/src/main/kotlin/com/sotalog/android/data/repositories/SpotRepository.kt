package com.sotalog.android.data.repositories

import com.sotalog.android.domain.models.Spot
import com.sotalog.android.domain.services.BandPlan
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.async
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.double
import kotlinx.serialization.json.doubleOrNull
import kotlinx.serialization.json.int
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import okhttp3.OkHttpClient
import okhttp3.Request
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class SpotRepository @Inject constructor(
    private val client: OkHttpClient,
    private val json: Json,
) {

    companion object {
        private const val SOTA_SPOTS_URL = "https://api-db2.sota.org.uk/api/spots/-1/all/cw,ssb"
        private const val POTA_SPOTS_URL = "https://api.pota.app/spot/activator"
        private const val USER_AGENT = "SOTA Log/1.0"
    }

    suspend fun fetchSOTASpots(): List<Spot> = withContext(Dispatchers.IO) {
        val request = Request.Builder()
            .url(SOTA_SPOTS_URL)
            .header("User-Agent", USER_AGENT)
            .get()
            .build()

        val response = client.newCall(request).execute()
        val body = response.body?.string() ?: return@withContext emptyList()

        try {
            val array = json.parseToJsonElement(body).jsonArray
            array.mapNotNull { element -> parseSOTASpot(element.jsonObject) }
        } catch (e: Exception) {
            emptyList()
        }
    }

    suspend fun fetchPOTASpots(): List<Spot> = withContext(Dispatchers.IO) {
        val request = Request.Builder()
            .url(POTA_SPOTS_URL)
            .header("User-Agent", USER_AGENT)
            .get()
            .build()

        val response = client.newCall(request).execute()
        val body = response.body?.string() ?: return@withContext emptyList()

        try {
            val array = json.parseToJsonElement(body).jsonArray
            array.mapNotNull { element -> parsePOTASpot(element.jsonObject) }
        } catch (e: Exception) {
            emptyList()
        }
    }

    suspend fun fetchAllSpots(): List<Spot> = withContext(Dispatchers.IO) {
        val sotaDeferred = async { runCatching { fetchSOTASpots() }.getOrDefault(emptyList()) }
        val potaDeferred = async { runCatching { fetchPOTASpots() }.getOrDefault(emptyList()) }

        val sotaSpots = sotaDeferred.await()
        val potaSpots = potaDeferred.await()
        sotaSpots + potaSpots
    }

    private fun parseSOTASpot(obj: JsonObject): Spot? {
        val id = obj["id"]?.jsonPrimitive?.int ?: return null
        val activatorCallsign = obj["activatorCallsign"]?.jsonPrimitive?.contentOrNull ?: return null
        val summitCode = obj["summitCode"]?.jsonPrimitive?.contentOrNull
        val summitName = obj["summitName"]?.jsonPrimitive?.contentOrNull
        val frequency = obj["frequency"]?.jsonPrimitive?.doubleOrNull ?: return null
        val modeStr = obj["mode"]?.jsonPrimitive?.contentOrNull
        val spotter = obj["callsign"]?.jsonPrimitive?.contentOrNull
        val comments = obj["comments"]?.jsonPrimitive?.contentOrNull
        val timeStamp = obj["timeStamp"]?.jsonPrimitive?.contentOrNull
        val type = obj["type"]?.jsonPrimitive?.contentOrNull

        val mode = modeStr?.takeIf { it.isNotEmpty() }
            ?: BandPlan.mode(frequency)
            ?: "CW"

        val finalComments = if (type?.equals("QRT", ignoreCase = true) == true) {
            "QRT" + (comments?.let { " $it" } ?: "")
        } else {
            comments
        }

        val timestamp = parseISO8601(timeStamp) ?: Date()

        return Spot(
            id = "sota-$id-$activatorCallsign",
            activatorCallsign = activatorCallsign,
            frequency = frequency,
            mode = mode.uppercase(),
            sotaReference = summitCode,
            sotaReferenceName = summitName,
            spotterCallsign = spotter,
            comments = finalComments,
            timestamp = timestamp,
        )
    }

    private fun parsePOTASpot(obj: JsonObject): Spot? {
        val spotId = obj["spotId"]?.jsonPrimitive?.int ?: return null
        val activator = obj["activator"]?.jsonPrimitive?.contentOrNull ?: return null
        val freqStr = obj["frequency"]?.jsonPrimitive?.contentOrNull ?: return null
        val modeStr = obj["mode"]?.jsonPrimitive?.contentOrNull ?: return null
        val reference = obj["reference"]?.jsonPrimitive?.contentOrNull
        val name = obj["name"]?.jsonPrimitive?.contentOrNull
        val spotter = obj["spotter"]?.jsonPrimitive?.contentOrNull
        val comments = obj["comments"]?.jsonPrimitive?.contentOrNull
        val spotTime = obj["spotTime"]?.jsonPrimitive?.contentOrNull

        // Filter: only CW and SSB modes
        val modeUpper = modeStr.uppercase()
        if (modeUpper != "CW" && modeUpper != "SSB") return null

        // Frequency may be in kHz (>1000) or MHz
        var frequency = freqStr.toDoubleOrNull() ?: return null
        if (frequency > 1000.0) {
            frequency /= 1000.0
        }

        val timestamp = parseISO8601(spotTime) ?: Date()

        return Spot(
            id = "pota-$spotId-$activator",
            activatorCallsign = activator,
            frequency = frequency,
            mode = modeUpper,
            potaReference = reference,
            potaReferenceName = name,
            spotterCallsign = spotter,
            comments = comments,
            timestamp = timestamp,
        )
    }

    private fun parseISO8601(dateStr: String?): Date? {
        if (dateStr == null) return null
        val formats = listOf(
            "yyyy-MM-dd'T'HH:mm:ss",
            "yyyy-MM-dd'T'HH:mm:ssX",
            "yyyy-MM-dd'T'HH:mm:ss.SSSX",
            "yyyy-MM-dd'T'HH:mm:ss.SSS",
            "yyyy-MM-dd HH:mm:ss",
        )
        for (fmt in formats) {
            try {
                val sdf = SimpleDateFormat(fmt, Locale.US).apply {
                    timeZone = TimeZone.getTimeZone("UTC")
                }
                return sdf.parse(dateStr)
            } catch (_: Exception) {
                // Try next format
            }
        }
        return null
    }
}
