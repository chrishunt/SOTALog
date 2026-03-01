import SwiftUI

/// Inline status display with labeled QSO count and per-reference progress.
///
/// Color is used only on the progress indicator (fraction or checkmark),
/// keeping references neutral so status pops at a glance.
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
            // Labeled QSO count
            HStack(spacing: 3) {
                Text("\(count)")
                    .font(.title3.monospacedDigit().bold())
                Text("QSOs")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let ref = potaReference {
                potaBlock(ref)
            }

            if let ref = sotaReference {
                sotaBlock(ref)
            }
        }
    }

    // MARK: - Reference blocks

    private func potaBlock(_ reference: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: "tree")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(reference)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
            if potaComplete {
                Image(systemName: "checkmark")
                    .font(.caption2.bold())
                    .foregroundStyle(.green)
            } else {
                Text("\(count)/\(potaThreshold)")
                    .font(.caption.monospacedDigit().bold())
                    .foregroundStyle(.orange)
            }
        }
    }

    private func sotaBlock(_ reference: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: "mountain.2")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(reference)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
            if sotaComplete {
                Image(systemName: "checkmark")
                    .font(.caption2.bold())
                    .foregroundStyle(.blue)
            } else {
                Text("\(count)/\(sotaThreshold)")
                    .font(.caption.monospacedDigit().bold())
                    .foregroundStyle(.orange)
            }
        }
    }
}
