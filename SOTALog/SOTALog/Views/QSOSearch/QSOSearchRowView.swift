import SwiftUI

struct QSOSearchRowView: View {
    let result: QSOSearchResult

    var body: some View {
        HStack(spacing: 12) {
            Text(result.formattedDate + " " + result.timeOn.insertingTimeSeparator + "Z")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .fixedSize()

            Text(result.callsign)
                .font(.body.monospaced().bold())
                .lineLimit(1)

            Text(result.band)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)

            Spacer()

            if result.logPotaReference != nil {
                Image(systemName: "tree")
                    .font(.caption)
                    .foregroundStyle(Color.appGreen)
            }

            if result.logSotaReference != nil {
                Image(systemName: "mountain.2")
                    .font(.caption)
                    .foregroundStyle(Color.appBlue)
            }
        }
        .contentShape(Rectangle())
        .padding(.vertical, 2)
    }
}
