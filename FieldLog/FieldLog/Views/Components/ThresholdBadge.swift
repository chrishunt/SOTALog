import SwiftUI

/// Colored count badge showing activation progress (e.g. "7/10 POTA").
struct ThresholdBadge: View {
    let count: Int
    let threshold: Int
    let label: String

    private var isComplete: Bool { count >= threshold }

    private var color: Color {
        if isComplete { return .green }
        if count > 0 { return .orange }
        return .secondary
    }

    var body: some View {
        HStack(spacing: 4) {
            Text("\(count)/\(threshold)")
                .font(.title3.monospacedDigit().bold())
            Text(label)
                .font(.caption.bold())
        }
        .foregroundStyle(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(color.opacity(0.12), in: Capsule())
    }
}
