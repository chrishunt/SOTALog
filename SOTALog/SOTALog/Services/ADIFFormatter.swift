import Foundation

/// Encodes and decodes ADIF (Amateur Data Interchange Format) records.
enum ADIFFormatter {

    // MARK: - Encoding

    /// Encodes a single QSO to an ADIF record string.
    static func encode(qso: QSO, log: Log? = nil) -> String {
        var fields: [(String, String)] = []

        fields.append(("CALL", qso.callsign))
        fields.append(("QSO_DATE", qso.date))
        fields.append(("TIME_ON", qso.timeOn))
        fields.append(("BAND", qso.band))
        fields.append(("MODE", qso.mode))
        fields.append(("RST_SENT", qso.rstSent))
        fields.append(("RST_RCVD", qso.rstReceived))

        if let freq = qso.frequency {
            fields.append(("FREQ", String(format: "%.4f", freq)))
        }
        if let name = qso.name, !name.isEmpty {
            fields.append(("NAME", name))
        }
        if let qth = qso.qth, !qth.isEmpty {
            fields.append(("QTH", qth))
        }
        if let grid = qso.grid, !grid.isEmpty {
            fields.append(("GRIDSQUARE", grid))
        }
        if let notes = qso.notes, !notes.isEmpty {
            fields.append(("COMMENT", notes))
        }

        // POTA fields
        if let log = log {
            if let myRef = log.potaReference {
                fields.append(("MY_SIG", "POTA"))
                fields.append(("MY_SIG_INFO", myRef))
            }
            if let myGrid = log.myGrid {
                fields.append(("MY_GRIDSQUARE", myGrid))
            }
            fields.append(("STATION_CALLSIGN", log.myCallsign))

            // SOTA fields
            if let myRef = log.sotaReference {
                fields.append(("MY_SOTA_REF", myRef))
            }
        }

        // Their POTA ref (park-to-park)
        if let ref = qso.potaRef, !ref.isEmpty {
            fields.append(("SIG", "POTA"))
            fields.append(("SIG_INFO", ref))
        }

        // Their SOTA ref (summit-to-summit)
        if let ref = qso.sotaRef, !ref.isEmpty {
            fields.append(("SOTA_REF", ref))
        }

        let record = fields.map { encodeField($0.0, value: $0.1) }.joined()
        return record + "<EOR>\n"
    }

    /// Encodes a full ADIF file with header.
    static func encodeFile(qsos: [QSO], log: Log? = nil) -> String {
        var output = "ADIF Export from SOTALog\n"
        output += encodeField("ADIF_VER", value: "3.1.4")
        output += encodeField("PROGRAMID", value: "SOTALog")
        output += encodeField("PROGRAMVERSION", value: "1.0")
        output += "<EOH>\n\n"

        for qso in qsos {
            output += encode(qso: qso, log: log)
        }

        return output
    }

    private static func encodeField(_ name: String, value: String) -> String {
        "<\(name):\(value.count)>\(value)"
    }

    // MARK: - Decoding

    /// Parses ADIF text into an array of field dictionaries.
    static func decode(_ adif: String) -> [[String: String]] {
        var records: [[String: String]] = []

        // Skip header if present — find <EOH> or start from beginning
        let bodyStart: String.Index
        if let eohRange = adif.range(of: "<EOH>", options: .caseInsensitive) {
            bodyStart = eohRange.upperBound
        } else if let eohRange = adif.range(of: "<eoh>", options: .caseInsensitive) {
            bodyStart = eohRange.upperBound
        } else {
            bodyStart = adif.startIndex
        }

        let body = String(adif[bodyStart...])

        // Split on <EOR>
        let rawRecords = body.components(separatedBy: "<EOR>")
            .map { $0.replacingOccurrences(of: "<eor>", with: "", options: .caseInsensitive) }

        for rawRecord in rawRecords {
            let fields = parseFields(rawRecord)
            if !fields.isEmpty {
                records.append(fields)
            }
        }

        return records
    }

    /// Parses a single record's fields.
    private static func parseFields(_ record: String) -> [String: String] {
        var fields: [String: String] = [:]
        var index = record.startIndex

        while index < record.endIndex {
            // Find next '<'
            guard let openBracket = record[index...].firstIndex(of: "<") else { break }
            guard let closeBracket = record[openBracket...].firstIndex(of: ">") else { break }

            let tagContent = String(record[record.index(after: openBracket)..<closeBracket])
            let parts = tagContent.split(separator: ":", maxSplits: 2)

            guard parts.count >= 2, let length = Int(parts[1]) else {
                index = record.index(after: closeBracket)
                continue
            }

            let fieldName = String(parts[0]).uppercased()
            let valueStart = record.index(after: closeBracket)

            guard valueStart < record.endIndex else {
                index = valueStart
                continue
            }

            let valueEnd = record.index(valueStart, offsetBy: length, limitedBy: record.endIndex) ?? record.endIndex
            let value = String(record[valueStart..<valueEnd])

            fields[fieldName] = value
            index = valueEnd
        }

        return fields
    }

    /// Converts parsed ADIF fields into a QSO record.
    static func qsoFromFields(_ fields: [String: String], logId: Int64? = nil) -> QSO? {
        guard let callsign = fields["CALL"],
              let date = fields["QSO_DATE"],
              let timeOn = fields["TIME_ON"] else {
            return nil
        }

        let band = fields["BAND"] ?? {
            if let freqStr = fields["FREQ"], let freq = Double(freqStr) {
                return BandPlan.band(for: freq) ?? "20m"
            }
            return "20m"
        }()

        return QSO(
            logId: logId,
            callsign: callsign.uppercased(),
            date: date,
            timeOn: String(timeOn.prefix(4)),
            frequency: fields["FREQ"].flatMap(Double.init),
            band: band,
            mode: fields["MODE"] ?? "CW",
            rstSent: fields["RST_SENT"] ?? "599",
            rstReceived: fields["RST_RCVD"] ?? "599",
            name: fields["NAME"],
            qth: fields["QTH"],
            grid: fields["GRIDSQUARE"],
            sotaRef: fields["SOTA_REF"],
            potaRef: fields["SIG_INFO"],
            notes: fields["COMMENT"]
        )
    }
}
