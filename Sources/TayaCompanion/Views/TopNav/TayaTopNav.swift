import SwiftUI

/// Top navigation bar with five items. The active item is expanded to a
/// pill (icon + label); the rest are compact circles. Animation is driven
/// by `progress` (fractional page index from the pager), so the pill
/// smoothly tracks the user's finger during a swipe.
struct TayaTopNav: View {
    let progress: Double
    let onTap: (AppTab) -> Void

    private let horizontalPadding: CGFloat = 20   // matches card padding
    private let topPadding: CGFloat = 6
    private let bottomPadding: CGFloat = 10
    private let itemSpacing: CGFloat = 6
    private let compactWidth: CGFloat = 36
    private let height: CGFloat = 36

    var body: some View {
        GeometryReader { geom in
            navRow(containerWidth: geom.size.width)
        }
        .frame(height: height + topPadding + bottomPadding)
        .background(Theme.background)
    }

    private func navRow(containerWidth: CGFloat) -> some View {
        let count = AppTab.allCases.count
        let usableWidth = containerWidth - (horizontalPadding * 2)
        let gapsTotal = itemSpacing * CGFloat(count - 1)
        let compactCount = count - 1                     // one slot expands; rest are compact
        let compactTotal = compactWidth * CGFloat(compactCount)
        let expandedWidth = max(compactWidth, usableWidth - compactTotal - gapsTotal)

        return HStack(spacing: itemSpacing) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                NavItem(
                    tab: tab,
                    expandedness: expandedness(for: tab),
                    expandedWidth: expandedWidth,
                    onTap: { onTap(tab) }
                )
            }
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.top, topPadding)
        .padding(.bottom, bottomPadding)
    }

    private func expandedness(for tab: AppTab) -> Double {
        let idx = Double(tab.index)
        return max(0, 1 - abs(idx - progress))
    }
}

#Preview("Today active") {
    TayaTopNav(progress: 2.0, onTap: { _ in })
        .background(Theme.background)
}

#Preview("Mid swipe (Today → Chats)") {
    TayaTopNav(progress: 2.5, onTap: { _ in })
        .background(Theme.background)
}
