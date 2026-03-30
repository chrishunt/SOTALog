package com.sotalog.android.ui.activations

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.sotalog.android.data.local.database.dao.LogDao
import com.sotalog.android.data.local.database.dao.QSODao
import com.sotalog.android.domain.models.Log
import com.sotalog.android.domain.services.BandPlan
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class LogListViewModel @Inject constructor(
    private val logDao: LogDao,
    private val qsoDao: QSODao,
) : ViewModel() {

    val logs: StateFlow<List<Log>> = logDao.observeAll()
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), emptyList())

    private val _qsoCounts = MutableStateFlow<Map<Long, Int>>(emptyMap())
    val qsoCounts: StateFlow<Map<Long, Int>> = _qsoCounts.asStateFlow()

    private val _bandsByLog = MutableStateFlow<Map<Long, List<String>>>(emptyMap())
    val bandsByLog: StateFlow<Map<Long, List<String>>> = _bandsByLog.asStateFlow()

    private val _allSyncedToQRZ = MutableStateFlow<Map<Long, Boolean>>(emptyMap())
    val allSyncedToQRZ: StateFlow<Map<Long, Boolean>> = _allSyncedToQRZ.asStateFlow()

    init {
        viewModelScope.launch {
            logs.collect { logList ->
                refreshAggregates(logList)
            }
        }
    }

    private suspend fun refreshAggregates(logList: List<Log>) {
        val counts = mutableMapOf<Long, Int>()
        val bands = mutableMapOf<Long, List<String>>()
        val synced = mutableMapOf<Long, Boolean>()

        for (log in logList) {
            val logId = log.id ?: continue
            val qsos = qsoDao.getByLogId(logId)
            counts[logId] = qsos.size
            synced[logId] = qsos.isNotEmpty() && qsos.all { it.syncedToQRZ }

            val logBands = qsos.map { it.band }.distinct()
            bands[logId] = logBands.sortedBy { band ->
                BandPlan.allBands.indexOf(band).takeIf { it >= 0 } ?: Int.MAX_VALUE
            }
        }

        _qsoCounts.value = counts
        _bandsByLog.value = bands
        _allSyncedToQRZ.value = synced
    }

    fun deleteLog(id: Long) {
        viewModelScope.launch {
            val log = logDao.getById(id) ?: return@launch
            qsoDao.deleteByLogId(id)
            logDao.delete(log)
        }
    }
}
