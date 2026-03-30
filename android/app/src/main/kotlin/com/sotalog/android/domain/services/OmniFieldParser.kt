package com.sotalog.android.domain.services

data class ParsedEntry(
    val callsign: String = "",
    val rstSent: String? = null,
    val rstReceived: String? = null,
    val frequency: String? = null,
    val mode: String? = null,
    val qth: String? = null,
    val potaRef: String? = null,
    val sotaRef: String? = null,
    val tokens: List<ClassifiedToken> = emptyList(),
)

data class ClassifiedToken(
    val text: String,
    val kind: TokenKind,
)

enum class TokenKind {
    CALLSIGN, RST, FREQUENCY, MODE, QTH, POTA_REF, SOTA_REF, UNRECOGNIZED,
}

object OmniFieldParser {

    fun parse(input: String): ParsedEntry {
        val tokens = input.split(" ").filter { it.isNotEmpty() }
        val first = tokens.firstOrNull() ?: return ParsedEntry()

        var callsign = first
        var rstSent: String? = null
        var rstReceived: String? = null
        var frequency: String? = null
        var mode: String? = null
        var qth: String? = null
        var potaRef: String? = null
        var sotaRef: String? = null
        val classified = mutableListOf(ClassifiedToken(first, TokenKind.CALLSIGN))
        var rstCount = 0

        for (token in tokens.drop(1)) {
            when {
                isModeToken(token) -> {
                    mode = token.uppercase()
                    classified.add(ClassifiedToken(token, TokenKind.MODE))
                }
                parseRST(token) != null -> {
                    val rst = parseRST(token)!!
                    when (rstCount) {
                        0 -> rstSent = rst
                        1 -> rstReceived = rst
                    }
                    rstCount++
                    classified.add(ClassifiedToken(token, TokenKind.RST))
                }
                isFrequency(token) -> {
                    frequency = token
                    classified.add(ClassifiedToken(token, TokenKind.FREQUENCY))
                }
                isQTH(token) -> {
                    qth = token.uppercase()
                    classified.add(ClassifiedToken(token, TokenKind.QTH))
                }
                isPOTACandidate(token) -> {
                    potaRef = token.uppercase()
                    classified.add(ClassifiedToken(token, TokenKind.POTA_REF))
                }
                isSOTACandidate(token) -> {
                    sotaRef = token.uppercase()
                    classified.add(ClassifiedToken(token, TokenKind.SOTA_REF))
                }
                else -> {
                    classified.add(ClassifiedToken(token, TokenKind.UNRECOGNIZED))
                }
            }
        }

        return ParsedEntry(
            callsign = callsign,
            rstSent = rstSent,
            rstReceived = rstReceived,
            frequency = frequency,
            mode = mode,
            qth = qth,
            potaRef = potaRef,
            sotaRef = sotaRef,
            tokens = classified,
        )
    }

    private fun parseRST(token: String): String? {
        if (token.length !in 2..3) return null
        if (!token.all { it.isDigit() }) return null

        val digits = token.toList()
        val r = digits[0].digitToInt()
        val s = digits[1].digitToInt()
        if (r !in 1..5 || s !in 1..9) return null

        if (digits.size == 3) {
            val t = digits[2].digitToInt()
            if (t !in 1..9) return null
        }
        return token
    }

    private fun isModeToken(token: String): Boolean {
        val upper = token.uppercase()
        return upper == "CW" || upper == "SSB"
    }

    private fun isFrequency(token: String): Boolean =
        token.contains('.') && token.toDoubleOrNull() != null

    private fun isQTH(token: String): Boolean =
        token.uppercase() in qthCodes

    private fun isPOTACandidate(token: String): Boolean {
        val upper = token.uppercase()
        if (upper.length < 3) return false
        val letterCount = upper.takeWhile { it.isLetter() }.length
        val rest = upper.drop(letterCount)
        return letterCount > 0 && rest.isNotEmpty() && rest.all { it.isDigit() }
    }

    private fun isSOTACandidate(token: String): Boolean {
        val upper = token.uppercase()
        if (upper.length < 4) return false

        var i = 0
        // Association prefix: one or more letters
        if (!upper[i].isLetter()) return false
        while (i < upper.length && upper[i].isLetter()) i++
        // Region digit(s)
        if (i >= upper.length || !upper[i].isDigit()) return false
        while (i < upper.length && upper[i].isDigit()) i++
        // Summit code: one or more letters
        if (i >= upper.length || !upper[i].isLetter()) return false
        while (i < upper.length && upper[i].isLetter()) i++
        // Summit number: one or more digits
        if (i >= upper.length || !upper[i].isDigit()) return false
        while (i < upper.length && upper[i].isDigit()) i++
        return i == upper.length
    }

    private val qthCodes: Set<String> = buildSet {
        // US states
        addAll(
            listOf(
                "AL", "AK", "AZ", "AR", "CA", "CO", "CT", "DE", "FL", "GA",
                "HI", "ID", "IL", "IN", "IA", "KS", "KY", "LA", "ME", "MD",
                "MA", "MI", "MN", "MS", "MO", "MT", "NE", "NV", "NH", "NJ",
                "NM", "NY", "NC", "ND", "OH", "OK", "OR", "PA", "RI", "SC",
                "SD", "TN", "TX", "UT", "VT", "VA", "WA", "WV", "WI", "WY",
            )
        )
        // DC + territories
        addAll(listOf("DC", "PR", "VI", "GU", "AS", "MP"))
        // Canadian provinces/territories
        addAll(listOf("AB", "BC", "MB", "NB", "NL", "NS", "NT", "NU", "ON", "PE", "QC", "SK", "YT"))
    }
}
