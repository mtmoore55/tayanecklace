import SwiftUI
import TayaIntelligence

/// Top navigation bar with five items. The active item is expanded to a
/// pill (icon + label); the rest are compact circles. Animation is driven
/// by `progress` (fractional page index from the pager).
///
/// During a sync, the necklace slot renders as a small inactive "sync
/// chip" that hugs its content (rotating icon + "N of M"). The active
/// expanded tab keeps its expansion — sync is meant to read as
/// background activity, not the foreground state.
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
    /// Approximate width the sync chip claims (icon + "N of M" + padding).
    private let syncChipWidth: CGFloat = 68

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
        let compactTotal = compactWidth * CGFloat(count - 1)

        // If the necklace is syncing, reserve extra width for the sync chip
        // so the expanded slot (e.g. Today) shrinks just enough to fit.
        let syncExtra: CGFloat = ambient.sync.isActive
            ? (syncChipWidth - compactWidth)
            : 0
        let expandedWidth = max(
            compactWidth,
            usableWidth - compactTotal - syncExtra - gapsTotal
        )

        return HStack(spacing: itemSpacing) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                slot(for: tab, expandedWidth: expandedWidth)
            }
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.top, topPadding)
        .padding(.bottom, bottomPadding)
    }

    /// Renders either the standard NavItem or — when this is the necklace
    /// and we're syncing — a compact inactive sync chip.
    @ViewBuilder
    private func slot(for tab: AppTab, expandedWidth: CGFloat) -> some View {
        if tab == .necklace, ambient.sync.isActive {
            syncChip
        } else {
            NavItem(
                tab: tab,
                label: label(for: tab),
                expandedness: expandedness(for: tab),
                expandedWidth: expandedWidth,
                icon: icon(for: tab),
                onTap: { onTap(tab) }
            )
        }
    }

    /// Inactive (blue50) chip with a rotating icon and "N of total". Sized
    /// to hug its content so the bar still reads as background activity.
    private var syncChip: some View {
        HStack(spacing: 5) {
            TimelineView(.animation) { context in
                let t = context.date.timeIntervalSinceReferenceDate
                let angle = (t * 360.0 / 1.1).truncatingRemainder(dividingBy: 360)
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(Theme.accent)
                    .rotationEffect(.degrees(angle))
            }

            if case .syncing(let current, let total) = ambient.sync {
                Text("\(current) of \(total)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.accent)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
        }
        .padding(.horizontal, 10)
        .frame(height: height)
        .background(Capsule(style: .continuous).fill(Theme.blue50))
        .accessibilityLabel("Syncing")
    }

    /// Per-tab label. `.today` swaps to "Tonight" at night.
    private func label(for tab: AppTab) -> String {
        switch tab {
        case .today: return ambient.isNight ? "Tonight" : tab.label()
        default:     return tab.label()
        }
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
                .foregroundStyle(Theme.accent)
        case .necklace:
            Image(systemName: batterySystemImage(forPercent: ambient.necklaceBattery))
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(Theme.accent)
        case .today:
            Image(systemName: ambient.isNight ? "moon.stars" : ambient.weather.systemImage)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(Theme.accent)
        case .chats:
            Image(systemName: tab.iconSystemName)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(Theme.accent)
        case .moments:
            Image(systemName: tab.iconSystemName)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(Theme.accent)
        }
    }
}

#Preview("Today active") {
    TayaTopNav(progress: 2.0, onTap: { _ in })
        .background(Theme.background)
}

#Preview("Syncing") {
    TayaTopNav(
        progress: 2.0,
        ambient: AmbientState(sync: .syncing(current: 1, total: 2)),
        onTap: { _ in }
    )
    .background(Theme.background)
}
