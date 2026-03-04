import SwiftUI

struct SpotRowView: View {
    let spot: Spot
    var isWorked: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(spot.activatorCallsign)
                    .font(.appCallsign)
                    .strikethrough(isWorked)

                Spacer()

                Text(String(format: "%.3f", spot.frequency))
                    .font(.appFrequency)

                Text("\(spot.ageMinutes)m")
                    .font(.appLabel)
                    .foregroundStyle(Color.appTextSecondary)
            }

            HStack(spacing: 6) {
                referenceInfo

                Spacer()

                Text("\(spot.band.uppercased()) \(spot.mode)")
                    .appBadge()
            }

            if let comments = spot.comments, !comments.isEmpty {
                Text(comments)
                    .font(.appLabel)
                    .foregroundStyle(Color.appTextTertiary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
        .opacity(isWorked ? 0.4 : 1.0)
    }

    @ViewBuilder
    private var referenceInfo: some View {
        if let potaRef = spot.potaReference {
            AppReferenceIcon(type: .pota)
            Text(potaRef)
                .font(.appReferenceCode)
                .foregroundStyle(Color.appTextSecondary)
            if let name = spot.potaReferenceName, spot.sotaReference == nil {
                Text(name)
                    .font(.appLabel)
                    .foregroundStyle(Color.appTextSecondary)
                    .lineLimit(1)
            }
        }

        if let sotaRef = spot.sotaReference {
            AppReferenceIcon(type: .sota)
            Text(sotaRef)
                .font(.appReferenceCode)
                .foregroundStyle(Color.appTextSecondary)
            if let name = spot.sotaReferenceName, spot.potaReference == nil {
                Text(name)
                    .font(.appLabel)
                    .foregroundStyle(Color.appTextSecondary)
                    .lineLimit(1)
            }
        }
    }
}
