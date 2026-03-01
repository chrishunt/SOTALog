import SwiftUI

/// Single capsule showing QSO count and activation progress.
///
/// - No activation: count only in secondary
/// - Single POTA: count | tree icon + progress
/// - Single SOTA: count | mountain icon + progress
/// - Dual: count | per-program indicator (checkmark when met, progress when not)
struct ActivationStatusView: View {
    let count: Int
    let isPOTA: Bool
    let isSOTA: Bool

    private let potaThreshold = 10
    private let sotaThreshold = 4

    private var potaComplete: Bool { count >= potaThreshold }
    private var sotaComplete: Bool { count >= sotaThreshold }

    private var hasActivation: Bool { isPOTA || isSOTA }

    /// Orange if any activation incomplete, green only when all met.
    private var capsuleColor: Color {
        guard hasActivation else { return .secondary }
        if isPOTA && !potaComplete { return .orange }
        if isSOTA && !sotaComplete { return .orange }
        return .green
    }

    var body: some View {
        HStack(spacing: 6) {
            Text("\(count)")
                .font(.title3.monospacedDigit().bold())
                .foregroundStyle(hasActivation ? .primary : .secondary)

            if hasActivation {
                divider

                if isPOTA && isSOTA {
                    dualIndicators
                } else if isPOTA {
                    potaIndicator
                } else {
                    sotaIndicator
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(capsuleColor.opacity(0.12), in: Capsule())
    }

    // MARK: - Single indicators

    private var potaIndicator: some View {
        HStack(spacing: 3) {
            if potaComplete {
                Image(systemName: "checkmark")
                    .font(.caption2.bold())
            }
            Image(systemName: "tree")
                .font(.caption)
            if !potaComplete {
                Text("\(count)/\(potaThreshold)")
                    .font(.caption.monospacedDigit().bold())
            }
        }
        .foregroundStyle(potaComplete ? .green : .orange)
    }

    private var sotaIndicator: some View {
        HStack(spacing: 3) {
            if sotaComplete {
                Image(systemName: "checkmark")
                    .font(.caption2.bold())
            }
            Image(systemName: "mountain.2")
                .font(.caption)
            if !sotaComplete {
                Text("\(count)/\(sotaThreshold)")
                    .font(.caption.monospacedDigit().bold())
            }
        }
        .foregroundStyle(sotaComplete ? .blue : .orange)
    }

    // MARK: - Dual indicators

    private var dualIndicators: some View {
        HStack(spacing: 6) {
            dualPotaChip
            divider
            dualSotaChip
        }
    }

    private var dualPotaChip: some View {
        HStack(spacing: 3) {
            if potaComplete {
                Image(systemName: "checkmark")
                    .font(.caption2.bold())
            }
            Image(systemName: "tree")
                .font(.caption)
            if !potaComplete {
                Text("\(count)/\(potaThreshold)")
                    .font(.caption.monospacedDigit().bold())
            }
        }
        .foregroundStyle(potaComplete ? .green : .orange)
    }

    private var dualSotaChip: some View {
        HStack(spacing: 3) {
            if sotaComplete {
                Image(systemName: "checkmark")
                    .font(.caption2.bold())
            }
            Image(systemName: "mountain.2")
                .font(.caption)
            if !sotaComplete {
                Text("\(count)/\(sotaThreshold)")
                    .font(.caption.monospacedDigit().bold())
            }
        }
        .foregroundStyle(sotaComplete ? .blue : .orange)
    }

    // MARK: - Helpers

    private var divider: some View {
        Rectangle()
            .fill(.quaternary)
            .frame(width: 1, height: 16)
    }
}
