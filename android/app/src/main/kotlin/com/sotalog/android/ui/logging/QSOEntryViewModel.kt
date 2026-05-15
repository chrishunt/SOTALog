package com.sotalog.android.ui.logging

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.sotalog.android.data.local.database.dao.CallsignHistoryDao
import com.sotalog.android.data.local.database.dao.LogDao
import com.sotalog.android.data.local.database.dao.QSODao
import com.sotalog.android.data.local.database.dao.ReferenceDao
import com.sotalog.android.data.local.preferences.CredentialStore
import com.sotalog.android.data.remote.api.QRZLookupApi
import com.sotalog.android.domain.models.CallsignHistory
import com.sotalog.android.domain.models.Log
import com.sotalog.android.domain.models.POTAPark
import com.sotalog.android.domain.models.QSO
import com.sotalog.android.domain.models.QRZCallsignResult
import com.sotalog.android.domain.models.SOTASummit
import com.sotalog.android.domain.models.Spot
import com.sotalog.android.domain.services.BandPlan
import com.sotalog.android.domain.services.CallsignPrefixResolver
import com.sotalog.android.domain.services.OmniFieldParser
import com.sotalog.android.domain.services.TokenKind
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import java.text.SimpleDateFormat
import java.util.Collections
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import java.util.concurrent.ConcurrentHashMap
import javax.inject.Inject

@HiltViewModel
class QSOEntryViewModel @Inject constructor(
    savedStateHandle: SavedStateHandle,
    private val logDao: LogDao,
    private val qsoDao: QSODao,
    private val callsignHistoryDao: CallsignHistoryDao,
    private val referenceDao: ReferenceDao,
    private val credentialStore: CredentialStore,
    private val qrzLookupApi: QRZLookupApi,
) : ViewModel() {

    private val logId: Long = savedStateHandle["logId"]
        ?: throw IllegalArgumentException("logId is required")

    private var log: Log? = null

    // Omnifield input
    private val _entryText = MutableStateFlow("")
    val entryText: StateFlow<String> = _entryText.asStateFlow()

    // Field state
    private val _rstSent = MutableStateFlow("599")
    val rstSent: StateFlow<String> = _rstSent.asStateFlow()

    private val _rstReceived = MutableStateFlow("599")
    val rstReceived: StateFlow<String> = _rstReceived.asStateFlow()

    private val _frequencyText = MutableStateFlow("14.060")
    val frequencyText: StateFlow<String> = _frequencyText.asStateFlow()

    private val _mode = MutableStateFlow("CW")
    val mode: StateFlow<String> = _mode.asStateFlow()

    private val _name = MutableStateFlow("")
    val name: StateFlow<String> = _name.asStateFlow()

    private val _qth = MutableStateFlow("")
    val qth: StateFlow<String> = _qth.asStateFlow()

    private val _potaRefInput = MutableStateFlow("")
    val potaRefInput: StateFlow<String> = _potaRefInput.asStateFlow()

    private val _potaRefFormatted = MutableStateFlow<String?>(null)
    val potaRefFormatted: StateFlow<String?> = _potaRefFormatted.asStateFlow()

    private val _potaRefName = MutableStateFlow<String?>(null)
    val potaRefName: StateFlow<String?> = _potaRefName.asStateFlow()

    private val _potaRefValid = MutableStateFlow(false)
    val potaRefValid: StateFlow<Boolean> = _potaRefValid.asStateFlow()

    private val _sotaRefInput = MutableStateFlow("")
    val sotaRefInput: StateFlow<String> = _sotaRefInput.asStateFlow()

    private val _sotaRefFormatted = MutableStateFlow<String?>(null)
    val sotaRefFormatted: StateFlow<String?> = _sotaRefFormatted.asStateFlow()

    private val _sotaRefValid = MutableStateFlow(false)
    val sotaRefValid: StateFlow<Boolean> = _sotaRefValid.asStateFlow()

    private val _notes = MutableStateFlow("")
    val notes: StateFlow<String> = _notes.asStateFlow()

    private val _gridInput = MutableStateFlow("")
    val gridInput: StateFlow<String> = _gridInput.asStateFlow()

    // Kind of the last unconfirmed (no trailing space) omnifield token from the prior parse.
    // Used to clear a previously previewed field when the operator types past it into a new kind.
    @Volatile private var previewKind: TokenKind? = null

    // Tracks which fields were manually edited (accessed from multiple coroutines)
    private val manualOverrides: MutableSet<String> = Collections.newSetFromMap(ConcurrentHashMap())

    // Editing state
    private val _editingQSO = MutableStateFlow<QSO?>(null)
    val editingQSO: StateFlow<QSO?> = _editingQSO.asStateFlow()

    val isEditing: Boolean get() = _editingQSO.value != null

    // Lookup state
    private val _timesWorked = MutableStateFlow(0)
    val timesWorked: StateFlow<Int> = _timesWorked.asStateFlow()

    private val _workedToday = MutableStateFlow(0)
    val workedToday: StateFlow<Int> = _workedToday.asStateFlow()

    private val _isDupe = MutableStateFlow(false)
    val isDupe: StateFlow<Boolean> = _isDupe.asStateFlow()

    private val _lastSavedQSO = MutableStateFlow<QSO?>(null)
    val lastSavedQSO: StateFlow<QSO?> = _lastSavedQSO.asStateFlow()

    private val _saveCount = MutableStateFlow(0)
    val saveCount: StateFlow<Int> = _saveCount.asStateFlow()

    // CW Keyer
    private val _keyerSendCount = MutableStateFlow(0)
    val keyerSendCount: StateFlow<Int> = _keyerSendCount.asStateFlow()

    // Spot lookup callback
    var spotLookup: ((String) -> Spot?)? = null

    private var lookupJob: Job? = null

    // Hidden auto-populated grid from QRZ/callsign history. Saved on the QSO and exported to ADIF,
    // but never shown as a chip — the chip only appears when the operator types a grid.
    @Volatile private var grid: String? = null

    val parsedCallsign: String
        get() {
            val first = _entryText.value.split(" ", limit = 2).firstOrNull() ?: ""
            return first.uppercase().filter { it.isLetterOrDigit() || it == '/' }
        }

    val defaultRST: String
        get() = if (_mode.value == "CW") "599" else "59"

    init {
        viewModelScope.launch {
            log = logDao.getById(logId)
        }
    }

    // MARK: - Entry text

    fun onEntryTextChanged(text: String) {
        _entryText.value = text
        parseEntry()
        callsignChanged()
    }

    fun onRstSentChanged(value: String) {
        _rstSent.value = value
        markManualOverride("rstSent")
    }

    fun onRstReceivedChanged(value: String) {
        _rstReceived.value = value
        markManualOverride("rstReceived")
    }

    fun onFrequencyChanged(value: String) {
        _frequencyText.value = value
        markManualOverride("frequency")
        frequencyChanged()
    }

    fun onNameChanged(value: String) {
        _name.value = value
        markManualOverride("name")
    }

    fun onQthChanged(value: String) {
        _qth.value = value
        markManualOverride("qth")
    }

    fun onPotaRefChanged(value: String) {
        _potaRefInput.value = value
        markManualOverride("potaRef")
        validatePOTARef()
    }

    fun onSotaRefChanged(value: String) {
        _sotaRefInput.value = value
        markManualOverride("sotaRef")
        validateSOTARef()
    }

    fun onGridChanged(value: String) {
        _gridInput.value = value
    }

    fun onNotesChanged(value: String) {
        _notes.value = value
    }

    // MARK: - Mode

    fun toggleMode() {
        _mode.value = when (_mode.value) {
            "CW" -> "SSB"
            "SSB" -> "FM"
            else -> "CW"
        }
        markManualOverride("mode")
        updateRSTForMode()
        recheckDupe()
    }

    private fun updateModeFromFrequency() {
        if ("mode" in manualOverrides) return
        val freq = _frequencyText.value.toDoubleOrNull() ?: return
        val derived = BandPlan.mode(freq) ?: return
        if (_mode.value != derived) {
            _mode.value = derived
            updateRSTForMode()
        }
    }

    private fun updateRSTForMode() {
        if ("rstSent" !in manualOverrides) {
            _rstSent.value = defaultRST
        }
        if ("rstReceived" !in manualOverrides) {
            _rstReceived.value = defaultRST
        }
    }

    private fun expandRST(raw: String): String {
        if (raw.length == 2 && _mode.value == "CW") return raw + "9"
        return raw
    }

    // MARK: - Omnifield Parsing

    private fun parseEntry() {
        val parsed = OmniFieldParser.parse(_entryText.value)

        // Clear stale previews when the last unconfirmed token flips kind.
        val endsWithSpace = _entryText.value.endsWith(" ")
        val currentLastKind = if (endsWithSpace) null else parsed.tokens.lastOrNull()?.kind
        val prev = previewKind
        if (prev != null && prev != currentLastKind) {
            clearPreview(prev)
        }
        previewKind = currentLastKind

        parsed.mode?.let { parsedMode ->
            _mode.value = parsedMode
            markManualOverride("mode")
            updateRSTForMode()
        }

        parsed.rstSent?.let { rst ->
            _rstSent.value = expandRST(rst)
            markManualOverride("rstSent")
        }
        parsed.rstReceived?.let { rst ->
            _rstReceived.value = expandRST(rst)
            markManualOverride("rstReceived")
        }
        parsed.frequency?.let { freq ->
            _frequencyText.value = freq
            markManualOverride("frequency")
            updateModeFromFrequency()
        }
        parsed.qth?.let { q ->
            _qth.value = q
            markManualOverride("qth")
        }
        parsed.gridSquare?.let { g ->
            _gridInput.value = g
        }
        parsed.potaRef?.let { ref ->
            _potaRefInput.value = ref
            markManualOverride("potaRef")
            validatePOTARef()
        }
        parsed.sotaRef?.let { ref ->
            _sotaRefInput.value = ref
            markManualOverride("sotaRef")
            validateSOTARef()
        }

        consumeTokens(parsed)
    }

    /**
     * Clears a previously-previewed field when the operator types past it into a different kind.
     * Only applies to fields that show a live preview in the metadata strip. Also drops the
     * corresponding manualOverride so a subsequent auto-populate isn't suppressed.
     */
    private fun clearPreview(kind: TokenKind) {
        when (kind) {
            TokenKind.QTH -> {
                _qth.value = ""
                manualOverrides.remove("qth")
            }
            TokenKind.GRID_SQUARE -> _gridInput.value = ""
            TokenKind.POTA_REF -> {
                _potaRefInput.value = ""
                _potaRefFormatted.value = null
                _potaRefName.value = null
                _potaRefValid.value = false
                manualOverrides.remove("potaRef")
            }
            TokenKind.SOTA_REF -> {
                _sotaRefInput.value = ""
                _sotaRefFormatted.value = null
                _sotaRefValid.value = false
                manualOverrides.remove("sotaRef")
            }
            else -> {}
        }
    }

    fun hasManualOverride(field: String): Boolean = field in manualOverrides

    private fun consumeTokens(parsed: com.sotalog.android.domain.services.ParsedEntry) {
        val tokens = parsed.tokens
        if (tokens.size <= 1) return

        val entryText = _entryText.value
        val endsWithSpace = entryText.endsWith(" ")

        val kept = mutableListOf<String>()
        for ((index, classified) in tokens.withIndex()) {
            val isLast = index == tokens.size - 1
            val isConfirmed = !isLast || endsWithSpace

            when (classified.kind) {
                TokenKind.CALLSIGN, TokenKind.RST, TokenKind.UNRECOGNIZED -> {
                    kept.add(classified.text)
                }
                TokenKind.FREQUENCY, TokenKind.MODE, TokenKind.QTH,
                TokenKind.GRID_SQUARE, TokenKind.POTA_REF, TokenKind.SOTA_REF -> {
                    if (!isConfirmed) kept.add(classified.text)
                }
            }
        }

        var rebuilt = kept.joinToString(" ")
        if (endsWithSpace) rebuilt += " "

        if (rebuilt != _entryText.value) {
            _entryText.value = rebuilt
        }
    }

    private fun markManualOverride(field: String) {
        manualOverrides.add(field)
    }

    // MARK: - Callsign Changed (Auto-populate cascade)

    private fun callsignChanged() {
        lookupJob?.cancel()
        val call = parsedCallsign

        if (call.isEmpty()) {
            clearAllFields()
            return
        }

        if (call.length < 3) {
            clearLookupFields()
            return
        }

        lookupJob = viewModelScope.launch {
            delay(300) // debounce

            // All sources fire in parallel
            val localJob = launch { resolveLocal(call) }
            val qrzJob = launch { resolveQRZ(call) }
            val spotJob = launch { resolveSpotData(call) }
            val todayJob = launch { resolveWorkedToday(call) }
            val dupeJob = launch { resolveDupe(call) }

            localJob.join()
            qrzJob.join()
            spotJob.join()
            todayJob.join()
            dupeJob.join()
        }
    }

    // MARK: - Lookup Sources

    private suspend fun resolveLocal(call: String) {
        val history = callsignHistoryDao.getByCallsign(call.uppercase())
        if (history != null) {
            _timesWorked.value = history.timesWorked
            if (!history.name.isNullOrEmpty() && _name.value.isEmpty()) _name.value = history.name
            if (!history.qth.isNullOrEmpty() && _qth.value.isEmpty()) _qth.value = history.qth
            if (!history.grid.isNullOrEmpty() && grid == null) grid = history.grid
        } else {
            _timesWorked.value = 0
        }

        // Lowest authority: prefix resolver
        val resolved = CallsignPrefixResolver.resolve(call)
        if (resolved != null && _qth.value.isEmpty()) {
            _qth.value = resolved
        }
    }

    private suspend fun resolveQRZ(call: String) {
        val sessionKey = credentialStore.load(CredentialStore.QRZ_SESSION_KEY) ?: return
        val result = try {
            parseQRZLookupResponse(qrzLookupApi.lookup(sessionKey, call))
        } catch (_: Exception) {
            return
        } ?: return

        val normalizedQTH = when {
            !result.state.isNullOrEmpty() -> result.state
            !result.country.isNullOrEmpty() -> CallsignPrefixResolver.abbreviate(result.country)
            else -> null
        }

        result.name?.takeIf { it.isNotEmpty() && "name" !in manualOverrides }?.let { _name.value = it }
        normalizedQTH?.takeIf { it.isNotEmpty() && "qth" !in manualOverrides }?.let { _qth.value = it }
        result.grid?.takeIf { it.isNotEmpty() }?.let { grid = it }
    }

    private suspend fun resolveSpotData(call: String) {
        val spot = spotLookup?.invoke(call) ?: return
        if (spot.potaReference != null && "potaRef" !in manualOverrides && _potaRefInput.value.isEmpty()) {
            _potaRefInput.value = POTAPark.normalize(spot.potaReference)
            validatePOTARef()
        }
        if (spot.sotaReference != null && "sotaRef" !in manualOverrides && _sotaRefInput.value.isEmpty()) {
            _sotaRefInput.value = SOTASummit.normalize(spot.sotaReference)
            validateSOTARef()
        }
    }

    private suspend fun resolveDupe(call: String) {
        val freq = _frequencyText.value.toDoubleOrNull()
        val band = freq?.let { BandPlan.band(it) }
        if (band == null) {
            _isDupe.value = false
            return
        }
        val qsos = qsoDao.getByLogId(logId)
        val editingId = _editingQSO.value?.id
        val dupe = qsos.any { qso ->
            qso.callsign.equals(call, ignoreCase = true) &&
                qso.band == band &&
                qso.mode == _mode.value &&
                qso.id != editingId
        }
        _isDupe.value = dupe
    }

    private suspend fun resolveWorkedToday(call: String) {
        val today = todayADIF()
        val allQsos = qsoDao.getByLogId(logId)
        val count = allQsos.count { qso ->
            qso.callsign.equals(call, ignoreCase = true) && qso.date == today
        }
        _workedToday.value = count
    }

    fun frequencyChanged() {
        updateModeFromFrequency()
        recheckDupe()
    }

    private fun recheckDupe() {
        val call = parsedCallsign
        if (call.length < 3) return
        viewModelScope.launch { resolveDupe(call) }
    }

    // MARK: - POTA P2P Validation

    fun validatePOTARef() {
        val normalized = _potaRefInput.value.uppercase().filter { it.isLetterOrDigit() }
        if (normalized.length < 3) {
            _potaRefValid.value = false
            _potaRefFormatted.value = null
            _potaRefName.value = null
            return
        }
        viewModelScope.launch {
            val parks = referenceDao.searchParksByNormalizedPrefix(normalized, 1)
            val park = parks.firstOrNull { it.referenceNormalized == normalized }
            if (park != null) {
                _potaRefValid.value = true
                _potaRefFormatted.value = park.reference
                _potaRefName.value = park.name
            } else {
                _potaRefValid.value = false
                _potaRefFormatted.value = null
                _potaRefName.value = null
            }
        }
    }

    // MARK: - SOTA S2S Validation

    fun validateSOTARef() {
        val normalized = _sotaRefInput.value.uppercase().filter { it.isLetterOrDigit() }
        if (normalized.length < 4) {
            _sotaRefValid.value = false
            _sotaRefFormatted.value = null
            return
        }
        viewModelScope.launch {
            val summits = referenceDao.searchSummitsByNormalizedPrefix(normalized, 1)
            val summit = summits.firstOrNull { it.codeNormalized == normalized }
            if (summit != null) {
                _sotaRefValid.value = true
                _sotaRefFormatted.value = summit.code
            } else {
                _sotaRefValid.value = false
                _sotaRefFormatted.value = null
            }
        }
    }

    // MARK: - Editing

    fun loadForEditing(qso: QSO) {
        if (qso.syncedToQRZ) return
        _editingQSO.value = qso
        _entryText.value = qso.callsign
        _rstSent.value = qso.rstSent
        _rstReceived.value = qso.rstReceived
        _mode.value = qso.mode
        qso.frequency?.let { _frequencyText.value = "%.3f".format(it) }
        _name.value = qso.name ?: ""
        _qth.value = qso.qth ?: ""
        qso.potaRef?.let { ref ->
            _potaRefInput.value = POTAPark.normalize(ref)
            validatePOTARef()
        }
        qso.sotaRef?.let { ref ->
            _sotaRefInput.value = SOTASummit.normalize(ref)
            validateSOTARef()
        }
        // Restore saved grid into the chip so it's visible and editable during edit.
        // The chip is the source of truth in edit mode — the hidden `grid` only carries
        // auto-populated lookups (resolveLocal/resolveQRZ).
        _gridInput.value = qso.grid ?: ""
    }

    fun cancelEditing() {
        _editingQSO.value = null
        clearFieldsForNextQSO()
    }

    // MARK: - Save QSO

    fun saveQSO() {
        val callsign = parsedCallsign
        if (callsign.isEmpty()) return

        val frequency = _frequencyText.value.toDoubleOrNull()
        val band = frequency?.let { BandPlan.band(it) } ?: "20m"
        // Operator-typed grid wins. New QSO with empty input falls back to the hidden
        // auto-populated value; an empty chip during edit means the operator cleared it.
        // Invalid typed input persists as null — ADIF GRIDSQUARE has a defined format and shouldn't carry junk.
        val gridValue = _gridInput.value
        val resolvedGrid: String? = when {
            gridValue.isNotEmpty() -> OmniFieldParser.parseGridSquare(gridValue)
            _editingQSO.value != null -> null
            else -> grid
        }

        viewModelScope.launch {
            val qso: QSO
            val editing = _editingQSO.value
            if (editing != null) {
                qso = QSO(
                    id = editing.id,
                    logId = logId,
                    callsign = callsign.uppercase(),
                    date = editing.date,
                    timeOn = editing.timeOn,
                    frequency = frequency,
                    band = band,
                    mode = _mode.value,
                    rstSent = _rstSent.value,
                    rstReceived = _rstReceived.value,
                    name = _name.value.ifEmpty { null },
                    qth = _qth.value.ifEmpty { null },
                    grid = resolvedGrid,
                    sotaRef = if (_sotaRefValid.value) _sotaRefFormatted.value else null,
                    potaRef = if (_potaRefValid.value) _potaRefFormatted.value else null,
                    qrzLogId = editing.qrzLogId,
                    syncedToQRZ = editing.syncedToQRZ,
                )
                qsoDao.update(qso)
                _lastSavedQSO.value = qso
            } else {
                val now = Date()
                qso = QSO(
                    logId = logId,
                    callsign = callsign.uppercase(),
                    date = formatADIFDate(now),
                    timeOn = formatADIFTime(now),
                    frequency = frequency,
                    band = band,
                    mode = _mode.value,
                    rstSent = _rstSent.value,
                    rstReceived = _rstReceived.value,
                    name = _name.value.ifEmpty { null },
                    qth = _qth.value.ifEmpty { null },
                    grid = resolvedGrid,
                    sotaRef = if (_sotaRefValid.value) _sotaRefFormatted.value else null,
                    potaRef = if (_potaRefValid.value) _potaRefFormatted.value else null,
                )
                val newId = qsoDao.insert(qso)
                _lastSavedQSO.value = qso.copy(id = newId)
            }

            // Update callsign history
            try {
                val existing = callsignHistoryDao.getByCallsign(qso.callsign)
                callsignHistoryDao.upsert(
                    CallsignHistory(
                        callsign = qso.callsign,
                        name = qso.name ?: existing?.name,
                        qth = qso.qth ?: existing?.qth,
                        grid = resolvedGrid ?: existing?.grid,
                        lastWorked = now(),
                        timesWorked = (existing?.timesWorked ?: 0) + 1,
                    ),
                )
            } catch (_: Exception) {
                // Non-critical
            }

            _editingQSO.value = null
            _saveCount.value += 1
            clearFieldsForNextQSO()
        }
    }

    // MARK: - Spot pre-fill

    fun prefillFromSpot(spot: Spot) {
        clearFieldsForNextQSO()
        _entryText.value = spot.activatorCallsign.uppercase()
        _frequencyText.value = "%.3f".format(spot.frequency)
        _mode.value = spot.mode
        _rstSent.value = defaultRST
        _rstReceived.value = defaultRST

        spot.potaReference?.let { ref ->
            _potaRefInput.value = POTAPark.normalize(ref)
            validatePOTARef()
        }
        spot.sotaReference?.let { ref ->
            _sotaRefInput.value = SOTASummit.normalize(ref)
            validateSOTARef()
        }
        callsignChanged()
    }

    // MARK: - CW Keyer

    fun expandTemplate(template: String): String {
        val currentLog = log ?: return template
        val activity = when {
            currentLog.sotaReference != null -> "SOTA"
            currentLog.potaReference != null -> "POTA"
            else -> ""
        }

        var text = template
        text = text.replace("{myCall}", currentLog.myCallsign)
        text = text.replace("{call}", parsedCallsign)
        text = text.replace("{rst}", rstForKeyer())
        text = text.replace("{mySOTA}", stripDashesForCW(currentLog.sotaReference ?: ""))
        text = text.replace("{myPOTA}", stripDashesForCW(currentLog.potaReference ?: ""))
        text = text.replace("{activity}", activity)
        text = text.replace(Regex("\\s+"), " ").trim()
        return text
    }

    fun previewExpandTemplate(template: String): String {
        val currentLog = log ?: return template
        val activity = when {
            currentLog.sotaReference != null -> "SOTA"
            currentLog.potaReference != null -> "POTA"
            else -> ""
        }

        val substitutions = listOf(
            "{myCall}" to currentLog.myCallsign,
            "{call}" to parsedCallsign,
            "{rst}" to rstForKeyer(),
            "{mySOTA}" to stripDashesForCW(currentLog.sotaReference ?: ""),
            "{myPOTA}" to stripDashesForCW(currentLog.potaReference ?: ""),
            "{activity}" to activity,
        )

        var text = template
        for ((placeholder, value) in substitutions) {
            if (value.isNotEmpty()) {
                text = text.replace(placeholder, value)
            }
        }
        text = text.replace(Regex("\\s+"), " ").trim()
        return text
    }

    private fun rstForKeyer(): String =
        _rstSent.value.replace("9", "N")

    private fun stripDashesForCW(ref: String): String =
        ref.replace("-", "")

    // MARK: - Private helpers

    private fun clearAllFields() {
        _rstSent.value = defaultRST
        _rstReceived.value = defaultRST
        _name.value = ""
        _qth.value = ""
        _potaRefInput.value = ""
        _potaRefFormatted.value = null
        _potaRefName.value = null
        _potaRefValid.value = false
        _sotaRefInput.value = ""
        _sotaRefFormatted.value = null
        _sotaRefValid.value = false
        _gridInput.value = ""
        _notes.value = ""
        _timesWorked.value = 0
        _workedToday.value = 0
        _isDupe.value = false
        grid = null
        previewKind = null
        manualOverrides.clear()
    }

    private fun clearLookupFields() {
        _timesWorked.value = 0
        _workedToday.value = 0
        _isDupe.value = false
        _name.value = ""
        _qth.value = ""
        grid = null
    }

    private fun clearFieldsForNextQSO() {
        _entryText.value = ""
        _rstSent.value = defaultRST
        _rstReceived.value = defaultRST
        _name.value = ""
        _qth.value = ""
        _potaRefInput.value = ""
        _potaRefFormatted.value = null
        _potaRefName.value = null
        _potaRefValid.value = false
        _sotaRefInput.value = ""
        _sotaRefFormatted.value = null
        _sotaRefValid.value = false
        _gridInput.value = ""
        _notes.value = ""
        _timesWorked.value = 0
        _workedToday.value = 0
        _isDupe.value = false
        grid = null
        previewKind = null
        manualOverrides.clear()
        // frequency and mode persist between QSOs
    }

    private fun now(): Date = Date()

    private fun todayADIF(): String = formatADIFDate(Date())

    private fun formatADIFDate(date: Date): String {
        val fmt = SimpleDateFormat("yyyyMMdd", Locale.US)
        fmt.timeZone = TimeZone.getTimeZone("UTC")
        return fmt.format(date)
    }

    private fun formatADIFTime(date: Date): String {
        val fmt = SimpleDateFormat("HHmm", Locale.US)
        fmt.timeZone = TimeZone.getTimeZone("UTC")
        return fmt.format(date)
    }

    private fun parseQRZLookupResponse(xml: String): QRZCallsignResult? {
        // Simple XML extraction for QRZ callsign lookup response
        fun extractTag(tag: String): String? {
            val pattern = "<$tag>(.*?)</$tag>"
            val match = Regex(pattern, RegexOption.DOT_MATCHES_ALL).find(xml) ?: return null
            return match.groupValues[1].trim().ifEmpty { null }
        }

        val callsign = extractTag("call") ?: return null
        return QRZCallsignResult(
            callsign = callsign,
            firstName = extractTag("fname"),
            nickname = extractTag("nickname"),
            lastName = extractTag("name"),
            city = extractTag("addr2"),
            state = extractTag("state"),
            country = extractTag("country"),
            grid = extractTag("grid"),
            county = extractTag("county"),
        )
    }
}
