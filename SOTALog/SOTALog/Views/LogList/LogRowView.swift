import SwiftUI

struct LogRowView: View {
    let log: Log
    let qsoCount: Int
    let bands: [String]
    let allSyncedToQRZ: Bool

    private let potaThreshold = 10
    private let sotaThreshold = 4

    private var hasReferences: Bool { log.potaReference != nil || log.sotaReference != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(log.myCallsign)
                    .font(.appCallsign)

                Spacer()

                Text(log.formattedDate)
                    .font(.appLabel)
                    .foregroundStyle(Color.appTextSecondary)
            }

            if hasReferences {
                HStack(spacing: 6) {
                    referenceBlocks

                    Spacer()

                    if allSyncedToQRZ {
                        AppQRZBadge()
                    }

                    ForEach(bands, id: \.self) { band in
                        Text(band.uppercased())
                            .appBadge()
                    }
                }

                HStack(spacing: 4) {
                    Text("\(qsoCount)")
                        .font(.appProgress)
                        .foregroundStyle(Color.appTextSecondary)
                    Text("QSOs")
                        .font(.appLabel)
                        .foregroundStyle(Color.appTextSecondary)

                    if let names = referenceNames {
                        Text("·")
                            .font(.appLabel)
                            .foregroundStyle(Color.appTextTertiary)
                        Text(names)
                            .font(.appLabel)
                            .foregroundStyle(Color.appTextTertiary)
                            .lineLimit(1)
                    }
                }
            } else {
                HStack(spacing: 4) {
                    Text("\(qsoCount)")
                        .font(.appProgress)
                        .foregroundStyle(Color.appTextSecondary)
                    Text("QSOs")
                        .font(.appLabel)
                        .foregroundStyle(Color.appTextSecondary)

                    Spacer()

                    if allSyncedToQRZ {
                        AppQRZBadge()
                    }

                    ForEach(bands, id: \.self) { band in
                        Text(band.uppercased())
                            .appBadge()
                    }
                }
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
                AppReferenceIcon(type: .pota)
                Text(ref)
                    .font(.appReferenceCode)
                    .foregroundStyle(Color.appTextSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                AppActivationProgress(count: qsoCount, threshold: potaThreshold, completeColor: Color.appGreen)
            }
        }

        if let ref = log.sotaReference {
            HStack(spacing: 3) {
                AppReferenceIcon(type: .sota)
                Text(ref)
                    .font(.appReferenceCode)
                    .foregroundStyle(Color.appTextSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                AppActivationProgress(count: qsoCount, threshold: sotaThreshold, completeColor: Color.appBlue)
            }
        }
    }
}
