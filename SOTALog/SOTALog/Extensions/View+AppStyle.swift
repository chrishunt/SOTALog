import SwiftUI

// MARK: - Badge Modifier

extension View {
    /// Band/mode capsule badge used in spot rows, QSO rows, and log rows.
    func appBadge() -> some View {
        self
            .font(.appLabel)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.accentColor.opacity(0.12), in: Capsule())
    }
}

// MARK: - Reference Icon

/// Tree or mountain icon with semantic color and accessibility label.
struct AppReferenceIcon: View {
    enum ReferenceType {
        case pota, sota
    }

    let type: ReferenceType

    var body: some View {
        Image(systemName: type == .pota ? "tree" : "mountain.2")
            .font(.appLabel)
            .foregroundStyle(type == .pota ? Color.appGreen : Color.appBlue)
            .accessibilityLabel(type == .pota ? "POTA" : "SOTA")
    }
}

// MARK: - Activation Progress

/// Checkmark-or-fraction indicator for activation thresholds.
struct AppActivationProgress: View {
    let count: Int
    let threshold: Int
    let completeColor: Color

    var body: some View {
        if count >= threshold {
            Image(systemName: "checkmark")
                .font(.appBadgeSmall)
                .foregroundStyle(completeColor)
        } else {
            Text("\(count)/\(threshold)")
                .font(.appProgress)
                .foregroundStyle(Color.appOrange)
        }
    }
}
