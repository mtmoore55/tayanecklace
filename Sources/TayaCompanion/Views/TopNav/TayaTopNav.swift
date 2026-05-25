import SwiftUI
import TayaIntelligence

/// Top navigation bar with five items. The active item is expanded to a
/// pill (icon + label); the rest are compact circles. Animation is driven
/// by `progress` (fractional page index from the pager).
///
/// Icons are *ambient* — `.user` shows the user's initial, `.necklace`
/// shows a battery glyph matching the live %, `.today` shows weather.
struct TayaTopNav: View {
    let progress: Double
    var ambient: AmbientState = .mock
    let onTap: (AppTab) -> Void

    private let horizontalPadding: CGFloat = 20
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
        let compactCount = count - 1
        let compactTotal = compactWidth * CGFloat(compactCount)
        let expandedWidth = max(compactWidth, usableWidth - compactTotal - gapsTotal)

        return HStack(spacing: itemSpacing) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                NavItem(
                    tab: tab,
                    expandedness: expandedness(for: tab),
                    expandedWidth: expandedWidth,
                    icon: icon(for: tab),
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

    /// Per-tab icon view. Some tabs render dynamic glyphs based on
    /// `ambient` instead of a static SF Symbol.
    @ViewBuilder
    private func icon(for tab: AppTab) -> some View {
        switch tab {
        case .user:
            Text(ambient.userInitial)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(TayaColors.oxfordBlue)
        case .necklace:
            Image(systemName: batterySystemImage(forPercent: ambient.necklaceBattery))
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(TayaColors.oxfordBlue)
        case .today:
            Image(systemName: ambient.weather.systemImage)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(TayaColors.oxfordBlue)
        case .chats:
            Image(systemName: tab.iconSystemName)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(TayaColors.oxfordBlue)
        case .moments:
            Image(systemName: tab.iconSystemName)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(TayaColors.oxfordBlue)
        }
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
