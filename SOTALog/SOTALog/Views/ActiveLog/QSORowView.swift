import SwiftUI

struct QSORowView: View {
    let qso: QSO

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 12) {
                Text(qso.timeOn.insertingTimeSeparator + "Z")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)

                Text(qso.callsign)
                    .font(.body.monospaced().bold())
                    .foregroundStyle(Color.appTextPrimary)
                    .frame(minWidth: 100, alignment: .leading)

                Spacer()

                if let potaRef = qso.potaRef {
                    Image(systemName: "tree")
                        .font(.caption)
                        .foregroundStyle(Color.appGreen)
                        .accessibilityLabel("Park to park \(potaRef)")
                }

                if let sotaRef = qso.sotaRef {
                    Image(systemName: "mountain.2")
                        .font(.caption)
                        .foregroundStyle(Color.appBlue)
                        .accessibilityLabel("Summit to summit \(sotaRef)")
                }

                if qso.syncedToQRZ {
                    Text("QRZ")
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(.secondary.opacity(0.12), in: Capsule())
                        .accessibilityLabel("Synced to QRZ")
                }

                Text("\(qso.band.uppercased()) \(qso.mode)")
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.12), in: Capsule())
            }

            if let detail = detailText {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
        switch (name, qth) {
        case let (n?, q?): return "\(n) · \(q)"
        case let (n?, nil): return n
        case let (nil, q?): return q
        case (nil, nil): return nil
        }
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
