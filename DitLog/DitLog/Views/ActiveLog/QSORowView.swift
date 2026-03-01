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
                .frame(minWidth: 100, alignment: .leading)

            Text(qso.band)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)

            Spacer()

            if qso.potaRef != nil {
                Image(systemName: "tree")
                    .font(.caption)
                    .foregroundStyle(.green)
            }

            if qso.sotaRef != nil {
                Image(systemName: "mountain.2")
                    .font(.caption)
                    .foregroundStyle(.blue)
            }
        }
        .contentShape(Rectangle())
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
