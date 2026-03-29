package com.sotalog.android.domain.services

import com.sotalog.android.domain.models.POTAPark
import com.sotalog.android.domain.models.QSO
import com.sotalog.android.domain.models.SOTASummit

object SyncImporter {

    data class ActivationKey(
        val date: String,
        val potaReference: String?,
        val sotaReference: String?,
        val stationCallsign: String,
        val myGrid: String?,
    ) {
        // Equality and hash based on date + potaReference + sotaReference only
        override fun equals(other: Any?): Boolean {
            if (this === other) return true
            if (other !is ActivationKey) return false
            return date == other.date &&
                potaReference == other.potaReference &&
                sotaReference == other.sotaReference
        }

        override fun hashCode(): Int {
            var result = date.hashCode()
            result = 31 * result + (potaReference?.hashCode() ?: 0)
            result = 31 * result + (sotaReference?.hashCode() ?: 0)
            return result
        }
    }

    data class ParsedQSORecord(
        val qso: QSO,
        val rawFields: Map<String, String>,
    )

    data class GroupingResult(
        val activations: List<Pair<ActivationKey, List<ParsedQSORecord>>>,
        val unattached: List<ParsedQSORecord>,
    )

    /**
     * Groups parsed ADIF records into activations by date and reference.
     *
     * @param records parsed ADIF field maps
     * @param fallbackCallsign callsign to use when STATION_CALLSIGN is absent
     * @param validPotaRefs map of normalized POTA ref -> canonical ref
     * @param validSotaCodes map of normalized SOTA code -> canonical code
     */
    fun groupByActivation(
        records: List<Map<String, String>>,
        fallbackCallsign: String?,
        validPotaRefs: Map<String, String>,
        validSotaCodes: Map<String, String>,
    ): GroupingResult {
        val groups = linkedMapOf<ActivationKey, MutableList<ParsedQSORecord>>()
        val unattached = mutableListOf<ParsedQSORecord>()

        for (fields in records) {
            val qso = ADIFFormatter.qsoFromFields(fields) ?: continue
            val record = ParsedQSORecord(qso, fields)

            // Extract and validate POTA reference
            val rawPota = fields["MY_SIG_INFO"]
            val validatedPota = rawPota?.let { raw ->
                val normalized = POTAPark.normalize(raw)
                validPotaRefs[normalized]
            }

            // Extract and validate SOTA reference
            val rawSota = fields["MY_SOTA_REF"]
            val validatedSota = rawSota?.let { raw ->
                val normalized = SOTASummit.normalize(raw)
                validSotaCodes[normalized]
            }

            // Station callsign with fallback
            val stationCallsign = fields["STATION_CALLSIGN"] ?: fallbackCallsign ?: ""

            // Grid square
            val myGrid = fields["MY_GRIDSQUARE"]

            if (validatedPota == null && validatedSota == null) {
                unattached += record
            } else {
                val key = ActivationKey(
                    date = qso.date,
                    potaReference = validatedPota,
                    sotaReference = validatedSota,
                    stationCallsign = stationCallsign,
                    myGrid = myGrid,
                )
                groups.getOrPut(key) { mutableListOf() } += record
            }
        }

        // Stable ordering by date then reference
        val sorted = groups.entries.sortedWith(compareBy(
            { it.key.date },
            { it.key.potaReference ?: it.key.sotaReference ?: "" },
        ))

        return GroupingResult(
            activations = sorted.map { it.key to it.value.toList() },
            unattached = unattached,
        )
    }
}
