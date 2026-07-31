import SwiftUI

/// Leading-aligned wrapping layout. Each subview keeps its natural size and
/// overflow moves to the next row — chips wrap instead of truncating.
/// A subview wider than the container is clamped to the container width so
/// its text truncates rather than overflowing the bounds.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6
    var rowSpacing: CGFloat = 4

    /// Fraction of the container width a subview may occupy before its text
    /// truncates. Data chips keep the default 1; prose chips (e.g. a long name)
    /// set a smaller cap so a single value can't hog a whole row.
    struct MaxWidthFraction: LayoutValueKey {
        static let defaultValue: CGFloat = 1
    }

    struct Row: Equatable {
        var range: Range<Int>
        var width: CGFloat
        var height: CGFloat
    }

    /// Greedy row-breaking over subview sizes. Internal for unit testing.
    static func computeRows(sizes: [CGSize], maxWidth: CGFloat, spacing: CGFloat) -> [Row] {
        var rows: [Row] = []
        var start = 0
        var width: CGFloat = 0
        var height: CGFloat = 0
        for (index, size) in sizes.enumerated() {
            let isFirstInRow = index == start
            let widthIfAdded = isFirstInRow ? size.width : width + spacing + size.width
            if !isFirstInRow && widthIfAdded > maxWidth {
                rows.append(Row(range: start..<index, width: width, height: height))
                start = index
                width = size.width
                height = size.height
            } else {
                width = widthIfAdded
                height = max(height, size.height)
            }
        }
        if start < sizes.count {
            rows.append(Row(range: start..<sizes.count, width: width, height: height))
        }
        return rows
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = finiteWidth(from: proposal) ?? .infinity
        let sizes = chipSizes(subviews, maxWidth: maxWidth)
        let rows = Self.computeRows(sizes: sizes, maxWidth: maxWidth, spacing: spacing)
        let height = rows.reduce(0) { $0 + $1.height } + rowSpacing * CGFloat(max(0, rows.count - 1))
        let width = finiteWidth(from: proposal) ?? (rows.map(\.width).max() ?? 0)
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let sizes = chipSizes(subviews, maxWidth: bounds.width)
        let rows = Self.computeRows(sizes: sizes, maxWidth: bounds.width, spacing: spacing)
        var y = bounds.minY
        for row in rows {
            var x = bounds.minX
            for index in row.range {
                let size = sizes[index]
                subviews[index].place(
                    at: CGPoint(x: x, y: y + (row.height - size.height) / 2),
                    proposal: ProposedViewSize(size)
                )
                x += size.width + spacing
            }
            y += row.height + rowSpacing
        }
    }

    private func chipSizes(_ subviews: Subviews, maxWidth: CGFloat) -> [CGSize] {
        subviews.map { subview in
            let cap = maxWidth.isFinite ? maxWidth * subview[MaxWidthFraction.self] : maxWidth
            return clamped(subview.sizeThatFits(.unspecified), to: cap)
        }
    }

    private func finiteWidth(from proposal: ProposedViewSize) -> CGFloat? {
        guard let width = proposal.width, width.isFinite else { return nil }
        return width
    }

    private func clamped(_ size: CGSize, to maxWidth: CGFloat) -> CGSize {
        CGSize(width: min(size.width, maxWidth), height: size.height)
    }
}
