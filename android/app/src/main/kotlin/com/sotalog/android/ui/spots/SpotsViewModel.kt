package com.sotalog.android.ui.spots

import android.content.SharedPreferences
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.sotalog.android.data.remote.api.POTASpotApi
import com.sotalog.android.data.remote.api.SOTASpotApi
import com.sotalog.android.domain.models.Spot
import com.sotalog.android.domain.services.BandPlan
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.doubleOrNull
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import javax.inject.Inject

enum class SourceFilter(val value: String) {
    ALL("all"),
    POTA("pota"),
    SOTA("sota"),
}

enum class ModeFilter(val value: String) {
    ALL("all"),
    CW("cw"),
    SSB("ssb"),
}

@HiltViewModel
class SpotsViewModel @Inject constructor(
    private val potaSpotApi: POTASpotApi,
    private val sotaSpotApi: SOTASpotApi,
    private val json: Json,
) : ViewModel() {

    private val _spots = MutableStateFlow<List<Spot>>(emptyList())
    val spots: StateFlow<List<Spot>> = _spots.asStateFlow()

    private val _sourceFilter = MutableStateFlow(SourceFilter.ALL)
    val sourceFilter: StateFlow<SourceFilter> = _sourceFilter.asStateFlow()

    private val _modeFilter = MutableStateFlow(ModeFilter.ALL)
    val modeFilter: StateFlow<ModeFilter> = _modeFilter.asStateFlow()

    private val _isLoading = MutableStateFlow(false)
    val isLoading: StateFlow<Boolean> = _isLoading.asStateFlow()

    private val _errorMessage = MutableStateFlow<String?>(null)
    val errorMessage: StateFlow<String?> = _errorMessage.asStateFlow()

    private var potaSpots: List<Spot> = emptyList()
    private var sotaSpots: List<Spot> = emptyList()
    private var autoRefreshJob: Job? = null
    private var sotaEpoch: String? = null

    data class SpotBandGroup(
        val band: String,
        val spots: List<Spot>,
    )

    val spotsByBand: StateFlow<List<SpotBandGroup>> = combine(
        _spots, _sourceFilter, _modeFilter,
    ) { spots, source, mode ->
        val consolidated = consolidateSpots(spots)
        val afterFilter = consolidated.filter { !it.isQRT && !it.isExpired() }

        val sourceFiltered = when (source) {
            SourceFilter.ALL -> afterFilter
            SourceFilter.POTA -> afterFilter.filter { it.potaReference != null }
            SourceFilter.SOTA -> afterFilter.filter { it.sotaReference != null }
        }

        val filtered = when (mode) {
            ModeFilter.ALL -> sourceFiltered
            ModeFilter.CW -> sourceFiltered.filter { it.mode == "CW" }
            ModeFilter.SSB -> sourceFiltered.filter { it.mode == "SSB" }
        }

        val grouped = mutableMapOf<String, MutableList<Spot>>()
        for (spot in filtered) {
            grouped.getOrPut(spot.band) { mutableListOf() }.add(spot)
        }

        for ((band, bandSpots) in grouped) {
            grouped[band] = bandSpots.sortedWith(
                compareBy<Spot> { it.frequency }.thenByDescending { it.timestamp },
            ).toMutableList()
        }

        BandPlan.allBands.mapNotNull { band ->
            val bandSpots = grouped[band]
            if (bandSpots.isNullOrEmpty()) null
            else SpotBandGroup(band = band, spots = bandSpots)
        }
    }.stateIn(viewModelScope, SharingStarted.Eagerly, emptyList())

    fun setSourceFilter(filter: SourceFilter) {
        _sourceFilter.value = filter
    }

    fun setModeFilter(filter: ModeFilter) {
        _modeFilter.value = filter
    }

    fun refresh() {
        viewModelScope.launch {
            _isLoading.value = true
            try {
                val potaResult = try { parsePOTASpots(potaSpotApi.getActivatorSpots().string()) } catch (_: Exception) { emptyList() }
                val sotaResult = try { parseSOTASpots(sotaSpotApi.getSpots().string()) } catch (_: Exception) { emptyList() }
                potaSpots = potaResult
                sotaSpots = sotaResult
                sotaEpoch = null // Reset epoch so next poll fetches fresh
                _spots.value = potaSpots + sotaSpots
                _errorMessage.value = null
            } catch (e: Exception) {
                _errorMessage.value = e.message
            } finally {
                _isLoading.value = false
            }
        }
    }

    fun startAutoRefresh() {
        autoRefreshJob?.cancel()
        autoRefreshJob = viewModelScope.launch {
            refresh()

            var tickCount = 0
            while (isActive) {
                delay(20_000)
                tickCount++

                try {
                    // Check SOTA epoch — only refetch if spots have changed
                    val epoch = try { sotaSpotApi.getEpoch().string().trim('"', ' ') } catch (_: Exception) { null }
                    if (epoch != null && epoch != sotaEpoch) {
                        sotaSpots = try { parseSOTASpots(sotaSpotApi.getSpots().string()) } catch (_: Exception) { sotaSpots }
                        sotaEpoch = epoch
                    }

                    // Every 3rd tick (~60s): also fetch POTA
                    if (tickCount % 3 == 0) {
                        potaSpots = try { parsePOTASpots(potaSpotApi.getActivatorSpots().string()) } catch (_: Exception) { potaSpots }
                    }

                    _spots.value = potaSpots + sotaSpots
                    _errorMessage.value = null
                } catch (e: Exception) {
                    _errorMessage.value = e.message
                }
            }
        }
    }

    fun stopAutoRefresh() {
        autoRefreshJob?.cancel()
        autoRefreshJob = null
    }

    internal fun setSpots(spots: List<Spot>) {
        _spots.value = spots
    }

    fun spotForCallsign(callsign: String): Spot? {
        val consolidated = consolidateSpots(_spots.value)
        return consolidated.firstOrNull {
            it.activatorCallsign.equals(callsign, ignoreCase = true) && !it.isExpired() && !it.isQRT
        }
    }

    private fun consolidateSpots(allSpots: List<Spot>): List<Spot> {
        val byCallsign = linkedMapOf<String, Spot>()
        val sorted = allSpots.sortedByDescending { it.timestamp }

        for (spot in sorted) {
            val key = spot.activatorCallsign.uppercase()
            val existing = byCallsign[key]
            if (existing != null) {
                var merged = existing
                if (merged.potaReference == null && spot.potaReference != null) {
                    merged = merged.copy(
                        potaReference = spot.potaReference,
                        potaReferenceName = spot.potaReferenceName,
                    )
                }
                if (merged.sotaReference == null && spot.sotaReference != null) {
                    merged = merged.copy(
                        sotaReference = spot.sotaReference,
                        sotaReferenceName = spot.sotaReferenceName,
                    )
                }
                byCallsign[key] = merged
            } else {
                byCallsign[key] = spot
            }
        }

        return byCallsign.values.toList()
    }

    // MARK: - Spot Parsing

    private fun parsePOTASpots(jsonStr: String): List<Spot> {
        val array = try { json.parseToJsonElement(jsonStr).jsonArray } catch (_: Exception) { return emptyList() }
        return array.mapNotNull { element ->
            try {
                val obj = element.jsonObject
                val callsign = obj["activator"]?.jsonPrimitive?.contentOrNull ?: return@mapNotNull null
                val freq = obj["frequency"]?.jsonPrimitive?.contentOrNull?.toDoubleOrNull()?.let { it / 1000.0 } ?: return@mapNotNull null
                val mode = obj["mode"]?.jsonPrimitive?.contentOrNull?.uppercase() ?: "CW"
                val reference = obj["reference"]?.jsonPrimitive?.contentOrNull
                val refName = obj["name"]?.jsonPrimitive?.contentOrNull
                val spotter = obj["spotter"]?.jsonPrimitive?.contentOrNull
                val comments = obj["comments"]?.jsonPrimitive?.contentOrNull
                val timestamp = obj["spotTime"]?.jsonPrimitive?.contentOrNull?.let { parseTimestamp(it) } ?: Date()

                val normalizedMode = when {
                    mode.contains("CW") -> "CW"
                    mode.contains("SSB") || mode.contains("LSB") || mode.contains("USB") || mode.contains("PHONE") -> "SSB"
                    mode.contains("FT") || mode.contains("DIGI") -> "FT8"
                    else -> mode
                }

                Spot(
                    id = "pota_${callsign}_${reference}",
                    activatorCallsign = callsign,
                    frequency = freq,
                    mode = normalizedMode,
                    potaReference = reference,
                    potaReferenceName = refName,
                    spotterCallsign = spotter,
                    comments = comments,
                    timestamp = timestamp,
                )
            } catch (_: Exception) {
                null
            }
        }
    }

    private fun parseSOTASpots(jsonStr: String): List<Spot> {
        val array = try { json.parseToJsonElement(jsonStr).jsonArray } catch (_: Exception) { return emptyList() }
        return array.mapNotNull { element ->
            try {
                val obj = element.jsonObject
                val callsign = obj["activatorCallsign"]?.jsonPrimitive?.contentOrNull ?: return@mapNotNull null
                val freq = obj["frequency"]?.jsonPrimitive?.doubleOrNull ?: return@mapNotNull null
                if (freq <= 0.0) return@mapNotNull null
                val mode = obj["mode"]?.jsonPrimitive?.contentOrNull?.uppercase() ?: "CW"
                val reference = obj["summitCode"]?.jsonPrimitive?.contentOrNull
                val refName = obj["summitName"]?.jsonPrimitive?.contentOrNull
                val spotter = obj["callsign"]?.jsonPrimitive?.contentOrNull
                val rawComments = obj["comments"]?.jsonPrimitive?.contentOrNull
                val type = obj["type"]?.jsonPrimitive?.contentOrNull
                val comments = if (type?.uppercase() == "QRT") {
                    val existing = rawComments ?: ""
                    if (existing.uppercase().contains("QRT")) existing else "QRT $existing".trim()
                } else {
                    rawComments
                }
                val spotId = obj["id"]?.jsonPrimitive?.contentOrNull ?: "0"
                val timestamp = obj["timeStamp"]?.jsonPrimitive?.contentOrNull?.let { parseTimestamp(it) } ?: Date()

                val normalizedMode = when {
                    mode.contains("CW") -> "CW"
                    mode.contains("SSB") || mode.contains("LSB") || mode.contains("USB") || mode.contains("FM") -> "SSB"
                    mode.contains("FT") || mode.contains("DATA") -> "FT8"
                    else -> mode
                }

                Spot(
                    id = "sota-${spotId}-${callsign}",
                    activatorCallsign = callsign,
                    frequency = freq,
                    mode = normalizedMode,
                    sotaReference = reference,
                    sotaReferenceName = refName,
                    spotterCallsign = spotter,
                    comments = comments,
                    timestamp = timestamp,
                )
            } catch (_: Exception) {
                null
            }
        }
    }

    private fun parseTimestamp(str: String): Date? {
        val formats = listOf(
            "yyyy-MM-dd'T'HH:mm:ss",
            "yyyy-MM-dd'T'HH:mm:ssX",
            "yyyy-MM-dd'T'HH:mm:ss.SSSX",
            "yyyy-MM-dd HH:mm:ss",
        )
        for (format in formats) {
            try {
                val sdf = SimpleDateFormat(format, Locale.US)
                sdf.timeZone = TimeZone.getTimeZone("UTC")
                return sdf.parse(str)
            } catch (_: Exception) {
                // try next format
            }
        }
        return null
    }
}
