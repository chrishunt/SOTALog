import SwiftUI

struct SpotRowView: View {
    let spot: Spot

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(spot.activatorCallsign)
                    .font(.headline.monospaced())
                    .strikethrough(spot.isQRT)
                    .opacity(spot.isExpired() ? 0.5 : 1.0)

                Spacer()

                Text(String(format: "%.3f", spot.frequency))
                    .font(.subheadline.monospacedDigit())

                Text(spot.band)
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.12), in: Capsule())
            }

            HStack {
                Image(systemName: spot.source == .pota ? "tree" : "mountain.2")
                    .font(.caption)
                    .foregroundStyle(spot.source == .pota ? .green : .blue)

                Text(spot.reference)
                    .font(.caption.monospaced())

                if let name = spot.referenceName {
                    Text(name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                if spot.isQRT {
                    Text("QRT")
                        .font(.caption2.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.red, in: Capsule())
                }

                Text("\(spot.ageMinutes)m ago")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if let comments = spot.comments, !comments.isEmpty {
                Text(comments)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
    }
}
