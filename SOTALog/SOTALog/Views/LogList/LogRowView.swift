import SwiftUI

struct LogRowView: View {
    let log: Log
    let qsoCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(log.myCallsign)
                    .font(.headline.monospaced())

                Spacer()

                Text("\(qsoCount) QSOs")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack {
                if let ref = log.referenceDisplay {
                    Text(ref)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(log.formattedDate)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
    }
}
