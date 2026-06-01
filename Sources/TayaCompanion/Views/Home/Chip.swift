import SwiftUI

/// Pill-shaped chip used for Places and Themes on Today. White surface
/// with a soft shadow. Optional leading SF Symbol — used by Places to
/// show a location arrow.
struct Chip: View {
    let text: String
    var systemImage: String? = nil
    var onTap: () -> Void = {}

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 5) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(Theme.homeIcon)
                }
                Text(text)
                    .font(Theme.bodyS())
                    .foregroundStyle(Theme.primaryText)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .tayaGlassCard(in: Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

/// Wrapping flow of chips that hugs each chip's intrinsic width — no
/// dead space between narrow items like LazyVGrid produces. Pass
/// `systemImage` to apply a leading SF Symbol to every chip in the flow.
struct ChipFlow: View {
    let items: [String]
    var systemImage: String? = nil
    var onTap: (String) -> Void = { _ in }

    var body: some View {
        FlowLayout(horizontalSpacing: 8, verticalSpacing: 8) {
            ForEach(items, id: \.self) { item in
                Chip(text: item, systemImage: systemImage) {
                    onTap(item)
                }
            }
        }
    }
}

/// Left-to-right wrapping layout. Each row consumes the parent's width
/// and wraps when the next subview would overflow.
struct FlowLayout: Layout {
    var horizontalSpacing: CGFloat = 8
    var verticalSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        let rows = rows(in: maxWidth, subviews: subviews)
        let height = rows.reduce(into: CGFloat(0)) { total, row in
            total += row.height
        } + CGFloat(max(0, rows.count - 1)) * verticalSpacing
        return CGSize(width: maxWidth, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = rows(in: bounds.width, subviews: subviews)
        var y = bounds.minY
        for row in rows {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(
                    at: CGPoint(x: x, y: y + (row.height - size.height) / 2),
                    proposal: ProposedViewSize(size)
                )
                x += size.width + horizontalSpacing
            }
            y += row.height + verticalSpacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func rows(in maxWidth: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = [Row()]
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let widthIfAdded = (rows[rows.count - 1].width == 0)
                ? size.width
                : rows[rows.count - 1].width + horizontalSpacing + size.width
            if widthIfAdded > maxWidth, !rows[rows.count - 1].indices.isEmpty {
                rows.append(Row())
                rows[rows.count - 1].indices.append(index)
                rows[rows.count - 1].width = size.width
                rows[rows.count - 1].height = size.height
            } else {
                rows[rows.count - 1].indices.append(index)
                rows[rows.count - 1].width = widthIfAdded
                rows[rows.count - 1].height = max(rows[rows.count - 1].height, size.height)
            }
        }
        return rows
    }
}
