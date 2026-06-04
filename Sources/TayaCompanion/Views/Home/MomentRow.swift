import SwiftUI

/// Compact moment row for the "Recently captured" section. Tappable; the
/// surrounding container wraps it in a NavigationLink to the source moment.
struct MomentRow: View {
    let moment: Moment
    var timeFormat: TimeFormat = .relative
    /// Optional swipe-to-delete action. Surfaces a trailing red Delete
    /// chip on a trailing swipe; commits via the closure (which the
    /// caller maps to `store.deleteMoment(_:)` for the active list).
    var onDelete: (() -> Void)? = nil

    enum TimeFormat {
        /// "today" → clock time; otherwise "yesterday" / "from Sat" / "Mar 12".
        case relative
        /// Always the clock time. Use when an outer section header already
        /// disambiguates the day (e.g. grouped Moments view).
        case timeOnly
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            sourceGlyph
            Text(moment.title)
                .font(Theme.bodyL())
                .foregroundStyle(Theme.primaryText)
                .lineLimit(1)
            if moment.syncStatus == .pending {
                pendingBadge
            }
            Spacer(minLength: 8)
            Text(timeLabel)
                .font(Theme.caption())
                .foregroundStyle(Theme.secondaryText)
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .swipeActions(trailing: trailingSwipeActions)
    }

    private var trailingSwipeActions: [SwipeAction] {
        guard let onDelete else { return [] }
        return [
            SwipeAction(
                label: "Delete",
                systemImage: "trash",
                tint: .red,
                role: .destructive,
                action: onDelete
            )
        ]
    }

    /// Necklace vs phone glyph. Necklace gets the brand sky-blue dotted
    /// ring (it's the headline capture surface); phone captures get a
    /// quieter secondary-tinted handset.
    @ViewBuilder
    private var sourceGlyph: some View {
        switch moment.source {
        case .necklace:
            Image(systemName: "circle.dotted.circle")
                .font(.system(size: 18, weight: .regular))
                .foregroundStyle(TayaColors.skyBlue)
                .frame(width: 22, alignment: .center)
        case .phone:
            Image(systemName: "iphone")
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(Theme.secondaryText)
                .frame(width: 22, alignment: .center)
        }
    }

    private var pendingBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 11, weight: .semibold))
            Text("Pending")
                .font(.system(size: 11, weight: .semibold))
        }
        .foregroundStyle(TayaColors.warningAmber)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(
            Capsule(style: .continuous)
                .fill(TayaColors.warningAmber.opacity(0.15))
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(TayaColors.warningAmber.opacity(0.45), lineWidth: 0.75)
        )
        .accessibilityLabel("Pending sync")
    }

    private var timeLabel: String {
        switch timeFormat {
        case .timeOnly:
            return moment.createdAt.formatted(date: .omitted, time: .shortened)
        case .relative:
            let cal = Calendar.current
            if cal.isDateInToday(moment.createdAt) {
                return moment.createdAt.formatted(date: .omitted, time: .shortened)
            }
            return RelativeDay.label(from: moment.createdAt)
        }
    }
}
