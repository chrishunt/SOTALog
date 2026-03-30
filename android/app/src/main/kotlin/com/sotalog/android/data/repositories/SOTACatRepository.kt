package com.sotalog.android.data.repositories

import com.sotalog.android.di.SOTACatClient
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.plus
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import java.net.URLEncoder
import java.util.concurrent.TimeUnit
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class SOTACatRepository @Inject constructor(
    @SOTACatClient private val client: OkHttpClient,
) {

    companion object {
        private const val PRIMARY_URL = "http://192.168.4.1"
        private const val FALLBACK_URL = "http://sotacat.local"
        private const val USER_AGENT = "SOTA Log/1.0"
        private const val POLL_INTERVAL_MS = 1_000L
        private const val PROBE_INTERVAL_MS = 5_000L
        private const val MAX_CONSECUTIVE_FAILURES = 5
    }

    private val _isConnected = MutableStateFlow(false)
    val isConnected: StateFlow<Boolean> = _isConnected.asStateFlow()

    private val _radioFrequency = MutableStateFlow<Double?>(null)
    val radioFrequency: StateFlow<Double?> = _radioFrequency.asStateFlow()

    private val _radioMode = MutableStateFlow<String?>(null)
    val radioMode: StateFlow<String?> = _radioMode.asStateFlow()

    private val _keyerActive = MutableStateFlow(false)
    val keyerActive: StateFlow<Boolean> = _keyerActive.asStateFlow()

    private val monitorScope = kotlinx.coroutines.CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private var monitorJob: Job? = null
    private var activeBaseUrl: String = PRIMARY_URL
    private var consecutiveFailures = 0

    fun startMonitoring() {
        if (monitorJob?.isActive == true) return

        monitorJob = monitorScope.launch {
            while (isActive) {
                if (_isConnected.value) {
                    pollRadioState()
                    delay(POLL_INTERVAL_MS)
                } else {
                    probeConnection()
                    delay(PROBE_INTERVAL_MS)
                }
            }
        }
    }

    fun stopMonitoring() {
        monitorJob?.cancel()
        monitorJob = null
        _isConnected.value = false
        _radioFrequency.value = null
        _radioMode.value = null
    }

    suspend fun tune(frequencyMHz: Double, mode: String = "CW") = withContext(Dispatchers.IO) {
        val hz = (frequencyMHz * 1_000_000).toLong()
        putRequest("$activeBaseUrl/api/v1/frequency?frequency=$hz")
        putRequest("$activeBaseUrl/api/v1/mode?mode=$mode")
    }

    suspend fun setMode(mode: String) = withContext(Dispatchers.IO) {
        putRequest("$activeBaseUrl/api/v1/mode?mode=$mode")
    }

    suspend fun sendKeyer(message: String): Boolean = withContext(Dispatchers.IO) {
        try {
            val encoded = URLEncoder.encode(message, "UTF-8")
            val keyerClient = client.newBuilder()
                .readTimeout(30, TimeUnit.SECONDS)
                .writeTimeout(30, TimeUnit.SECONDS)
                .build()

            _keyerActive.value = true
            val request = Request.Builder()
                .url("$activeBaseUrl/api/v1/keyer?message=$encoded")
                .header("User-Agent", USER_AGENT)
                .put("".toRequestBody("text/plain".toMediaType()))
                .build()

            keyerClient.newCall(request).execute().use { it.isSuccessful }
        } catch (e: Exception) {
            false
        } finally {
            _keyerActive.value = false
        }
    }

    private fun probeConnection() {
        // Try primary URL first, then fallback
        for (url in listOf(PRIMARY_URL, FALLBACK_URL)) {
            try {
                val request = Request.Builder()
                    .url("$url/api/v1/version")
                    .header("User-Agent", USER_AGENT)
                    .get()
                    .build()

                val success = client.newCall(request).execute().use { it.isSuccessful }
                if (success) {
                    activeBaseUrl = url
                    _isConnected.value = true
                    consecutiveFailures = 0
                    return
                }
            } catch (_: Exception) {
                // Try next URL
            }
        }
    }

    private fun pollRadioState() {
        try {
            // Poll frequency
            val freqRequest = Request.Builder()
                .url("$activeBaseUrl/api/v1/frequency")
                .header("User-Agent", USER_AGENT)
                .get()
                .build()

            client.newCall(freqRequest).execute().use { freqResponse ->
                if (freqResponse.isSuccessful) {
                    val hzStr = freqResponse.body?.string()?.trim()
                    val hz = hzStr?.toDoubleOrNull()
                    if (hz != null) {
                        _radioFrequency.value = hz / 1_000_000.0
                    }
                    consecutiveFailures = 0
                } else {
                    consecutiveFailures++
                }
            }

            // Poll mode
            val modeRequest = Request.Builder()
                .url("$activeBaseUrl/api/v1/mode")
                .header("User-Agent", USER_AGENT)
                .get()
                .build()

            client.newCall(modeRequest).execute().use { modeResponse ->
                if (modeResponse.isSuccessful) {
                    val rawMode = modeResponse.body?.string()?.trim()?.uppercase()
                    _radioMode.value = normalizeMode(rawMode)
                }
            }
        } catch (_: Exception) {
            consecutiveFailures++
        }

        // After too many failures, verify connection is still alive
        if (consecutiveFailures >= MAX_CONSECUTIVE_FAILURES) {
            verifyConnectionOrDisconnect()
        }
    }

    private fun verifyConnectionOrDisconnect() {
        try {
            val request = Request.Builder()
                .url("$activeBaseUrl/api/v1/version")
                .header("User-Agent", USER_AGENT)
                .get()
                .build()

            val success = client.newCall(request).execute().use { it.isSuccessful }
            if (success) {
                consecutiveFailures = 0
            } else {
                disconnect()
            }
        } catch (_: Exception) {
            disconnect()
        }
    }

    private fun disconnect() {
        _isConnected.value = false
        _radioFrequency.value = null
        _radioMode.value = null
        consecutiveFailures = 0
    }

    private fun putRequest(url: String) {
        val request = Request.Builder()
            .url(url)
            .header("User-Agent", USER_AGENT)
            .put("".toRequestBody("text/plain".toMediaType()))
            .build()

        client.newCall(request).execute().close()
    }

    private fun normalizeMode(mode: String?): String? = when (mode) {
        "LSB", "USB" -> "SSB"
        "CW_R", "CWR" -> "CW"
        else -> mode
    }
}
