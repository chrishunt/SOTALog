import SwiftUI

struct SpotRowView: View {
    let spot: Spot
    var isWorked: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(spot.activatorCallsign)
                    .font(.headline.monospaced())
                    .strikethrough(isWorked)

                Spacer()

                Text(String(format: "%.3f", spot.frequency))
                    .font(.subheadline.monospacedDigit())

                Text("\(spot.ageMinutes)m")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 6) {
                referenceInfo

                Spacer()

                Text(spot.band.uppercased())
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.12), in: Capsule())
            }

            if let comments = spot.comments, !comments.isEmpty {
                Text(comments)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
        .opacity(isWorked ? 0.4 : 1.0)
    }

    @ViewBuilder
    private var referenceInfo: some View {
        if let potaRef = spot.potaReference {
            Image(systemName: "tree")
                .font(.caption)
                .foregroundStyle(Color.appGreen)
                .accessibilityLabel("POTA")
            Text(potaRef)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
            if let name = spot.potaReferenceName, spot.sotaReference == nil {
                Text(name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }

        if let sotaRef = spot.sotaReference {
            Image(systemName: "mountain.2")
                .font(.caption)
                .foregroundStyle(Color.appBlue)
                .accessibilityLabel("SOTA")
            Text(sotaRef)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
            if let name = spot.sotaReferenceName, spot.potaReference == nil {
                Text(name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }
}
