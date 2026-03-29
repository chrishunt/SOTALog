package com.sotalog.android.ui.logging

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.sotalog.android.data.local.database.dao.LogDao
import com.sotalog.android.data.local.database.dao.QSODao
import com.sotalog.android.domain.models.Log
import com.sotalog.android.domain.models.QSO
import com.sotalog.android.domain.services.ADIFFormatter
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import javax.inject.Inject

data class ADIFFile(
    val filename: String,
    val content: String,
)

@HiltViewModel
class ActiveLogViewModel @Inject constructor(
    savedStateHandle: SavedStateHandle,
    private val logDao: LogDao,
    private val qsoDao: QSODao,
) : ViewModel() {

    private val logId: Long = savedStateHandle["logId"]
        ?: throw IllegalArgumentException("logId is required")

    private val _log = MutableStateFlow<Log?>(null)
    val log: StateFlow<Log?> = _log.asStateFlow()

    val qsos: StateFlow<List<QSO>> = qsoDao.observeByLogId(logId)
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), emptyList())

    val qsoCount: Int get() = qsos.value.size

    init {
        viewModelScope.launch {
            logDao.observeById(logId).collect { _log.value = it }
        }
    }

    fun deleteQSO(id: Long) {
        viewModelScope.launch {
            val qso = qsoDao.getById(id) ?: return@launch
            qsoDao.delete(qso)
        }
    }

    val exportFiles: List<ADIFFile>
        get() {
            val currentLog = _log.value ?: return emptyList()
            val currentQsos = qsos.value
            val files = mutableListOf<ADIFFile>()

            if (currentLog.isPOTA) {
                files += ADIFFile(
                    filename = ADIFFormatter.activationFilename(currentLog, ADIFFormatter.Program.POTA),
                    content = ADIFFormatter.encodeFile(currentQsos, currentLog, ADIFFormatter.Program.POTA),
                )
            }
            if (currentLog.isSOTA) {
                files += ADIFFile(
                    filename = ADIFFormatter.activationFilename(currentLog, ADIFFormatter.Program.SOTA),
                    content = ADIFFormatter.encodeFile(currentQsos, currentLog, ADIFFormatter.Program.SOTA),
                )
            } else if (currentQsos.any { it.sotaRef != null }) {
                files += ADIFFile(
                    filename = ADIFFormatter.activationFilename(currentLog, ADIFFormatter.Program.SOTA),
                    content = ADIFFormatter.encodeFile(currentQsos, currentLog, ADIFFormatter.Program.SOTA),
                )
            }
            files += ADIFFile(
                filename = ADIFFormatter.activationFilename(currentLog),
                content = ADIFFormatter.encodeFile(currentQsos, currentLog),
            )
            return files
        }
}
