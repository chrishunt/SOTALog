import Foundation

struct SOTAmatService {
    static let phoneNumber = "+16017682628"
    static let setupURL = URL(string: "https://sotamat.com/sms-services/")!

    static func spotMessage(
        log: Log, frequencyMHz: String, mode: String,
        comment: String?
    ) -> String? {
        guard log.isPOTA || log.isSOTA else { return nil }

        let sanitizedComment = comment.flatMap { raw -> String? in
            let stripped = CharacterSet(charactersIn: ";,'\u{2018}\u{2019}\u{201C}\u{201D}\"")
            let cleaned = raw.unicodeScalars
                .filter { !stripped.contains($0) }
                .reduce(into: "") { $0.unicodeScalars.append($1) }
                .trimmingCharacters(in: .whitespaces)
            return cleaned.isEmpty ? nil : cleaned
        }

        let isQRT = sanitizedComment?.range(
            of: "QRT", options: .caseInsensitive
        ) != nil

        var commands: [String] = []

        if log.isSOTA, let ref = log.sotaReference {
            let sotaMode = isQRT ? "QRT" : mode
            var cmd = "SotaPostSpot \(log.myCallsign) \(ref) \(frequencyMHz) \(sotaMode)"
            if let c = sanitizedComment {
                cmd += " '\(c)"
            }
            commands.append(cmd)
        }

        if log.isPOTA, let ref = log.potaReference {
            var potaComment = sanitizedComment
            if isQRT, let c = potaComment {
                if c.range(of: "QRT", options: .caseInsensitive) == nil {
                    potaComment = "QRT \(c)"
                }
            } else if isQRT {
                potaComment = "QRT"
            }
            var cmd = "PotaPostSpot \(log.myCallsign) \(ref) \(frequencyMHz) \(mode)"
            if let c = potaComment {
                cmd += " '\(c)"
            }
            commands.append(cmd)
        }

        return commands.isEmpty ? nil : commands.joined(separator: "; ")
    }
}
