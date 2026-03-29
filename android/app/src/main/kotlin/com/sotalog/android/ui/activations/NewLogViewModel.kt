package com.sotalog.android.ui.activations

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.sotalog.android.data.local.database.dao.LogDao
import com.sotalog.android.data.local.database.dao.ReferenceDao
import com.sotalog.android.data.local.preferences.CredentialStore
import com.sotalog.android.data.local.preferences.LocationService
import com.sotalog.android.domain.models.Log
import com.sotalog.android.domain.models.POTAPark
import com.sotalog.android.domain.models.SOTASummit
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import javax.inject.Inject
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.sin
import kotlin.math.sqrt

@HiltViewModel
class NewLogViewModel @Inject constructor(
    private val logDao: LogDao,
    private val referenceDao: ReferenceDao,
    private val credentialStore: CredentialStore,
    private val locationService: LocationService,
) : ViewModel() {

    companion object {
        private const val SUGGESTION_LIMIT = 5
        private const val NEARBY_DEGREES = 0.5 // ~35 miles bounding box
    }

    private val _myCallsign = MutableStateFlow("")
    val myCallsign: StateFlow<String> = _myCallsign.asStateFlow()

    private val _date = MutableStateFlow(todayADIF())
    val date: StateFlow<String> = _date.asStateFlow()

    val myGrid: StateFlow<String?> = locationService.currentGrid

    private val _potaReference = MutableStateFlow("")
    val potaReference: StateFlow<String> = _potaReference.asStateFlow()

    private val _sotaReference = MutableStateFlow("")
    val sotaReference: StateFlow<String> = _sotaReference.asStateFlow()

    private val _parkName = MutableStateFlow<String?>(null)
    val parkName: StateFlow<String?> = _parkName.asStateFlow()

    private val _summitName = MutableStateFlow<String?>(null)
    val summitName: StateFlow<String?> = _summitName.asStateFlow()

    private val _parkSearchResults = MutableStateFlow<List<POTAPark>>(emptyList())
    val parkSearchResults: StateFlow<List<POTAPark>> = _parkSearchResults.asStateFlow()

    private val _summitSearchResults = MutableStateFlow<List<SOTASummit>>(emptyList())
    val summitSearchResults: StateFlow<List<SOTASummit>> = _summitSearchResults.asStateFlow()

    private val _nearbyParks = MutableStateFlow<List<POTAPark>>(emptyList())
    val nearbyParks: StateFlow<List<POTAPark>> = _nearbyParks.asStateFlow()

    private val _nearbySummits = MutableStateFlow<List<SOTASummit>>(emptyList())
    val nearbySummits: StateFlow<List<SOTASummit>> = _nearbySummits.asStateFlow()

    private val _hasPOTAData = MutableStateFlow(false)
    val hasPOTAData: StateFlow<Boolean> = _hasPOTAData.asStateFlow()

    private val _hasSOTAData = MutableStateFlow(false)
    val hasSOTAData: StateFlow<Boolean> = _hasSOTAData.asStateFlow()

    private var searchJob: Job? = null

    init {
        loadSavedCallsign()
    }

    private fun loadSavedCallsign() {
        credentialStore.load(CredentialStore.MY_CALLSIGN)?.let {
            _myCallsign.value = it
        }
    }

    fun onCallsignChanged(callsign: String) {
        _myCallsign.value = callsign
    }

    fun onPotaReferenceChanged(ref: String) {
        _potaReference.value = ref
        searchParks()
    }

    fun onSotaReferenceChanged(ref: String) {
        _sotaReference.value = ref
        searchSummits()
    }

    fun checkReferenceData() {
        viewModelScope.launch {
            val potaMeta = referenceDao.getMetadata("potaParks")
            _hasPOTAData.value = (potaMeta?.recordCount ?: 0) > 0
            val sotaMeta = referenceDao.getMetadata("sotaSummits")
            _hasSOTAData.value = (sotaMeta?.recordCount ?: 0) > 0
        }
    }

    fun requestLocation() {
        locationService.requestLocation()
        viewModelScope.launch {
            delay(2_000)
            loadNearbyReferences()
        }
    }

    private suspend fun loadNearbyReferences() {
        val lat = locationService.currentLatitude.value ?: return
        val lon = locationService.currentLongitude.value ?: return

        val parks = referenceDao.getParksInBounds(
            minLat = lat - NEARBY_DEGREES,
            maxLat = lat + NEARBY_DEGREES,
            minLon = lon - NEARBY_DEGREES,
            maxLon = lon + NEARBY_DEGREES,
        ).sortedBy { park ->
            val pLat = park.latitude ?: return@sortedBy Double.MAX_VALUE
            val pLon = park.longitude ?: return@sortedBy Double.MAX_VALUE
            approxDistanceKm(lat, lon, pLat, pLon)
        }.take(SUGGESTION_LIMIT)

        val summits = referenceDao.getSummitsInBounds(
            minLat = lat - NEARBY_DEGREES,
            maxLat = lat + NEARBY_DEGREES,
            minLon = lon - NEARBY_DEGREES,
            maxLon = lon + NEARBY_DEGREES,
        ).sortedBy { summit ->
            val sLat = summit.latitude ?: return@sortedBy Double.MAX_VALUE
            val sLon = summit.longitude ?: return@sortedBy Double.MAX_VALUE
            approxDistanceKm(lat, lon, sLat, sLon)
        }.take(SUGGESTION_LIMIT)

        _nearbyParks.value = parks
        _nearbySummits.value = summits
    }

    fun distanceMiles(toLatitude: Double?, toLongitude: Double?): Double? {
        val userLat = locationService.currentLatitude.value ?: return null
        val userLon = locationService.currentLongitude.value ?: return null
        val lat = toLatitude ?: return null
        val lon = toLongitude ?: return null
        val km = approxDistanceKm(userLat, userLon, lat, lon)
        return km * 0.621371
    }

    fun selectPark(park: POTAPark) {
        _potaReference.value = park.reference
        _parkName.value = park.name
        _parkSearchResults.value = emptyList()
    }

    fun selectSummit(summit: SOTASummit) {
        _sotaReference.value = summit.code
        _summitName.value = summit.name
        _summitSearchResults.value = emptyList()
    }

    suspend fun createLog(): Long {
        val call = _myCallsign.value.uppercase().filter { it.isLetterOrDigit() || it == '/' }

        credentialStore.save(CredentialStore.MY_CALLSIGN, call)

        val grid = myGrid.value
        val potaRef = _potaReference.value.ifEmpty { null }?.uppercase()
        val sotaRef = _sotaReference.value.ifEmpty { null }?.uppercase()

        val log = Log(
            createdAt = Date(),
            date = _date.value,
            myCallsign = call,
            myGrid = grid,
            potaReference = potaRef,
            sotaReference = sotaRef,
            parkName = _parkName.value,
            summitName = _summitName.value,
        )

        return logDao.insert(log)
    }

    private fun searchParks() {
        searchJob?.cancel()
        val query = _potaReference.value
        if (query.length < 2) {
            _parkSearchResults.value = emptyList()
            _parkName.value = null
            return
        }
        searchJob = viewModelScope.launch {
            delay(300)
            val normalized = POTAPark.normalize(query)
            val results = referenceDao.searchParksByNormalizedPrefix(normalized, SUGGESTION_LIMIT)
            _parkSearchResults.value = results
            val exact = results.firstOrNull { it.referenceNormalized == normalized }
            if (exact != null) {
                _parkName.value = exact.name
            }
        }
    }

    private fun searchSummits() {
        searchJob?.cancel()
        val query = _sotaReference.value
        if (query.length < 2) {
            _summitSearchResults.value = emptyList()
            _summitName.value = null
            return
        }
        searchJob = viewModelScope.launch {
            delay(300)
            val normalized = SOTASummit.normalize(query)
            val results = referenceDao.searchSummitsByNormalizedPrefix(normalized, SUGGESTION_LIMIT)
            _summitSearchResults.value = results
            val exact = results.firstOrNull { it.code == query.uppercase() }
            if (exact != null) {
                _summitName.value = exact.name
            }
        }
    }

    private fun todayADIF(): String {
        val formatter = SimpleDateFormat("yyyyMMdd", Locale.US).apply {
            timeZone = TimeZone.getTimeZone("UTC")
        }
        return formatter.format(Date())
    }

    private fun approxDistanceKm(lat1: Double, lon1: Double, lat2: Double, lon2: Double): Double {
        val r = 6371.0
        val dLat = Math.toRadians(lat2 - lat1)
        val dLon = Math.toRadians(lon2 - lon1)
        val a = sin(dLat / 2) * sin(dLat / 2) +
            cos(Math.toRadians(lat1)) * cos(Math.toRadians(lat2)) *
            sin(dLon / 2) * sin(dLon / 2)
        return r * 2 * atan2(sqrt(a), sqrt(1 - a))
    }
}
