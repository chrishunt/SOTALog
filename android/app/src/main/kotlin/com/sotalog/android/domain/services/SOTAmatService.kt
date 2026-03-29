package com.sotalog.android.domain.services

import com.sotalog.android.domain.models.Log

object SOTAmatService {

    const val PHONE_NUMBER = "+16017682628"
    const val SETUP_URL = "https://sotamat.com/sms-services/"

    /**
     * Builds an SMS message body to post a spot via SOTAmat.
     * Returns null if the log has neither POTA nor SOTA reference.
     */
    fun spotMessage(
        log: Log,
        frequencyMHz: String,
        mode: String,
        comment: String?,
    ): String? {
        if (!log.isPOTA && !log.isSOTA) return null

        val sanitizedComment = comment?.let { sanitizeComment(it) }

        val isQRT = sanitizedComment?.contains("QRT", ignoreCase = true) == true

        val commands = mutableListOf<String>()

        if (log.isSOTA) {
            log.sotaReference?.let { ref ->
                val sotaMode = if (isQRT) "QRT" else mode
                val cmd = buildString {
                    append("SotaPostSpot ${log.myCallsign} $ref $frequencyMHz $sotaMode")
                    if (sanitizedComment != null) append(" '$sanitizedComment")
                }
                commands += cmd
            }
        }

        if (log.isPOTA) {
            log.potaReference?.let { ref ->
                val potaComment = when {
                    isQRT && sanitizedComment != null &&
                        !sanitizedComment.contains("QRT", ignoreCase = true) ->
                        "QRT $sanitizedComment"
                    isQRT && sanitizedComment == null -> "QRT"
                    else -> sanitizedComment
                }
                val cmd = buildString {
                    append("PotaPostSpot ${log.myCallsign} $ref $frequencyMHz $mode")
                    if (potaComment != null) append(" '$potaComment")
                }
                commands += cmd
            }
        }

        return commands.ifEmpty { null }?.joinToString("; ")
    }

    /**
     * Strips quotes, semicolons, and pipe characters; trims whitespace.
     * Returns null if the result is empty.
     */
    fun sanitizeComment(comment: String): String? {
        val stripped = buildString {
            for (c in comment) {
                when (c) {
                    ';', ',', '|', '"', '\'',
                    '\u2018', '\u2019', '\u201C', '\u201D' -> { /* skip */ }
                    else -> append(c)
                }
            }
        }.trim()
        return stripped.ifEmpty { null }
    }
}
