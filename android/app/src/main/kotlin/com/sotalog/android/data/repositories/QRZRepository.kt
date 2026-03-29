package com.sotalog.android.data.repositories

import com.sotalog.android.data.local.preferences.CredentialStore
import com.sotalog.android.domain.models.QRZCallsignResult
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.FormBody
import okhttp3.OkHttpClient
import okhttp3.Request
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class QRZRepository @Inject constructor(
    private val client: OkHttpClient,
    private val credentialStore: CredentialStore,
    private val callsignHistoryRepository: CallsignHistoryRepository,
) {

    companion object {
        private const val LOGBOOK_API_URL = "https://logbook.qrz.com/api"
        private const val XML_API_URL = "https://xmldata.qrz.com/xml/current/"
        private const val USER_AGENT = "SOTA Log/1.0"
    }

    // -- Logbook API --

    suspend fun testAPIKey(apiKey: String) = withContext(Dispatchers.IO) {
        val body = FormBody.Builder()
            .add("KEY", apiKey)
            .add("ACTION", "STATUS")
            .build()

        val request = Request.Builder()
            .url(LOGBOOK_API_URL)
            .header("User-Agent", USER_AGENT)
            .post(body)
            .build()

        val response = client.newCall(request).execute()
        val responseBody = response.body?.string() ?: throw QRZException("Empty response")
        val parsed = parseResponse(responseBody)

        if (parsed["RESULT"] != "OK") {
            throw QRZException(parsed["REASON"] ?: "API key validation failed")
        }
    }

    suspend fun uploadQSO(apiKey: String, adifRecord: String): Long? =
        withContext(Dispatchers.IO) {
            val body = FormBody.Builder()
                .add("KEY", apiKey)
                .add("ACTION", "INSERT")
                .add("ADIF", adifRecord)
                .build()

            val request = Request.Builder()
                .url(LOGBOOK_API_URL)
                .header("User-Agent", USER_AGENT)
                .post(body)
                .build()

            val response = client.newCall(request).execute()
            val responseBody = response.body?.string() ?: throw QRZException("Empty response")
            val parsed = parseResponse(responseBody)

            if (parsed["RESULT"] == "REPLACE") {
                // QRZ replaced an existing record; extract the log ID
                return@withContext parsed["LOGID"]?.toLongOrNull()
            }

            if (parsed["RESULT"] != "OK") {
                throw QRZException(parsed["REASON"] ?: "Upload failed")
            }

            parsed["LOGID"]?.toLongOrNull()
        }

    suspend fun downloadQSOs(apiKey: String, afterLogId: Long = 0): Pair<String, Int> =
        withContext(Dispatchers.IO) {
            val body = FormBody.Builder()
                .add("KEY", apiKey)
                .add("ACTION", "FETCH")
                .apply {
                    if (afterLogId > 0) {
                        add("OPTION", "BETWEEN:$afterLogId:999999999999")
                    }
                }
                .build()

            val request = Request.Builder()
                .url(LOGBOOK_API_URL)
                .header("User-Agent", USER_AGENT)
                .post(body)
                .build()

            val response = client.newCall(request).execute()
            val responseBody = response.body?.string() ?: throw QRZException("Empty response")
            val parsed = parseResponse(responseBody)

            if (parsed["RESULT"] != "OK") {
                // "NO DATA" means empty logbook, not an error
                if (parsed["REASON"]?.contains("no data", ignoreCase = true) == true) {
                    return@withContext "" to 0
                }
                throw QRZException(parsed["REASON"] ?: "Download failed")
            }

            val adif = parsed["ADIF"] ?: ""
            val count = parsed["COUNT"]?.toIntOrNull() ?: 0
            adif to count
        }

    /**
     * Parses QRZ's pseudo-form-encoded response format.
     *
     * The response contains key=value pairs separated by &, but the ADIF field
     * contains raw & characters that break standard URL decoding. Strategy:
     * extract known fields first, then treat the remainder as ADIF content.
     */
    fun parseResponse(response: String): Map<String, String> {
        val result = mutableMapOf<String, String>()
        var remaining = response.trim()

        // Extract known non-ADIF fields
        val knownFields = listOf("RESULT", "REASON", "COUNT", "LOGID", "LOGIDS")
        for (field in knownFields) {
            val prefix = "$field="
            val idx = remaining.indexOf(prefix)
            if (idx == -1) continue

            val valueStart = idx + prefix.length
            val ampIdx = remaining.indexOf('&', valueStart)
            val value: String
            if (ampIdx == -1) {
                value = remaining.substring(valueStart)
                remaining = remaining.substring(0, idx)
            } else {
                value = remaining.substring(valueStart, ampIdx)
                remaining = remaining.substring(0, idx) + remaining.substring(ampIdx + 1)
            }
            result[field] = value.trim()
        }

        // Whatever remains (after stripping known fields) is the ADIF blob
        val adif = remaining
            .replace("&amp;", "&")
            .replace("&lt;", "<")
            .replace("&gt;", ">")
            .trim()
            .removePrefix("ADIF=")
            .removePrefix("&")
            .trim()

        if (adif.isNotEmpty()) {
            result["ADIF"] = adif
        }

        return result
    }

    // -- XML Lookup API --

    suspend fun login(username: String, password: String): String =
        withContext(Dispatchers.IO) {
            val request = Request.Builder()
                .url("$XML_API_URL?username=$username&password=$password&agent=$USER_AGENT")
                .header("User-Agent", USER_AGENT)
                .get()
                .build()

            val response = client.newCall(request).execute()
            val xml = response.body?.string() ?: throw QRZException("Empty response")

            val error = extractXmlTag(xml, "Error")
            if (error != null) {
                throw QRZException(error)
            }

            extractXmlTag(xml, "Key")
                ?: throw QRZException("No session key returned")
        }

    suspend fun lookup(callsign: String, sessionKey: String): QRZCallsignResult =
        withContext(Dispatchers.IO) {
            val request = Request.Builder()
                .url("$XML_API_URL?s=$sessionKey&callsign=$callsign")
                .header("User-Agent", USER_AGENT)
                .get()
                .build()

            val response = client.newCall(request).execute()
            val xml = response.body?.string() ?: throw QRZException("Empty response")

            val error = extractXmlTag(xml, "Error")
            if (error != null) {
                throw QRZException(error)
            }

            QRZCallsignResult(
                callsign = extractXmlTag(xml, "call") ?: callsign,
                firstName = extractXmlTag(xml, "fname"),
                nickname = extractXmlTag(xml, "nickname"),
                lastName = extractXmlTag(xml, "name"),
                city = extractXmlTag(xml, "addr2"),
                state = extractXmlTag(xml, "state"),
                country = extractXmlTag(xml, "country"),
                grid = extractXmlTag(xml, "grid"),
                county = extractXmlTag(xml, "county"),
            )
        }

    suspend fun lookupWithAutoLogin(callsign: String): QRZCallsignResult? =
        withContext(Dispatchers.IO) {
            val username = credentialStore.load(CredentialStore.QRZ_USERNAME)
            val password = credentialStore.load(CredentialStore.QRZ_PASSWORD)
            if (username == null || password == null) return@withContext null

            var sessionKey = credentialStore.load(CredentialStore.QRZ_SESSION_KEY)

            // First attempt: use cached session key
            if (sessionKey != null) {
                try {
                    val result = lookup(callsign, sessionKey)
                    callsignHistoryRepository.updateFromLookup(
                        callsign = result.callsign,
                        name = result.name,
                        qth = result.qth,
                        grid = result.grid,
                    )
                    return@withContext result
                } catch (_: QRZException) {
                    // Session expired, re-login below
                }
            }

            // Re-login and retry
            sessionKey = login(username, password)
            credentialStore.save(CredentialStore.QRZ_SESSION_KEY, sessionKey)

            try {
                val result = lookup(callsign, sessionKey)
                callsignHistoryRepository.updateFromLookup(
                    callsign = result.callsign,
                    name = result.name,
                    qth = result.qth,
                    grid = result.grid,
                )
                result
            } catch (e: QRZException) {
                null
            }
        }

    private fun extractXmlTag(xml: String, tag: String): String? {
        val openTag = "<$tag>"
        val closeTag = "</$tag>"
        val startIdx = xml.indexOf(openTag)
        if (startIdx == -1) return null
        val valueStart = startIdx + openTag.length
        val endIdx = xml.indexOf(closeTag, valueStart)
        if (endIdx == -1) return null
        return xml.substring(valueStart, endIdx).trim()
    }
}

class QRZException(message: String) : Exception(message)
