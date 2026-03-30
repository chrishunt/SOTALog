package com.sotalog.android.domain.services

import com.sotalog.android.domain.models.Log
import com.sotalog.android.domain.models.QSO
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone

object ADIFFormatter {

    enum class Program { POTA, SOTA }

    // MARK: - Encoding

    fun encode(qso: QSO, log: Log? = null, program: Program? = null): String {
        val fields = mutableListOf<Pair<String, String>>()

        fields += "CALL" to qso.callsign
        fields += "QSO_DATE" to qso.date
        fields += "TIME_ON" to qso.timeOn
        fields += "BAND" to qso.band
        fields += "MODE" to qso.mode
        fields += "RST_SENT" to qso.rstSent
        fields += "RST_RCVD" to qso.rstReceived

        qso.frequency?.let { fields += "FREQ" to "%.4f".format(it) }
        qso.name?.takeIf { it.isNotEmpty() }?.let { fields += "NAME" to it }
        qso.qth?.takeIf { it.isNotEmpty() }?.let { fields += "QTH" to it }
        qso.grid?.takeIf { it.isNotEmpty() }?.let { fields += "GRIDSQUARE" to it }
        qso.notes?.takeIf { it.isNotEmpty() }?.let { fields += "COMMENT" to it }

        if (log != null) {
            if (program != Program.SOTA) {
                log.potaReference?.let {
                    fields += "MY_SIG" to "POTA"
                    fields += "MY_SIG_INFO" to it
                }
            }
            log.myGrid?.let { fields += "MY_GRIDSQUARE" to it }
            fields += "STATION_CALLSIGN" to log.myCallsign

            if (program != Program.POTA) {
                log.sotaReference?.let { fields += "MY_SOTA_REF" to it }
            }
        }

        if (program != Program.SOTA) {
            qso.potaRef?.takeIf { it.isNotEmpty() }?.let {
                fields += "SIG" to "POTA"
                fields += "SIG_INFO" to it
            }
        }

        if (program != Program.POTA) {
            qso.sotaRef?.takeIf { it.isNotEmpty() }?.let {
                fields += "SOTA_REF" to it
            }
        }

        val record = fields.joinToString("") { encodeField(it.first, it.second) }
        return "$record<EOR>\n"
    }

    fun encodeFile(
        qsos: List<QSO>,
        log: Log? = null,
        program: Program? = null,
    ): String = buildString {
        append("ADIF Export from SOTA Log\n")
        append(encodeField("ADIF_VER", "3.1.4"))
        append(encodeField("PROGRAMID", "SOTA Log"))
        append(encodeField("PROGRAMVERSION", "1.0"))
        append("<EOH>\n\n")
        for (qso in qsos) {
            append(encode(qso, log, program))
        }
    }

    fun encodeFile(
        sections: List<Pair<Log, List<QSO>>>,
        unattached: List<QSO> = emptyList(),
    ): String = buildString {
        append("ADIF Export from SOTA Log\n")
        append(encodeField("ADIF_VER", "3.1.4"))
        append(encodeField("PROGRAMID", "SOTA Log"))
        append(encodeField("PROGRAMVERSION", "1.0"))
        append("<EOH>\n\n")
        for ((log, qsos) in sections) {
            for (qso in qsos) {
                append(encode(qso, log))
            }
        }
        for (qso in unattached) {
            append(encode(qso))
        }
    }

    fun encodeField(name: String, value: String): String =
        "<$name:${value.length}>$value"

    // MARK: - Decoding

    fun decode(adif: String): List<Map<String, String>> {
        val eohIndex = adif.indexOf("<EOH>", ignoreCase = true)
        val body = if (eohIndex >= 0) {
            adif.substring(eohIndex + 5)
        } else {
            adif
        }

        val normalized = body.replace(Regex("<eor>", RegexOption.IGNORE_CASE), "<EOR>")
        return normalized.split("<EOR>").mapNotNull { raw ->
            val fields = parseFields(raw)
            fields.takeIf { it.isNotEmpty() }
        }
    }

    private fun parseFields(record: String): Map<String, String> {
        val fields = mutableMapOf<String, String>()
        var index = 0

        while (index < record.length) {
            val openBracket = record.indexOf('<', index)
            if (openBracket == -1) break
            val closeBracket = record.indexOf('>', openBracket)
            if (closeBracket == -1) break

            val tagContent = record.substring(openBracket + 1, closeBracket)
            val parts = tagContent.split(":", limit = 3)

            if (parts.size < 2) {
                index = closeBracket + 1
                continue
            }

            val length = parts[1].toIntOrNull()
            if (length == null) {
                index = closeBracket + 1
                continue
            }

            val fieldName = parts[0].uppercase()
            val valueStart = closeBracket + 1

            if (valueStart >= record.length) {
                index = valueStart
                continue
            }

            val valueEnd = minOf(valueStart + length, record.length)
            fields[fieldName] = record.substring(valueStart, valueEnd)
            index = valueEnd
        }

        return fields
    }

    // MARK: - Filenames

    fun activationFilename(log: Log, program: Program? = null): String = when (program) {
        Program.POTA ->
            "${log.myCallsign}@${log.potaReference ?: "POTA"}_${log.date}.adi"
        Program.SOTA -> {
            val ref = log.sotaReference
            if (ref != null) {
                "${log.myCallsign}@${ref.replace("/", "-")}_${log.date}.adi"
            } else {
                "${log.myCallsign}_SOTA_${log.date}.adi"
            }
        }
        null ->
            "${log.myCallsign}_${log.date}.adi"
    }

    fun exportAllFilename(): String {
        val formatter = SimpleDateFormat("yyyyMMdd_HHmm", Locale.US).apply {
            timeZone = TimeZone.getTimeZone("UTC")
        }
        return "SOTALog_${formatter.format(Date())}Z.adi"
    }

    // MARK: - QSO from fields

    fun qsoFromFields(fields: Map<String, String>, logId: Long? = null): QSO? {
        val callsign = fields["CALL"] ?: return null
        val date = fields["QSO_DATE"] ?: return null
        val timeOn = fields["TIME_ON"] ?: return null

        val band = run {
            val freqStr = fields["FREQ"]
            if (freqStr != null) {
                val freq = freqStr.toDoubleOrNull()
                if (freq != null) {
                    val derived = BandPlan.band(freq)
                    if (derived != null) return@run derived
                }
            }
            val raw = fields["BAND"]
            if (raw != null && raw in BandPlan.allBands) return@run raw
            "20m"
        }

        return QSO(
            logId = logId,
            callsign = callsign.uppercase(),
            date = date,
            timeOn = timeOn.take(4),
            frequency = fields["FREQ"]?.toDoubleOrNull(),
            band = band,
            mode = fields["MODE"] ?: "CW",
            rstSent = fields["RST_SENT"] ?: "599",
            rstReceived = fields["RST_RCVD"] ?: "599",
            name = fields["NAME"],
            qth = fields["QTH"],
            grid = fields["GRIDSQUARE"],
            sotaRef = fields["SOTA_REF"],
            potaRef = fields["SIG_INFO"],
            notes = fields["COMMENT"],
        )
    }
}
