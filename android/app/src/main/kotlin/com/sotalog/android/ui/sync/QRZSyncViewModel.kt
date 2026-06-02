package com.sotalog.android.ui.sync

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.sotalog.android.data.local.database.dao.LogDao
import com.sotalog.android.data.local.database.dao.QSODao
import com.sotalog.android.data.local.database.dao.ReferenceDao
import com.sotalog.android.data.local.preferences.CredentialStore
import com.sotalog.android.data.local.preferences.LocationService
import com.sotalog.android.data.remote.api.POTAParkApi
import com.sotalog.android.data.remote.api.QRZLogbookApi
import com.sotalog.android.data.remote.api.QRZLookupApi
import com.sotalog.android.data.remote.api.SOTASummitApi
import com.sotalog.android.data.repositories.ReferenceRepository
import com.sotalog.android.data.repositories.SummitParkNetworkRepository
import com.sotalog.android.domain.models.Log
import com.sotalog.android.domain.models.POTAPark
import com.sotalog.android.domain.models.QSO
import com.sotalog.android.domain.models.ReferenceMetadata
import com.sotalog.android.domain.models.SOTASummit
import com.sotalog.android.domain.services.ADIFFormatter
import com.sotalog.android.domain.services.SyncImporter
import com.sotalog.android.ui.logging.ADIFFile
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import java.util.Date
import javax.inject.Inject

sealed class SyncStatus {
    data object Idle : SyncStatus()
    data object Synced : SyncStatus()
    data class Uploading(val done: Int, val total: Int) : SyncStatus()
    data object PreparingReferences : SyncStatus()
    data class Downloading(val count: Int) : SyncStatus()
    data object Importing : SyncStatus()
    data class Error(val message: String) : SyncStatus()
}

sealed class CredentialTestResult {
    data object Success : CredentialTestResult()
    data class Failure(val message: String) : CredentialTestResult()
}

@HiltViewModel
class QRZSyncViewModel @Inject constructor(
    private val logDao: LogDao,
    private val qsoDao: QSODao,
    private val referenceDao: ReferenceDao,
    private val credentialStore: CredentialStore,
    private val qrzLogbookApi: QRZLogbookApi,
    private val qrzLookupApi: QRZLookupApi,
    private val potaParkApi: POTAParkApi,
    private val sotaSummitApi: SOTASummitApi,
    private val summitParkNetworkRepo: SummitParkNetworkRepository,
    private val referenceRepo: ReferenceRepository,
    private val locationService: LocationService,
) : ViewModel() {

    private val _hasAPIKey = MutableStateFlow(false)
    val hasAPIKey: StateFlow<Boolean> = _hasAPIKey.asStateFlow()

    private val _hasCredentials = MutableStateFlow(false)
    val hasCredentials: StateFlow<Boolean> = _hasCredentials.asStateFlow()

    private val _username = MutableStateFlow<String?>(null)
    val username: StateFlow<String?> = _username.asStateFlow()

    private val _unsyncedCount = MutableStateFlow(0)
    val unsyncedCount: StateFlow<Int> = _unsyncedCount.asStateFlow()

    private val _syncStatus = MutableStateFlow<SyncStatus>(SyncStatus.Idle)
    val syncStatus: StateFlow<SyncStatus> = _syncStatus.asStateFlow()

    private val _lastSyncDate = MutableStateFlow<Date?>(null)
    val lastSyncDate: StateFlow<Date?> = _lastSyncDate.asStateFlow()

    private val _adifExport = MutableStateFlow(ADIFFile("", ""))
    val adifExport: StateFlow<ADIFFile> = _adifExport.asStateFlow()

    private val _parkCount = MutableStateFlow(0)
    val parkCount: StateFlow<Int> = _parkCount.asStateFlow()

    private val _summitCount = MutableStateFlow(0)
    val summitCount: StateFlow<Int> = _summitCount.asStateFlow()

    private val _isParkLoading = MutableStateFlow(false)
    val isParkLoading: StateFlow<Boolean> = _isParkLoading.asStateFlow()

    private val _isSummitLoading = MutableStateFlow(false)
    val isSummitLoading: StateFlow<Boolean> = _isSummitLoading.asStateFlow()

    // Credential testing
    private val _isTestingCredentials = MutableStateFlow(false)
    val isTestingCredentials: StateFlow<Boolean> = _isTestingCredentials.asStateFlow()

    private val _apiKeyTestResult = MutableStateFlow<CredentialTestResult?>(null)
    val apiKeyTestResult: StateFlow<CredentialTestResult?> = _apiKeyTestResult.asStateFlow()

    private val _xmlLoginTestResult = MutableStateFlow<CredentialTestResult?>(null)
    val xmlLoginTestResult: StateFlow<CredentialTestResult?> = _xmlLoginTestResult.asStateFlow()

    val isBusy: Boolean
        get() = when (_syncStatus.value) {
            is SyncStatus.Idle, is SyncStatus.Synced, is SyncStatus.Error -> false
            else -> true
        }

    val isAllSynced: Boolean
        get() = when (_syncStatus.value) {
            is SyncStatus.Synced -> true
            is SyncStatus.Idle -> _unsyncedCount.value == 0
            else -> false
        }

    val apiKeyTestPassed: Boolean
        get() = _apiKeyTestResult.value is CredentialTestResult.Success

    val callsignTestPassed: Boolean
        get() = _xmlLoginTestResult.value is CredentialTestResult.Success

    fun loadState() {
        viewModelScope.launch {
            _hasAPIKey.value = credentialStore.load(CredentialStore.QRZ_API_KEY) != null
            _hasCredentials.value = credentialStore.load(CredentialStore.QRZ_USERNAME) != null
            _username.value = credentialStore.load(CredentialStore.QRZ_USERNAME)

            val logs = logDao.getAll()
            var unsynced = 0
            for (log in logs) {
                val logId = log.id ?: continue
                unsynced += qsoDao.getUnsyncedByLogId(logId).size
            }
            _unsyncedCount.value = unsynced

            if (unsynced == 0) {
                _syncStatus.value = SyncStatus.Synced
            }

            refreshADIF()
            loadCounts()
        }
    }

    fun loadCounts() {
        viewModelScope.launch {
            _parkCount.value = referenceDao.getParkCount()
            _summitCount.value = referenceDao.getSummitCount()
        }
    }

    private suspend fun refreshADIF() {
        val logs = logDao.getAll()
        val sections = mutableListOf<Pair<Log, List<QSO>>>()
        val unattachedQSOs = mutableListOf<QSO>()

        for (log in logs) {
            val logId = log.id ?: continue
            val qsos = qsoDao.getByLogId(logId)
            if (qsos.isNotEmpty()) {
                sections.add(log to qsos)
            }
        }

        _adifExport.value = ADIFFile(
            filename = ADIFFormatter.exportAllFilename(),
            content = ADIFFormatter.encodeFile(sections, unattachedQSOs),
        )
    }

    fun saveAPIKey(apiKey: String) {
        if (apiKey.isEmpty()) return
        viewModelScope.launch {
            _isTestingCredentials.value = true
            _apiKeyTestResult.value = null
            testAPIKey(apiKey)
            _isTestingCredentials.value = false

            if (apiKeyTestPassed) {
                credentialStore.save(CredentialStore.QRZ_API_KEY, apiKey)
                _hasAPIKey.value = true
            } else {
                credentialStore.delete(CredentialStore.QRZ_API_KEY)
                _hasAPIKey.value = false
            }
        }
    }

    fun saveCallsignCredentials(username: String, password: String) {
        if (username.isEmpty() || password.isEmpty()) return
        viewModelScope.launch {
            _isTestingCredentials.value = true
            _xmlLoginTestResult.value = null
            testXMLLogin(username, password)
            _isTestingCredentials.value = false

            if (callsignTestPassed) {
                credentialStore.save(CredentialStore.QRZ_USERNAME, username)
                credentialStore.save(CredentialStore.QRZ_PASSWORD, password)
                _hasCredentials.value = true
                _username.value = username
            } else {
                credentialStore.delete(CredentialStore.QRZ_USERNAME)
                credentialStore.delete(CredentialStore.QRZ_PASSWORD)
                _hasCredentials.value = false
                _username.value = null
            }
        }
    }

    private suspend fun testAPIKey(apiKey: String) {
        try {
            val response = qrzLogbookApi.execute(apiKey = apiKey, action = "STATUS")
            if (response.contains("RESULT=OK", ignoreCase = true) || !response.contains("invalid", ignoreCase = true)) {
                _apiKeyTestResult.value = CredentialTestResult.Success
            } else {
                _apiKeyTestResult.value = CredentialTestResult.Failure("Invalid API key")
            }
        } catch (e: Exception) {
            _apiKeyTestResult.value = CredentialTestResult.Failure(e.message ?: "Unknown error")
        }
    }

    private suspend fun testXMLLogin(username: String, password: String) {
        try {
            val response = qrzLookupApi.getSession(username, password)
            val sessionKey = extractXmlTag(response, "Key")
            if (sessionKey != null) {
                credentialStore.save(CredentialStore.QRZ_SESSION_KEY, sessionKey)
                _xmlLoginTestResult.value = CredentialTestResult.Success
            } else {
                val error = extractXmlTag(response, "Error") ?: "Login failed"
                _xmlLoginTestResult.value = CredentialTestResult.Failure(error)
            }
        } catch (e: Exception) {
            _xmlLoginTestResult.value = CredentialTestResult.Failure(e.message ?: "Unknown error")
        }
    }

    fun clearAPIKey() {
        credentialStore.delete(CredentialStore.QRZ_API_KEY)
        _hasAPIKey.value = false
        _syncStatus.value = SyncStatus.Idle
        _apiKeyTestResult.value = null
    }

    fun clearXMLCredentials() {
        credentialStore.delete(CredentialStore.QRZ_USERNAME)
        credentialStore.delete(CredentialStore.QRZ_PASSWORD)
        credentialStore.delete(CredentialStore.QRZ_SESSION_KEY)
        _hasCredentials.value = false
        _username.value = null
        _xmlLoginTestResult.value = null
    }

    fun removeCredentials() {
        clearAPIKey()
        clearXMLCredentials()
    }

    // MARK: - Upload

    fun uploadAll() {
        viewModelScope.launch {
            val apiKey = credentialStore.load(CredentialStore.QRZ_API_KEY) ?: return@launch

            val logs = logDao.getAll()
            val logMap = logs.mapNotNull { log -> log.id?.let { it to log } }.toMap()

            val unsynced = mutableListOf<QSO>()
            for (log in logs) {
                val logId = log.id ?: continue
                unsynced.addAll(qsoDao.getUnsyncedByLogId(logId))
            }

            if (unsynced.isEmpty()) return@launch

            _syncStatus.value = SyncStatus.Uploading(0, unsynced.size)

            try {
                var done = 0
                for (qso in unsynced) {
                    val log = qso.logId?.let { logMap[it] }
                    val adif = ADIFFormatter.encode(qso, log)

                    val response = qrzLogbookApi.execute(
                        apiKey = apiKey,
                        action = "INSERT",
                        adif = adif,
                    )

                    val qrzLogId = extractLogId(response)
                    if (qrzLogId != null && qso.id != null) {
                        qsoDao.update(qso.copy(syncedToQRZ = true, qrzLogId = qrzLogId))
                    }

                    done++
                    _syncStatus.value = SyncStatus.Uploading(done, unsynced.size)
                }

                _unsyncedCount.value = 0
                _syncStatus.value = SyncStatus.Synced
                refreshADIF()
            } catch (e: Exception) {
                _syncStatus.value = SyncStatus.Error(e.message ?: "Upload failed")
            }
        }
    }

    // MARK: - Refresh from QRZ

    fun refreshFromQRZ() {
        viewModelScope.launch {
            val apiKey = credentialStore.load(CredentialStore.QRZ_API_KEY) ?: return@launch

            // 0. Pre-check: ensure reference data is available
            try {
                ensureReferencesLoaded()
            } catch (e: Exception) {
                _syncStatus.value = SyncStatus.Error("Failed to fetch reference data: ${e.message}")
                return@launch
            }

            // 1. Download phase
            _syncStatus.value = SyncStatus.Downloading(0)
            val allRecords = mutableListOf<Map<String, String>>()

            try {
                var afterLogId: Long = 0
                var previousMaxLogId: Long = -1

                for (page in 0 until 200) {
                    val response = qrzLogbookApi.execute(
                        apiKey = apiKey,
                        action = "FETCH",
                        option = "BETWEEN:$afterLogId:999999999999",
                    )

                    val adifPortion = extractAdifFromResponse(response)
                    val records = ADIFFormatter.decode(adifPortion)
                    allRecords.addAll(records)

                    _syncStatus.value = SyncStatus.Downloading(allRecords.size)

                    if (records.size < 250) break

                    val pageMaxLogId = records.mapNotNull { it["APP_QRZLOG_LOGID"]?.toLongOrNull() }.maxOrNull() ?: 0
                    if (pageMaxLogId == 0L || pageMaxLogId == previousMaxLogId) break
                    previousMaxLogId = pageMaxLogId
                    afterLogId = pageMaxLogId + 1
                }
            } catch (e: Exception) {
                _syncStatus.value = SyncStatus.Error(e.message ?: "Download failed")
                return@launch
            }

            // 2. Group phase
            val validPotaRefs = loadValidPotaRefs()
            val validSotaCodes = loadValidSotaCodes()

            val fallbackCallsign = credentialStore.load(CredentialStore.QRZ_USERNAME)?.uppercase()
            val grouped = SyncImporter.groupByActivation(
                records = allRecords,
                fallbackCallsign = fallbackCallsign,
                validPotaRefs = validPotaRefs,
                validSotaCodes = validSotaCodes,
            )

            // 3. Import phase
            _syncStatus.value = SyncStatus.Importing
            try {
                fullRefreshImport(grouped)
                // The worked count is derived from the qso table, so a full refresh
                // needs no count rebuild.
                _lastSyncDate.value = Date()

                var unsynced = 0
                for (log in logDao.getAll()) {
                    val logId = log.id ?: continue
                    unsynced += qsoDao.getUnsyncedByLogId(logId).size
                }
                _unsyncedCount.value = unsynced
                _syncStatus.value = if (unsynced == 0) SyncStatus.Synced else SyncStatus.Idle
                refreshADIF()
            } catch (e: Exception) {
                _syncStatus.value = SyncStatus.Error(e.message ?: "Import failed")
            }
        }
    }

    private suspend fun fullRefreshImport(grouped: SyncImporter.GroupingResult) {
        // Create or reuse logs for each activation
        for ((key, records) in grouped.activations) {
            val existingLogs = logDao.getAll().filter { log ->
                log.date == key.date &&
                    log.potaReference == key.potaReference &&
                    log.sotaReference == key.sotaReference
            }

            val logId: Long
            if (existingLogs.isNotEmpty()) {
                logId = existingLogs.first().id!!
                // Delete existing QSOs for this log (full refresh)
                qsoDao.deleteByLogId(logId)
            } else {
                logId = logDao.insert(
                    Log(
                        createdAt = Date(),
                        date = key.date,
                        myCallsign = key.stationCallsign,
                        myGrid = key.myGrid,
                        potaReference = key.potaReference,
                        sotaReference = key.sotaReference,
                    ),
                )
            }

            for (record in records) {
                val qso = record.qso.copy(
                    id = null,
                    logId = logId,
                    syncedToQRZ = true,
                    qrzLogId = record.rawFields["APP_QRZLOG_LOGID"]?.toLongOrNull(),
                )
                try {
                    qsoDao.insert(qso)
                } catch (_: Exception) {
                    // Skip duplicates
                }
            }
        }

        // Import unattached QSOs
        for (record in grouped.unattached) {
            val qso = record.qso.copy(
                id = null,
                logId = null,
                syncedToQRZ = true,
                qrzLogId = record.rawFields["APP_QRZLOG_LOGID"]?.toLongOrNull(),
            )
            try {
                qsoDao.insert(qso)
            } catch (_: Exception) {
                // Skip duplicates
            }
        }
    }


    private suspend fun loadValidPotaRefs(): Map<String, String> {
        val parks = referenceDao.searchParksByNormalizedPrefix("", 100_000)
        return parks.mapNotNull { park ->
            park.referenceNormalized?.let { it to park.reference }
        }.toMap()
    }

    private suspend fun loadValidSotaCodes(): Map<String, String> {
        val summits = referenceDao.searchSummitsByNormalizedPrefix("", 100_000)
        return summits.mapNotNull { summit ->
            summit.codeNormalized?.let { it to summit.code }
        }.toMap()
    }

    // MARK: - Reference Data

    private suspend fun ensureReferencesLoaded() {
        val potaMeta = referenceDao.getMetadata("potaParks")
        val sotaMeta = referenceDao.getMetadata("sotaSummits")

        val needsPota = (potaMeta?.recordCount ?: 0) == 0
        val needsSota = (sotaMeta?.recordCount ?: 0) == 0

        if (!needsPota && !needsSota) return

        _syncStatus.value = SyncStatus.PreparingReferences

        if (needsPota) {
            downloadParks()
        }

        if (needsSota) {
            downloadSummits()
        }
    }

    fun downloadParks() {
        viewModelScope.launch {
            _isParkLoading.value = true
            _syncStatus.value = SyncStatus.PreparingReferences
            try {
                val parks = summitParkNetworkRepo.fetchPOTAParks()
                referenceDao.deleteAllParks()
                referenceRepo.importParks(parks)

                // Enrich with coordinates from POTA location API
                try {
                    summitParkNetworkRepo.enrichParks(
                        refRepo = referenceRepo,
                        userLatitude = locationService.currentLatitude.value,
                        userLongitude = locationService.currentLongitude.value,
                    )
                } catch (_: Exception) {
                    // Partial enrichment is fine — keep whatever parks were imported
                }

                referenceDao.upsertMetadata(
                    ReferenceMetadata(
                        key = "potaParks",
                        lastRefreshed = Date(),
                        recordCount = referenceDao.getParkCount(),
                    ),
                )
                _parkCount.value = referenceDao.getParkCount()
                _syncStatus.value = SyncStatus.Idle
            } catch (e: Exception) {
                _syncStatus.value = SyncStatus.Error("Failed to download parks: ${e.message}")
            } finally {
                _isParkLoading.value = false
            }
        }
    }

    fun downloadSummits() {
        viewModelScope.launch {
            _isSummitLoading.value = true
            _syncStatus.value = SyncStatus.PreparingReferences
            try {
                val summits = summitParkNetworkRepo.fetchSOTASummits()
                referenceDao.deleteAllSummits()
                referenceRepo.importSummits(summits)
                referenceDao.upsertMetadata(
                    ReferenceMetadata(
                        key = "sotaSummits",
                        lastRefreshed = Date(),
                        recordCount = referenceDao.getSummitCount(),
                    ),
                )
                _summitCount.value = referenceDao.getSummitCount()
                _syncStatus.value = SyncStatus.Idle
            } catch (e: Exception) {
                _syncStatus.value = SyncStatus.Error("Failed to download summits: ${e.message}")
            } finally {
                _isSummitLoading.value = false
            }
        }
    }

    fun exportADIF(): ADIFFile = _adifExport.value

    // MARK: - XML Helpers

    private fun extractXmlTag(xml: String, tag: String): String? {
        val pattern = "<$tag>(.*?)</$tag>"
        val match = Regex(pattern, RegexOption.DOT_MATCHES_ALL).find(xml) ?: return null
        return match.groupValues[1].trim().ifEmpty { null }
    }

    private fun extractLogId(response: String): Long? {
        // QRZ logbook response contains LOGID=<number>
        val match = Regex("LOGID=(\\d+)").find(response)
        return match?.groupValues?.get(1)?.toLongOrNull()
    }

    private fun extractAdifFromResponse(response: String): String {
        // QRZ logbook FETCH response contains ADIF data
        val adifStart = response.indexOf("ADIF=")
        if (adifStart >= 0) {
            return response.substring(adifStart + 5)
        }
        return response
    }
}
