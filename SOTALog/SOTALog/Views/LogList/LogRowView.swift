import SwiftUI

struct LogRowView: View {
    let log: Log
    let qsoCount: Int
    let bands: [String]

    private let potaThreshold = 10
    private let sotaThreshold = 4

    private var hasReferences: Bool { log.potaReference != nil || log.sotaReference != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(log.myCallsign)
                    .font(.headline.monospaced())

                Spacer()

                Text(log.formattedDate)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 6) {
                if hasReferences {
                    referenceBlocks
                } else {
                    Text("\(qsoCount)")
                        .font(.caption.monospacedDigit().bold())
                        .foregroundStyle(.secondary)
                    Text("QSOs")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                ForEach(bands, id: \.self) { band in
                    Text(band.uppercased())
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.12), in: Capsule())
                }
            }

            if let names = referenceNames {
                Text(names)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
    }

    private var referenceNames: String? {
        let parts = [log.parkName, log.summitName].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    @ViewBuilder
    private var referenceBlocks: some View {
        if let ref = log.potaReference {
            HStack(spacing: 3) {
                Image(systemName: "tree")
                    .font(.caption)
                    .foregroundStyle(Color.appGreen)
                Text(ref)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                if qsoCount >= potaThreshold {
                    Image(systemName: "checkmark")
                        .font(.caption2.bold())
                        .foregroundStyle(Color.appGreen)
                } else {
                    Text("\(qsoCount)/\(potaThreshold)")
                        .font(.caption.monospacedDigit().bold())
                        .foregroundStyle(Color.appOrange)
                }
            }
        }

        if let ref = log.sotaReference {
            HStack(spacing: 3) {
                Image(systemName: "mountain.2")
                    .font(.caption)
                    .foregroundStyle(Color.appBlue)
                Text(ref)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                if qsoCount >= sotaThreshold {
                    Image(systemName: "checkmark")
                        .font(.caption2.bold())
                        .foregroundStyle(Color.appBlue)
                } else {
                    Text("\(qsoCount)/\(sotaThreshold)")
                        .font(.caption.monospacedDigit().bold())
                        .foregroundStyle(Color.appOrange)
                }
            }
        }
    }
}
