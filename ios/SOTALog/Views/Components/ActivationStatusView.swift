import SwiftUI

/// Inline status display with labeled QSO count and per-reference progress.
///
/// Reference icons use semantic colors (tree=green, mountain=blue) for
/// instant recognition. Progress indicators use orange/green/blue.
///
/// - No activation: `5 QSOs` (secondary)
/// - POTA incomplete: `5 QSOs  🌲 US-4431  5/10` (fraction orange)
/// - POTA complete: `12 QSOs  🌲 US-4431  ✓` (checkmark green)
/// - SOTA complete: `6 QSOs  ⛰️ W4C/CM-001  ✓` (checkmark blue)
/// - Dual mixed: both blocks, each with its own progress color
struct ActivationStatusView: View {
    let count: Int
    let potaReference: String?
    let sotaReference: String?

    private let potaThreshold = 10
    private let sotaThreshold = 4

    private var potaComplete: Bool { count >= potaThreshold }
    private var sotaComplete: Bool { count >= sotaThreshold }
    private var hasActivation: Bool { potaReference != nil || sotaReference != nil }

    var body: some View {
        HStack(spacing: 6) {
            HStack(spacing: 3) {
                Text("\(count)")
                    .font(.appSectionHeader)
                Text("QSOs")
                    .font(.appLabel)
                    .foregroundStyle(Color.appTextSecondary)
            }

            if let ref = potaReference {
                potaBlock(ref)
            }

            if let ref = sotaReference {
                sotaBlock(ref)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    private var accessibilityDescription: String {
        var parts = ["\(count) QSOs"]
        if let ref = potaReference {
            parts.append("POTA \(ref) \(potaComplete ? "complete" : "\(count) of \(potaThreshold)")")
        }
        if let ref = sotaReference {
            parts.append("SOTA \(ref) \(sotaComplete ? "complete" : "\(count) of \(sotaThreshold)")")
        }
        return parts.joined(separator: ", ")
    }

    // MARK: - Reference blocks

    private func potaBlock(_ reference: String) -> some View {
        HStack(spacing: 3) {
            AppReferenceIcon(type: .pota)
            Text(reference)
                .font(.appReferenceCode)
                .foregroundStyle(Color.appTextSecondary)
            AppActivationProgress(count: count, threshold: potaThreshold, completeColor: Color.appGreen)
        }
    }

    private func sotaBlock(_ reference: String) -> some View {
        HStack(spacing: 3) {
            AppReferenceIcon(type: .sota)
            Text(reference)
                .font(.appReferenceCode)
                .foregroundStyle(Color.appTextSecondary)
            AppActivationProgress(count: count, threshold: sotaThreshold, completeColor: Color.appBlue)
        }
    }
}
