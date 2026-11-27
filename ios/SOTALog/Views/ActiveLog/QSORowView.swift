import SwiftUI
import HamCore

struct QSORowView: View {
    let qso: QSO
    /// One emoji per callsign list the station is on.
    var mark: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 12) {
                Text(qso.timeOn.insertingTimeSeparator + "Z")
                    .font(.appTimestamp)
                    .foregroundStyle(Color.appTextSecondary)

                Text(qso.callsign)
                    .font(.appCallsignRow)
                    .foregroundStyle(Color.appTextPrimary)
                    .frame(minWidth: 100, alignment: .leading)

                Spacer()

                if let potaRef = qso.potaRef {
                    AppReferenceIcon(type: .pota)
                        .accessibilityLabel("Park to park \(potaRef)")
                }

                if let sotaRef = qso.sotaRef {
                    AppReferenceIcon(type: .sota)
                        .accessibilityLabel("Summit to summit \(sotaRef)")
                }

                if qso.syncedToQRZ {
                    AppQRZBadge()
                }

                Text("\(qso.band.uppercased()) \(qso.mode)")
                    .appBadge()
            }

            if let detail = detailText {
                Text(detail)
                    .font(.appLabel)
                    .foregroundStyle(Color.appTextSecondary)
                    .lineLimit(1)
                    .padding(.leading, 54)
            }
        }
        .contentShape(Rectangle())
        .padding(.vertical, 2)
    }

    private var detailText: String? {
        let name = qso.name?.isEmpty == false ? qso.name : nil
        let qth = qso.qth?.isEmpty == false ? qso.qth : nil
        let person = [mark, name].compactMap { $0 }.joined(separator: " ")
        let parts = [person.isEmpty ? nil : person, qth].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

extension String {
    /// Converts "1234" to "12:34"
    var insertingTimeSeparator: String {
        guard count == 4 else { return self }
        let idx = index(startIndex, offsetBy: 2)
        return String(self[..<idx]) + ":" + String(self[idx...])
    }
}
