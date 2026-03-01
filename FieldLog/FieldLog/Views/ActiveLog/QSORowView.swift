import SwiftUI

struct QSORowView: View {
    let qso: QSO

    var body: some View {
        HStack(spacing: 12) {
            Text(qso.timeOn.insertingTimeSeparator + "Z")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)

            Text(qso.callsign)
                .font(.body.monospaced().bold())
                .frame(minWidth: 80, alignment: .leading)

            if let freq = qso.frequency {
                Text(String(format: "%.3f", freq))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 4) {
                Text(qso.rstSent)
                    .font(.caption.monospacedDigit())
                Text(qso.rstReceived)
                    .font(.caption.monospacedDigit())
            }
            .foregroundStyle(.secondary)

            if let ref = qso.potaRef {
                Text(ref)
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }

            if let ref = qso.sotaRef {
                Text(ref)
                    .font(.caption2)
                    .foregroundStyle(.blue)
            }
        }
        .padding(.vertical, 2)
    }
}

private extension String {
    /// Converts "1234" to "12:34"
    var insertingTimeSeparator: String {
        guard count == 4 else { return self }
        let idx = index(startIndex, offsetBy: 2)
        return String(self[..<idx]) + ":" + String(self[idx...])
    }
}
