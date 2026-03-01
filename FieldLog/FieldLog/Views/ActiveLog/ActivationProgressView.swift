import SwiftUI

struct ActivationProgressView: View {
    let count: Int
    let threshold: Int
    let label: String

    private var isComplete: Bool { count >= threshold }

    var body: some View {
        HStack(spacing: 4) {
            Text("\(count)/\(threshold)")
                .font(.title3.monospacedDigit().bold())
            Text(label)
                .font(.caption.bold())
        }
        .foregroundStyle(isComplete ? .green : (count > 0 ? .orange : .secondary))
    }
}
