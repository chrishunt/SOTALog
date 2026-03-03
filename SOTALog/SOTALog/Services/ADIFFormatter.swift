import Foundation
import CoreTransferable
import UniformTypeIdentifiers

/// Encodes and decodes ADIF (Amateur Data Interchange Format) records.
enum ADIFFormatter {

    /// Program-specific export filtering.
    enum Program {
        case pota
        case sota
    }

    // MARK: - Encoding

    /// Encodes a single QSO to an ADIF record string.
    static func encode(qso: QSO, log: Log? = nil) -> String {
        encode(qso: qso, log: log, program: nil)
    }

    /// Encodes a single QSO, filtering fields for a specific program.
    static func encode(qso: QSO, log: Log? = nil, program: Program?) -> String {
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

        if let log = log {
            // POTA fields — skip for SOTA exports
            if program != .sota, let myRef = log.potaReference {
                fields.append(("MY_SIG", "POTA"))
                fields.append(("MY_SIG_INFO", myRef))
            }
            if let myGrid = log.myGrid {
                fields.append(("MY_GRIDSQUARE", myGrid))
            }
            fields.append(("STATION_CALLSIGN", log.myCallsign))

            // SOTA fields — skip for POTA exports
            if program != .pota, let myRef = log.sotaReference {
                fields.append(("MY_SOTA_REF", myRef))
            }
        }

        // Their POTA ref (park-to-park) — skip for SOTA exports
        if program != .sota, let ref = qso.potaRef, !ref.isEmpty {
            fields.append(("SIG", "POTA"))
            fields.append(("SIG_INFO", ref))
        }

        // Their SOTA ref (summit-to-summit) — skip for POTA exports
        if program != .pota, let ref = qso.sotaRef, !ref.isEmpty {
            fields.append(("SOTA_REF", ref))
        }

        let record = fields.map { encodeField($0.0, value: $0.1) }.joined()
        return record + "<EOR>\n"
    }

    /// Encodes a full ADIF file with header.
    static func encodeFile(qsos: [QSO], log: Log? = nil) -> String {
        encodeFile(qsos: qsos, log: log, program: nil)
    }

    /// Encodes a full ADIF file, filtering fields for a specific program.
    static func encodeFile(qsos: [QSO], log: Log? = nil, program: Program?) -> String {
        var output = "ADIF Export from SOTALog\n"
        output += encodeField("ADIF_VER", value: "3.1.4")
        output += encodeField("PROGRAMID", value: "SOTALog")
        output += encodeField("PROGRAMVERSION", value: "1.0")
        output += "<EOH>\n\n"

        for qso in qsos {
            output += encode(qso: qso, log: log, program: program)
        }

        return output
    }

    /// Encodes a full ADIF file from log+QSO sections, preserving each log's context.
    static func encodeFile(sections: [(Log, [QSO])]) -> String {
        var output = "ADIF Export from SOTALog\n"
        output += encodeField("ADIF_VER", value: "3.1.4")
        output += encodeField("PROGRAMID", value: "SOTALog")
        output += encodeField("PROGRAMVERSION", value: "1.0")
        output += "<EOH>\n\n"

        for (log, qsos) in sections {
            for qso in qsos {
                output += encode(qso: qso, log: log)
            }
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

        // Normalize <eor>/<Eor>/etc. to <EOR>, then split
        let normalized = body.replacingOccurrences(of: "<eor>", with: "<EOR>", options: .caseInsensitive)
        let rawRecords = normalized.components(separatedBy: "<EOR>")

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

    // MARK: - Filenames

    /// Generates an export filename for the given log and program.
    static func filename(log: Log, program: Program?) -> String {
        switch program {
        case .pota:
            return "\(log.myCallsign)@\(log.potaReference ?? "POTA")_\(log.date).adi"
        case .sota:
            if let ref = log.sotaReference {
                return "\(log.myCallsign)@\(ref.replacingOccurrences(of: "/", with: "-"))_\(log.date).adi"
            }
            return "\(log.myCallsign)_SOTA_\(log.date).adi"
        case nil:
            return "\(log.myCallsign)_\(log.date).adi"
        }
    }

    /// Converts parsed ADIF fields into a QSO record.
    static func qsoFromFields(_ fields: [String: String], logId: Int64? = nil) -> QSO? {
        guard let callsign = fields["CALL"],
              let date = fields["QSO_DATE"],
              let timeOn = fields["TIME_ON"] else {
            return nil
        }

        let band: String = {
            if let freqStr = fields["FREQ"], let freq = Double(freqStr),
               let derived = BandPlan.band(for: freq) {
                return derived
            }
            if let raw = fields["BAND"], BandPlan.allBands.contains(raw) {
                return raw
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

/// A named ADIF file that can be shared via ShareLink.
struct ADIFFile: Transferable {
    let filename: String
    let content: String

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .plainText) { file in
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent(file.filename)
            try file.content.write(to: url, atomically: true, encoding: .utf8)
            return SentTransferredFile(url)
        }
    }
}
