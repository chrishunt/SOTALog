import Foundation

enum SyncImporter {

    // MARK: - Types

    struct ActivationKey: Hashable {
        let date: String
        let potaReference: String?
        let sotaReference: String?

        // Carried for Log creation but NOT part of equality/hash
        var stationCallsign: String
        var myGrid: String?

        func hash(into hasher: inout Hasher) {
            hasher.combine(date)
            hasher.combine(potaReference)
            hasher.combine(sotaReference)
        }

        static func == (lhs: ActivationKey, rhs: ActivationKey) -> Bool {
            lhs.date == rhs.date &&
            lhs.potaReference == rhs.potaReference &&
            lhs.sotaReference == rhs.sotaReference
        }
    }

    struct ParsedQSORecord {
        var qso: QSO
        var rawFields: [String: String]
    }

    struct GroupingResult {
        var activations: [(key: ActivationKey, qsos: [ParsedQSORecord])]
        var unattached: [ParsedQSORecord]
    }

    // MARK: - Grouping

    static func groupByActivation(
        records: [[String: String]],
        fallbackCallsign: String?,
        validPotaRefs: [String: String],
        validSotaCodes: [String: String]
    ) -> GroupingResult {
        var groups: [ActivationKey: [ParsedQSORecord]] = [:]
        var unattached: [ParsedQSORecord] = []

        for fields in records {
            guard let qso = ADIFFormatter.qsoFromFields(fields) else { continue }
            let record = ParsedQSORecord(qso: qso, rawFields: fields)

            // Extract and validate POTA reference
            let rawPota = fields["MY_SIG_INFO"]
            let validatedPota: String? = rawPota.flatMap { raw in
                let normalized = POTAPark.normalize(raw)
                return validPotaRefs[normalized]
            }

            // Extract and validate SOTA reference
            let rawSota = fields["MY_SOTA_REF"]
            let validatedSota: String? = rawSota.flatMap { raw in
                let normalized = SOTASummit.normalize(raw)
                return validSotaCodes[normalized]
            }

            // Station callsign with fallback
            let stationCallsign = fields["STATION_CALLSIGN"] ?? fallbackCallsign ?? ""

            // Grid square
            let myGrid = fields["MY_GRIDSQUARE"]

            if validatedPota == nil && validatedSota == nil {
                unattached.append(record)
            } else {
                let key = ActivationKey(
                    date: qso.date,
                    potaReference: validatedPota,
                    sotaReference: validatedSota,
                    stationCallsign: stationCallsign,
                    myGrid: myGrid
                )
                groups[key, default: []].append(record)
            }
        }

        // Stable ordering by date then reference
        let sorted = groups.sorted { a, b in
            if a.key.date != b.key.date { return a.key.date < b.key.date }
            let aRef = a.key.potaReference ?? a.key.sotaReference ?? ""
            let bRef = b.key.potaReference ?? b.key.sotaReference ?? ""
            return aRef < bRef
        }

        return GroupingResult(
            activations: sorted.map { (key: $0.key, qsos: $0.value) },
            unattached: unattached
        )
    }
}
